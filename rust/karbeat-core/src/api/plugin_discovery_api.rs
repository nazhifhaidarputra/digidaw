use std::{
    path::PathBuf,
    sync::{
        Arc, LazyLock,
        atomic::{AtomicBool, AtomicU64, Ordering},
    },
};

use karbeat_host::{
    HostError, PluginDescriptor, ScanRequest,
    scanner::{ScanCache, ScanProgress, ScanResult, ScanSettings},
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

/// Notification emitted during one asynchronous external-plugin discovery session.
pub enum PluginScanEvent {
    /// Confirms that the scan thread started, carrying the identifier used for cancellation.
    Started {
        /// Identifier assigned to this scan session.
        id: u64,
    },
    /// Reports incremental scanner progress.
    Progress(ScanProgress),
    /// Reports the completed scan, including discovered plugins and scanner failures.
    Finished(ScanResult),
    /// Reports a failure that prevented the scan from completing.
    Failed(String),
}

fn cache_path() -> Result<PathBuf, HostError> {
    let base = crate::core::file_manager::app_cache_dir()
        .ok_or_else(|| HostError::Scanner("user cache directory is unavailable".into()))?;
    Ok(base.join("plugins/vst3-v1.json"))
}

/// Returns the platform's conventional VST3 search directories.
pub fn default_scan_paths() -> Vec<PathBuf> {
    karbeat_host::HostClient::global()
        .and_then(|client| futures_lite::future::block_on(client.default_scan_paths_all()))
        .unwrap_or_default()
}

/// Loads the persisted scan settings, or returns defaults when no settings file exists.
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

fn normalize_scan_settings(mut settings: ScanSettings) -> Result<ScanSettings, HostError> {
    if !(1..=300).contains(&settings.timeout_seconds)
        || settings
            .directories
            .iter()
            .any(|path| path.as_os_str().is_empty())
    {
        return Err(HostError::InvalidConfiguration);
    }

    let mut seen = std::collections::HashSet::new();
    settings
        .directories
        .retain(|directory| seen.insert(directory.clone()));
    Ok(settings)
}

/// Validates, deduplicates, and atomically persists plugin scan settings.
///
/// Timeouts must be between one and 300 seconds and directory paths must be non-empty. The returned
/// value is the normalized form written to disk.
pub fn update_scan_settings(settings: ScanSettings) -> Result<ScanSettings, HostError> {
    let settings = normalize_scan_settings(settings)?;
    save_scan_settings(&settings)?;
    Ok(settings)
}

/// Starts isolated discovery without retaining the project context or blocking native UI dispatch.
pub fn start_scan(
    settings: ScanSettings,
    retry: bool,
    notify: impl FnMut(PluginScanEvent) -> bool + Send + 'static,
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
    let client = karbeat_host::HostClient::global()
        .unwrap_or_else(|_| karbeat_host::HostClient::unavailable());
    let guard = ScanGuard(id);
    std::thread::Builder::new()
        .name("plugin-discovery".into())
        .spawn(move || {
            let guard = guard;
            let notify = Arc::new(Mutex::new(notify));
            if !(notify.lock())(PluginScanEvent::Started { id }) {
                return;
            }
            let result = (|| {
                let settings = update_scan_settings(settings)?;
                let progress_notify = notify.clone();
                let progress_cancelled = session.cancelled.clone();
                let request = ScanRequest {
                    directories: settings.directories,
                    timeout_seconds: settings.timeout_seconds,
                    retry_quarantined: retry,
                    cancelled: session.cancelled.clone(),
                    cache_path: Some(cache_path()?),
                    progress: Some(Arc::new(move |progress| {
                        if !(progress_notify.lock())(PluginScanEvent::Progress(progress)) {
                            progress_cancelled.store(true, Ordering::Release);
                        }
                    })),
                };
                futures_lite::future::block_on(client.scan_all(request))
            })();
            drop(guard);
            match result {
                Ok(result) => {
                    (notify.lock())(PluginScanEvent::Finished(result));
                }
                Err(error) => {
                    (notify.lock())(PluginScanEvent::Failed(error.to_string()));
                }
            }
        })?;
    Ok(id)
}

/// Requests cancellation of the active scan when its identifier matches `id`.
///
/// Returns `false` when no scan is active or when `id` refers to a different session. Cancellation
/// is cooperative and does not imply that the worker has already exited.
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

/// Loads the external-plugin descriptors currently stored in the discovery cache.
pub fn cached_plugins() -> Result<Vec<PluginDescriptor>, HostError> {
    Ok(ScanCache::load(&cache_path()?)?.catalog())
}

/// Merges cached external-plugin descriptors into the context catalog and returns its external entries.
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
    fn scan_settings_validate_and_deduplicate_directories() {
        let settings = normalize_scan_settings(ScanSettings {
            directories: vec!["/plugins".into(), "/more".into(), "/plugins".into()],
            timeout_seconds: 30,
        })
        .unwrap();
        assert_eq!(
            settings.directories,
            vec![PathBuf::from("/plugins"), PathBuf::from("/more")]
        );
        assert!(
            normalize_scan_settings(ScanSettings {
                directories: vec![PathBuf::new()],
                timeout_seconds: 30,
            })
            .is_err()
        );
        assert!(
            normalize_scan_settings(ScanSettings {
                directories: Vec::new(),
                timeout_seconds: 0,
            })
            .is_err()
        );
    }

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
