use flutter_rust_bridge::frb;
use karbeat_core::{
    api::{
        external_plugin_api,
        plugin_discovery_api::{self, PluginScanEvent},
    },
    context::DawContext,
};
use karbeat_host::{PluginDescriptor, PluginFormat, PluginKind, scanner::ScanSettings};

use crate::{api::plugin::UiPluginTarget, frb_generated::StreamSink};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UiExternalPluginFormat {
    Vst3,
    Lv2,
    Clap,
    Au,
}

impl From<PluginFormat> for UiExternalPluginFormat {
    fn from(value: PluginFormat) -> Self {
        match value {
            PluginFormat::Vst3 => Self::Vst3,
            PluginFormat::Lv2 => Self::Lv2,
            PluginFormat::Clap => Self::Clap,
            PluginFormat::Au => Self::Au,
        }
    }
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiExternalPluginDescriptor {
    pub format: UiExternalPluginFormat,
    pub native_id: String,
    pub path: String,
    pub name: String,
    pub vendor: String,
    pub version: String,
    pub instrument: bool,
}

impl From<PluginDescriptor> for UiExternalPluginDescriptor {
    fn from(value: PluginDescriptor) -> Self {
        Self {
            format: value.identity.format.into(),
            native_id: value.identity.native_id,
            path: value.path.to_string_lossy().into_owned(),
            name: value.name,
            vendor: value.vendor,
            version: value.version,
            instrument: value.kind == PluginKind::Instrument,
        }
    }
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiExternalPluginEntry {
    pub id: u32,
    pub available: bool,
    pub descriptor: UiExternalPluginDescriptor,
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiPluginScanFailure {
    pub path: String,
    pub reason: String,
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub enum UiPluginScanEvent {
    Started {
        id: u64,
    },
    Progress {
        completed: u32,
        total: u32,
        discovered: u32,
        path: String,
        error: Option<String>,
    },
    Finished {
        plugins: Vec<UiExternalPluginDescriptor>,
        failures: Vec<UiPluginScanFailure>,
        cancelled: bool,
    },
    Failed {
        message: String,
    },
}

impl From<PluginScanEvent> for UiPluginScanEvent {
    fn from(value: PluginScanEvent) -> Self {
        match value {
            PluginScanEvent::Started { id } => Self::Started { id },
            PluginScanEvent::Progress(progress) => Self::Progress {
                completed: u32::try_from(progress.completed).unwrap_or(u32::MAX),
                total: u32::try_from(progress.total).unwrap_or(u32::MAX),
                discovered: u32::try_from(progress.discovered).unwrap_or(u32::MAX),
                path: progress.path.to_string_lossy().into_owned(),
                error: progress.error,
            },
            PluginScanEvent::Finished(result) => Self::Finished {
                plugins: result.plugins.into_iter().map(Into::into).collect(),
                failures: result
                    .failures
                    .into_iter()
                    .map(|(path, reason)| UiPluginScanFailure {
                        path: path.to_string_lossy().into_owned(),
                        reason,
                    })
                    .collect(),
                cancelled: result.cancelled,
            },
            PluginScanEvent::Failed(message) => Self::Failed { message },
        }
    }
}

pub fn default_plugin_scan_paths() -> Vec<String> {
    plugin_discovery_api::default_scan_paths()
        .into_iter()
        .map(|path| path.to_string_lossy().into_owned())
        .collect()
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiPluginScanSettings {
    pub directories: Vec<String>,
    pub timeout_seconds: u32,
}

pub fn plugin_scan_settings() -> anyhow::Result<UiPluginScanSettings> {
    let settings = plugin_discovery_api::scan_settings()?;
    Ok(UiPluginScanSettings {
        directories: settings
            .directories
            .into_iter()
            .map(|path| path.to_string_lossy().into_owned())
            .collect(),
        timeout_seconds: u32::try_from(settings.timeout_seconds)?.clamp(1, 300),
    })
}

pub fn save_plugin_scan_settings(
    directories: Vec<String>,
    timeout_seconds: u32,
) -> anyhow::Result<UiPluginScanSettings> {
    let settings = plugin_discovery_api::update_scan_settings(ScanSettings {
        directories: directories.into_iter().map(Into::into).collect(),
        timeout_seconds: u64::from(timeout_seconds),
    })?;
    Ok(UiPluginScanSettings {
        directories: settings
            .directories
            .into_iter()
            .map(|path| path.to_string_lossy().into_owned())
            .collect(),
        timeout_seconds: u32::try_from(settings.timeout_seconds)?.clamp(1, 300),
    })
}

/// Starts a worker and publishes progress events; never retains the project context.
#[frb(sync)]
pub fn scan_external_plugins(
    directories: Vec<String>,
    timeout_seconds: u32,
    retry_quarantined: bool,
    sink: StreamSink<UiPluginScanEvent>,
) -> Result<(), String> {
    plugin_discovery_api::start_scan(
        ScanSettings {
            directories: directories.into_iter().map(Into::into).collect(),
            timeout_seconds: u64::from(timeout_seconds),
        },
        retry_quarantined,
        move |event| sink.add(event.into()).is_ok(),
    )
    .map(|_| ())
    .map_err(|error| error.to_string())
}

pub fn cancel_external_plugin_scan(id: u64) -> bool {
    plugin_discovery_api::cancel_scan(id)
}

pub fn external_plugin_descriptor(
    ctx: &DawContext,
    target: UiPluginTarget,
) -> Option<UiExternalPluginDescriptor> {
    external_plugin_api::descriptor(ctx, target.into()).map(Into::into)
}

pub fn refresh_external_plugin_catalog(
    ctx: &mut DawContext,
) -> anyhow::Result<Vec<UiExternalPluginEntry>> {
    Ok(plugin_discovery_api::refresh_catalog(ctx)?
        .into_iter()
        .map(|entry| UiExternalPluginEntry {
            id: entry.id,
            available: entry.available,
            descriptor: entry.descriptor.into(),
        })
        .collect())
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiExternalPluginCapabilities {
    pub controller: bool,
    pub editor: bool,
    pub sidechain: bool,
}

pub fn external_plugin_capabilities(
    ctx: &mut DawContext,
    target: UiPluginTarget,
) -> anyhow::Result<UiExternalPluginCapabilities> {
    let capabilities = external_plugin_api::capabilities(ctx, target.into())?;
    Ok(UiExternalPluginCapabilities {
        controller: capabilities.controller,
        editor: capabilities.editor,
        sidechain: capabilities.sidechain,
    })
}

/// Reopening an existing editor brings its native window to the foreground.
pub fn open_external_plugin_editor(
    ctx: &mut DawContext,
    target: UiPluginTarget,
) -> anyhow::Result<()> {
    external_plugin_api::open_editor(ctx, target.into())
}

pub fn close_external_plugin_editor(
    ctx: &mut DawContext,
    target: UiPluginTarget,
) -> anyhow::Result<()> {
    external_plugin_api::close_editor(ctx, target.into())
}

pub fn set_external_plugin_parameter(
    ctx: &mut DawContext,
    target: UiPluginTarget,
    parameter: u32,
    value: f64,
) -> anyhow::Result<()> {
    external_plugin_api::set_parameter(ctx, target.into(), parameter, value)
}

pub fn external_plugin_parameter_text(
    ctx: &mut DawContext,
    target: UiPluginTarget,
    parameter: u32,
    value: f64,
) -> anyhow::Result<String> {
    external_plugin_api::parameter_text(ctx, target.into(), parameter, value)
}

pub fn parse_external_plugin_parameter(
    ctx: &mut DawContext,
    target: UiPluginTarget,
    parameter: u32,
    text: String,
) -> anyhow::Result<f64> {
    external_plugin_api::parse_parameter(ctx, target.into(), parameter, text)
}

pub fn convert_external_plugin_parameter(
    ctx: &mut DawContext,
    target: UiPluginTarget,
    parameter: u32,
    value: f64,
    to_normalized: bool,
) -> anyhow::Result<f64> {
    external_plugin_api::convert_parameter(ctx, target.into(), parameter, value, to_normalized)
}

pub fn external_plugin_failure(ctx: &DawContext, target: UiPluginTarget) -> Option<String> {
    external_plugin_api::failure(ctx, target.into())
}

pub fn retry_external_plugin(ctx: &mut DawContext, target: UiPluginTarget) -> anyhow::Result<()> {
    external_plugin_api::retry(ctx, target.into())
}
