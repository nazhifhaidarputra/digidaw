//! Discovery runs on a worker; each native module is probed by a disposable child process.

use std::{
    collections::{HashMap, HashSet},
    fs,
    hash::{Hash, Hasher},
    path::{Path, PathBuf},
    process::{Command, Stdio},
    sync::atomic::{AtomicBool, Ordering},
    time::{Duration, Instant, UNIX_EPOCH},
};

use serde::{Deserialize, Serialize};

use crate::{HostError, PluginDescriptor, PluginFormat, PluginIdentity};

/// JSON request/response and cache schema version shared with the scanner helper.
pub const SCANNER_PROTOCOL_VERSION: u32 = 1;
const MAX_RESULT_BYTES: u64 = 16 * 1024 * 1024;

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
    /// Directory trees searched recursively for `.vst3` modules.
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

/// Recursively discovers canonical `.vst3` modules beneath the supplied roots.
///
/// Directory entries are sorted for deterministic traversal, canonical paths prevent cycles and
/// duplicates, missing roots are ignored, and cancellation stops traversal without an error.
pub fn discover_modules(
    directories: &[PathBuf],
    cancelled: &AtomicBool,
) -> Result<Vec<PathBuf>, HostError> {
    fn visit(
        path: &Path,
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
        if path
            .extension()
            .is_some_and(|e| e.eq_ignore_ascii_case("vst3"))
        {
            modules.push(canonical);
        } else if path.is_dir() {
            let mut entries = fs::read_dir(path)?
                .map(|e| e.map(|e| e.path()))
                .collect::<Result<Vec<_>, _>>()?;
            entries.sort();
            for entry in entries {
                visit(&entry, seen, modules, cancelled)?;
            }
        }
        Ok(())
    }
    let mut modules = Vec::new();
    let mut seen = HashSet::new();
    for path in directories {
        visit(path, &mut seen, &mut modules, cancelled)?;
    }
    Ok(modules)
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

/// Cancelling or timing out always kills and reaps the child before returning.
pub fn probe_module(
    helper: &Path,
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
        p.identity.format != PluginFormat::Vst3
            || p.path != module
            || p.identity.native_id.len() != 32
            || !p.identity.native_id.bytes().all(|c| c.is_ascii_hexdigit())
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

/// Failed or cancelled rescans never erase previously discovered plugin metadata.
pub fn scan(
    helper: &Path,
    settings: &ScanSettings,
    cache: &mut ScanCache,
    retry: bool,
    cancelled: &AtomicBool,
    progress: &mut dyn FnMut(ScanProgress),
) -> Result<ScanResult, HostError> {
    let modules = discover_modules(&settings.directories, cancelled)?;
    let mut result = ScanResult::default();
    let mut identities: HashMap<PluginIdentity, usize> = HashMap::new();
    for (index, path) in modules.iter().enumerate() {
        if cancelled.load(Ordering::Relaxed) {
            result.cancelled = true;
            break;
        }
        let fingerprint = match module_fingerprint(path) {
            Ok(fingerprint) => fingerprint,
            Err(error) => {
                let error = error.to_string();
                result.failures.push((path.clone(), error.clone()));
                progress(ScanProgress {
                    completed: index + 1,
                    total: modules.len(),
                    discovered: result.plugins.len(),
                    path: path.clone(),
                    error: Some(error),
                });
                continue;
            }
        };
        let cached = cache.modules.get(path);
        let needs_probe = retry || cached.is_none_or(|c| c.fingerprint != fingerprint);
        if needs_probe {
            match probe_module(
                helper,
                path,
                Duration::from_secs(settings.timeout_seconds.max(1)),
                cancelled,
            ) {
                Ok(plugins) => {
                    cache.modules.insert(
                        path.clone(),
                        CachedModule {
                            fingerprint,
                            plugins,
                            quarantine: None,
                        },
                    );
                }
                Err(error) => {
                    if cancelled.load(Ordering::Relaxed) {
                        result.cancelled = true;
                        break;
                    }
                    let previous = cache
                        .modules
                        .get(path)
                        .map(|c| c.plugins.clone())
                        .unwrap_or_default();
                    cache.modules.insert(
                        path.clone(),
                        CachedModule {
                            fingerprint,
                            plugins: previous,
                            quarantine: Some(error.to_string()),
                        },
                    );
                }
            }
        }
        if let Some(entry) = cache.modules.get(path) {
            if let Some(error) = &entry.quarantine {
                result.failures.push((path.clone(), error.clone()));
            } else {
                for plugin in &entry.plugins {
                    if let Some(&existing) = identities.get(&plugin.identity) {
                        if cache
                            .preferred_locations
                            .get(&identity_key(&plugin.identity))
                            == Some(path)
                        {
                            result.plugins[existing] = plugin.clone();
                        }
                    } else {
                        identities.insert(plugin.identity.clone(), result.plugins.len());
                        result.plugins.push(plugin.clone());
                    }
                }
            }
            progress(ScanProgress {
                completed: index + 1,
                total: modules.len(),
                discovered: result.plugins.len(),
                path: path.clone(),
                error: entry.quarantine.clone(),
            });
        }
    }
    for plugin in &result.plugins {
        cache
            .preferred_locations
            .insert(identity_key(&plugin.identity), plugin.path.clone());
    }
    result.cancelled |= cancelled.load(Ordering::Relaxed);
    Ok(result)
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "test fixtures use assertions for failure reporting"
)]
mod tests {
    use super::*;

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
        let paths = [
            root.path().join("First.vst3"),
            root.path().join("Second.vst3"),
        ];
        let mut cache = ScanCache::default();
        for path in &paths {
            fs::write(path, b"module").unwrap();
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
            Path::new("unused-helper"),
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
            Path::new("unused-helper"),
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
            Path::new("missing-helper"),
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
        let result = scan(&helper, &settings, &mut cache, false, &cancel, &mut |_| {}).unwrap();
        assert_eq!(result.plugins.len(), 2);
        fs::write(&module, b"changed module").unwrap();
        fs::write(&response_path, b"malformed response").unwrap();
        let result = scan(&helper, &settings, &mut cache, false, &cancel, &mut |_| {}).unwrap();
        assert_eq!(result.failures.len(), 1);
        assert!(cache.modules[&module].quarantine.is_some());
        assert_eq!(cache.modules[&module].plugins.len(), 2);
        fs::write(&response_path, serde_json::to_vec(&response).unwrap()).unwrap();
        let result = scan(&helper, &settings, &mut cache, false, &cancel, &mut |_| {}).unwrap();
        assert_eq!(result.failures.len(), 1);
        let result = scan(&helper, &settings, &mut cache, true, &cancel, &mut |_| {}).unwrap();
        assert_eq!(result.plugins.len(), 2);
        assert!(result.failures.is_empty());
        assert!(cache.modules[&module].quarantine.is_none());
        let mut invalid = response;
        invalid.plugins[0].identity.native_id = "not-a-class-id".into();
        fs::write(&response_path, serde_json::to_vec(&invalid).unwrap()).unwrap();
        assert!(probe_module(&helper, &module, Duration::from_secs(1), &cancel).is_err());
    }

    #[test]
    fn discovery_stops_at_bundles_and_fingerprints_contents() {
        let root = tempfile::tempdir().unwrap();
        let bundle = root.path().join("Synth.vst3");
        fs::create_dir_all(bundle.join("Contents")).unwrap();
        fs::write(bundle.join("Contents/plugin.so"), b"first").unwrap();
        let modules = discover_modules(
            &[root.path().to_path_buf(), bundle.clone()],
            &AtomicBool::new(false),
        )
        .unwrap();
        assert_eq!(modules, vec![fs::canonicalize(&bundle).unwrap()]);
        let before = module_fingerprint(&bundle).unwrap();
        fs::write(bundle.join("Contents/plugin.so"), b"replacement").unwrap();
        assert_ne!(before, module_fingerprint(&bundle).unwrap());
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
                root.path(),
                Duration::from_secs(30),
                &AtomicBool::new(true)
            )
            .is_err()
        );
    }
}
