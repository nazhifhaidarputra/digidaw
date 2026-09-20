use flutter_rust_bridge::frb;
use karbeat_core::{
    api::{
        external_plugin_api,
        plugin_discovery_api::{self, PluginScanEvent},
    },
};
use karbeat_host::{PluginDescriptor, PluginFormat, PluginKind, scanner::ScanSettings};

use crate::{api::{context::DawContext, plugin::UiPluginTarget}, frb_generated::StreamSink};

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
    crate::api::context::read_ctx!(ctx);
    external_plugin_api::descriptor(ctx, target.into()).map(Into::into)
}

pub fn refresh_external_plugin_catalog(
    ctx: &DawContext,
) -> anyhow::Result<Vec<UiExternalPluginEntry>> {
    crate::api::context::project_ctx!(ctx);
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

fn resolve_hosted_target(
    ctx: &DawContext,
    target: UiPluginTarget,
) -> anyhow::Result<karbeat_host::HostInstanceId> {
    let lookup = {
        let ctx = ctx.read();
        external_plugin_api::prepare_hosted_target(&ctx, target.into())?
    };
    external_plugin_api::resolve_hosted_target(lookup)
}

pub fn external_plugin_capabilities(
    ctx: &DawContext,
    target: UiPluginTarget,
) -> anyhow::Result<UiExternalPluginCapabilities> {
    let _operation = ctx
        .try_runtime_operation()
        .ok_or_else(|| anyhow::anyhow!("project operation is in progress"))?;
    let capabilities = external_plugin_api::capabilities_for(resolve_hosted_target(ctx, target)?)?;
    Ok(UiExternalPluginCapabilities {
        controller: capabilities.controller,
        editor: capabilities.editor,
        sidechain: capabilities.sidechain,
    })
}

/// Reopening an existing editor brings its native window to the foreground.
pub fn open_external_plugin_editor(
    ctx: &DawContext,
    target: UiPluginTarget,
) -> anyhow::Result<()> {
    let _operation = ctx
        .try_runtime_operation()
        .ok_or_else(|| anyhow::anyhow!("project operation is in progress"))?;
    let core_target = target.into();
    let (lookup, context) = {
        let ctx = ctx.read();
        (
            external_plugin_api::prepare_hosted_target(&ctx, core_target)?,
            external_plugin_api::editor_context(&ctx, core_target),
        )
    };
    let instance = external_plugin_api::resolve_hosted_target(lookup)?;
    external_plugin_api::open_editor_for(instance, context)
}

pub fn close_external_plugin_editor(
    ctx: &DawContext,
    target: UiPluginTarget,
) -> anyhow::Result<()> {
    let _operation = ctx
        .try_runtime_operation()
        .ok_or_else(|| anyhow::anyhow!("project operation is in progress"))?;
    external_plugin_api::close_editor_for(resolve_hosted_target(ctx, target)?)
}

pub fn set_external_plugin_parameter(
    ctx: &DawContext,
    target: UiPluginTarget,
    parameter: u32,
    value: f64,
) -> anyhow::Result<()> {
    let _operation = ctx
        .try_runtime_operation()
        .ok_or_else(|| anyhow::anyhow!("project operation is in progress"))?;
    external_plugin_api::set_parameter_for(resolve_hosted_target(ctx, target)?, parameter, value)
}

pub fn external_plugin_parameter_text(
    ctx: &DawContext,
    target: UiPluginTarget,
    parameter: u32,
    value: f64,
) -> anyhow::Result<String> {
    let _operation = ctx
        .try_runtime_operation()
        .ok_or_else(|| anyhow::anyhow!("project operation is in progress"))?;
    external_plugin_api::parameter_text_for(resolve_hosted_target(ctx, target)?, parameter, value)
}

pub fn parse_external_plugin_parameter(
    ctx: &DawContext,
    target: UiPluginTarget,
    parameter: u32,
    text: String,
) -> anyhow::Result<f64> {
    let _operation = ctx
        .try_runtime_operation()
        .ok_or_else(|| anyhow::anyhow!("project operation is in progress"))?;
    external_plugin_api::parse_parameter_for(
        resolve_hosted_target(ctx, target)?,
        parameter,
        text,
    )
}

pub fn convert_external_plugin_parameter(
    ctx: &DawContext,
    target: UiPluginTarget,
    parameter: u32,
    value: f64,
    to_normalized: bool,
) -> anyhow::Result<f64> {
    let _operation = ctx
        .try_runtime_operation()
        .ok_or_else(|| anyhow::anyhow!("project operation is in progress"))?;
    external_plugin_api::convert_parameter_for(
        resolve_hosted_target(ctx, target)?,
        parameter,
        value,
        to_normalized,
    )
}

pub fn external_plugin_failure(ctx: &DawContext, target: UiPluginTarget) -> Option<String> {
    crate::api::context::read_ctx!(ctx);
    external_plugin_api::failure(ctx, target.into())
}

pub fn retry_external_plugin(ctx: &DawContext, target: UiPluginTarget) -> anyhow::Result<()> {
    let operation = ctx.begin_project_operation();
    let pending = {
        let core = operation.read_core();
        external_plugin_api::begin_retry(&core, target.into())?
    };
    let completed = external_plugin_api::execute_retry(pending)?;
    external_plugin_api::commit_retry(&mut operation.write_core(), completed);
    Ok(())
}
