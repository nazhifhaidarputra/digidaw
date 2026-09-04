use crate::{
    audio::backend::{
        self, AudioDeviceInfo, AudioRuntimeSettings, DeviceStreamStatus, OutputDeviceSelection,
        OutputHostSelection, RequestedOutputConfig,
    },
    context::DawContext,
};

pub fn available_output_hosts() -> Vec<String> {
    backend::get_available_hosts()
}

pub fn available_output_devices(host_name: Option<&str>) -> anyhow::Result<Vec<AudioDeviceInfo>> {
    backend::get_output_devices(host_name)
}

pub fn runtime_settings(ctx: &DawContext) -> AudioRuntimeSettings {
    ctx.audio_runtime_settings.read().clone()
}

pub fn output_underrun_samples() -> u64 {
    backend::output_underrun_samples()
}

pub const SUPPORTED_DSP_SAMPLE_RATES: [u32; 4] = [44_100, 48_000, 88_200, 96_000];
pub const SUPPORTED_DSP_BLOCK_SIZES: [u32; 6] = [64, 128, 256, 512, 1_024, 2_048];

pub fn set_dsp_config(
    ctx: &mut DawContext,
    sample_rate: u32,
    block_size: u32,
) -> anyhow::Result<AudioRuntimeSettings> {
    anyhow::ensure!(
        SUPPORTED_DSP_SAMPLE_RATES.contains(&sample_rate),
        "Unsupported DSP sample rate: {sample_rate}"
    );
    anyhow::ensure!(
        SUPPORTED_DSP_BLOCK_SIZES.contains(&block_size),
        "Unsupported DSP block size: {block_size}"
    );

    {
        let mut runtime = ctx.audio_runtime_settings.write();
        runtime.requested_dsp.sample_rate = sample_rate;
        runtime.requested_dsp.block_size = block_size;
        runtime.stream_status = DeviceStreamStatus::Starting;
    }
    ctx.app_state.audio_config.sample_rate = sample_rate;
    ctx.app_state.audio_config.buffer_size = block_size;
    Ok(ctx.audio_runtime_settings.read().clone())
}

pub fn select_output(
    ctx: &DawContext,
    host_name: Option<String>,
    device_id: Option<String>,
) -> anyhow::Result<AudioRuntimeSettings> {
    if let Some(host_name) = host_name.as_deref()
        && !available_output_hosts()
            .iter()
            .any(|name| name == host_name)
    {
        anyhow::bail!("Audio host '{host_name}' is unavailable");
    }

    let selected_device = match device_id {
        None => OutputDeviceSelection::SystemDefault,
        Some(id) => {
            let devices = available_output_devices(host_name.as_deref())?;
            let device = devices
                .into_iter()
                .find(|device| device.id == id)
                .ok_or_else(|| anyhow::anyhow!("Output device '{id}' is unavailable"))?;
            OutputDeviceSelection::Specific {
                id: device.id,
                name: device.name,
            }
        }
    };
    let selected_host = host_name
        .clone()
        .map(OutputHostSelection::Named)
        .unwrap_or(OutputHostSelection::SystemDefault);

    {
        let mut legacy = ctx.active_audio_config.write();
        legacy.host_name = host_name;
        match &selected_device {
            OutputDeviceSelection::SystemDefault => {
                legacy.device_id = None;
                legacy.device_name = None;
            }
            OutputDeviceSelection::Specific { id, name } => {
                legacy.device_id = Some(id.clone());
                legacy.device_name = Some(name.clone());
            }
        }
    }

    let mut runtime = ctx.audio_runtime_settings.write();
    runtime.requested_output = RequestedOutputConfig {
        host: selected_host,
        device: selected_device,
    };
    runtime.stream_status = DeviceStreamStatus::Starting;
    Ok(runtime.clone())
}

#[cfg(test)]
#[allow(
    clippy::expect_used,
    reason = "audio configuration tests fail immediately when a fixed fixture is invalid"
)]
mod tests {
    use super::{select_output, set_dsp_config};
    use crate::{
        audio::backend::{OutputDeviceSelection, OutputHostSelection},
        context::DawContext,
    };

    #[test]
    fn system_default_selection_is_explicit_and_does_not_require_hardware() {
        let ctx = DawContext::new();
        let settings = select_output(&ctx, None, None).expect("default selection should work");
        assert_eq!(
            settings.requested_output.host,
            OutputHostSelection::SystemDefault
        );
        assert_eq!(
            settings.requested_output.device,
            OutputDeviceSelection::SystemDefault
        );
        assert!(ctx.active_audio_config.read().device_id.is_none());
    }

    #[test]
    fn unknown_named_host_is_rejected_without_mutating_selection() {
        let ctx = DawContext::new();
        let result = select_output(&ctx, Some("not-a-real-host".to_string()), None);
        assert!(result.is_err());
        assert_eq!(
            ctx.audio_runtime_settings.read().requested_output.host,
            OutputHostSelection::SystemDefault
        );
    }

    #[test]
    fn dsp_config_is_validated_without_changing_device_preferences() {
        let mut ctx = DawContext::new();
        ctx.active_audio_config.write().device_id = Some("device-a".to_string());
        let settings = set_dsp_config(&mut ctx, 96_000, 256).expect("valid DSP config");
        assert_eq!(settings.requested_dsp.sample_rate, 96_000);
        assert_eq!(settings.requested_dsp.block_size, 256);
        assert_eq!(
            ctx.active_audio_config.read().device_id.as_deref(),
            Some("device-a")
        );
        assert!(set_dsp_config(&mut ctx, 12_345, 256).is_err());
    }
}
