use std::{
    path::Path,
    sync::{
        Arc, Weak,
        mpsc::{self, RecvTimeoutError},
    },
    time::Duration,
};

use flutter_rust_bridge::frb;
use karbeat_core::api::mitigation_api::{self, StartupRecovery};
use karbeat_core::core::mitigation::{
    AutoSaveSettings, FlutterCrashSource, RecoveryInfo, StoredCrashReport,
};

use crate::api::context::{DawContext, DawSessionInner};
use crate::api::project::UiApplicationState;
use crate::api::serialization::restore_loaded_project;

/// Retry delay after an auto save tick found another project operation running.
const BUSY_RETRY: Duration = Duration::from_secs(5);

// =======================================
// Data type definition
// =======================================

/// Auto save settings as edited in General Settings.
#[derive(Clone, Copy, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiAutoSaveSettings {
    pub is_enabled: bool,
    /// Seconds between auto saves, from 60 to 3600.
    pub interval_seconds: u32,
}

impl From<AutoSaveSettings> for UiAutoSaveSettings {
    fn from(settings: AutoSaveSettings) -> Self {
        Self {
            is_enabled: settings.is_enabled,
            interval_seconds: u32::try_from(settings.every_seconds.as_secs()).unwrap_or(u32::MAX),
        }
    }
}

impl From<UiAutoSaveSettings> for AutoSaveSettings {
    fn from(settings: UiAutoSaveSettings) -> Self {
        Self {
            every_seconds: Duration::from_secs(u64::from(settings.interval_seconds)),
            is_enabled: settings.is_enabled,
        }
    }
}

/// Auto saved project that can be recovered.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiRecoveryInfo {
    pub project_name: String,
    /// Project file the copy belongs to; `None` for an untitled project.
    pub original_path: Option<String>,
    /// Milliseconds since the Unix epoch when the copy was written.
    pub saved_at_millis: i64,
}

impl From<RecoveryInfo> for UiRecoveryInfo {
    fn from(info: RecoveryInfo) -> Self {
        Self {
            project_name: info.project_name,
            original_path: info
                .original_path
                .map(|path| path.to_string_lossy().into_owned()),
            saved_at_millis: info.saved_at.as_millisecond(),
        }
    }
}

/// One stored crash report, summarized for the recovery dialog.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiCrashReportSummary {
    /// Identifier used to export or remove the report.
    pub id: String,
    /// Stable code documented in `docs/CODE_ERROR_GUIDE.md`.
    pub code: u16,
    pub summary: String,
    /// Milliseconds since the Unix epoch when the crash happened.
    pub occurred_at_millis: i64,
    pub app_version: String,
}

impl From<StoredCrashReport> for UiCrashReportSummary {
    fn from(stored: StoredCrashReport) -> Self {
        Self {
            id: stored.id,
            code: stored.report.code,
            summary: stored.report.source.summary(),
            occurred_at_millis: stored.report.when.as_millisecond(),
            app_version: stored.report.app_version,
        }
    }
}

/// What the previous run left behind, reported once at startup.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiStartupRecovery {
    pub previous_session_unclean: bool,
    pub recovery: Option<UiRecoveryInfo>,
    pub crash_reports: Vec<UiCrashReportSummary>,
}

impl From<StartupRecovery> for UiStartupRecovery {
    fn from(startup: StartupRecovery) -> Self {
        Self {
            previous_session_unclean: startup.previous_session_unclean,
            recovery: startup.recovery.map(UiRecoveryInfo::from),
            crash_reports: startup
                .crash_reports
                .into_iter()
                .map(UiCrashReportSummary::from)
                .collect(),
        }
    }
}

/// Which Flutter error handler caught the crash.
#[derive(Clone, Copy, Debug)]
pub enum UiFlutterCrashKind {
    /// `FlutterError.onError`.
    FrameworkError,
    /// `PlatformDispatcher.onError`.
    UncaughtAsync,
}

// =======================================
// APIs
// =======================================

/// Configures crash reporting and auto save recovery under `support_dir`, then starts the auto
/// save worker. Call once after the project is initialized; later calls return the current state.
pub fn configure_mitigation(
    ctx: &DawContext,
    support_dir: String,
    app_version: String,
) -> anyhow::Result<UiStartupRecovery> {
    let startup = mitigation_api::configure(
        &mut ctx.runtime_write(),
        Path::new(&support_dir),
        &app_version,
    )?;
    start_auto_save_worker(ctx)?;
    Ok(startup.into())
}

/// Validates and applies auto save settings, and wakes the worker to use the new interval.
pub fn set_auto_save_settings(
    ctx: &DawContext,
    settings: UiAutoSaveSettings,
) -> anyhow::Result<UiAutoSaveSettings> {
    let applied =
        mitigation_api::set_auto_save_settings(&mut ctx.runtime_write(), settings.into())?;
    if let Some(wake) = ctx.inner.auto_save_wake.lock().as_ref() {
        let _ = wake.send(());
    }
    Ok(applied.into())
}

/// Writes a crash report for an error caught by a Flutter error handler.
#[frb(sync)]
pub fn record_flutter_crash(
    kind: UiFlutterCrashKind,
    source_library: Option<String>,
    message: String,
    stack: Option<String>,
) -> anyhow::Result<()> {
    let source = match kind {
        UiFlutterCrashKind::FrameworkError => FlutterCrashSource::FrameworkError {
            library: source_library,
            message,
            stack,
        },
        UiFlutterCrashKind::UncaughtAsync => FlutterCrashSource::UncaughtAsync { message, stack },
    };
    mitigation_api::record_flutter_crash(source)?;
    Ok(())
}

/// Lists stored crash reports, newest first.
pub fn list_crash_reports() -> anyhow::Result<Vec<UiCrashReportSummary>> {
    Ok(mitigation_api::crash_reports()?
        .into_iter()
        .map(UiCrashReportSummary::from)
        .collect())
}

/// Deletes one stored crash report.
pub fn remove_crash_report(id: String) -> anyhow::Result<()> {
    Ok(mitigation_api::remove_crash_report(&id)?)
}

/// Copies one crash report's JSON to `destination`.
pub fn export_crash_report(id: String, destination: String) -> anyhow::Result<()> {
    Ok(mitigation_api::export_crash_report(
        &id,
        Path::new(&destination),
    )?)
}

/// Replaces the live project with the auto saved copy. The recovered project is marked unsaved
/// and keeps the file path of the project it was auto saved from.
pub fn load_recovered_project(ctx: &DawContext) -> anyhow::Result<UiApplicationState> {
    let operation = ctx.begin_project_operation();
    let recovered = {
        let core = operation.read_core();
        let sample_rate = core.audio_runtime_settings.read().requested_dsp.sample_rate;
        mitigation_api::load_recovery_file(&core, sample_rate)?
    };
    let ui_state = restore_loaded_project(&operation, recovered)?;
    log::info!("Recovered the auto saved project");
    Ok(ui_state)
}

/// Deletes the auto saved copy.
pub fn discard_recovered_project(ctx: &DawContext) -> anyhow::Result<()> {
    Ok(mitigation_api::discard_recovery(&ctx.read())?)
}

/// Suspends the session while a mobile app is backgrounded, and resumes it on return, so an OS
/// kill in the background is not reported as a crash. The recovery copy is kept.
pub fn set_session_suspended(ctx: &DawContext, suspended: bool) -> anyhow::Result<()> {
    Ok(mitigation_api::set_session_suspended(
        &ctx.read(),
        suspended,
    )?)
}

/// Ends the session cleanly so the next launch does not report a crash or offer recovery.
pub fn mark_clean_shutdown(ctx: &DawContext) -> anyhow::Result<()> {
    Ok(mitigation_api::mark_clean_shutdown(&ctx.read())?)
}

// =======================================
// Auto save worker
// =======================================

/// Result of one auto save attempt.
#[derive(Debug, PartialEq, Eq)]
pub(crate) enum AutoSaveOutcome {
    /// A recovery copy was written.
    Saved,
    /// Disabled, unconfigured, or nothing new to save.
    Idle,
    /// Another save, load, or export holds the project; try again shortly.
    Busy,
}

/// Runs one auto save if enabled and needed. Skips while another project operation runs.
pub(crate) fn auto_save_once(ctx: &DawContext) -> anyhow::Result<AutoSaveOutcome> {
    let Some(_operation) = ctx.try_runtime_operation() else {
        return Ok(AutoSaveOutcome::Busy);
    };
    let Some(pending) = mitigation_api::begin_auto_save(&ctx.read()) else {
        return Ok(AutoSaveOutcome::Idle);
    };
    let revision = mitigation_api::execute_auto_save(pending)?;
    mitigation_api::commit_auto_save(&mut ctx.runtime_write(), revision);
    Ok(AutoSaveOutcome::Saved)
}

fn start_auto_save_worker(ctx: &DawContext) -> anyhow::Result<()> {
    let mut wake = ctx.inner.auto_save_wake.lock();
    if wake.is_some() {
        return Ok(());
    }
    let (sender, receiver) = mpsc::channel();
    let session = Arc::downgrade(&ctx.inner);
    std::thread::Builder::new()
        .name("karbeat-auto-save".into())
        .spawn(move || run_auto_save_worker(session, receiver))?;
    *wake = Some(sender);
    Ok(())
}

/// Sleeps for the configured interval, auto saves, and repeats. Holds only a weak session
/// reference between ticks and exits once the session is dropped.
fn run_auto_save_worker(session: Weak<DawSessionInner>, wake: mpsc::Receiver<()>) {
    let mut delay = None;
    loop {
        let Some(interval) = delay.take().or_else(|| {
            let inner = session.upgrade()?;
            Some(
                inner_context(inner)
                    .read()
                    .session_settings
                    .auto_save
                    .every_seconds,
            )
        }) else {
            return;
        };
        match wake.recv_timeout(interval) {
            Ok(()) => continue,
            Err(RecvTimeoutError::Disconnected) => return,
            Err(RecvTimeoutError::Timeout) => {}
        }
        let Some(inner) = session.upgrade() else {
            return;
        };
        match auto_save_once(&inner_context(inner)) {
            Ok(AutoSaveOutcome::Saved) => log::info!("Auto saved a recovery copy"),
            Ok(AutoSaveOutcome::Idle) => {}
            Ok(AutoSaveOutcome::Busy) => delay = Some(BUSY_RETRY),
            Err(error) => log::warn!("Auto save failed: {error:#}"),
        }
    }
}

fn inner_context(inner: Arc<DawSessionInner>) -> DawContext {
    DawContext { inner }
}

#[cfg(test)]
mod tests {
    use super::{AutoSaveOutcome, auto_save_once};
    use crate::api::context::DawContext;
    use crate::sync::check_random;
    use karbeat_core::api::{mitigation_api, track_api};

    #[test]
    fn auto_save_skips_busy_and_idle_sessions_and_writes_dirty_ones() {
        let dir = tempfile::tempdir().expect("temporary directory");
        let root = dir.path().to_path_buf();
        check_random(
            move || {
                let session = DawContext::new(karbeat_core::context::DawContext::new());
                assert_eq!(
                    auto_save_once(&session).expect("unconfigured"),
                    AutoSaveOutcome::Idle
                );

                mitigation_api::configure(&mut session.runtime_write(), &root, "test")
                    .expect("configure");
                track_api::add_new_audio_track(&mut session.project_write());

                let operation = session.begin_project_operation();
                assert_eq!(
                    auto_save_once(&session).expect("busy"),
                    AutoSaveOutcome::Busy
                );
                drop(operation);

                assert_eq!(
                    auto_save_once(&session).expect("dirty"),
                    AutoSaveOutcome::Saved
                );
                assert_eq!(
                    auto_save_once(&session).expect("already saved"),
                    AutoSaveOutcome::Idle
                );
                assert!(!mitigation_api::is_project_saved(&session.read()));
            },
            1,
        );
    }
}
