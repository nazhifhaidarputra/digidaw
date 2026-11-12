//! App-wide settings and user libraries, kept in TOML files by `karbeat-settings`.
//!
//! The process holds one [`SettingsStore`], opened by [`open_settings`] at startup. Engine-backed
//! values are checked against the same limits the engine enforces, so a saved value can always
//! be applied.

#[cfg(not(windows))]
use std::env::var_os;
use std::{
    collections::{BTreeSet, HashMap},
    fs::canonicalize,
    path::{Path, PathBuf},
    time::Duration,
};

use anyhow::{Context, anyhow};
use flutter_rust_bridge::frb;
use karbeat_core::core::{history::MAX_HISTORY_LIMIT, mitigation::AutoSaveSettings};
use karbeat_core_api::audio_settings_api::validate_dsp_config;
use karbeat_settings::{
    AppearanceSettings, AudioPreferences, AutomationTemplate, AutomationTemplates, BackgroundFit,
    ColorPalette, ColorThemeChoice, CurveType, GeneralSettings, LogLevel, LogSettings,
    PluginFavorites, PluginScanSettings, RecentProjects, Recovered, SampleFolders, SettingsError,
    SettingsStore, ShortcutChord, TemplatePoint, ThemeMode,
};
use parking_lot::RwLock;

use crate::api::{
    automation::{AutomationCurveTypeDto, AutomationPointDto, BezierHandlesDto},
    mitigation::UiAutoSaveSettings,
};

/// The process's settings, once [`open_settings`] has run.
///
/// A plain OS lock: settings are never touched inside a Shuttle schedule.
static SETTINGS: RwLock<Option<SettingsStore>> = RwLock::new(None);

/// Name of the folder holding the settings files inside the app support directory.
const SETTINGS_FOLDER: &str = "settings";

fn read<R>(read: impl FnOnce(&SettingsStore) -> R) -> anyhow::Result<R> {
    let store = SETTINGS.read();
    let store = store.as_ref().ok_or_else(not_open)?;
    Ok(read(store))
}

fn write<R>(
    write: impl FnOnce(&mut SettingsStore) -> Result<R, SettingsError>,
) -> anyhow::Result<R> {
    let mut store = SETTINGS.write();
    let store = store.as_mut().ok_or_else(not_open)?;
    Ok(write(store)?)
}

fn not_open() -> anyhow::Error {
    anyhow!("Settings are not open yet")
}

fn path_string(path: &Path) -> String {
    path.to_string_lossy().into_owned()
}

fn optional_path_string(path: Option<&PathBuf>) -> Option<String> {
    path.map(|path| path_string(path))
}

// =======================================
// Opening
// =======================================

/// A settings file that could not be read and was replaced by defaults.
#[derive(Clone, Debug)]
pub struct UiRecoveredSettingsFile {
    pub file: String,
    /// Where the unreadable file was moved.
    pub backup: String,
    pub reason: String,
}

impl From<Recovered> for UiRecoveredSettingsFile {
    fn from(recovered: Recovered) -> Self {
        Self {
            file: path_string(&recovered.file),
            backup: path_string(&recovered.backup),
            reason: recovered.reason,
        }
    }
}

/// Loads the settings from `<support_dir>/settings`. Call once at startup, before any other
/// settings function; later calls change nothing and report no recovered files.
pub fn open_settings(support_dir: String) -> anyhow::Result<Vec<UiRecoveredSettingsFile>> {
    let mut slot = SETTINGS.write();
    if slot.is_some() {
        return Ok(Vec::new());
    }
    let dir = Path::new(&support_dir).join(SETTINGS_FOLDER);
    let (store, recovered) = SettingsStore::open(&dir)
        .with_context(|| format!("Could not open the settings in {}", dir.display()))?;
    *slot = Some(store);
    Ok(recovered.into_iter().map(Into::into).collect())
}

// =======================================
// General
// =======================================

/// Undo history, auto save and default folders.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiGeneralSettings {
    /// Undo entries kept, from 0 (undo disabled) to the engine's maximum.
    pub history_limit: u32,
    pub auto_save: UiAutoSaveSettings,
    /// Folder the project save and open dialogs start in.
    pub default_project_folder: Option<String>,
    /// Folder exports go to unless another one is chosen.
    pub default_export_folder: Option<String>,
    /// Whether the project menu lists recently opened projects.
    pub show_recent_projects: bool,
}

fn history_limit_is_valid(limit: u32) -> bool {
    usize::try_from(limit).is_ok_and(|limit| limit <= MAX_HISTORY_LIMIT)
}

fn auto_save_settings(enabled: bool, interval_seconds: u32) -> AutoSaveSettings {
    AutoSaveSettings {
        every_seconds: Duration::from_secs(u64::from(interval_seconds)),
        is_enabled: enabled,
    }
}

impl From<&GeneralSettings> for UiGeneralSettings {
    /// Values the engine would reject read as their defaults.
    fn from(settings: &GeneralSettings) -> Self {
        let defaults = GeneralSettings::default();
        let history_limit = if history_limit_is_valid(settings.history_limit) {
            settings.history_limit
        } else {
            defaults.history_limit
        };
        let interval_seconds = if auto_save_settings(true, settings.auto_save_interval_seconds)
            .validated()
            .is_ok()
        {
            settings.auto_save_interval_seconds
        } else {
            defaults.auto_save_interval_seconds
        };
        Self {
            history_limit,
            auto_save: UiAutoSaveSettings {
                is_enabled: settings.auto_save_enabled,
                interval_seconds,
            },
            default_project_folder: optional_path_string(settings.default_project_folder.as_ref()),
            default_export_folder: optional_path_string(settings.default_export_folder.as_ref()),
            show_recent_projects: settings.show_recent_projects,
        }
    }
}

fn general_settings(store: &SettingsStore) -> UiGeneralSettings {
    (&store.preferences().general).into()
}

pub fn load_general_settings() -> anyhow::Result<UiGeneralSettings> {
    read(general_settings)
}

pub fn save_history_limit(limit: u32) -> anyhow::Result<UiGeneralSettings> {
    anyhow::ensure!(
        history_limit_is_valid(limit),
        "History limit must be between 0 and {MAX_HISTORY_LIMIT}"
    );
    write(|store| {
        store.update_preferences(|preferences| preferences.general.history_limit = limit)?;
        Ok(general_settings(store))
    })
}

pub fn save_auto_save_preferences(
    settings: UiAutoSaveSettings,
) -> anyhow::Result<UiGeneralSettings> {
    auto_save_settings(settings.is_enabled, settings.interval_seconds).validated()?;
    write(|store| {
        store.update_preferences(|preferences| {
            preferences.general.auto_save_enabled = settings.is_enabled;
            preferences.general.auto_save_interval_seconds = settings.interval_seconds;
        })?;
        Ok(general_settings(store))
    })
}

/// Sets the folder project dialogs start in; `None` clears it. The folder must exist.
pub fn save_default_project_folder(folder: Option<String>) -> anyhow::Result<UiGeneralSettings> {
    write(|store| {
        store.update_preferences(|preferences| {
            preferences.general.default_project_folder = folder.map(PathBuf::from);
        })?;
        Ok(general_settings(store))
    })
}

/// Sets the folder exports go to; `None` clears it. The folder must exist.
pub fn save_default_export_folder(folder: Option<String>) -> anyhow::Result<UiGeneralSettings> {
    write(|store| {
        store.update_preferences(|preferences| {
            preferences.general.default_export_folder = folder.map(PathBuf::from);
        })?;
        Ok(general_settings(store))
    })
}

/// Shows or hides the recent projects in the project menu. Hiding keeps the list.
pub fn save_show_recent_projects(visible: bool) -> anyhow::Result<UiGeneralSettings> {
    write(|store| {
        store
            .update_preferences(|preferences| preferences.general.show_recent_projects = visible)?;
        Ok(general_settings(store))
    })
}

// =======================================
// Audio
// =======================================

/// Audio devices, engine timing and the metronome sound.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiAudioPreferences {
    /// `None` uses the system default host.
    pub output_host: Option<String>,
    /// `None` uses the host's default device.
    pub output_device: Option<String>,
    pub input_enabled: bool,
    /// `None` uses the system default input.
    pub input_device: Option<String>,
    pub sample_rate: u32,
    pub block_size: u32,
    /// `None` uses the built-in click.
    pub metronome_sound: Option<String>,
}

impl From<&AudioPreferences> for UiAudioPreferences {
    /// Engine timing the engine would reject reads as the defaults.
    fn from(audio: &AudioPreferences) -> Self {
        let defaults = AudioPreferences::default();
        let (sample_rate, block_size) =
            if validate_dsp_config(audio.sample_rate, audio.block_size).is_ok() {
                (audio.sample_rate, audio.block_size)
            } else {
                (defaults.sample_rate, defaults.block_size)
            };
        Self {
            output_host: audio.output_host.clone(),
            output_device: audio.output_device.clone(),
            input_enabled: audio.input_enabled,
            input_device: audio.input_device.clone(),
            sample_rate,
            block_size,
            metronome_sound: optional_path_string(audio.metronome_sound.as_ref()),
        }
    }
}

fn audio_preferences(store: &SettingsStore) -> UiAudioPreferences {
    (&store.preferences().audio).into()
}

pub fn load_audio_preferences() -> anyhow::Result<UiAudioPreferences> {
    read(audio_preferences)
}

fn update_audio(change: impl FnOnce(&mut AudioPreferences)) -> anyhow::Result<UiAudioPreferences> {
    write(|store| {
        store.update_preferences(|preferences| change(&mut preferences.audio))?;
        Ok(audio_preferences(store))
    })
}

pub fn save_audio_output(
    host_name: Option<String>,
    device_id: Option<String>,
) -> anyhow::Result<UiAudioPreferences> {
    update_audio(|audio| {
        audio.output_host = host_name;
        audio.output_device = device_id;
    })
}

pub fn save_audio_input(
    enabled: bool,
    device_id: Option<String>,
) -> anyhow::Result<UiAudioPreferences> {
    update_audio(|audio| {
        audio.input_enabled = enabled;
        audio.input_device = device_id;
    })
}

pub fn save_audio_dsp(sample_rate: u32, block_size: u32) -> anyhow::Result<UiAudioPreferences> {
    validate_dsp_config(sample_rate, block_size)?;
    update_audio(|audio| {
        audio.sample_rate = sample_rate;
        audio.block_size = block_size;
    })
}

/// Sets the metronome sound file; `None` uses the built-in click.
pub fn save_metronome_sound(path: Option<String>) -> anyhow::Result<UiAudioPreferences> {
    update_audio(|audio| audio.metronome_sound = path.map(PathBuf::from))
}

// =======================================
// Appearance
// =======================================

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UiThemeMode {
    System,
    Light,
    Dark,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UiColorPalette {
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

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UiBackgroundFit {
    Cover,
    Contain,
    Fill,
}

/// Where the app's colors come from.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum UiColorThemeChoice {
    /// The color theme bundled with the app.
    Bundled,
    /// Colors derived from the accent palette.
    AccentPalette,
    /// A color theme, named by an asset or a file path.
    Source(String),
}

/// Theme, colors, background and font.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiAppearanceSettings {
    pub theme_mode: UiThemeMode,
    pub color_palette: UiColorPalette,
    pub background_image: Option<String>,
    pub background_fit: UiBackgroundFit,
    /// Opacity of the layer over the background image, from 0.0 to 0.9.
    pub background_overlay: f64,
    pub font_path: Option<String>,
    pub font_family: Option<String>,
    pub color_theme: UiColorThemeChoice,
    pub custom_color_theme_paths: Vec<String>,
}

impl From<ThemeMode> for UiThemeMode {
    fn from(mode: ThemeMode) -> Self {
        match mode {
            ThemeMode::System => Self::System,
            ThemeMode::Light => Self::Light,
            ThemeMode::Dark => Self::Dark,
        }
    }
}

impl From<UiThemeMode> for ThemeMode {
    fn from(mode: UiThemeMode) -> Self {
        match mode {
            UiThemeMode::System => Self::System,
            UiThemeMode::Light => Self::Light,
            UiThemeMode::Dark => Self::Dark,
        }
    }
}

impl From<ColorPalette> for UiColorPalette {
    fn from(palette: ColorPalette) -> Self {
        match palette {
            ColorPalette::Purple => Self::Purple,
            ColorPalette::Blue => Self::Blue,
            ColorPalette::Teal => Self::Teal,
            ColorPalette::Orange => Self::Orange,
            ColorPalette::Red => Self::Red,
            ColorPalette::Green => Self::Green,
            ColorPalette::Pink => Self::Pink,
            ColorPalette::Cyan => Self::Cyan,
            ColorPalette::Indigo => Self::Indigo,
            ColorPalette::Amber => Self::Amber,
            ColorPalette::Lime => Self::Lime,
            ColorPalette::Magenta => Self::Magenta,
            ColorPalette::Graphite => Self::Graphite,
        }
    }
}

impl From<UiColorPalette> for ColorPalette {
    fn from(palette: UiColorPalette) -> Self {
        match palette {
            UiColorPalette::Purple => Self::Purple,
            UiColorPalette::Blue => Self::Blue,
            UiColorPalette::Teal => Self::Teal,
            UiColorPalette::Orange => Self::Orange,
            UiColorPalette::Red => Self::Red,
            UiColorPalette::Green => Self::Green,
            UiColorPalette::Pink => Self::Pink,
            UiColorPalette::Cyan => Self::Cyan,
            UiColorPalette::Indigo => Self::Indigo,
            UiColorPalette::Amber => Self::Amber,
            UiColorPalette::Lime => Self::Lime,
            UiColorPalette::Magenta => Self::Magenta,
            UiColorPalette::Graphite => Self::Graphite,
        }
    }
}

impl From<BackgroundFit> for UiBackgroundFit {
    fn from(fit: BackgroundFit) -> Self {
        match fit {
            BackgroundFit::Cover => Self::Cover,
            BackgroundFit::Contain => Self::Contain,
            BackgroundFit::Fill => Self::Fill,
        }
    }
}

impl From<UiBackgroundFit> for BackgroundFit {
    fn from(fit: UiBackgroundFit) -> Self {
        match fit {
            UiBackgroundFit::Cover => Self::Cover,
            UiBackgroundFit::Contain => Self::Contain,
            UiBackgroundFit::Fill => Self::Fill,
        }
    }
}

impl From<ColorThemeChoice> for UiColorThemeChoice {
    fn from(choice: ColorThemeChoice) -> Self {
        match choice {
            ColorThemeChoice::Default => Self::Bundled,
            ColorThemeChoice::AccentPalette => Self::AccentPalette,
            ColorThemeChoice::Source(source) => Self::Source(source),
        }
    }
}

impl From<UiColorThemeChoice> for ColorThemeChoice {
    fn from(choice: UiColorThemeChoice) -> Self {
        match choice {
            UiColorThemeChoice::Bundled => Self::Default,
            UiColorThemeChoice::AccentPalette => Self::AccentPalette,
            UiColorThemeChoice::Source(source) => Self::Source(source),
        }
    }
}

/// Empty strings mean "not set", as they did when the UI stored these values itself.
fn non_empty_path(path: Option<String>) -> Option<PathBuf> {
    path.filter(|path| !path.is_empty()).map(PathBuf::from)
}

impl From<AppearanceSettings> for UiAppearanceSettings {
    fn from(settings: AppearanceSettings) -> Self {
        Self {
            theme_mode: settings.theme_mode.into(),
            color_palette: settings.color_palette.into(),
            background_image: optional_path_string(settings.background_image.as_ref()),
            background_fit: settings.background_fit.into(),
            background_overlay: settings.background_overlay,
            font_path: optional_path_string(settings.font_path.as_ref()),
            font_family: settings.font_family,
            color_theme: settings.color_theme.into(),
            custom_color_theme_paths: settings
                .custom_color_theme_paths
                .iter()
                .map(|path| path_string(path))
                .collect(),
        }
    }
}

impl From<UiAppearanceSettings> for AppearanceSettings {
    fn from(settings: UiAppearanceSettings) -> Self {
        Self {
            theme_mode: settings.theme_mode.into(),
            color_palette: settings.color_palette.into(),
            background_image: non_empty_path(settings.background_image),
            background_fit: settings.background_fit.into(),
            background_overlay: settings.background_overlay,
            font_path: non_empty_path(settings.font_path),
            font_family: settings.font_family.filter(|family| !family.is_empty()),
            color_theme: settings.color_theme.into(),
            custom_color_theme_paths: settings
                .custom_color_theme_paths
                .into_iter()
                .map(PathBuf::from)
                .collect(),
        }
    }
}

pub fn load_appearance_settings() -> anyhow::Result<UiAppearanceSettings> {
    read(|store| store.preferences().appearance.clone().into())
}

/// Saves the appearance settings and returns them as stored, with the overlay brought into range.
pub fn save_appearance_settings(
    settings: UiAppearanceSettings,
) -> anyhow::Result<UiAppearanceSettings> {
    write(|store| {
        let saved = store.update_preferences(|preferences| {
            preferences.appearance = settings.into();
        })?;
        Ok(saved.appearance.clone().into())
    })
}

// =======================================
// Logs
// =======================================

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UiLogLevel {
    Trace,
    Debug,
    Info,
    Warning,
    Error,
    Fatal,
}

/// What the log viewer keeps.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiLogSettings {
    pub minimum_level: UiLogLevel,
    /// Entries kept, from 50 to 2000.
    pub maximum_entries: u32,
}

impl From<&LogSettings> for UiLogSettings {
    fn from(settings: &LogSettings) -> Self {
        Self {
            minimum_level: match settings.minimum_level {
                LogLevel::Trace => UiLogLevel::Trace,
                LogLevel::Debug => UiLogLevel::Debug,
                LogLevel::Info => UiLogLevel::Info,
                LogLevel::Warning => UiLogLevel::Warning,
                LogLevel::Error => UiLogLevel::Error,
                LogLevel::Fatal => UiLogLevel::Fatal,
            },
            maximum_entries: settings.maximum_entries,
        }
    }
}

impl From<UiLogSettings> for LogSettings {
    fn from(settings: UiLogSettings) -> Self {
        Self {
            minimum_level: match settings.minimum_level {
                UiLogLevel::Trace => LogLevel::Trace,
                UiLogLevel::Debug => LogLevel::Debug,
                UiLogLevel::Info => LogLevel::Info,
                UiLogLevel::Warning => LogLevel::Warning,
                UiLogLevel::Error => LogLevel::Error,
                UiLogLevel::Fatal => LogLevel::Fatal,
            },
            maximum_entries: settings.maximum_entries,
        }
    }
}

pub fn load_log_settings() -> anyhow::Result<UiLogSettings> {
    read(|store| (&store.preferences().logs).into())
}

/// Saves the log settings and returns them as stored, with the entry count brought into range.
pub fn save_log_settings(settings: UiLogSettings) -> anyhow::Result<UiLogSettings> {
    write(|store| {
        let saved = store.update_preferences(|preferences| preferences.logs = settings.into())?;
        Ok((&saved.logs).into())
    })
}

// =======================================
// Shortcuts
// =======================================

/// A key with its modifiers.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct UiShortcutChord {
    /// Flutter logical key id.
    pub key: i64,
    pub control: bool,
    pub shift: bool,
    pub alt: bool,
    pub meta: bool,
}

impl From<ShortcutChord> for UiShortcutChord {
    fn from(chord: ShortcutChord) -> Self {
        Self {
            key: chord.key,
            control: chord.control,
            shift: chord.shift,
            alt: chord.alt,
            meta: chord.meta,
        }
    }
}

impl From<UiShortcutChord> for ShortcutChord {
    fn from(chord: UiShortcutChord) -> Self {
        Self {
            key: chord.key,
            control: chord.control,
            shift: chord.shift,
            alt: chord.alt,
            meta: chord.meta,
        }
    }
}

/// Shortcuts changed from their defaults, by action id.
pub fn load_shortcut_overrides() -> anyhow::Result<HashMap<String, UiShortcutChord>> {
    read(|store| {
        store
            .preferences()
            .shortcuts
            .overrides
            .iter()
            .map(|(action, chord)| (action.clone(), (*chord).into()))
            .collect()
    })
}

/// Replaces every changed shortcut.
pub fn save_shortcut_overrides(overrides: HashMap<String, UiShortcutChord>) -> anyhow::Result<()> {
    write(|store| {
        store.update_preferences(|preferences| {
            preferences.shortcuts.overrides = overrides
                .into_iter()
                .map(|(action, chord)| (action, chord.into()))
                .collect();
        })?;
        Ok(())
    })
}

// =======================================
// Automation templates
// =======================================

/// A saved automation curve.
#[derive(Clone, Debug)]
pub struct UiAutomationTemplate {
    pub id: String,
    pub name: String,
    /// Length of the saved range in ticks.
    pub length_ticks: u32,
    /// Points timed from the start of the template. Their ids are 0; pasting assigns real ones.
    pub points: Vec<AutomationPointDto>,
}

fn curve_type_dto(curve: CurveType) -> AutomationCurveTypeDto {
    match curve {
        CurveType::Linear => AutomationCurveTypeDto::Linear,
        CurveType::Exponential => AutomationCurveTypeDto::Exponential,
        CurveType::Step => AutomationCurveTypeDto::Step,
        CurveType::Logarithmic => AutomationCurveTypeDto::Logarithmic,
        CurveType::SCurve => AutomationCurveTypeDto::SCurve,
        CurveType::Bezier => AutomationCurveTypeDto::Bezier,
        CurveType::Stairs => AutomationCurveTypeDto::Stairs,
        CurveType::SmoothStairs => AutomationCurveTypeDto::SmoothStairs,
        CurveType::Pulse => AutomationCurveTypeDto::Pulse,
        CurveType::Wave => AutomationCurveTypeDto::Wave,
        CurveType::Triangle => AutomationCurveTypeDto::Triangle,
        CurveType::HalfSine => AutomationCurveTypeDto::HalfSine,
    }
}

fn curve_type(curve: AutomationCurveTypeDto) -> CurveType {
    match curve {
        AutomationCurveTypeDto::Linear => CurveType::Linear,
        AutomationCurveTypeDto::Exponential => CurveType::Exponential,
        AutomationCurveTypeDto::Step => CurveType::Step,
        AutomationCurveTypeDto::Logarithmic => CurveType::Logarithmic,
        AutomationCurveTypeDto::SCurve => CurveType::SCurve,
        AutomationCurveTypeDto::Bezier => CurveType::Bezier,
        AutomationCurveTypeDto::Stairs => CurveType::Stairs,
        AutomationCurveTypeDto::SmoothStairs => CurveType::SmoothStairs,
        AutomationCurveTypeDto::Pulse => CurveType::Pulse,
        AutomationCurveTypeDto::Wave => CurveType::Wave,
        AutomationCurveTypeDto::Triangle => CurveType::Triangle,
        AutomationCurveTypeDto::HalfSine => CurveType::HalfSine,
    }
}

impl From<&AutomationTemplate> for UiAutomationTemplate {
    fn from(template: &AutomationTemplate) -> Self {
        Self {
            id: template.id.clone(),
            name: template.name.clone(),
            length_ticks: template.length_ticks,
            points: template
                .points
                .iter()
                .map(|point| AutomationPointDto {
                    id: 0,
                    time_ticks: point.time_ticks,
                    value: point.value,
                    curve_type: curve_type_dto(point.curve_type),
                    tension: point.tension,
                    handles: point.handles.map(|[x1, y1, x2, y2]| BezierHandlesDto {
                        x1,
                        y1,
                        x2,
                        y2,
                    }),
                })
                .collect(),
        }
    }
}

impl From<UiAutomationTemplate> for AutomationTemplate {
    fn from(template: UiAutomationTemplate) -> Self {
        Self {
            id: template.id,
            name: template.name,
            length_ticks: template.length_ticks,
            points: template
                .points
                .into_iter()
                .map(|point| TemplatePoint {
                    time_ticks: point.time_ticks,
                    value: point.value,
                    curve_type: curve_type(point.curve_type),
                    tension: point.tension,
                    handles: point
                        .handles
                        .map(|handles| [handles.x1, handles.y1, handles.x2, handles.y2]),
                })
                .collect(),
        }
    }
}

fn automation_templates(templates: &AutomationTemplates) -> Vec<UiAutomationTemplate> {
    templates.templates.iter().map(Into::into).collect()
}

pub fn load_automation_templates() -> anyhow::Result<Vec<UiAutomationTemplate>> {
    read(|store| automation_templates(store.automation_templates()))
}

/// Replaces the template library and returns it as stored; templates without points are dropped.
pub fn save_automation_templates(
    templates: Vec<UiAutomationTemplate>,
) -> anyhow::Result<Vec<UiAutomationTemplate>> {
    write(|store| {
        let saved = store.set_automation_templates(AutomationTemplates {
            templates: templates.into_iter().map(Into::into).collect(),
        })?;
        Ok(automation_templates(saved))
    })
}

// =======================================
// Plugin favorites and sample folders
// =======================================

/// Catalog ids of the favorite plugins, sorted.
pub fn load_plugin_favorites() -> anyhow::Result<Vec<String>> {
    read(|store| store.plugin_favorites().ids.iter().cloned().collect())
}

pub fn save_plugin_favorites(ids: Vec<String>) -> anyhow::Result<()> {
    write(|store| {
        store.set_plugin_favorites(PluginFavorites {
            ids: ids.into_iter().collect(),
        })?;
        Ok(())
    })
}

/// Sample browser folders, sorted and each listed once.
pub fn load_sample_folders() -> anyhow::Result<Vec<String>> {
    read(|store| {
        store
            .sample_folders()
            .folders
            .iter()
            .map(|folder| path_string(folder))
            .collect()
    })
}

pub fn save_sample_folders(folders: Vec<String>) -> anyhow::Result<()> {
    write(|store| {
        store.set_sample_folders(SampleFolders {
            folders: folders
                .into_iter()
                .map(PathBuf::from)
                .collect::<BTreeSet<_>>(),
        })?;
        Ok(())
    })
}

// =======================================
// Recent projects
// =======================================

/// A recently opened or saved project.
#[derive(Clone, Debug)]
pub struct UiRecentProject {
    /// The project file, as stored.
    pub path: String,
    /// The path as menus show it: under the home folder it starts with `~`, as in VS Code.
    pub label: String,
    /// Whether the file still exists.
    pub exists: bool,
}

/// `path` with the home folder written as `~`. Windows paths are shown in full, as VS Code does.
fn display_path(path: &Path) -> String {
    #[cfg(not(windows))]
    if let Some(home) = var_os("HOME").filter(|home| !home.is_empty())
        && let Ok(relative) = path.strip_prefix(home)
    {
        return Path::new("~").join(relative).to_string_lossy().into_owned();
    }
    path_string(path)
}

/// Recently opened or saved projects, most recent first.
pub fn load_recent_projects() -> anyhow::Result<Vec<UiRecentProject>> {
    let paths = read(|store| store.recent_projects().paths.clone())?;
    Ok(paths
        .iter()
        .map(|path| UiRecentProject {
            path: path_string(path),
            label: display_path(path),
            exists: path.is_file(),
        })
        .collect())
}

/// Forgets one recent project.
pub fn remove_recent_project(path: String) -> anyhow::Result<()> {
    write(|store| {
        let mut projects = store.recent_projects().clone();
        projects.paths.retain(|listed| *listed != Path::new(&path));
        store.set_recent_projects(projects)?;
        Ok(())
    })
}

/// Forgets every recent project.
pub fn clear_recent_projects() -> anyhow::Result<()> {
    write(|store| {
        store.set_recent_projects(RecentProjects::default())?;
        Ok(())
    })
}

/// Makes the project at `path` the most recent one. Called after a project is loaded or saved;
/// failures are logged, since they must not fail the load or save.
pub(crate) fn record_recent_project(path: &str) {
    // The same file reached through another path (relative, symlinked) is listed once.
    let path = canonicalize(path).unwrap_or_else(|_| PathBuf::from(path));
    if let Err(error) = write(|store| store.record_recent_project(path).map(|_| ())) {
        tracing::warn!("Could not remember the recent project: {error}");
    }
}

// =======================================
// Plugin scan
// =======================================

/// The saved plugin scan settings; `external_plugins` validates them against the host's rules.
pub(crate) fn stored_plugin_scan() -> anyhow::Result<PluginScanSettings> {
    read(|store| store.preferences().plugin_scan.clone())
}

/// Saves plugin scan settings already validated by `external_plugins`.
pub(crate) fn store_plugin_scan(
    directories: &[PathBuf],
    timeout_seconds: u64,
) -> anyhow::Result<()> {
    write(|store| {
        store.update_preferences(|preferences| {
            preferences.plugin_scan = PluginScanSettings {
                directories: directories.to_vec(),
                timeout_seconds,
            };
        })?;
        Ok(())
    })
}

// =======================================
// Language
// =======================================

/// The saved language code; `None` follows the system. `l10n` checks it is a known language.
pub(crate) fn stored_language() -> anyhow::Result<Option<String>> {
    read(|store| store.preferences().general.language.clone())
}

/// Saves a language code already checked by `l10n`; `None` follows the system.
pub(crate) fn store_language(code: Option<String>) -> anyhow::Result<()> {
    write(|store| {
        store.update_preferences(|preferences| preferences.general.language = code)?;
        Ok(())
    })
}
