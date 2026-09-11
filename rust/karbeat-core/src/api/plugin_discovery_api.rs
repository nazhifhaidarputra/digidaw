use std::{
    path::PathBuf,
    sync::{
        Arc, LazyLock,
        atomic::{AtomicBool, AtomicU64, Ordering},
    },
};

use karbeat_host::{
    HostError, PluginDescriptor,
    scanner::{self, ScanCache, ScanProgress, ScanResult, ScanSettings},
};
use parking_lot::Mutex;

use crate::{audio::plugin_catalog::ExternalPluginEntry, context::DawContext};

static NEXT_SCAN: AtomicU64 = AtomicU64::new(1);
static ACTIVE_SCAN: LazyLock<Mutex<Option<ScanSession>>> = LazyLock::new(|| Mutex::new(None));

#[derive(Clone)]
struct ScanSession {
    id: u64,
    cancelled: Arc<AtomicBool>,
}

struct ScanGuard(u64);
impl Drop for ScanGuard {
    fn drop(&mut self) {
        let mut active = ACTIVE_SCAN.lock();
        if active.as_ref().is_some_and(|session| session.id == self.0) {
            *active = None;
        }
    }
}

pub enum PluginScanEvent {
    Started { id: u64 },
    Progress(ScanProgress),
    Finished(ScanResult),
    Failed(String),
}

fn cache_path() -> Result<PathBuf, HostError> {
    let base = if cfg!(target_os = "windows") {
        std::env::var_os("LOCALAPPDATA").map(PathBuf::from)
    } else if cfg!(target_os = "macos") {
        std::env::var_os("HOME").map(|home| PathBuf::from(home).join("Library/Caches"))
    } else {
        std::env::var_os("XDG_CACHE_HOME")
            .filter(|value| !value.is_empty())
            .map(PathBuf::from)
            .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".cache")))
    }
    .ok_or_else(|| HostError::Scanner("user cache directory is unavailable".into()))?;
    Ok(base.join("digidaw/plugins/vst3-v1.json"))
}

pub fn default_scan_paths() -> Vec<PathBuf> {
    karbeat_vst3::module::default_scan_paths()
}

pub fn scan_settings() -> Result<ScanSettings, HostError> {
    let path = cache_path()?.with_file_name("scan-settings-v1.json");
    if !path.exists() {
        return Ok(ScanSettings::default());
    }
    serde_json::from_slice(&std::fs::read(path)?)
        .map_err(|error| HostError::Scanner(error.to_string()))
}

fn save_scan_settings(settings: &ScanSettings) -> Result<(), HostError> {
    let path = cache_path()?.with_file_name("scan-settings-v1.json");
    let parent = path
        .parent()
        .ok_or_else(|| HostError::Scanner("scan settings directory is unavailable".into()))?;
    std::fs::create_dir_all(parent)?;
    let temporary = tempfile::NamedTempFile::new_in(parent)?;
    serde_json::to_writer(temporary.as_file(), settings)
        .map_err(|error| HostError::Scanner(error.to_string()))?;
    temporary.as_file().sync_all()?;
    temporary
        .persist(path)
        .map_err(|error| HostError::Io(error.error))?;
    Ok(())
}

/// Starts isolated discovery without retaining the project context or blocking native UI dispatch.
pub fn start_scan(
    mut settings: ScanSettings,
    retry: bool,
    mut notify: impl FnMut(PluginScanEvent) -> bool + Send + 'static,
) -> Result<u64, HostError> {
    if !(1..=300).contains(&settings.timeout_seconds) {
        return Err(HostError::InvalidConfiguration);
    }
    let mut active = ACTIVE_SCAN.lock();
    if active.is_some() {
        return Err(HostError::Busy);
    }
    let id = NEXT_SCAN
        .fetch_update(Ordering::Relaxed, Ordering::Relaxed, |id| id.checked_add(1))
        .map_err(|_| HostError::InvalidTransition)?;
    let session = ScanSession {
        id,
        cancelled: Arc::new(AtomicBool::new(false)),
    };
    *active = Some(session.clone());
    drop(active);
    let guard = ScanGuard(id);
    std::thread::Builder::new()
        .name("plugin-discovery".into())
        .spawn(move || {
            let guard = guard;
            if !notify(PluginScanEvent::Started { id }) {
                return;
            }
            let result = (|| {
                save_scan_settings(&settings)?;
                settings.directories.extend(default_scan_paths());
                let path = cache_path()?;
                let mut cache = ScanCache::load(&path)?;
                let helper = scanner::scanner_executable()?;
                let result = scanner::scan(
                    &helper,
                    &settings,
                    &mut cache,
                    retry,
                    &session.cancelled,
                    &mut |progress| {
                        if !notify(PluginScanEvent::Progress(progress)) {
                            session.cancelled.store(true, Ordering::Release);
                        }
                    },
                )?;
                cache.save(&path)?;
                Ok::<_, HostError>(result)
            })();
            drop(guard);
            match result {
                Ok(result) => {
                    notify(PluginScanEvent::Finished(result));
                }
                Err(error) => {
                    notify(PluginScanEvent::Failed(error.to_string()));
                }
            }
        })?;
    Ok(id)
}

pub fn cancel_scan(id: u64) -> bool {
    let active = ACTIVE_SCAN.lock();
    active.as_ref().is_some_and(|session| {
        if session.id != id {
            return false;
        }
        session.cancelled.store(true, Ordering::Release);
        true
    })
}

pub fn cached_plugins() -> Result<Vec<PluginDescriptor>, HostError> {
    Ok(ScanCache::load(&cache_path()?)?.catalog())
}

pub fn refresh_catalog(ctx: &mut DawContext) -> Result<Vec<ExternalPluginEntry>, HostError> {
    ctx.plugin_catalog.merge(cached_plugins()?);
    Ok(ctx.plugin_catalog.external_entries())
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "scanner control fixture must join and receive its handshake"
)]
mod tests {
    use super::*;

    #[test]
    fn only_one_scan_runs_and_cancellation_cannot_target_another_scan() {
        let (started, started_rx) = std::sync::mpsc::sync_channel(1);
        let (release, release_rx) = std::sync::mpsc::sync_channel(1);
        let id = start_scan(ScanSettings::default(), false, move |event| {
            if let PluginScanEvent::Started { id } = event {
                started.send(id).unwrap();
                release_rx.recv().unwrap();
            }
            false
        })
        .unwrap();
        assert_eq!(started_rx.recv().unwrap(), id);
        assert!(matches!(
            start_scan(ScanSettings::default(), false, |_| false),
            Err(HostError::Busy)
        ));
        assert!(!cancel_scan(id + 1));
        assert!(cancel_scan(id));
        release.send(()).unwrap();
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(5);
        while ACTIVE_SCAN.lock().is_some() {
            assert!(std::time::Instant::now() < deadline);
            std::thread::yield_now();
        }
        assert!(!cancel_scan(id));
    }
}
