use std::{
    io::ErrorKind,
    path::{Path, PathBuf},
    time::Duration,
};

use jiff::Timestamp;
use serde::{Deserialize, Serialize};
use thiserror::Error;

use super::MitigationError;

/// Shortest accepted auto save interval.
pub const MIN_AUTO_SAVE_INTERVAL: Duration = Duration::from_mins(1);
/// Longest accepted auto save interval.
pub const MAX_AUTO_SAVE_INTERVAL: Duration = Duration::from_hours(1);
/// Interval used until the user chooses one.
pub const DEFAULT_AUTO_SAVE_INTERVAL: Duration = Duration::from_mins(5);

/// Define Auto Save Settings. Put it inside A session settings struct. In
/// `SessionState` struct, there is `is_saved` to track whether the project
/// has been saved after changes. With that property, app can give warning
/// for unsaved project
///
/// Should persists in every sessions. The host app stores the values in its preferences and
/// applies them at startup; the engine only keeps the active copy.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct AutoSaveSettings {
    /// Frequency time in which auto save is executed
    pub every_seconds: Duration,
    /// Whether the auto save worker writes recovery copies at all.
    pub is_enabled: bool,
}

impl Default for AutoSaveSettings {
    fn default() -> Self {
        Self {
            every_seconds: DEFAULT_AUTO_SAVE_INTERVAL,
            is_enabled: true,
        }
    }
}

/// Rejected auto save settings.
#[derive(Debug, Error, PartialEq, Eq)]
pub enum AutoSaveSettingsError {
    /// The interval lies outside the supported range.
    #[error("Auto save interval must be between {minimum} and {maximum} seconds, got {requested}")]
    IntervalOutOfRange {
        /// Requested interval in seconds.
        requested: u64,
        /// Shortest accepted interval in seconds.
        minimum: u64,
        /// Longest accepted interval in seconds.
        maximum: u64,
    },
}

impl AutoSaveSettings {
    /// Returns the settings unchanged when the interval is within the supported range.
    pub fn validated(self) -> Result<Self, AutoSaveSettingsError> {
        if !(MIN_AUTO_SAVE_INTERVAL..=MAX_AUTO_SAVE_INTERVAL).contains(&self.every_seconds) {
            return Err(AutoSaveSettingsError::IntervalOutOfRange {
                requested: self.every_seconds.as_secs(),
                minimum: MIN_AUTO_SAVE_INTERVAL.as_secs(),
                maximum: MAX_AUTO_SAVE_INTERVAL.as_secs(),
            });
        }
        Ok(self)
    }
}

/// Application-level settings that survive project replacement but are never saved in a project.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct SessionSettings {
    /// Active auto save configuration.
    pub auto_save: AutoSaveSettings,
}

/// Describes the recovery copy written by the most recent auto save.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct RecoveryInfo {
    /// Project title at the time of the auto save.
    pub project_name: String,
    /// File the project was loaded from or last saved to; `None` for an untitled project.
    pub original_path: Option<PathBuf>,
    /// When the recovery copy was written.
    pub saved_at: Timestamp,
}

/// Owns the auto save directory holding a single recovery copy and its [`RecoveryInfo`].
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RecoveryStore {
    dir: PathBuf,
}

impl RecoveryStore {
    const PROJECT_FILE: &'static str = "recovery.dgdaw";
    const INFO_FILE: &'static str = "recovery.json";

    /// Creates the directory when missing.
    pub fn open(dir: impl Into<PathBuf>) -> Result<Self, MitigationError> {
        let dir = dir.into();
        std::fs::create_dir_all(&dir)?;
        Ok(Self { dir })
    }

    /// Project file the auto save worker writes.
    pub fn project_path(&self) -> PathBuf {
        self.dir.join(Self::PROJECT_FILE)
    }

    fn info_path(&self) -> PathBuf {
        self.dir.join(Self::INFO_FILE)
    }

    /// Records which project the recovery copy belongs to. Call after the copy is written.
    pub fn write_info(&self, info: &RecoveryInfo) -> Result<(), MitigationError> {
        write_json_atomically(&self.info_path(), info)
    }

    /// Returns the recovery description when both it and the recovery copy exist.
    pub fn read_info(&self) -> Result<Option<RecoveryInfo>, MitigationError> {
        if !self.project_path().is_file() {
            return Ok(None);
        }
        match std::fs::read(self.info_path()) {
            Ok(bytes) => Ok(Some(serde_json::from_slice(&bytes)?)),
            Err(error) if error.kind() == ErrorKind::NotFound => Ok(None),
            Err(error) => Err(error.into()),
        }
    }

    /// Deletes the recovery copy and its description.
    pub fn clear(&self) -> Result<(), MitigationError> {
        remove_if_exists(&self.info_path())?;
        remove_if_exists(&self.project_path())?;
        Ok(())
    }
}

pub(super) fn write_json_atomically<T: Serialize>(
    path: &Path,
    value: &T,
) -> Result<(), MitigationError> {
    let bytes = serde_json::to_vec_pretty(value)?;
    let temporary = path.with_extension("json.tmp");
    std::fs::write(&temporary, bytes)?;
    std::fs::rename(&temporary, path)?;
    Ok(())
}

pub(super) fn remove_if_exists(path: &Path) -> Result<(), MitigationError> {
    match std::fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error.into()),
    }
}

#[cfg(test)]
#[allow(
    clippy::expect_used,
    reason = "recovery store tests fail immediately when temporary files cannot be used"
)]
mod tests {
    use super::*;

    #[test]
    fn interval_bounds_are_enforced() {
        let settings = |secs| AutoSaveSettings {
            every_seconds: Duration::from_secs(secs),
            is_enabled: true,
        };

        assert!(settings(60).validated().is_ok());
        assert!(settings(3600).validated().is_ok());
        assert_eq!(
            settings(59).validated(),
            Err(AutoSaveSettingsError::IntervalOutOfRange {
                requested: 59,
                minimum: 60,
                maximum: 3600,
            })
        );
        assert!(settings(3601).validated().is_err());
        assert!(AutoSaveSettings::default().validated().is_ok());
    }

    #[test]
    fn recovery_info_requires_the_recovery_copy() {
        let dir = tempfile::tempdir().expect("temporary directory");
        let store = RecoveryStore::open(dir.path().join("autosave")).expect("open store");
        let info = RecoveryInfo {
            project_name: "Song".into(),
            original_path: Some("/music/song.dgdaw".into()),
            saved_at: Timestamp::UNIX_EPOCH,
        };

        store.write_info(&info).expect("write info");
        assert_eq!(store.read_info().expect("read info"), None);

        std::fs::write(store.project_path(), b"project").expect("write copy");
        assert_eq!(store.read_info().expect("read info"), Some(info));

        store.clear().expect("clear");
        assert_eq!(store.read_info().expect("read info"), None);
        store.clear().expect("clearing twice is fine");
    }
}
