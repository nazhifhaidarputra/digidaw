use std::path::Path;

use jiff::Timestamp;

use crate::{
    context::DawContext,
    core::{
        file_manager::project_loader::load_daw_project,
        mitigation::{
            AutoSaveSettings, CrashReporter, CrashSource, CrashStore, FlutterCrashSource,
            MitigationError, MitigationPaths, MitigationState, RecoveryInfo, RecoveryStore,
            RustCrashSource, StoredCrashReport, UserDevice, crash, session_marker,
            session_marker::PreviousSession,
        },
        project::ApplicationState,
    },
};

/// What the previous run left behind, reported once at startup.
#[derive(Clone, Debug)]
pub struct StartupRecovery {
    /// The previous session ended without a clean shutdown.
    pub previous_session_unclean: bool,
    /// The previous session was terminated on request, such as by Ctrl+C. Not a crash.
    pub previous_session_forced: bool,
    /// Auto saved copy that can be recovered.
    pub recovery: Option<RecoveryInfo>,
    /// Crash reports on disk, newest first.
    pub crash_reports: Vec<StoredCrashReport>,
}

/// Configures crash reporting and auto save recovery under `root`, starts the session marker,
/// and reports what the previous run left behind.
///
/// A stale session marker is recorded as a [`RustCrashSource::UncleanShutdown`] report.
pub fn configure(
    ctx: &mut DawContext,
    root: &Path,
    app_version: &str,
) -> Result<StartupRecovery, MitigationError> {
    let paths = MitigationPaths::new(root);
    let reporter = crash::configure_reporter(CrashReporter::new(
        CrashStore::open(paths.crash_dir())?,
        UserDevice::detect(),
        app_version,
    ));
    let recovery_store = RecoveryStore::open(paths.autosave_dir())?;

    let previous_session = session_marker::begin_session(&paths.session_marker())?;
    match previous_session {
        PreviousSession::Unclean => {
            reporter.record(CrashSource::Rust(RustCrashSource::UncleanShutdown))?;
        }
        PreviousSession::Forced => log::info!("The previous session was forcibly shut down"),
        PreviousSession::Clean => {}
    }

    let recovery = recovery_store.read_info()?;
    ctx.mitigation = Some(MitigationState {
        recovery: recovery_store,
        session_marker: paths.session_marker(),
    });
    Ok(StartupRecovery {
        previous_session_unclean: previous_session == PreviousSession::Unclean,
        previous_session_forced: previous_session == PreviousSession::Forced,
        recovery,
        crash_reports: reporter.store().list()?,
    })
}

/// Records a crash reported by the Flutter UI.
pub fn record_flutter_crash(source: FlutterCrashSource) -> Result<String, MitigationError> {
    crash::reporter()
        .ok_or(MitigationError::NotConfigured)?
        .record(CrashSource::Flutter(source))
}

/// Lists stored crash reports, newest first.
pub fn crash_reports() -> Result<Vec<StoredCrashReport>, MitigationError> {
    crash::reporter()
        .ok_or(MitigationError::NotConfigured)?
        .store()
        .list()
}

/// Deletes one stored crash report.
pub fn remove_crash_report(id: &str) -> Result<(), MitigationError> {
    crash::reporter()
        .ok_or(MitigationError::NotConfigured)?
        .store()
        .remove(id)
}

/// Copies one stored crash report's JSON to `destination`.
pub fn export_crash_report(id: &str, destination: &Path) -> Result<(), MitigationError> {
    crash::reporter()
        .ok_or(MitigationError::NotConfigured)?
        .store()
        .export(id, destination)
}

/// Validates and applies auto save settings, returning the active values.
pub fn set_auto_save_settings(
    ctx: &mut DawContext,
    settings: AutoSaveSettings,
) -> anyhow::Result<AutoSaveSettings> {
    ctx.session_settings.auto_save = settings.validated()?;
    Ok(ctx.session_settings.auto_save)
}

/// Returns the active auto save settings.
pub fn auto_save_settings(ctx: &DawContext) -> AutoSaveSettings {
    ctx.session_settings.auto_save
}

/// Whether the current project has no unsaved changes.
pub fn is_project_saved(ctx: &DawContext) -> bool {
    ctx.app_state.session.is_saved()
}

/// Auto save work captured while the project is readable; the slow write happens afterwards.
pub struct PendingAutoSave {
    save: super::project_api::PendingProjectSave,
    store: RecoveryStore,
    info: RecoveryInfo,
}

/// Starts an auto save when it is enabled, configured, and there are unwritten changes.
///
/// The caller must hold the project-operation lock until [`commit_auto_save`], so no load or
/// save can replace the project in between.
pub fn begin_auto_save(ctx: &DawContext) -> Option<PendingAutoSave> {
    let store = ctx.mitigation.as_ref()?.recovery.clone();
    if !ctx.session_settings.auto_save.is_enabled || !ctx.app_state.session.needs_autosave() {
        return None;
    }
    let project_path = store.project_path();
    Some(PendingAutoSave {
        save: super::project_api::begin_save_project(ctx, &project_path.to_string_lossy()),
        info: RecoveryInfo {
            project_name: ctx.app_state.metadata.name.clone(),
            original_path: ctx.app_state.session.file_path().map(Path::to_path_buf),
            saved_at: Timestamp::now(),
        },
        store,
    })
}

/// Writes the recovery copy and its description. Returns the revision it captured.
pub fn execute_auto_save(pending: PendingAutoSave) -> anyhow::Result<u64> {
    let completed = super::project_api::execute_save_project(pending.save)?;
    pending.store.write_info(&RecoveryInfo {
        saved_at: Timestamp::now(),
        ..pending.info
    })?;
    Ok(completed.revision())
}

/// Records that the recovery copy covers every change up to `revision`. The project stays
/// unsaved: auto save never replaces an explicit save.
pub fn commit_auto_save(ctx: &mut DawContext, revision: u64) {
    ctx.app_state.session.mark_autosaved_at(revision);
}

/// Loads the recovery copy as a staged project marked unsaved and pointing at its original file.
pub fn load_recovery_file(ctx: &DawContext, sample_rate: u32) -> anyhow::Result<ApplicationState> {
    let store = &ctx
        .mitigation
        .as_ref()
        .ok_or(MitigationError::NotConfigured)?
        .recovery;
    let info = store
        .read_info()?
        .ok_or_else(|| anyhow::anyhow!("There is no auto saved project to recover"))?;
    let mut recovered = load_daw_project(&store.project_path(), sample_rate)?;
    recovered.session.set_file_path(info.original_path);
    recovered.session.mark_modified();
    Ok(recovered)
}

/// Deletes the recovery copy.
pub fn discard_recovery(ctx: &DawContext) -> Result<(), MitigationError> {
    match &ctx.mitigation {
        Some(mitigation) => mitigation.recovery.clear(),
        None => Ok(()),
    }
}

/// Suspends or resumes the session marker without touching the recovery copy.
///
/// Mobile platforms may kill a backgrounded app without warning; that is not a crash. Suspending
/// on background and resuming on foreground keeps those launches from being reported, while the
/// recovery copy stays available.
pub fn set_session_suspended(ctx: &DawContext, suspended: bool) -> Result<(), MitigationError> {
    let Some(mitigation) = &ctx.mitigation else {
        return Ok(());
    };
    if suspended {
        session_marker::end_session(&mitigation.session_marker)
    } else {
        session_marker::begin_session(&mitigation.session_marker).map(|_| ())
    }
}

/// Records termination signals such as Ctrl+C as a forced shutdown rather than a crash.
///
/// Installs process-wide signal handling, so only the application calls this, once mitigation is
/// configured. Does nothing on platforms without POSIX signals.
pub fn watch_shutdown_signals(ctx: &DawContext) {
    #[cfg(unix)]
    if let Some(mitigation) = &ctx.mitigation {
        crate::core::mitigation::shutdown_signals::watch(mitigation.session_marker.clone());
    }
    #[cfg(not(unix))]
    let _ = ctx;
}

/// Ends the session cleanly: removes the recovery copy and the session marker.
pub fn mark_clean_shutdown(ctx: &DawContext) -> Result<(), MitigationError> {
    if let Some(mitigation) = &ctx.mitigation {
        mitigation.recovery.clear()?;
        session_marker::end_session(&mitigation.session_marker)?;
    }
    Ok(())
}
