//! Discovery runs on a worker; each native module is probed by a disposable child process.

use std::{
    collections::{HashMap, HashSet, VecDeque},
    fs,
    hash::{Hash, Hasher},
    ops::ControlFlow,
    path::{Path, PathBuf},
    process::{Command, Stdio},
    sync::{
        atomic::{AtomicBool, Ordering},
        mpsc,
    },
    time::{Duration, Instant, UNIX_EPOCH},
};

use rayon::prelude::*;
use serde::{Deserialize, Serialize};

use crate::{HostError, PluginDescriptor, PluginFormat, PluginIdentity};

/// JSON request/response and cache schema version shared with the scanner helper.
pub const SCANNER_PROTOCOL_VERSION: u32 = 1;
const MAX_RESULT_BYTES: u64 = 16 * 1024 * 1024;

// =============================================================================
// Parallelism guardrails
// =============================================================================
// Parallel work only pays off when there is enough of it to amortize thread
// hand-off. Below these thresholds the single-threaded path is used unchanged.

/// Entries seen within the first [`DISCOVERY_SAMPLE_DEPTH`] levels before discovery forks.
const PARALLEL_DISCOVERY_MIN_ENTRIES: usize = 64;
/// Levels below each root sampled when estimating the discovery workload.
const DISCOVERY_SAMPLE_DEPTH: usize = 2;
/// A directory needs at least this many children before its subtrees are walked in parallel.
const PARALLEL_DISCOVERY_FORK_MIN_ENTRIES: usize = 8;
/// Modules expected to need a helper probe before probing runs in parallel.
const PARALLEL_PROBE_MIN_MODULES: usize = 4;
/// Module count at which fingerprinting alone is enough work to run in parallel.
const PARALLEL_FINGERPRINT_MIN_MODULES: usize = 64;
/// Upper bound on concurrent probe helpers, since each one loads a native plugin binary.
const MAX_PARALLEL_SCAN_WORKERS: usize = 4;

/// Probes one canonical module path within a timeout, honouring cooperative cancellation.
pub type ModuleProbe<'a> =
    dyn Fn(&Path, Duration, &AtomicBool) -> Result<Vec<PluginDescriptor>, HostError> + Sync + 'a;

/// Format-specific half of a scan: which paths are modules, and how one is probed.
///
/// Discovery, fingerprinting, the cache, quarantine, and progress reporting are shared by all
/// formats.
#[derive(Clone, Copy)]
pub struct ModuleScanner<'a> {
    /// Format every descriptor returned by `probe` must carry.
    pub format: PluginFormat,
    /// File or directory extension that marks one module, without its dot.
    pub extension: &'a str,
    /// Reads the plugin classes of one module.
    pub probe: &'a ModuleProbe<'a>,
}

/// Builds the probe that runs the isolated scanner helper for each `format` module.
pub fn helper_probe(
    helper: &Path,
    format: PluginFormat,
) -> impl Fn(&Path, Duration, &AtomicBool) -> Result<Vec<PluginDescriptor>, HostError> + Sync + '_ {
    move |module, timeout, cancelled| probe_module(helper, format, module, timeout, cancelled)
}

/// Value of the helper's `--format` argument for `format`.
pub const fn format_argument(format: PluginFormat) -> &'static str {
    match format {
        PluginFormat::Vst3 => "vst3",
        PluginFormat::Lv2 => "lv2",
        PluginFormat::Clap => "clap",
    }
}

/// Result file written by one isolated helper process after probing a module.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ProbeResponse {
    /// Scanner protocol version used to encode this response.
    pub version: u32,
    /// Valid plugin classes discovered in the requested module.
    pub plugins: Vec<PluginDescriptor>,
    /// Helper-side load or enumeration failure, if probing could not complete.
    pub error: Option<String>,
}

/// Roots and per-module timeout used by a discovery scan.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ScanSettings {
    /// Directory trees searched recursively for plugin modules.
    pub directories: Vec<PathBuf>,
    /// Maximum seconds allowed for each isolated helper process.
    pub timeout_seconds: u64,
}

impl Default for ScanSettings {
    fn default() -> Self {
        Self {
            directories: Vec::new(),
            timeout_seconds: 30,
        }
    }
}

/// Cached result for one canonical module path and filesystem fingerprint.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CachedModule {
    /// Hash of canonical paths, sizes, and modification times in the module bundle.
    pub fingerprint: u64,
    /// Last descriptors successfully returned for this module.
    pub plugins: Vec<PluginDescriptor>,
    /// Most recent probe failure; quarantined modules are excluded from the catalog.
    pub quarantine: Option<String>,
}

/// Persisted discovery cache and duplicate-installation preference table.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ScanCache {
    /// Cache schema version; incompatible files are discarded on load.
    pub version: u32,
    /// Canonical module path to cached fingerprint and descriptors.
    pub modules: HashMap<PathBuf, CachedModule>,
    /// Format/native-ID key to the selected installation path.
    pub preferred_locations: HashMap<String, PathBuf>,
}

impl Default for ScanCache {
    fn default() -> Self {
        Self {
            version: SCANNER_PROTOCOL_VERSION,
            modules: HashMap::new(),
            preferred_locations: HashMap::new(),
        }
    }
}

impl ScanCache {
    /// Last confirmed descriptors, retaining the selected location when duplicate modules exist.
    pub fn catalog(&self) -> Vec<PluginDescriptor> {
        let mut modules: Vec<_> = self.modules.iter().collect();
        modules.sort_by_key(|(path, _)| *path);
        let mut plugins: Vec<PluginDescriptor> = Vec::new();
        let mut identities = HashMap::new();
        for (path, module) in modules {
            if module.quarantine.is_some() {
                continue;
            }
            for plugin in &module.plugins {
                if let Some(&index) = identities.get(&plugin.identity) {
                    if self
                        .preferred_locations
                        .get(&identity_key(&plugin.identity))
                        == Some(path)
                    {
                        plugins[index] = plugin.clone();
                    }
                } else {
                    identities.insert(plugin.identity.clone(), plugins.len());
                    plugins.push(plugin.clone());
                }
            }
        }
        plugins
    }

    /// Loads a cache, returning an empty cache for a missing file or incompatible version.
    pub fn load(path: &Path) -> Result<Self, HostError> {
        if !path.exists() {
            return Ok(Self::default());
        }
        let cache: Self = serde_json::from_slice(&fs::read(path)?)
            .map_err(|e| HostError::Scanner(e.to_string()))?;
        if cache.version != SCANNER_PROTOCOL_VERSION {
            return Ok(Self::default());
        }
        Ok(cache)
    }

    /// Atomically persists the cache through a synchronized temporary file in the same directory.
    pub fn save(&self, path: &Path) -> Result<(), HostError> {
        let parent = path
            .parent()
            .ok_or_else(|| HostError::Scanner("cache needs a parent directory".into()))?;
        fs::create_dir_all(parent)?;
        let temp = tempfile::NamedTempFile::new_in(parent)?;
        serde_json::to_writer(temp.as_file(), self)
            .map_err(|e| HostError::Scanner(e.to_string()))?;
        temp.as_file().sync_all()?;
        temp.persist(path).map_err(|e| HostError::Io(e.error))?;
        Ok(())
    }
}

/// Progress snapshot emitted after each discovered module is handled.
#[derive(Clone, Debug)]
pub struct ScanProgress {
    /// Number of module paths handled so far.
    pub completed: usize,
    /// Total module paths found before probing began.
    pub total: usize,
    /// Number of de-duplicated plugin classes currently accepted.
    pub discovered: usize,
    /// Module path associated with this update.
    pub path: PathBuf,
    /// Probe, fingerprint, or quarantine diagnostic for this module.
    pub error: Option<String>,
}

/// Aggregate result of a scan, including usable descriptors and per-module failures.
#[derive(Clone, Debug, Default)]
pub struct ScanResult {
    /// De-duplicated plugin descriptors selected for the catalog.
    pub plugins: Vec<PluginDescriptor>,
    /// Module paths that failed fingerprinting or are currently quarantined.
    pub failures: Vec<(PathBuf, String)>,
    /// Whether cancellation stopped the scan before all modules were handled.
    pub cancelled: bool,
}

/// Resolves the installed helper beside the application, including macOS Contents/MacOS.
pub fn scanner_executable() -> Result<PathBuf, HostError> {
    let application = std::env::current_exe()?;
    let directory = application
        .parent()
        .ok_or_else(|| HostError::Scanner("application directory unavailable".into()))?;
    let name = if cfg!(windows) {
        "digidaw-plugin-scanner.exe"
    } else {
        "digidaw-plugin-scanner"
    };
    let path = directory.join(name);
    if !path.is_file() {
        return Err(HostError::Scanner(format!(
            "scanner helper is missing: {}",
            path.display()
        )));
    }
    Ok(path)
}

/// Recursively discovers canonical modules with `extension` beneath the supplied roots.
///
/// Directory entries are sorted for deterministic traversal, canonical paths prevent cycles and
/// duplicates, missing roots are ignored, and cancellation stops traversal without an error.
/// Large trees are walked in parallel; the returned order is the same either way.
pub fn discover_modules(
    directories: &[PathBuf],
    extension: &str,
    cancelled: &AtomicBool,
) -> Result<Vec<PathBuf>, HostError> {
    if available_workers() > 1
        && discovery_workload_reaches(
            directories,
            extension,
            PARALLEL_DISCOVERY_MIN_ENTRIES,
            cancelled,
        )
    {
        discover_modules_parallel(directories, extension, cancelled)
    } else {
        discover_modules_sequential(directories, extension, cancelled)
    }
}

fn available_workers() -> usize {
    std::thread::available_parallelism().map_or(1, std::num::NonZeroUsize::get)
}

fn is_module(path: &Path, extension: &str) -> bool {
    path.extension()
        .is_some_and(|e| e.eq_ignore_ascii_case(extension))
}

/// Breadth-first samples the top of each root and stops as soon as `threshold` entries are seen,
/// so the estimate never costs more than `threshold` directory entries of I/O.
fn discovery_workload_reaches(
    directories: &[PathBuf],
    extension: &str,
    threshold: usize,
    cancelled: &AtomicBool,
) -> bool {
    let mut queue: VecDeque<(PathBuf, usize)> =
        directories.iter().map(|path| (path.clone(), 0)).collect();
    let mut seen: usize = 0;
    while let Some((path, depth)) = queue.pop_front() {
        if cancelled.load(Ordering::Relaxed) {
            return false;
        }
        if is_module(&path, extension) {
            continue;
        }
        let Ok(entries) = fs::read_dir(&path) else {
            continue;
        };
        for entry in entries.flatten() {
            seen = seen.saturating_add(1);
            if seen >= threshold {
                return true;
            }
            let child = entry.path();
            let child_depth = depth.saturating_add(1);
            if child_depth < DISCOVERY_SAMPLE_DEPTH && child.is_dir() {
                queue.push_back((child, child_depth));
            }
        }
    }
    false
}

fn discover_modules_sequential(
    directories: &[PathBuf],
    extension: &str,
    cancelled: &AtomicBool,
) -> Result<Vec<PathBuf>, HostError> {
    fn visit(
        path: &Path,
        extension: &str,
        seen: &mut HashSet<PathBuf>,
        modules: &mut Vec<PathBuf>,
        cancelled: &AtomicBool,
    ) -> Result<(), HostError> {
        if cancelled.load(Ordering::Relaxed) || !path.exists() {
            return Ok(());
        }
        let canonical = fs::canonicalize(path)?;
        if !seen.insert(canonical.clone()) {
            return Ok(());
        }
        if is_module(path, extension) {
            modules.push(canonical);
        } else if path.is_dir() {
            let mut entries = fs::read_dir(path)?
                .map(|e| e.map(|e| e.path()))
                .collect::<Result<Vec<_>, _>>()?;
            entries.sort();
            for entry in entries {
                visit(&entry, extension, seen, modules, cancelled)?;
            }
        }
        Ok(())
    }
    let mut modules = Vec::new();
    let mut seen = HashSet::new();
    for path in directories {
        visit(path, extension, &mut seen, &mut modules, cancelled)?;
    }
    Ok(modules)
}

/// Subtrees are walked independently, so cycles are cut with the ancestor chain instead of a
/// shared visited set. Results are concatenated in sorted order and de-duplicated afterwards,
/// which yields the same first-seen order as the sequential walk.
fn discover_modules_parallel(
    directories: &[PathBuf],
    extension: &str,
    cancelled: &AtomicBool,
) -> Result<Vec<PathBuf>, HostError> {
    fn visit(
        path: &Path,
        extension: &str,
        ancestors: &[PathBuf],
        cancelled: &AtomicBool,
    ) -> Result<Vec<PathBuf>, HostError> {
        if cancelled.load(Ordering::Relaxed) || !path.exists() {
            return Ok(Vec::new());
        }
        let canonical = fs::canonicalize(path)?;
        if ancestors.contains(&canonical) {
            return Ok(Vec::new());
        }
        if is_module(path, extension) {
            return Ok(vec![canonical]);
        }
        if !path.is_dir() {
            return Ok(Vec::new());
        }
        let mut entries = fs::read_dir(path)?
            .map(|e| e.map(|e| e.path()))
            .collect::<Result<Vec<_>, _>>()?;
        entries.sort();
        let mut chain = ancestors.to_vec();
        chain.push(canonical);
        let nested = if entries.len() >= PARALLEL_DISCOVERY_FORK_MIN_ENTRIES {
            entries
                .par_iter()
                .map(|entry| visit(entry, extension, &chain, cancelled))
                .collect::<Result<Vec<_>, _>>()?
        } else {
            entries
                .iter()
                .map(|entry| visit(entry, extension, &chain, cancelled))
                .collect::<Result<Vec<_>, _>>()?
        };
        Ok(nested.concat())
    }
    let per_root = directories
        .par_iter()
        .map(|root| visit(root, extension, &[], cancelled))
        .collect::<Result<Vec<_>, _>>()?;
    let mut seen = HashSet::new();
    Ok(per_root
        .into_iter()
        .flatten()
        .filter(|module| seen.insert(module.clone()))
        .collect())
}

/// Hashes a module's canonical paths, file sizes, and modification times recursively.
///
/// The fingerprint detects bundle changes without reading plugin binaries into memory. Directory
/// traversal is sorted and canonical-path tracking prevents cycles.
pub fn module_fingerprint(path: &Path) -> Result<u64, HostError> {
    fn visit(
        path: &Path,
        hash: &mut std::hash::DefaultHasher,
        seen: &mut HashSet<PathBuf>,
    ) -> Result<(), HostError> {
        path.hash(hash);
        let canonical = fs::canonicalize(path)?;
        canonical.hash(hash);
        if !seen.insert(canonical) {
            return Ok(());
        }
        let metadata = fs::metadata(path)?;
        metadata.len().hash(hash);
        metadata
            .modified()?
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos()
            .hash(hash);
        if metadata.is_dir() {
            let mut entries = fs::read_dir(path)?
                .map(|e| e.map(|e| e.path()))
                .collect::<Result<Vec<_>, _>>()?;
            entries.sort();
            for entry in entries {
                visit(&entry, hash, seen)?;
            }
        }
        Ok(())
    }
    let mut hash = std::hash::DefaultHasher::new();
    visit(path, &mut hash, &mut HashSet::new())?;
    Ok(hash.finish())
}

/// Probes one `format` module in an isolated helper process.
///
/// Cancelling or timing out always kills and reaps the child before returning.
pub fn probe_module(
    helper: &Path,
    format: PluginFormat,
    module: &Path,
    timeout: Duration,
    cancelled: &AtomicBool,
) -> Result<Vec<PluginDescriptor>, HostError> {
    if cancelled.load(Ordering::Relaxed) {
        return Err(HostError::Cancelled);
    }
    let directory = tempfile::tempdir()?;
    let result_path = directory.path().join("result.json");
    let mut child = Command::new(helper)
        .arg("--module")
        .arg(module)
        .arg("--result")
        .arg(&result_path)
        .arg("--format")
        .arg(format_argument(format))
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()?;
    let start = Instant::now();
    loop {
        if cancelled.load(Ordering::Relaxed) || start.elapsed() >= timeout {
            drop(child.kill());
            child.wait()?;
            return Err(HostError::Scanner(
                if cancelled.load(Ordering::Relaxed) {
                    "cancelled"
                } else {
                    "probe timed out"
                }
                .into(),
            ));
        }
        match child.try_wait() {
            Ok(Some(status)) => {
                if !status.success() {
                    return Err(HostError::Scanner(format!("probe terminated: {status}")));
                }
                break;
            }
            Ok(None) => std::thread::sleep(Duration::from_millis(5)),
            Err(error) => {
                drop(child.kill());
                drop(child.wait());
                return Err(error.into());
            }
        }
    }
    if fs::metadata(&result_path)?.len() > MAX_RESULT_BYTES {
        return Err(HostError::Scanner("probe result exceeds size limit".into()));
    }
    let response: ProbeResponse = serde_json::from_slice(&fs::read(result_path)?)
        .map_err(|e| HostError::Scanner(e.to_string()))?;
    if response.version != SCANNER_PROTOCOL_VERSION {
        return Err(HostError::Scanner("incompatible probe protocol".into()));
    }
    if let Some(error) = response.error {
        return Err(HostError::Scanner(error));
    }
    let module = fs::canonicalize(module)?;
    if response.plugins.iter().any(|p| {
        p.identity.format != format
            || p.path != module
            || p.identity.native_id.is_empty()
            || (format == PluginFormat::Vst3
                && (p.identity.native_id.len() != 32
                    || !p.identity.native_id.bytes().all(|c| c.is_ascii_hexdigit())))
    }) {
        return Err(HostError::Scanner(
            "probe returned an invalid descriptor".into(),
        ));
    }
    Ok(response.plugins)
}

fn identity_key(identity: &PluginIdentity) -> String {
    format!("{:?}:{}", identity.format, identity.native_id)
}

/// How the per-module fingerprint and probe phase is executed.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ScanStrategy {
    Sequential,
    Parallel { workers: usize },
}

/// Picks parallel execution only when enough modules are expected to need real work.
///
/// Modules that are uncached (or every module on an explicit retry) will certainly be probed;
/// cached modules that changed on disk are only discovered after fingerprinting, so a very large
/// module count also qualifies on fingerprinting cost alone.
fn scan_strategy(module_count: usize, expected_probes: usize, workers: usize) -> ScanStrategy {
    let workers = workers.min(MAX_PARALLEL_SCAN_WORKERS);
    if workers > 1
        && (expected_probes >= PARALLEL_PROBE_MIN_MODULES
            || module_count >= PARALLEL_FINGERPRINT_MIN_MODULES)
    {
        ScanStrategy::Parallel { workers }
    } else {
        ScanStrategy::Sequential
    }
}

/// Work done for one module without touching the shared cache, so it can run on any thread.
enum ModuleOutcome {
    FingerprintFailed(String),
    Unchanged,
    Probed {
        fingerprint: u64,
        probe: Result<Vec<PluginDescriptor>, HostError>,
    },
}

fn evaluate_module(
    scanner: &ModuleScanner<'_>,
    path: &Path,
    cached_fingerprint: Option<u64>,
    retry: bool,
    timeout: Duration,
    cancelled: &AtomicBool,
) -> ModuleOutcome {
    match module_fingerprint(path) {
        Err(error) => ModuleOutcome::FingerprintFailed(error.to_string()),
        Ok(fingerprint) if retry || cached_fingerprint != Some(fingerprint) => {
            ModuleOutcome::Probed {
                fingerprint,
                probe: probe_checked(scanner, path, timeout, cancelled),
            }
        }
        Ok(_) => ModuleOutcome::Unchanged,
    }
}

/// Runs the format's probe and rejects descriptors that belong to another format or module.
fn probe_checked(
    scanner: &ModuleScanner<'_>,
    path: &Path,
    timeout: Duration,
    cancelled: &AtomicBool,
) -> Result<Vec<PluginDescriptor>, HostError> {
    if cancelled.load(Ordering::Relaxed) {
        return Err(HostError::Cancelled);
    }
    let plugins = (scanner.probe)(path, timeout, cancelled)?;
    if plugins.iter().any(|plugin| {
        plugin.identity.format != scanner.format
            || plugin.identity.native_id.is_empty()
            || plugin.path != path
    }) {
        return Err(HostError::Scanner(
            "probe returned an invalid descriptor".into(),
        ));
    }
    Ok(plugins)
}

/// Mutable scan state that must be updated in module order to keep de-duplication deterministic.
struct ScanMerge<'a> {
    cache: &'a mut ScanCache,
    result: ScanResult,
    identities: HashMap<PluginIdentity, usize>,
    total: usize,
    cancelled: &'a AtomicBool,
    progress: &'a mut dyn FnMut(ScanProgress),
}

impl ScanMerge<'_> {
    fn apply(&mut self, index: usize, path: &Path, outcome: ModuleOutcome) -> ControlFlow<()> {
        match outcome {
            ModuleOutcome::FingerprintFailed(error) => {
                self.result
                    .failures
                    .push((path.to_path_buf(), error.clone()));
                (self.progress)(ScanProgress {
                    completed: index.saturating_add(1),
                    total: self.total,
                    discovered: self.result.plugins.len(),
                    path: path.to_path_buf(),
                    error: Some(error),
                });
                return ControlFlow::Continue(());
            }
            ModuleOutcome::Unchanged => {}
            ModuleOutcome::Probed {
                fingerprint,
                probe: Ok(plugins),
            } => {
                self.cache.modules.insert(
                    path.to_path_buf(),
                    CachedModule {
                        fingerprint,
                        plugins,
                        quarantine: None,
                    },
                );
            }
            ModuleOutcome::Probed {
                fingerprint,
                probe: Err(error),
            } => {
                if self.cancelled.load(Ordering::Relaxed) {
                    self.result.cancelled = true;
                    return ControlFlow::Break(());
                }
                let previous = self
                    .cache
                    .modules
                    .get(path)
                    .map(|c| c.plugins.clone())
                    .unwrap_or_default();
                self.cache.modules.insert(
                    path.to_path_buf(),
                    CachedModule {
                        fingerprint,
                        plugins: previous,
                        quarantine: Some(error.to_string()),
                    },
                );
            }
        }
        if let Some(entry) = self.cache.modules.get(path) {
            if let Some(error) = &entry.quarantine {
                self.result
                    .failures
                    .push((path.to_path_buf(), error.clone()));
            } else {
                for plugin in &entry.plugins {
                    if let Some(&existing) = self.identities.get(&plugin.identity) {
                        if self
                            .cache
                            .preferred_locations
                            .get(&identity_key(&plugin.identity))
                            .is_some_and(|preferred| preferred == path)
                            && let Some(slot) = self.result.plugins.get_mut(existing)
                        {
                            *slot = plugin.clone();
                        }
                    } else {
                        self.identities
                            .insert(plugin.identity.clone(), self.result.plugins.len());
                        self.result.plugins.push(plugin.clone());
                    }
                }
            }
            (self.progress)(ScanProgress {
                completed: index.saturating_add(1),
                total: self.total,
                discovered: self.result.plugins.len(),
                path: path.to_path_buf(),
                error: entry.quarantine.clone(),
            });
        }
        ControlFlow::Continue(())
    }

    fn finish(mut self) -> ScanResult {
        for plugin in &self.result.plugins {
            self.cache
                .preferred_locations
                .insert(identity_key(&plugin.identity), plugin.path.clone());
        }
        self.result.cancelled |= self.cancelled.load(Ordering::Relaxed);
        self.result
    }
}

/// Failed or cancelled rescans never erase previously discovered plugin metadata.
///
/// Module probing runs on a bounded rayon pool when enough modules need work (see
/// [`scan_strategy`]); otherwise it runs on the calling thread. Both paths merge results in
/// discovery order, so the returned catalog, cache, and progress sequence are identical.
pub fn scan(
    scanner: &ModuleScanner<'_>,
    settings: &ScanSettings,
    cache: &mut ScanCache,
    retry: bool,
    cancelled: &AtomicBool,
    progress: &mut dyn FnMut(ScanProgress),
) -> Result<ScanResult, HostError> {
    let modules = discover_modules(&settings.directories, scanner.extension, cancelled)?;
    let expected_probes = if retry {
        modules.len()
    } else {
        modules
            .iter()
            .filter(|path| !cache.modules.contains_key(*path))
            .count()
    };
    let strategy = scan_strategy(modules.len(), expected_probes, available_workers());
    Ok(scan_modules(
        scanner, settings, cache, retry, cancelled, progress, &modules, strategy,
    ))
}

#[allow(
    clippy::too_many_arguments,
    reason = "internal split of scan() that also takes the chosen strategy"
)]
fn scan_modules(
    scanner: &ModuleScanner<'_>,
    settings: &ScanSettings,
    cache: &mut ScanCache,
    retry: bool,
    cancelled: &AtomicBool,
    progress: &mut dyn FnMut(ScanProgress),
    modules: &[PathBuf],
    strategy: ScanStrategy,
) -> ScanResult {
    let timeout = Duration::from_secs(settings.timeout_seconds.max(1));
    let pool = match strategy {
        ScanStrategy::Sequential => None,
        ScanStrategy::Parallel { workers } => match rayon::ThreadPoolBuilder::new()
            .num_threads(workers)
            .thread_name(|index| format!("plugin-scan-{index}"))
            .build()
        {
            Ok(pool) => Some(pool),
            Err(error) => {
                tracing::warn!("Plugin scan falling back to one thread: {error}");
                None
            }
        },
    };
    let mut merge = ScanMerge {
        cache,
        result: ScanResult::default(),
        identities: HashMap::new(),
        total: modules.len(),
        cancelled,
        progress,
    };

    let Some(pool) = pool else {
        for (index, path) in modules.iter().enumerate() {
            if cancelled.load(Ordering::Relaxed) {
                merge.result.cancelled = true;
                break;
            }
            let cached = merge.cache.modules.get(path).map(|c| c.fingerprint);
            let outcome = evaluate_module(scanner, path, cached, retry, timeout, cancelled);
            if merge.apply(index, path, outcome).is_break() {
                break;
            }
        }
        return merge.finish();
    };

    // Workers only read this snapshot; every cache write happens in the ordered merge below.
    let cached: Vec<Option<u64>> = modules
        .iter()
        .map(|path| merge.cache.modules.get(path).map(|c| c.fingerprint))
        .collect();
    let (sender, receiver) = mpsc::channel::<(usize, ModuleOutcome)>();
    pool.in_place_scope(|scope| {
        scope.spawn(|_| {
            // par_bridge hands out modules in discovery order, so the in-order merge rarely waits.
            modules
                .iter()
                .zip(&cached)
                .enumerate()
                .par_bridge()
                .for_each_with(sender, |sender, (index, (path, cached))| {
                    if cancelled.load(Ordering::Relaxed) {
                        return;
                    }
                    let outcome =
                        evaluate_module(scanner, path, *cached, retry, timeout, cancelled);
                    // The merge stops receiving only after cancellation, when results are unused.
                    drop(sender.send((index, outcome)));
                });
        });

        let mut pending: Vec<Option<ModuleOutcome>> = std::iter::repeat_with(|| None)
            .take(modules.len())
            .collect();
        let mut next = 0;
        'merge: for (index, outcome) in &receiver {
            if let Some(slot) = pending.get_mut(index) {
                *slot = Some(outcome);
            }
            while let (Some(outcome), Some(path)) = (
                pending.get_mut(next).and_then(Option::take),
                modules.get(next),
            ) {
                if cancelled.load(Ordering::Relaxed) {
                    merge.result.cancelled = true;
                    break 'merge;
                }
                if merge.apply(next, path, outcome).is_break() {
                    break 'merge;
                }
                next = next.saturating_add(1);
            }
        }
    });
    merge.finish()
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "test fixtures use assertions for failure reporting"
)]
mod tests {
    use super::*;

    fn vst3_scanner<'a>(probe: &'a ModuleProbe<'a>) -> ModuleScanner<'a> {
        ModuleScanner {
            format: PluginFormat::Vst3,
            extension: "vst3",
            probe,
        }
    }

    fn descriptor(path: &Path, number: u32) -> PluginDescriptor {
        PluginDescriptor {
            identity: PluginIdentity {
                format: PluginFormat::Vst3,
                native_id: format!("{number:032X}"),
            },
            path: fs::canonicalize(path).unwrap(),
            name: format!("Plugin {number}"),
            vendor: "Fixture".into(),
            version: "1".into(),
            kind: crate::PluginKind::Instrument,
        }
    }

    #[test]
    fn multiple_classes_deduplicate_by_identity_and_keep_a_valid_selected_location() {
        let root = tempfile::tempdir().unwrap();
        let paths = ["First.vst3", "Second.vst3"].map(|name| {
            let path = root.path().join(name);
            fs::write(&path, b"module").unwrap();
            fs::canonicalize(path).unwrap()
        });
        let mut cache = ScanCache::default();
        for path in &paths {
            cache.modules.insert(
                path.clone(),
                CachedModule {
                    fingerprint: module_fingerprint(path).unwrap(),
                    plugins: vec![descriptor(path, 1), descriptor(path, 2)],
                    quarantine: None,
                },
            );
        }
        let key = identity_key(&descriptor(&paths[0], 1).identity);
        cache
            .preferred_locations
            .insert(key.clone(), paths[1].clone());
        let settings = ScanSettings {
            directories: paths.to_vec(),
            ..Default::default()
        };
        let cancel = AtomicBool::new(false);
        let mut progress = Vec::new();
        let result = scan(
            &vst3_scanner(&helper_probe(
                Path::new("unused-helper"),
                PluginFormat::Vst3,
            )),
            &settings,
            &mut cache,
            false,
            &cancel,
            &mut |p| progress.push(p),
        )
        .unwrap();
        assert_eq!(result.plugins.len(), 2);
        assert_eq!(result.plugins[0].path, paths[1]);
        assert_eq!(result.plugins[1].path, paths[0]);
        assert_eq!(progress.len(), 2);
        assert_eq!(progress[1].completed, progress[1].total);
        cache.modules.get_mut(&paths[1]).unwrap().quarantine = Some("crashed".into());
        let result = scan(
            &vst3_scanner(&helper_probe(
                Path::new("unused-helper"),
                PluginFormat::Vst3,
            )),
            &settings,
            &mut cache,
            false,
            &cancel,
            &mut |_| {},
        )
        .unwrap();
        assert_eq!(result.plugins.len(), 2);
        assert!(result.plugins.iter().all(|p| p.path == paths[0]));
        assert_eq!(result.failures.len(), 1);
        assert_eq!(cache.preferred_locations[&key], paths[0]);
    }

    #[test]
    fn cancelled_discovery_reports_cancellation_without_spawning_a_helper() {
        let cancel = AtomicBool::new(true);
        let result = scan(
            &vst3_scanner(&helper_probe(
                Path::new("missing-helper"),
                PluginFormat::Vst3,
            )),
            &ScanSettings::default(),
            &mut ScanCache::default(),
            false,
            &cancel,
            &mut |_| {},
        )
        .unwrap();
        assert!(result.cancelled);
        assert!(matches!(
            probe_module(
                Path::new("missing-helper"),
                PluginFormat::Vst3,
                Path::new("missing.vst3"),
                Duration::ZERO,
                &cancel
            ),
            Err(HostError::Cancelled)
        ));
    }

    #[cfg(unix)]
    #[test]
    fn fingerprints_follow_linked_binaries_without_following_directory_cycles() {
        use std::os::unix::fs::symlink;
        let root = tempfile::tempdir().unwrap();
        let binary = root.path().join("binary.so");
        let bundle = root.path().join("Linked.vst3");
        fs::create_dir(&bundle).unwrap();
        fs::write(&binary, b"first").unwrap();
        symlink(&binary, bundle.join("plugin.so")).unwrap();
        symlink(&bundle, bundle.join("cycle")).unwrap();
        let before = module_fingerprint(&bundle).unwrap();
        assert_eq!(before, module_fingerprint(&bundle).unwrap());
        fs::write(&binary, b"replacement").unwrap();
        assert_ne!(before, module_fingerprint(&bundle).unwrap());
    }

    #[cfg(unix)]
    #[test]
    fn rescan_failure_retains_metadata_and_explicit_retry_clears_quarantine() {
        use std::os::unix::fs::PermissionsExt;
        let root = tempfile::tempdir().unwrap();
        let module = root.path().join("Instrument.vst3");
        fs::write(&module, b"module").unwrap();
        let helper = root.path().join("probe");
        fs::write(&helper, "#!/bin/sh\ncat \"$2.json\" > \"$4\"\n").unwrap();
        fs::set_permissions(&helper, fs::Permissions::from_mode(0o700)).unwrap();
        let response_path = module.with_extension("vst3.json");
        let response = ProbeResponse {
            version: SCANNER_PROTOCOL_VERSION,
            plugins: vec![descriptor(&module, 1), descriptor(&module, 2)],
            error: None,
        };
        fs::write(&response_path, serde_json::to_vec(&response).unwrap()).unwrap();
        let settings = ScanSettings {
            directories: vec![module.clone()],
            ..Default::default()
        };
        let mut cache = ScanCache::default();
        let cancel = AtomicBool::new(false);
        let result = scan(
            &vst3_scanner(&helper_probe(&helper, PluginFormat::Vst3)),
            &settings,
            &mut cache,
            false,
            &cancel,
            &mut |_| {},
        )
        .unwrap();
        assert_eq!(result.plugins.len(), 2);
        fs::write(&module, b"changed module").unwrap();
        fs::write(&response_path, b"malformed response").unwrap();
        let result = scan(
            &vst3_scanner(&helper_probe(&helper, PluginFormat::Vst3)),
            &settings,
            &mut cache,
            false,
            &cancel,
            &mut |_| {},
        )
        .unwrap();
        assert_eq!(result.failures.len(), 1);
        assert!(cache.modules[&module].quarantine.is_some());
        assert_eq!(cache.modules[&module].plugins.len(), 2);
        fs::write(&response_path, serde_json::to_vec(&response).unwrap()).unwrap();
        let result = scan(
            &vst3_scanner(&helper_probe(&helper, PluginFormat::Vst3)),
            &settings,
            &mut cache,
            false,
            &cancel,
            &mut |_| {},
        )
        .unwrap();
        assert_eq!(result.failures.len(), 1);
        let result = scan(
            &vst3_scanner(&helper_probe(&helper, PluginFormat::Vst3)),
            &settings,
            &mut cache,
            true,
            &cancel,
            &mut |_| {},
        )
        .unwrap();
        assert_eq!(result.plugins.len(), 2);
        assert!(result.failures.is_empty());
        assert!(cache.modules[&module].quarantine.is_none());
        let mut invalid = response;
        invalid.plugins[0].identity.native_id = "not-a-class-id".into();
        fs::write(&response_path, serde_json::to_vec(&invalid).unwrap()).unwrap();
        assert!(
            probe_module(
                &helper,
                PluginFormat::Vst3,
                &module,
                Duration::from_secs(1),
                &cancel
            )
            .is_err()
        );
    }

    #[test]
    fn discovery_stops_at_bundles_and_fingerprints_contents() {
        let root = tempfile::tempdir().unwrap();
        let bundle = root.path().join("Synth.vst3");
        fs::create_dir_all(bundle.join("Contents")).unwrap();
        fs::write(bundle.join("Contents/plugin.so"), b"first").unwrap();
        let modules = discover_modules(
            &[root.path().to_path_buf(), bundle.clone()],
            "vst3",
            &AtomicBool::new(false),
        )
        .unwrap();
        assert_eq!(modules, vec![fs::canonicalize(&bundle).unwrap()]);
        let before = module_fingerprint(&bundle).unwrap();
        fs::write(bundle.join("Contents/plugin.so"), b"replacement").unwrap();
        assert_ne!(before, module_fingerprint(&bundle).unwrap());
    }

    #[test]
    fn scan_strategy_stays_sequential_for_small_or_single_core_workloads() {
        assert_eq!(scan_strategy(3, 3, 8), ScanStrategy::Sequential);
        assert_eq!(scan_strategy(500, 500, 1), ScanStrategy::Sequential);
        assert_eq!(
            scan_strategy(10, PARALLEL_PROBE_MIN_MODULES, 8),
            ScanStrategy::Parallel {
                workers: MAX_PARALLEL_SCAN_WORKERS
            }
        );
        assert_eq!(
            scan_strategy(PARALLEL_FINGERPRINT_MIN_MODULES, 0, 2),
            ScanStrategy::Parallel { workers: 2 }
        );
    }

    #[test]
    fn discovery_workload_estimate_stops_at_threshold_and_skips_bundles() {
        let root = tempfile::tempdir().unwrap();
        let bundle = root.path().join("Big.vst3");
        fs::create_dir(&bundle).unwrap();
        for index in 0..100 {
            fs::write(bundle.join(format!("file-{index}")), b"x").unwrap();
        }
        let cancel = AtomicBool::new(false);
        let roots = [root.path().to_path_buf()];
        assert!(!discovery_workload_reaches(&roots, "vst3", 16, &cancel));

        let vendor = root.path().join("Vendor");
        fs::create_dir(&vendor).unwrap();
        for index in 0..16 {
            fs::create_dir(vendor.join(format!("Dir{index}"))).unwrap();
        }
        assert!(discovery_workload_reaches(&roots, "vst3", 16, &cancel));
        assert!(!discovery_workload_reaches(
            &roots,
            "vst3",
            16,
            &AtomicBool::new(true)
        ));
    }

    fn nested_module_tree(root: &Path) -> Vec<PathBuf> {
        let mut roots = vec![root.to_path_buf()];
        for vendor in 0..6 {
            let vendor_dir = root.join(format!("Vendor{vendor}"));
            for product in 0..PARALLEL_DISCOVERY_FORK_MIN_ENTRIES + 2 {
                let dir = vendor_dir.join(format!("Product{product}"));
                fs::create_dir_all(dir.join(format!("P{vendor}_{product}.vst3/Contents"))).unwrap();
                fs::write(dir.join("readme.txt"), b"not a plugin").unwrap();
            }
        }
        roots.push(root.join("Vendor3"));
        roots.push(root.join("missing"));
        roots
    }

    #[test]
    fn parallel_discovery_matches_sequential_order_and_deduplication() {
        let root = tempfile::tempdir().unwrap();
        let roots = nested_module_tree(root.path());
        #[cfg(unix)]
        std::os::unix::fs::symlink(root.path(), root.path().join("Vendor0/cycle")).unwrap();
        let cancel = AtomicBool::new(false);
        let sequential = discover_modules_sequential(&roots, "vst3", &cancel).unwrap();
        let parallel = discover_modules_parallel(&roots, "vst3", &cancel).unwrap();
        assert_eq!(
            sequential.len(),
            6 * (PARALLEL_DISCOVERY_FORK_MIN_ENTRIES + 2)
        );
        assert_eq!(parallel, sequential);
        assert_eq!(
            discover_modules(&roots, "vst3", &cancel).unwrap(),
            sequential
        );
    }

    type ProgressRecord = (usize, usize, usize, PathBuf, Option<String>);

    fn run_scan(
        helper: &Path,
        modules: &[PathBuf],
        cache: &mut ScanCache,
        retry: bool,
        strategy: ScanStrategy,
    ) -> (ScanResult, Vec<ProgressRecord>) {
        let settings = ScanSettings {
            directories: modules.to_vec(),
            timeout_seconds: 10,
        };
        let mut progress = Vec::new();
        let result = scan_modules(
            &vst3_scanner(&helper_probe(helper, PluginFormat::Vst3)),
            &settings,
            cache,
            retry,
            &AtomicBool::new(false),
            &mut |p| progress.push((p.completed, p.total, p.discovered, p.path, p.error)),
            modules,
            strategy,
        );
        (result, progress)
    }

    fn assert_same_scan(
        (left, left_progress): &(ScanResult, Vec<ProgressRecord>),
        (right, right_progress): &(ScanResult, Vec<ProgressRecord>),
    ) {
        let paths = |r: &ScanResult| {
            r.plugins
                .iter()
                .map(|p| (p.identity.native_id.clone(), p.path.clone()))
                .collect::<Vec<_>>()
        };
        assert_eq!(paths(left), paths(right));
        assert_eq!(left.failures, right.failures);
        assert_eq!(left.cancelled, right.cancelled);
        assert_eq!(left_progress, right_progress);
    }

    #[test]
    fn parallel_fingerprinting_of_cached_modules_matches_sequential_scan() {
        let root = tempfile::tempdir().unwrap();
        let mut cache = ScanCache::default();
        let mut modules = Vec::new();
        for index in 0..u32::try_from(PARALLEL_FINGERPRINT_MIN_MODULES).unwrap() {
            let path = root.path().join(format!("M{index:03}.vst3"));
            fs::write(&path, b"module").unwrap();
            let path = fs::canonicalize(path).unwrap();
            cache.modules.insert(
                path.clone(),
                CachedModule {
                    fingerprint: module_fingerprint(&path).unwrap(),
                    plugins: vec![descriptor(&path, index % 7)],
                    quarantine: (index % 11 == 0).then(|| "crashed".to_string()),
                },
            );
            modules.push(path);
        }
        modules.push(root.path().join("vanished.vst3"));
        let mut parallel_cache = cache.clone();
        let sequential = run_scan(
            Path::new("unused-helper"),
            &modules,
            &mut cache,
            false,
            ScanStrategy::Sequential,
        );
        let parallel = run_scan(
            Path::new("unused-helper"),
            &modules,
            &mut parallel_cache,
            false,
            ScanStrategy::Parallel { workers: 4 },
        );
        assert_same_scan(&sequential, &parallel);
        assert_eq!(sequential.1.len(), modules.len());
        assert_eq!(
            cache.preferred_locations,
            parallel_cache.preferred_locations
        );
    }

    #[cfg(unix)]
    #[test]
    fn parallel_probing_matches_sequential_scan() {
        use std::os::unix::fs::PermissionsExt;
        let root = tempfile::tempdir().unwrap();
        let helper = root.path().join("probe");
        fs::write(&helper, "#!/bin/sh\nsleep 0.05\ncat \"$2.json\" > \"$4\"\n").unwrap();
        fs::set_permissions(&helper, fs::Permissions::from_mode(0o700)).unwrap();
        let mut modules = Vec::new();
        for index in 0..8u32 {
            let path = root.path().join(format!("Probe{index}.vst3"));
            fs::write(&path, b"module").unwrap();
            let path = fs::canonicalize(path).unwrap();
            let response = if index == 5 {
                b"malformed".to_vec()
            } else {
                serde_json::to_vec(&ProbeResponse {
                    version: SCANNER_PROTOCOL_VERSION,
                    plugins: vec![descriptor(&path, index % 3), descriptor(&path, 10 + index)],
                    error: None,
                })
                .unwrap()
            };
            fs::write(path.with_extension("vst3.json"), response).unwrap();
            modules.push(path);
        }
        let mut sequential_cache = ScanCache::default();
        let mut parallel_cache = ScanCache::default();
        let sequential = run_scan(
            &helper,
            &modules,
            &mut sequential_cache,
            false,
            ScanStrategy::Sequential,
        );
        let parallel = run_scan(
            &helper,
            &modules,
            &mut parallel_cache,
            false,
            ScanStrategy::Parallel { workers: 4 },
        );
        assert_same_scan(&sequential, &parallel);
        assert_eq!(sequential.0.failures.len(), 1);
        assert_eq!(
            sequential_cache.preferred_locations,
            parallel_cache.preferred_locations
        );
        for module in &modules {
            let quarantine =
                |cache: &ScanCache| cache.modules.get(module).map(|m| m.quarantine.clone());
            assert_eq!(quarantine(&sequential_cache), quarantine(&parallel_cache));
        }
    }

    #[cfg(unix)]
    #[test]
    fn cancelled_parallel_scan_stops_and_keeps_existing_metadata() {
        use std::os::unix::fs::PermissionsExt;
        let root = tempfile::tempdir().unwrap();
        let helper = root.path().join("probe");
        fs::write(&helper, "#!/bin/sh\nexec sleep 30\n").unwrap();
        fs::set_permissions(&helper, fs::Permissions::from_mode(0o700)).unwrap();
        let modules: Vec<PathBuf> = (0..6)
            .map(|index| {
                let path = root.path().join(format!("Slow{index}.vst3"));
                fs::write(&path, b"module").unwrap();
                fs::canonicalize(path).unwrap()
            })
            .collect();
        let settings = ScanSettings {
            directories: modules.clone(),
            timeout_seconds: 30,
        };
        let cancel = AtomicBool::new(false);
        let mut cache = ScanCache::default();
        let started = Instant::now();
        let result = std::thread::scope(|scope| {
            scope.spawn(|| {
                std::thread::sleep(Duration::from_millis(100));
                cancel.store(true, Ordering::Relaxed);
            });
            scan_modules(
                &vst3_scanner(&helper_probe(&helper, PluginFormat::Vst3)),
                &settings,
                &mut cache,
                false,
                &cancel,
                &mut |_| {},
                &modules,
                ScanStrategy::Parallel { workers: 4 },
            )
        });
        assert!(result.cancelled);
        assert_eq!(result.plugins.len(), 0);
        assert_eq!(cache.modules.len(), 0);
        assert!(started.elapsed() < Duration::from_secs(10));
    }

    #[test]
    fn cache_round_trip_preserves_quarantine() {
        let root = tempfile::tempdir().unwrap();
        let path = root.path().join("cache.json");
        let mut cache = ScanCache::default();
        cache.modules.insert(
            PathBuf::from("bad.vst3"),
            CachedModule {
                fingerprint: 7,
                plugins: vec![],
                quarantine: Some("timeout".into()),
            },
        );
        cache.save(&path).unwrap();
        let restored = ScanCache::load(&path).unwrap();
        assert_eq!(
            restored.modules[Path::new("bad.vst3")]
                .quarantine
                .as_deref(),
            Some("timeout")
        );
    }

    #[cfg(unix)]
    #[test]
    fn helpers_are_told_the_format_and_clap_ids_need_not_be_class_ids() {
        use std::os::unix::fs::PermissionsExt;
        let root = tempfile::tempdir().unwrap();
        let module = root.path().join("Synth.clap");
        fs::write(&module, b"module").unwrap();
        let helper = root.path().join("probe");
        // Answers only when asked for CLAP, so any other format fails the probe.
        fs::write(
            &helper,
            "#!/bin/sh\n[ \"$5\" = --format ] && [ \"$6\" = clap ] && cat \"$2.json\" > \"$4\"\n",
        )
        .unwrap();
        fs::set_permissions(&helper, fs::Permissions::from_mode(0o700)).unwrap();
        let mut plugin = descriptor(&module, 1);
        plugin.identity = PluginIdentity {
            format: PluginFormat::Clap,
            native_id: "org.example.synth".into(),
        };
        let response = ProbeResponse {
            version: SCANNER_PROTOCOL_VERSION,
            plugins: vec![plugin.clone()],
            error: None,
        };
        fs::write(
            module.with_extension("clap.json"),
            serde_json::to_vec(&response).unwrap(),
        )
        .unwrap();
        let cancel = AtomicBool::new(false);
        let probe =
            |format| probe_module(&helper, format, &module, Duration::from_secs(5), &cancel);
        assert_eq!(probe(PluginFormat::Clap).unwrap(), [plugin]);
        assert!(probe(PluginFormat::Vst3).is_err());
    }

    #[cfg(unix)]
    #[test]
    fn crashed_hung_and_malformed_helpers_are_contained() {
        use std::os::unix::fs::PermissionsExt;
        let root = tempfile::tempdir().unwrap();
        let helper = root.path().join("probe");
        for script in [
            "#!/bin/sh\nexit 1\n",
            "#!/bin/sh\nexec sleep 30\n",
            "#!/bin/sh\necho invalid > \"$4\"\n",
        ] {
            fs::write(&helper, script).unwrap();
            fs::set_permissions(&helper, fs::Permissions::from_mode(0o700)).unwrap();
            assert!(
                probe_module(
                    &helper,
                    PluginFormat::Vst3,
                    root.path(),
                    Duration::from_millis(30),
                    &AtomicBool::new(false)
                )
                .is_err()
            );
        }
        assert!(
            probe_module(
                &helper,
                PluginFormat::Vst3,
                root.path(),
                Duration::from_secs(30),
                &AtomicBool::new(true)
            )
            .is_err()
        );
    }

    fn lv2_descriptor(path: &Path, uri: &str) -> PluginDescriptor {
        PluginDescriptor {
            identity: PluginIdentity {
                format: PluginFormat::Lv2,
                native_id: uri.into(),
            },
            path: path.to_path_buf(),
            name: uri.into(),
            vendor: "Fixture".into(),
            version: "1".into(),
            kind: crate::PluginKind::Effect,
        }
    }

    #[test]
    fn formats_discover_their_own_modules_and_share_one_cache() {
        let root = tempfile::tempdir().unwrap();
        let vst3 = root.path().join("Synth.vst3");
        let lv2 = root.path().join("effects.lv2");
        fs::write(&vst3, b"module").unwrap();
        fs::create_dir(&lv2).unwrap();
        fs::write(lv2.join("manifest.ttl"), b"").unwrap();
        let (vst3, lv2) = (
            fs::canonicalize(vst3).unwrap(),
            fs::canonicalize(lv2).unwrap(),
        );
        let roots = [root.path().to_path_buf()];
        let cancel = AtomicBool::new(false);
        assert_eq!(
            discover_modules(&roots, "lv2", &cancel).unwrap(),
            vec![lv2.clone()]
        );
        assert_eq!(
            discover_modules(&roots, "vst3", &cancel).unwrap(),
            vec![vst3.clone()]
        );

        let settings = ScanSettings {
            directories: roots.to_vec(),
            ..Default::default()
        };
        let mut cache = ScanCache::default();
        let vst3_probe =
            |module: &Path, _: Duration, _: &AtomicBool| Ok(vec![descriptor(module, 1)]);
        let lv2_probe = |module: &Path, _: Duration, _: &AtomicBool| {
            Ok(vec![
                lv2_descriptor(module, "urn:fixture:a"),
                lv2_descriptor(module, "urn:fixture:b"),
            ])
        };
        let first = scan(
            &vst3_scanner(&vst3_probe),
            &settings,
            &mut cache,
            false,
            &cancel,
            &mut |_| {},
        )
        .unwrap();
        assert_eq!(first.plugins.len(), 1);
        let second = scan(
            &ModuleScanner {
                format: PluginFormat::Lv2,
                extension: "lv2",
                probe: &lv2_probe,
            },
            &settings,
            &mut cache,
            false,
            &cancel,
            &mut |_| {},
        )
        .unwrap();
        assert_eq!(second.plugins.len(), 2);
        assert!(
            second
                .plugins
                .iter()
                .all(|plugin| plugin.identity.format == PluginFormat::Lv2 && plugin.path == lv2)
        );
        // Each scan only walks its own modules, and the shared cache keeps both formats.
        assert_eq!(cache.modules.len(), 2);
        assert_eq!(cache.catalog().len(), 3);
    }

    #[test]
    fn descriptors_for_another_format_or_module_quarantine_the_module() {
        let root = tempfile::tempdir().unwrap();
        let bundle = root.path().join("wrong.lv2");
        fs::create_dir(&bundle).unwrap();
        let bundle = fs::canonicalize(bundle).unwrap();
        let settings = ScanSettings {
            directories: vec![bundle.clone()],
            ..Default::default()
        };
        let cancel = AtomicBool::new(false);
        let elsewhere = root.path().to_path_buf();
        let probes: [&ModuleProbe<'_>; 2] = [
            &|module: &Path, _: Duration, _: &AtomicBool| Ok(vec![descriptor(module, 1)]),
            &|_: &Path, _: Duration, _: &AtomicBool| {
                Ok(vec![lv2_descriptor(&elsewhere, "urn:fixture:a")])
            },
        ];
        for probe in probes {
            let mut cache = ScanCache::default();
            let result = scan(
                &ModuleScanner {
                    format: PluginFormat::Lv2,
                    extension: "lv2",
                    probe,
                },
                &settings,
                &mut cache,
                false,
                &cancel,
                &mut |_| {},
            )
            .unwrap();
            assert!(result.plugins.is_empty());
            assert_eq!(result.failures.len(), 1);
            assert!(cache.modules[&bundle].quarantine.is_some());
        }
    }
}
