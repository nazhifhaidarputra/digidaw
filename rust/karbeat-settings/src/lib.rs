//! App-wide settings that outlive a session, stored as TOML files in one directory.
//!
//! ```text
//! <dir>/
//!   settings.toml               preferences, one section per settings page
//!   automation-templates.toml   automation curve template library
//!   plugin-favorites.toml       favorite plugins
//!   sample-folders.toml         sample browser folders
//!   recent-projects.toml        recently opened projects
//! ```
//!
//! [`SettingsStore`] is a plain value: the app keeps one for the process, and tests open their
//! own in a temporary directory.

use std::{
    fs::create_dir_all,
    io::Error as IoError,
    path::{Path, PathBuf},
};

use thiserror::Error;
use toml::ser::Error as TomlEncodeError;

/// Reading and atomically writing one settings file.
pub mod file;
mod lenient;
/// Automation curve templates, favorite plugins and sample folders.
pub mod library;
/// The user's preferences.
pub mod preferences;

pub use file::{Recovered, SettingsFile};
pub use library::{
    AutomationTemplate, AutomationTemplates, CurveType, PluginFavorites, RecentProjects,
    SampleFolders, TemplatePoint,
};
pub use preferences::{
    AppearanceSettings, AudioPreferences, BackgroundFit, ColorPalette, ColorThemeChoice,
    GeneralSettings, LogLevel, LogSettings, PluginScanSettings, Preferences, ShortcutChord,
    ShortcutSettings, ThemeMode,
};

/// Failure while reading, changing or writing settings.
#[derive(Debug, Error)]
pub enum SettingsError {
    /// Filesystem access failed.
    #[error("Settings file access failed: {0}")]
    Io(#[from] IoError),
    /// Settings could not be written as TOML.
    #[error("Settings could not be encoded: {0}")]
    Encode(#[from] TomlEncodeError),
    /// A folder setting named something that is not an existing folder.
    #[error("'{}' is not an existing folder", .0.display())]
    NotAFolder(PathBuf),
}

/// Every settings file of one directory, loaded in memory and written on each change.
#[derive(Clone, Debug)]
pub struct SettingsStore {
    dir: PathBuf,
    preferences: Preferences,
    automation_templates: AutomationTemplates,
    plugin_favorites: PluginFavorites,
    sample_folders: SampleFolders,
    recent_projects: RecentProjects,
}

impl SettingsStore {
    /// Loads every settings file in `dir`, creating `dir` when missing.
    ///
    /// Missing files give defaults. Files that could not be read are moved aside, replaced by
    /// defaults, and listed in the returned [`Recovered`] entries.
    pub fn open(dir: impl Into<PathBuf>) -> Result<(Self, Vec<Recovered>), SettingsError> {
        let dir = dir.into();
        create_dir_all(&dir)?;
        let mut recovered = Vec::new();
        let store = Self {
            preferences: load(&dir, &mut recovered)?,
            automation_templates: load(&dir, &mut recovered)?,
            plugin_favorites: load(&dir, &mut recovered)?,
            sample_folders: load(&dir, &mut recovered)?,
            recent_projects: load(&dir, &mut recovered)?,
            dir,
        };
        Ok((store, recovered))
    }

    /// Directory holding the settings files.
    pub fn dir(&self) -> &Path {
        &self.dir
    }

    /// The user's preferences.
    pub fn preferences(&self) -> &Preferences {
        &self.preferences
    }

    /// Applies `change` to the preferences, brings them into range and saves them.
    ///
    /// Nothing changes when a changed folder setting is not an existing folder or saving fails.
    pub fn update_preferences(
        &mut self,
        change: impl FnOnce(&mut Preferences),
    ) -> Result<&Preferences, SettingsError> {
        let mut next = self.preferences.clone();
        change(&mut next);
        next.validate_changes(&self.preferences)?;
        replace(&self.dir, &mut self.preferences, next)
    }

    /// The automation curve template library.
    pub fn automation_templates(&self) -> &AutomationTemplates {
        &self.automation_templates
    }

    /// Replaces and saves the automation curve template library.
    pub fn set_automation_templates(
        &mut self,
        templates: AutomationTemplates,
    ) -> Result<&AutomationTemplates, SettingsError> {
        replace(&self.dir, &mut self.automation_templates, templates)
    }

    /// The favorite plugins.
    pub fn plugin_favorites(&self) -> &PluginFavorites {
        &self.plugin_favorites
    }

    /// Replaces and saves the favorite plugins.
    pub fn set_plugin_favorites(
        &mut self,
        favorites: PluginFavorites,
    ) -> Result<&PluginFavorites, SettingsError> {
        replace(&self.dir, &mut self.plugin_favorites, favorites)
    }

    /// The sample browser folders.
    pub fn sample_folders(&self) -> &SampleFolders {
        &self.sample_folders
    }

    /// Replaces and saves the sample browser folders.
    pub fn set_sample_folders(
        &mut self,
        folders: SampleFolders,
    ) -> Result<&SampleFolders, SettingsError> {
        replace(&self.dir, &mut self.sample_folders, folders)
    }

    /// Recently opened projects, most recent first.
    pub fn recent_projects(&self) -> &RecentProjects {
        &self.recent_projects
    }

    /// Makes `path` the most recent project and saves the list.
    pub fn record_recent_project(
        &mut self,
        path: impl Into<PathBuf>,
    ) -> Result<&RecentProjects, SettingsError> {
        let mut next = self.recent_projects.clone();
        next.record(path.into());
        replace(&self.dir, &mut self.recent_projects, next)
    }

    /// Replaces and saves the recent projects, e.g. to forget one or all of them.
    pub fn set_recent_projects(
        &mut self,
        projects: RecentProjects,
    ) -> Result<&RecentProjects, SettingsError> {
        replace(&self.dir, &mut self.recent_projects, projects)
    }
}

/// Loads one file, adding it to `recovered` when it had to be replaced by defaults.
fn load<T: SettingsFile>(dir: &Path, recovered: &mut Vec<Recovered>) -> Result<T, SettingsError> {
    let loaded = file::load(dir)?;
    recovered.extend(loaded.recovered);
    Ok(loaded.value)
}

/// Normalizes and saves `next`, and keeps it in `slot` only once it is saved.
fn replace<'a, T: SettingsFile>(
    dir: &Path,
    slot: &'a mut T,
    mut next: T,
) -> Result<&'a T, SettingsError> {
    next.normalize();
    file::save(dir, &next)?;
    *slot = next;
    Ok(slot)
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "settings tests fail immediately when temporary file I/O breaks"
)]
mod tests;
