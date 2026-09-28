//! Mitigation-related code to handle Auto save, and Crash reporting handle
//!
//! Everything here lives under one application-support directory chosen by the host app:
//!
//! ```text
//! <root>/
//!   session.lock          present while a session runs; a stale one means the last run crashed
//!   autosave/
//!     recovery.dgdaw      latest auto saved copy of the open project
//!     recovery.json       RecoveryInfo describing that copy
//!   crashes/
//!     crash-<ns>-<code>.json
//! ```

use std::path::{Path, PathBuf};

use thiserror::Error;

/// Auto save settings and the recovery copy it writes.
pub mod auto_save;
/// Typed crash sources, reports, the report store, and the Rust panic hook.
pub mod crash;
/// Hardware and operating-system description attached to crash reports.
pub mod device;
/// Stale-session detection used to report crashes that no hook could observe.
pub mod session_marker;

pub use auto_save::{
    AutoSaveSettings, AutoSaveSettingsError, MAX_AUTO_SAVE_INTERVAL, MIN_AUTO_SAVE_INTERVAL,
    RecoveryInfo, RecoveryStore, SessionSettings,
};
pub use crash::{
    CrashReport, CrashReporter, CrashSource, CrashStore, FlutterCrashSource, RustCrashSource,
    StoredCrashReport,
};
pub use device::UserDevice;

/// Failure while reading or writing mitigation files.
#[derive(Debug, Error)]
pub enum MitigationError {
    /// Filesystem access failed.
    #[error("Mitigation file access failed: {0}")]
    Io(#[from] std::io::Error),
    /// A report or recovery description could not be encoded or decoded.
    #[error("Mitigation file is not valid JSON: {0}")]
    Json(#[from] serde_json::Error),
    /// A crash report identifier did not name a report inside the crash directory.
    #[error("Invalid crash report id '{0}'")]
    InvalidReportId(String),
    /// Crash reporting was used before the application configured its directory.
    #[error("Crash reporting has not been configured")]
    NotConfigured,
}

/// Mitigation locations held by the engine context once the host app configures them.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MitigationState {
    /// Auto save recovery copy location.
    pub recovery: RecoveryStore,
    /// Session marker removed on clean shutdown.
    pub session_marker: PathBuf,
}

/// Directory layout for session markers, auto save recovery copies, and crash reports.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MitigationPaths {
    root: PathBuf,
}

impl MitigationPaths {
    /// Uses `root` (normally the platform application-support directory) as the layout root.
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    /// Root directory supplied by the host application.
    pub fn root(&self) -> &Path {
        &self.root
    }

    /// Directory holding the recovery copy and its description.
    pub fn autosave_dir(&self) -> PathBuf {
        self.root.join("autosave")
    }

    /// Directory holding one JSON file per crash report.
    pub fn crash_dir(&self) -> PathBuf {
        self.root.join("crashes")
    }

    /// Marker file present while a session is running.
    pub fn session_marker(&self) -> PathBuf {
        self.root.join("session.lock")
    }
}
