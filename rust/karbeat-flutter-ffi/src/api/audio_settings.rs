use flutter_rust_bridge::frb;
use karbeat_core::{
    api::audio_settings_api,
    audio::backend::{
        ActualDeviceStreamConfig, AudioDeviceInfo, AudioRuntimeSettings, DeviceStreamStatus,
        OutputDeviceSelection, OutputHostSelection, RequestedDspConfig, RequestedOutputConfig,
    },
    context::DawContext,
};

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiAudioHostInfo {
    pub host_name: Option<String>,
    pub display_name: String,
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiOutputDeviceInfo {
    pub device_id: Option<String>,
    pub display_name: String,
    pub is_current_system_default: bool,
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub enum UiOutputHostSelection {
    SystemDefault,
    Named { name: String },
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub enum UiOutputDeviceSelection {
    SystemDefault,
    Specific { id: String, name: String },
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiRequestedOutputConfig {
    pub host: UiOutputHostSelection,
    pub device: UiOutputDeviceSelection,
}

#[derive(Clone, Copy, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiRequestedDspConfig {
    pub sample_rate: u32,
    pub block_size: u32,
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub enum UiDeviceStreamStatus {
    Starting,
    Running,
    Retrying { reason: String },
    Unavailable { reason: String },
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiActualDeviceStreamConfig {
    pub host_name: String,
    pub device_id: String,
    pub device_name: String,
    pub sample_rate: u32,
    pub callback_buffer_size: u32,
    pub channels: u16,
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiAudioRuntimeSettings {
    pub requested_output: UiRequestedOutputConfig,
    pub requested_dsp: UiRequestedDspConfig,
    pub actual_stream: Option<UiActualDeviceStreamConfig>,
    pub stream_status: UiDeviceStreamStatus,
}

pub fn list_output_hosts() -> Vec<UiAudioHostInfo> {
    let hosts = audio_settings_api::available_output_hosts();
    let default_name = cpal_default_host_name();
    let mut result = Vec::with_capacity(hosts.len() + 1);
    result.push(UiAudioHostInfo {
        host_name: None,
        display_name: format!("System default ({default_name})"),
    });
    result.extend(hosts.into_iter().map(|name| UiAudioHostInfo {
        display_name: name.clone(),
        host_name: Some(name),
    }));
    result
}

pub fn list_output_devices(host_name: Option<String>) -> Result<Vec<UiOutputDeviceInfo>, String> {
    let devices = audio_settings_api::available_output_devices(host_name.as_deref())
        .map_err(|error| error.to_string())?;
    let mut result = Vec::with_capacity(devices.len() + 1);
    result.push(UiOutputDeviceInfo {
        device_id: None,
        display_name: "System default output".to_string(),
        is_current_system_default: true,
    });
    result.extend(devices.into_iter().map(UiOutputDeviceInfo::from));
    Ok(result)
}

pub fn get_audio_runtime_settings(ctx: &DawContext) -> UiAudioRuntimeSettings {
    audio_settings_api::runtime_settings(ctx).into()
}

pub fn get_output_underrun_samples() -> u64 {
    audio_settings_api::output_underrun_samples()
}

pub fn set_output_selection(
    ctx: &DawContext,
    host_name: Option<String>,
    device_id: Option<String>,
) -> Result<UiAudioRuntimeSettings, String> {
    audio_settings_api::select_output(ctx, host_name, device_id)
        .map(Into::into)
        .map_err(|error| error.to_string())
}

pub fn set_dsp_config(
    ctx: &mut DawContext,
    sample_rate: u32,
    block_size: u32,
) -> Result<UiAudioRuntimeSettings, String> {
    audio_settings_api::set_dsp_config(ctx, sample_rate, block_size)
        .map(Into::into)
        .map_err(|error| error.to_string())
}

pub fn supported_dsp_sample_rates() -> Vec<u32> {
    audio_settings_api::SUPPORTED_DSP_SAMPLE_RATES.to_vec()
}

pub fn supported_dsp_block_sizes() -> Vec<u32> {
    audio_settings_api::SUPPORTED_DSP_BLOCK_SIZES.to_vec()
}

fn cpal_default_host_name() -> String {
    cpal::default_host().id().name().to_string()
}

impl From<AudioDeviceInfo> for UiOutputDeviceInfo {
    fn from(value: AudioDeviceInfo) -> Self {
        Self {
            device_id: Some(value.id),
            display_name: value.name,
            is_current_system_default: value.is_default,
        }
    }
}

impl From<OutputHostSelection> for UiOutputHostSelection {
    fn from(value: OutputHostSelection) -> Self {
        match value {
            OutputHostSelection::SystemDefault => Self::SystemDefault,
            OutputHostSelection::Named(name) => Self::Named { name },
        }
    }
}

impl From<OutputDeviceSelection> for UiOutputDeviceSelection {
    fn from(value: OutputDeviceSelection) -> Self {
        match value {
            OutputDeviceSelection::SystemDefault => Self::SystemDefault,
            OutputDeviceSelection::Specific { id, name } => Self::Specific { id, name },
        }
    }
}

impl From<RequestedOutputConfig> for UiRequestedOutputConfig {
    fn from(value: RequestedOutputConfig) -> Self {
        Self {
            host: value.host.into(),
            device: value.device.into(),
        }
    }
}

impl From<RequestedDspConfig> for UiRequestedDspConfig {
    fn from(value: RequestedDspConfig) -> Self {
        Self {
            sample_rate: value.sample_rate,
            block_size: value.block_size,
        }
    }
}

impl From<DeviceStreamStatus> for UiDeviceStreamStatus {
    fn from(value: DeviceStreamStatus) -> Self {
        match value {
            DeviceStreamStatus::Starting => Self::Starting,
            DeviceStreamStatus::Running => Self::Running,
            DeviceStreamStatus::Retrying { reason } => Self::Retrying { reason },
            DeviceStreamStatus::Unavailable { reason } => Self::Unavailable { reason },
        }
    }
}

impl From<ActualDeviceStreamConfig> for UiActualDeviceStreamConfig {
    fn from(value: ActualDeviceStreamConfig) -> Self {
        Self {
            host_name: value.host_name,
            device_id: value.device_id,
            device_name: value.device_name,
            sample_rate: value.sample_rate,
            callback_buffer_size: value.callback_buffer_size,
            channels: value.channels,
        }
    }
}

impl From<AudioRuntimeSettings> for UiAudioRuntimeSettings {
    fn from(value: AudioRuntimeSettings) -> Self {
        Self {
            requested_output: value.requested_output.into(),
            requested_dsp: value.requested_dsp.into(),
            actual_stream: value.actual_stream.map(Into::into),
            stream_status: value.stream_status.into(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{UiOutputDeviceInfo, UiOutputHostSelection};
    use karbeat_core::audio::backend::{AudioDeviceInfo, OutputHostSelection};

    #[test]
    fn default_host_is_a_typed_variant() {
        assert!(matches!(
            UiOutputHostSelection::from(OutputHostSelection::SystemDefault),
            UiOutputHostSelection::SystemDefault
        ));
    }

    #[test]
    fn output_device_conversion_preserves_default_status() {
        let converted = UiOutputDeviceInfo::from(AudioDeviceInfo {
            id: "device-id".to_string(),
            name: "Speakers".to_string(),
            is_default: true,
        });
        assert_eq!(converted.device_id.as_deref(), Some("device-id"));
        assert!(converted.is_current_system_default);
    }
}
