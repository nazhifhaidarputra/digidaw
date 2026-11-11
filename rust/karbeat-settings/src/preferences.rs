//! The user's preferences, stored in `settings.toml`.

use std::{
    collections::BTreeMap,
    ops::RangeInclusive,
    path::{Path, PathBuf},
};

use serde::{Deserialize, Serialize};

use crate::{SettingsError, file::SettingsFile, lenient};

/// Every preference, one section per settings page.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct Preferences {
    /// Undo history, auto save and default folders.
    #[serde(deserialize_with = "lenient::section")]
    pub general: GeneralSettings,
    /// Audio devices, engine timing and the metronome sound.
    #[serde(deserialize_with = "lenient::section")]
    pub audio: AudioPreferences,
    /// Theme, colors, background and font.
    #[serde(deserialize_with = "lenient::section")]
    pub appearance: AppearanceSettings,
    /// What the log viewer keeps.
    #[serde(deserialize_with = "lenient::section")]
    pub logs: LogSettings,
    /// Keyboard shortcuts changed from their defaults.
    #[serde(deserialize_with = "lenient::section")]
    pub shortcuts: ShortcutSettings,
    /// Where and how hosted plugins are scanned.
    #[serde(deserialize_with = "lenient::section")]
    pub plugin_scan: PluginScanSettings,
}

impl SettingsFile for Preferences {
    const FILE_NAME: &'static str = "settings.toml";

    fn normalize(&mut self) {
        self.appearance.normalize();
        self.logs.normalize();
    }
}

impl Preferences {
    /// Checks the values that changed from `previous`, which may have been accepted before
    /// whatever they point at disappeared.
    pub(crate) fn validate_changes(&self, previous: &Self) -> Result<(), SettingsError> {
        self.general.validate_changes(&previous.general)
    }
}

/// Undo history, auto save and default folders.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
pub struct GeneralSettings {
    /// Undo entries kept; 0 disables undo.
    pub history_limit: u32,
    /// Whether a recovery copy is written periodically.
    pub auto_save_enabled: bool,
    /// Seconds between recovery copies.
    pub auto_save_interval_seconds: u32,
    /// Folder the project save and open dialogs start in; `None` lets the dialog choose.
    pub default_project_folder: Option<PathBuf>,
    /// Folder exports go to unless another one is chosen; `None` asks every time.
    pub default_export_folder: Option<PathBuf>,
    /// Whether the project menu lists recently opened projects.
    pub show_recent_projects: bool,
}

impl Default for GeneralSettings {
    fn default() -> Self {
        Self {
            history_limit: 100,
            auto_save_enabled: true,
            auto_save_interval_seconds: 300,
            default_project_folder: None,
            default_export_folder: None,
            show_recent_projects: true,
        }
    }
}

impl GeneralSettings {
    fn validate_changes(&self, previous: &Self) -> Result<(), SettingsError> {
        let folders = [
            (
                &self.default_project_folder,
                &previous.default_project_folder,
            ),
            (&self.default_export_folder, &previous.default_export_folder),
        ];
        for (folder, before) in folders {
            if let Some(folder) = folder
                && Some(folder) != before.as_ref()
                && !is_existing_folder(folder)
            {
                return Err(SettingsError::NotAFolder(folder.clone()));
            }
        }
        Ok(())
    }
}

fn is_existing_folder(path: &Path) -> bool {
    path.is_absolute() && path.is_dir()
}

/// Audio devices, engine timing and the metronome sound.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
pub struct AudioPreferences {
    /// Audio host (e.g. ALSA, WASAPI); `None` uses the system default.
    pub output_host: Option<String>,
    /// Output device id; `None` uses the host's default device.
    pub output_device: Option<String>,
    /// Whether device input is opened.
    pub input_enabled: bool,
    /// Input device id; `None` uses the system default input.
    pub input_device: Option<String>,
    /// Engine sample rate in Hz.
    pub sample_rate: u32,
    /// Frames rendered per engine block.
    pub block_size: u32,
    /// Audio file played by the metronome; `None` uses the built-in click.
    pub metronome_sound: Option<PathBuf>,
}

impl Default for AudioPreferences {
    fn default() -> Self {
        Self {
            output_host: None,
            output_device: None,
            input_enabled: false,
            input_device: None,
            sample_rate: 48_000,
            block_size: 1024,
            metronome_sound: None,
        }
    }
}

/// Light or dark theme.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ThemeMode {
    /// Follows the operating system.
    System,
    /// Light theme.
    Light,
    /// Dark theme.
    #[default]
    Dark,
}

/// Accent color used when no color theme file is chosen.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
#[expect(missing_docs, reason = "each variant is the color it names")]
pub enum ColorPalette {
    #[default]
    Purple,
    Blue,
    Teal,
    Orange,
    Red,
    Green,
    Pink,
    Cyan,
    Indigo,
    Amber,
    Lime,
    Magenta,
    Graphite,
}

/// How the background image fills the window.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum BackgroundFit {
    /// Fills the window, cropping the image.
    #[default]
    Cover,
    /// Shows the whole image, leaving bars.
    Contain,
    /// Stretches the image to the window.
    Fill,
}

/// Where the app's colors come from.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ColorThemeChoice {
    /// The color theme bundled with the app.
    #[default]
    Default,
    /// Colors derived from the accent palette.
    AccentPalette,
    /// A color theme, named by an asset or a file path.
    Source(String),
}

/// Theme, colors, background and font.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct AppearanceSettings {
    /// Light or dark theme.
    pub theme_mode: ThemeMode,
    /// Accent palette.
    pub color_palette: ColorPalette,
    /// Background image file; `None` shows no image.
    pub background_image: Option<PathBuf>,
    /// How the background image fills the window.
    pub background_fit: BackgroundFit,
    /// Opacity of the layer over the background image, within [`Self::OVERLAY_RANGE`].
    pub background_overlay: f64,
    /// Font file; `None` uses the bundled font.
    pub font_path: Option<PathBuf>,
    /// Family name registered for the font file.
    pub font_family: Option<String>,
    /// Where the colors come from.
    pub color_theme: ColorThemeChoice,
    /// Color theme files the user loaded, offered in the theme list.
    pub custom_color_theme_paths: Vec<PathBuf>,
}

impl AppearanceSettings {
    /// Allowed background overlay opacities.
    pub const OVERLAY_RANGE: RangeInclusive<f64> = 0.0..=0.9;
    /// Overlay opacity used when none is stored.
    pub const DEFAULT_OVERLAY: f64 = 0.35;

    fn normalize(&mut self) {
        if !Self::OVERLAY_RANGE.contains(&self.background_overlay) {
            self.background_overlay = Self::DEFAULT_OVERLAY;
        }
    }
}

impl Default for AppearanceSettings {
    fn default() -> Self {
        Self {
            theme_mode: ThemeMode::default(),
            color_palette: ColorPalette::default(),
            background_image: None,
            background_fit: BackgroundFit::default(),
            background_overlay: Self::DEFAULT_OVERLAY,
            font_path: None,
            font_family: None,
            color_theme: ColorThemeChoice::default(),
            custom_color_theme_paths: Vec::new(),
        }
    }
}

/// Least severe log level the log viewer keeps.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
#[expect(missing_docs, reason = "each variant is the level it names")]
pub enum LogLevel {
    Trace,
    Debug,
    #[default]
    Info,
    Warning,
    Error,
    Fatal,
}

/// What the log viewer keeps.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
pub struct LogSettings {
    /// Least severe level kept.
    pub minimum_level: LogLevel,
    /// Entries kept, within [`Self::ENTRIES_RANGE`].
    pub maximum_entries: u32,
}

impl LogSettings {
    /// Allowed numbers of kept entries.
    pub const ENTRIES_RANGE: RangeInclusive<u32> = 50..=2000;
    /// Entries kept when none is stored.
    pub const DEFAULT_ENTRIES: u32 = 250;

    fn normalize(&mut self) {
        if !Self::ENTRIES_RANGE.contains(&self.maximum_entries) {
            self.maximum_entries = Self::DEFAULT_ENTRIES;
        }
    }
}

impl Default for LogSettings {
    fn default() -> Self {
        Self {
            minimum_level: LogLevel::default(),
            maximum_entries: Self::DEFAULT_ENTRIES,
        }
    }
}

/// A key with its modifiers.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ShortcutChord {
    /// Flutter logical key id.
    pub key: i64,
    /// Control held.
    pub control: bool,
    /// Shift held.
    pub shift: bool,
    /// Alt held.
    pub alt: bool,
    /// Meta (Super, Command) held.
    pub meta: bool,
}

/// Keyboard shortcuts changed from their defaults.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
pub struct ShortcutSettings {
    /// Chord bound to each changed action, by action id.
    #[serde(deserialize_with = "lenient::map")]
    pub overrides: BTreeMap<String, ShortcutChord>,
}

/// Where and how hosted plugins are scanned.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
pub struct PluginScanSettings {
    /// Folders searched recursively for plugins.
    pub directories: Vec<PathBuf>,
    /// Seconds one plugin may take to be scanned.
    pub timeout_seconds: u64,
}

impl Default for PluginScanSettings {
    fn default() -> Self {
        Self {
            directories: Vec::new(),
            timeout_seconds: 30,
        }
    }
}
