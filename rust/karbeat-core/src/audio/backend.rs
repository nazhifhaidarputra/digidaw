use std::{
    str::FromStr,
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicU64, Ordering},
    },
    time::{Duration, Instant},
};

use anyhow::{Context, Result, anyhow};
use cpal::{
    DeviceId, FromSample, OutputCallbackInfo, SizedSample,
    traits::{DeviceTrait, HostTrait, StreamTrait},
};
use parking_lot::Mutex;
use rtrb::{Consumer, Producer, RingBuffer};
use serde::{Deserialize, Serialize};

use crate::{
    audio::{
        engine::{AudioEngine, AudioEngineTelemetry},
        event::TransportFeedback,
        rate_bridge::DeviceRateBridge,
    },
    commands::{AudioCommand, TelemetryRegistration},
    context::DawContext,
    message::TelemetryRegistry,
};

static OUTPUT_UNDERRUN_SAMPLES: AtomicU64 = AtomicU64::new(0);
const OUTPUT_CHANNELS: usize = 2;
type OutputFrame = [f32; OUTPUT_CHANNELS];

pub fn output_underrun_samples() -> u64 {
    OUTPUT_UNDERRUN_SAMPLES.load(Ordering::Relaxed)
}

#[inline(always)]
fn sanitize_output_sample(sample: f32) -> f32 {
    if sample.is_finite() {
        sample.clamp(-1.0, 1.0)
    } else {
        0.0
    }
}

#[inline]
fn write_output_data<T>(data: &mut [T], consumer: &mut Consumer<OutputFrame>)
where
    T: SizedSample + FromSample<f32>,
{
    let mut output_frames = data.chunks_exact_mut(OUTPUT_CHANNELS);
    for output_frame in &mut output_frames {
        let engine_frame = consumer.pop().unwrap_or_else(|_| {
            OUTPUT_UNDERRUN_SAMPLES.fetch_add(OUTPUT_CHANNELS as u64, Ordering::Relaxed);
            [0.0; OUTPUT_CHANNELS]
        });

        for (output, sample) in output_frame.iter_mut().zip(engine_frame) {
            *output = T::from_sample(sanitize_output_sample(sample));
        }
    }

    // A valid stereo CPAL callback is frame-aligned. Keep any malformed tail
    // silent without consuming half of the next engine frame.
    for output in output_frames.into_remainder() {
        *output = T::from_sample(0.0);
    }
}

#[inline]
fn push_output_frames(producer: &mut Producer<OutputFrame>, samples: &[f32]) -> bool {
    if !samples.len().is_multiple_of(OUTPUT_CHANNELS) {
        return false;
    }

    for frame in samples.chunks_exact(OUTPUT_CHANNELS) {
        if producer.push([frame[0], frame[1]]).is_err() {
            return false;
        }
    }

    true
}

enum RestartReason {
    StreamError,
    ConfigurationChanged,
    DefaultDeviceChanged,
}

/// Macro to generate the stream building logic
/// $device: cpal device
/// $config: cpal config
/// $ctx: The AudioContext (moved into the closure)
/// $consumer: The RingBuffer consumer (moved into the closure)
/// $sample_type: The primitive type (f32, i16, etc)
macro_rules! run_stream {
    (
        $device:expr,
        $config:expr,
        $consumer:expr,
        $sample_type:ty,
        $err_fn:expr
    ) => {{
        let mut consumer = $consumer;

        $device.build_output_stream(
            &$config,
            move |data: &mut [$sample_type], _: &OutputCallbackInfo| {
                write_output_data(data, &mut consumer);
            },
            $err_fn,
            None,
        )
    }};
}
/// Resolve the automatic host.
///
/// CPAL's platform default is deliberately used here because it is the host
/// intended to coexist with ordinary desktop applications. Low-latency hosts
/// such as ASIO and JACK can take exclusive ownership of an endpoint (or depend
/// on a separately configured server), so choosing them merely because they can
/// enumerate a device makes startup fail while applications such as Spotify are
/// already playing. They remain available through an explicit `host_name`.
fn automatic_host() -> cpal::Host {
    let host = cpal::default_host();
    log::info!("Connected to automatic audio Host: {}", host.id().name());
    host
}

const INITIAL_RETRY_DELAY: Duration = Duration::from_secs(2);
const MAX_RETRY_DELAY: Duration = Duration::from_secs(10);
const STABLE_STREAM_DURATION: Duration = Duration::from_secs(10);

fn next_retry_delay(delay: Duration) -> Duration {
    delay.saturating_mul(2).min(MAX_RETRY_DELAY)
}

fn output_sample_format_priority(format: cpal::SampleFormat) -> u8 {
    match format {
        // The engine renders f32. Keeping that representation all the way to
        // the device avoids integer quantization of quiet signals.
        cpal::SampleFormat::F32 => 10,
        cpal::SampleFormat::F64 => 9,
        cpal::SampleFormat::I64 | cpal::SampleFormat::U64 => 8,
        cpal::SampleFormat::I32 | cpal::SampleFormat::U32 => 7,
        cpal::SampleFormat::I24 | cpal::SampleFormat::U24 => 6,
        cpal::SampleFormat::I16 | cpal::SampleFormat::U16 => 5,
        cpal::SampleFormat::I8 | cpal::SampleFormat::U8 => 4,
        _ => 0,
    }
}

fn select_output_config(
    configs: impl IntoIterator<Item = cpal::SupportedStreamConfigRange>,
    target_sample_rate: u32,
    native_sample_rate: u32,
) -> Option<(cpal::SupportedStreamConfig, bool)> {
    let stereo_configs = configs
        .into_iter()
        .filter(|config| config.channels() == OUTPUT_CHANNELS as u16)
        .filter(|config| output_sample_format_priority(config.sample_format()) > 0)
        .collect::<Vec<_>>();

    if let Some(config) = stereo_configs
        .iter()
        .filter(|config| {
            config.min_sample_rate() <= target_sample_rate
                && config.max_sample_rate() >= target_sample_rate
        })
        .max_by_key(|config| output_sample_format_priority(config.sample_format()))
    {
        return Some((config.with_sample_rate(target_sample_rate), false));
    }

    stereo_configs
        .iter()
        .max_by_key(|config| output_sample_format_priority(config.sample_format()))
        .map(|config| {
            let sample_rate =
                native_sample_rate.clamp(config.min_sample_rate(), config.max_sample_rate());
            (config.with_sample_rate(sample_rate), true)
        })
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AudioDeviceConfig {
    /// The string name of the CPAL host (e.g., "ASIO", "WASAPI", "CoreAudio")
    pub host_name: Option<String>,
    /// The specific device name chosen by the user
    pub device_name: Option<String>,
    pub device_id: Option<String>,
    /// The user's desired sample rate (e.g., 44100, 48000, 96000)
    pub sample_rate: Option<u32>,
    /// The desired block/buffer size (e.g., 256, 512, 1024)
    pub buffer_size: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AudioDeviceInfo {
    pub id: String,
    pub name: String,
    pub is_default: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum OutputHostSelection {
    SystemDefault,
    Named(String),
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum OutputDeviceSelection {
    SystemDefault,
    Specific { id: String, name: String },
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RequestedOutputConfig {
    pub host: OutputHostSelection,
    pub device: OutputDeviceSelection,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub struct RequestedDspConfig {
    pub sample_rate: u32,
    pub block_size: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum DeviceStreamStatus {
    Starting,
    Running,
    Retrying { reason: String },
    Unavailable { reason: String },
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ActualDeviceStreamConfig {
    pub host_name: String,
    pub device_id: String,
    pub device_name: String,
    pub sample_rate: u32,
    pub callback_buffer_size: u32,
    pub channels: u16,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AudioRuntimeSettings {
    pub requested_output: RequestedOutputConfig,
    pub requested_dsp: RequestedDspConfig,
    pub actual_stream: Option<ActualDeviceStreamConfig>,
    pub stream_status: DeviceStreamStatus,
}

impl Default for AudioRuntimeSettings {
    fn default() -> Self {
        Self {
            requested_output: RequestedOutputConfig {
                host: OutputHostSelection::SystemDefault,
                device: OutputDeviceSelection::SystemDefault,
            },
            requested_dsp: RequestedDspConfig {
                sample_rate: 48_000,
                block_size: 1_024,
            },
            actual_stream: None,
            stream_status: DeviceStreamStatus::Starting,
        }
    }
}

impl Default for AudioDeviceConfig {
    fn default() -> Self {
        Self {
            host_name: None,
            device_name: None,
            device_id: None,
            sample_rate: None,
            buffer_size: None, // Falls back to 1024
        }
    }
}

/// Resolve the host based on user preference or OS defaults
fn resolve_host(preferred_host: Option<&str>) -> cpal::Host {
    if let Some(host_name) = preferred_host {
        if let Some(host_id) = cpal::available_hosts()
            .into_iter()
            .find(|h| h.name() == host_name)
        {
            if let Ok(host) = cpal::host_from_id(host_id) {
                log::info!("Connected to user-selected Host: {}", host_name);
                return host;
            }
        }
        log::warn!(
            "Requested host '{}' not found or failed to load. Falling back...",
            host_name
        );
    }

    automatic_host()
}

/// Returns a list of available host names on the current OS
pub fn get_available_hosts() -> Vec<String> {
    cpal::available_hosts()
        .into_iter()
        .filter(|h| match h.name() {
            "ASIO" => cfg!(feature = "asio"),
            _ => true,
        })
        .map(|h| h.name().to_string())
        .collect()
}

/// Returns the available output devices for a specific host
pub fn get_output_devices(host_name: Option<&str>) -> Result<Vec<AudioDeviceInfo>, anyhow::Error> {
    let host = match host_name {
        None => cpal::default_host(),
        Some(name) => {
            let host_id = cpal::available_hosts()
                .into_iter()
                .find(|host_id| host_id.name() == name)
                .ok_or_else(|| anyhow!("Audio host '{name}' is unavailable"))?;
            cpal::host_from_id(host_id)?
        }
    };
    let default_id = host
        .default_output_device()
        .and_then(|device| device.id().ok())
        .map(|id| id.to_string());
    let mut devices = vec![];

    for dev in host.output_devices()? {
        if let (Ok(id), Ok(desc)) = (dev.id(), dev.description()) {
            let id = id.to_string();
            devices.push(AudioDeviceInfo {
                is_default: default_id.as_deref() == Some(id.as_str()),
                id,
                name: desc.to_string(),
            });
        }
    }

    Ok(devices)
}

/// Returns the supported sample rates for a specific device on a specific host
pub fn get_device_sample_rates(
    host_name: String,
    device_id: String,
) -> Result<Vec<u32>, anyhow::Error> {
    let host_id = cpal::available_hosts()
        .into_iter()
        .find(|h| h.name() == host_name)
        .unwrap_or_else(|| cpal::default_host().id());

    let host = cpal::host_from_id(host_id)?;
    let device = host
        .output_devices()?
        .find(|d| {
            let Ok(id) = d.id() else {
                return false;
            };

            id.to_string() == device_id
        })
        .ok_or_else(|| anyhow::anyhow!("Device not found"))?;

    let mut rates = vec![];
    for config in device.supported_output_configs()? {
        rates.push(config.min_sample_rate());
        rates.push(config.max_sample_rate());
    }

    rates.sort();
    rates.dedup();
    Ok(rates)
}

/// Helper to dry up the code and fetch the device repeatedly during restarts
fn get_device_and_config(
    config_pref: &AudioDeviceConfig,
) -> Result<(cpal::Device, cpal::StreamConfig, cpal::SampleFormat)> {
    let host = resolve_host(config_pref.host_name.as_deref());

    let device = if let Some(dev_id) = &config_pref.device_id {
        // Try to load the user's specifically saved device
        host.output_devices()?
            .find(|d| {
                if let Ok(id_str) = d.id() {
                    let Ok(device_id) = DeviceId::from_str(dev_id.as_str()) else {
                        return false;
                    };
                    return id_str == device_id;
                }
                false
            })
            .ok_or_else(|| anyhow!("Requested device '{}' not found", dev_id))?
    } else {
        // If no device is saved, aggressively prefer FlexASIO over ASIO4ALL
        let mut devices = host.output_devices()?;

        devices
            .find(|d| {
                let res = d.id();
                match res {
                    Ok(name) => name.to_string().contains("FlexASIO"),
                    Err(_) => false,
                }
            })
            .or_else(|| host.default_output_device())
            .context("no audio output device available")?
    };

    let default_config = device
        .default_output_config()
        .context("no default output config available")?;
    let native_sample_rate = default_config.sample_rate();

    let target_sample_rate = config_pref.sample_rate.unwrap_or(native_sample_rate);

    let supported_configs = device
        .supported_output_configs()
        .map_err(|e| anyhow!("error querying configs: {e}"))?
        .collect::<Vec<_>>();

    let (supported_config, used_fallback_rate) =
        select_output_config(supported_configs, target_sample_rate, native_sample_rate)
            .context("device does not support stereo (2 channels) output")?;

    if used_fallback_rate {
        log::warn!("Requested sample rate unsupported by device, falling back");
    }

    // Yield to the Server's globally locked buffer size if using JACK to prevent crash loop
    let buffer_size = if host.id().name() == "JACK" {
        cpal::BufferSize::Default
    } else {
        match supported_config.buffer_size() {
            cpal::SupportedBufferSize::Range { min, max } => {
                let desired = config_pref.buffer_size.unwrap_or(1024);
                cpal::BufferSize::Fixed(desired.clamp(*min, *max))
            }
            cpal::SupportedBufferSize::Unknown => cpal::BufferSize::Default,
        }
    };

    let config = cpal::StreamConfig {
        channels: supported_config.channels(),
        sample_rate: supported_config.sample_rate(),
        buffer_size,
    };

    Ok((device, config, supported_config.sample_format()))
}
/// Start the audio stream by initializing the Command Queue and Audio Engine
/// and then spawning the Monitor Thread to handle stream failures.
pub fn start_audio_stream(
    ctx: &mut DawContext,
    command_consumer: Consumer<AudioCommand>,
    config_pref: AudioDeviceConfig,
) -> Result<()> {
    // Sync the passed config into the context's active_audio_config
    {
        let mut active_cfg = ctx.active_audio_config.write();
        *active_cfg = config_pref.clone();
    }

    let active_config_arc = Arc::clone(&ctx.active_audio_config);
    let runtime_settings_arc = Arc::clone(&ctx.audio_runtime_settings);

    // Resolve initial device and config to create the engine exactly once
    let (device, config, sample_format) = get_device_and_config(&config_pref)?;

    // Extract actual values granted by the OS instead of relying on preferences
    let device_sample_rate = config.sample_rate;
    let channels = config.channels as usize;
    let device_buffer_size = match config.buffer_size {
        cpal::BufferSize::Fixed(size) => size as usize,
        cpal::BufferSize::Default => config_pref.buffer_size.unwrap_or(1024) as usize,
    };

    {
        let mut runtime = runtime_settings_arc.write();
        runtime.requested_output = RequestedOutputConfig {
            host: config_pref
                .host_name
                .clone()
                .map(OutputHostSelection::Named)
                .unwrap_or(OutputHostSelection::SystemDefault),
            device: match (&config_pref.device_id, &config_pref.device_name) {
                (Some(id), Some(name)) => OutputDeviceSelection::Specific {
                    id: id.clone(),
                    name: name.clone(),
                },
                (Some(id), None) => OutputDeviceSelection::Specific {
                    id: id.clone(),
                    name: id.clone(),
                },
                _ => OutputDeviceSelection::SystemDefault,
            },
        };
        runtime.actual_stream = Some(actual_stream_config(
            &device,
            &config,
            config_pref.host_name.as_deref(),
            device_buffer_size as u32,
        ));
        runtime.stream_status = DeviceStreamStatus::Starting;
    }

    // Sync actual OS values back to the active configuration immediately
    {
        let mut active_cfg = active_config_arc.write();
        active_cfg.sample_rate = Some(device_sample_rate);
        active_cfg.buffer_size = Some(device_buffer_size as u32);
        active_cfg.host_name = config_pref.host_name;
        active_cfg.device_id = config_pref.device_id;
    }

    log::info!(
        "Initial Stream Config: {:?} Hz, {} Channels",
        device_sample_rate,
        channels
    );
    log::info!("Initial Sample format: {:?}", sample_format);

    let initial_dsp_config = runtime_settings_arc.read().requested_dsp;
    ctx.app_state.audio_config.sample_rate = initial_dsp_config.sample_rate;
    ctx.app_state.audio_config.buffer_size = initial_dsp_config.block_size;
    ctx.app_state.audio_config.selected_output_device = device
        .id()
        .map(|id| id.to_string())
        .unwrap_or_else(|_| "Unknown".into());

    let (pos_producer, pos_consumer) = RingBuffer::<TransportFeedback>::new(100);
    ctx.position_consumer = Arc::new(Mutex::new(Some(pos_consumer)));

    let (feedback_producer, feedback_consumer) =
        RingBuffer::<crate::commands::AudioFeedback>::new(512);
    ctx.feedback_consumer = Arc::new(Mutex::new(Some(feedback_consumer)));

    let initial_bpm = ctx.app_state.transport.bpm;

    let (engine_telemetry, mixer_consumer) = AudioEngineTelemetry::new();

    let (telemetry_reg_sender, telemetry_reg_receiver) =
        std::sync::mpsc::sync_channel::<TelemetryRegistration>(64);

    let mut engine = AudioEngine::new(
        command_consumer,
        pos_producer,
        feedback_producer,
        initial_dsp_config.sample_rate,
        channels as u16,
        initial_bpm,
        initial_dsp_config.block_size as usize,
        engine_telemetry,
        telemetry_reg_sender,
    );

    let telemetry_registry = TelemetryRegistry::new(mixer_consumer);

    ctx.update_telemetry_reg(telemetry_registry);
    ctx.telemetry_reg_receiver = Some(Mutex::new(telemetry_reg_receiver));

    // Spawn the Device Monitor Thread
    std::thread::spawn(move || {
        let mut retry_delay = INITIAL_RETRY_DELAY;

        loop {
            log::info!("Monitor: Attempting to build and start audio stream...");

            let mut current_config_pref = active_config_arc.read().clone();
            let current_dsp_config = runtime_settings_arc.read().requested_dsp;

            let (device, config, sample_format) = match get_device_and_config(&current_config_pref)
            {
                Ok(res) => res,
                Err(e) => {
                    runtime_settings_arc.write().stream_status = DeviceStreamStatus::Retrying {
                        reason: e.to_string(),
                    };
                    log::error!(
                        "Monitor: Failed to resolve audio device: {}. Retrying in {:?}...",
                        e,
                        retry_delay
                    );
                    std::thread::sleep(retry_delay);
                    retry_delay = next_retry_delay(retry_delay);
                    continue;
                }
            };

            let device_sample_rate = config.sample_rate;
            let channels = config.channels as usize;
            let device_buffer_size = match config.buffer_size {
                cpal::BufferSize::Fixed(size) => size as usize,
                cpal::BufferSize::Default => {
                    current_config_pref.buffer_size.unwrap_or(1024) as usize
                }
            };

            let playing_device_id = device.id().ok();
            let current_host = resolve_host(current_config_pref.host_name.as_deref());
            let actual_config = actual_stream_config(
                &device,
                &config,
                current_config_pref.host_name.as_deref(),
                device_buffer_size as u32,
            );

            // Sync actual OS values back to the active configuration immediately to prevent restart loops
            {
                let mut cfg = active_config_arc.write();
                cfg.sample_rate = Some(device_sample_rate);
                cfg.buffer_size = Some(device_buffer_size as u32);
                current_config_pref = cfg.clone(); // Crucial: update local tracking to silence the polling loop
            }

            {
                engine.process_command(AudioCommand::UpdateAudioConfig {
                    sample_rate: Some(current_dsp_config.sample_rate),
                    buffer_size: Some(current_dsp_config.block_size as usize),
                });
            }

            let mut rate_bridge = match DeviceRateBridge::new(
                current_dsp_config.sample_rate,
                device_sample_rate,
                channels,
                current_dsp_config.block_size as usize,
            ) {
                Ok(bridge) => bridge,
                Err(error) => {
                    runtime_settings_arc.write().stream_status = DeviceStreamStatus::Unavailable {
                        reason: error.to_string(),
                    };
                    log::error!("Could not configure the device-rate bridge: {error}");
                    std::thread::sleep(retry_delay);
                    continue;
                }
            };
            let maximum_device_frames = rate_bridge.maximum_output_samples() / OUTPUT_CHANNELS;
            let ring_buffer_capacity = (maximum_device_frames * 8).next_power_of_two().max(4_096);
            let (mut producer, consumer) = RingBuffer::<OutputFrame>::new(ring_buffer_capacity);
            let mut staging_buffer = vec![0.0; current_dsp_config.block_size as usize * channels];

            // Setup Dedicated DSP Thread State
            let is_dsp_running = Arc::new(AtomicBool::new(true));
            let is_dsp_running_clone = Arc::clone(&is_dsp_running);
            // Pre-fill ring buffer to create a latency cushion to withstand OS scheduling jitter
            let prefill_blocks = (ring_buffer_capacity / 2) / maximum_device_frames;
            for _ in 0..prefill_blocks {
                engine.process(&mut staging_buffer);
                let queued =
                    push_output_frames(&mut producer, rate_bridge.process(&staging_buffer));
                debug_assert!(queued, "pre-filled output must fit in the ring buffer");
            }

            // Spawn the Dedicated DSP Thread
            let dsp_thread = std::thread::spawn(move || {
                while is_dsp_running_clone.load(Ordering::Relaxed) {
                    if producer.slots() >= maximum_device_frames {
                        engine.process(&mut staging_buffer);
                        let queued =
                            push_output_frames(&mut producer, rate_bridge.process(&staging_buffer));
                        debug_assert!(queued, "rendered output must fit in the ring buffer");
                    } else {
                        // Sleep slightly to prevent a 100% CPU busy-wait loop
                        std::thread::sleep(std::time::Duration::from_millis(1));
                    }
                }
                log::info!("DSP Thread explicitly shut down gracefully.");
                engine
            });

            // Each stream owns its restart signal. A bounded channel coalesces
            // repeated backend callbacks and cannot carry a stale signal into
            // the next stream attempt.
            let (restart_tx, restart_rx) = std::sync::mpsc::sync_channel::<()>(1);
            let tx_clone = restart_tx.clone();

            let err_config_arc = Arc::clone(&active_config_arc);

            let err_fn = move |err: cpal::StreamError| {
                match err {
                    cpal::StreamError::DeviceNotAvailable => {
                        log::error!("Audio device disconnected: {}. Triggering restart...", err);
                        let _ = tx_clone.try_send(());
                    }
                    cpal::StreamError::BackendSpecific { ref err } => {
                        let err_msg = err.to_string().to_lowercase();
                        if err_msg.contains("underrun") || err_msg.contains("overrun") {
                            log::warn!(
                                "Audio glitch (buffer underrun) detected due to CPU lag. Recovering naturally..."
                            );
                        } else if err_msg.contains("buffer size changed to:") {
                            log::warn!(
                                "Host forced a different buffer size. Adapting config to prevent crash loop..."
                            );

                            // Extract the exact buffer size JACK/OS is forcing us to use
                            let parts: Vec<&str> =
                                err_msg.split("buffer size changed to:").collect();
                            if parts.len() > 1 {
                                let num_str = parts[1]
                                    .trim()
                                    .chars()
                                    .take_while(|c| c.is_ascii_digit())
                                    .collect::<String>();
                                if let Ok(new_size) = num_str.parse::<u32>() {
                                    log::info!("Dynamically updating buffer size to {}", new_size);
                                    let mut cfg = err_config_arc.write();

                                    // Only trigger logic if the size is ACTUALLY different
                                    if cfg.buffer_size != Some(new_size) {
                                        log::info!(
                                            "Dynamically updating buffer size to {}",
                                            new_size
                                        );
                                        cfg.buffer_size = Some(new_size);
                                        let _ = tx_clone.try_send(());
                                    } else {
                                        log::debug!(
                                            "Buffer size is already synced to {}. Ignoring redundant error.",
                                            new_size
                                        );
                                    }
                                }
                            }
                        } else {
                            log::error!(
                                "Audio stream backend error: {}. Triggering restart...",
                                err_msg
                            );
                            let _ = tx_clone.try_send(());
                        }
                    }
                    cpal::StreamError::BufferUnderrun => {
                        log::warn!(
                            "Native buffer underrun detected due to CPU lag. Recovering naturally..."
                        );
                    }
                    cpal::StreamError::StreamInvalidated => {
                        log::error!("Audio stream invalidated by the OS. Triggering restart...");
                        let _ = tx_clone.try_send(());
                    }
                }
            };

            let stream_result = match sample_format {
                cpal::SampleFormat::I8 => run_stream!(device, config, consumer, i8, err_fn),
                cpal::SampleFormat::I16 => run_stream!(device, config, consumer, i16, err_fn),
                cpal::SampleFormat::I24 => run_stream!(device, config, consumer, cpal::I24, err_fn),
                cpal::SampleFormat::I32 => run_stream!(device, config, consumer, i32, err_fn),
                cpal::SampleFormat::I64 => run_stream!(device, config, consumer, i64, err_fn),
                cpal::SampleFormat::U8 => run_stream!(device, config, consumer, u8, err_fn),
                cpal::SampleFormat::U16 => run_stream!(device, config, consumer, u16, err_fn),
                cpal::SampleFormat::U24 => run_stream!(device, config, consumer, cpal::U24, err_fn),
                cpal::SampleFormat::U32 => run_stream!(device, config, consumer, u32, err_fn),
                cpal::SampleFormat::U64 => run_stream!(device, config, consumer, u64, err_fn),
                cpal::SampleFormat::F32 => run_stream!(device, config, consumer, f32, err_fn),
                cpal::SampleFormat::F64 => run_stream!(device, config, consumer, f64, err_fn),
                _ => Err(cpal::BuildStreamError::StreamConfigNotSupported),
            };

            let stream = match stream_result {
                Ok(s) => s,
                Err(e) => {
                    log::error!(
                        "Monitor: Failed to build stream: {}. Retrying in {:?}...",
                        e,
                        retry_delay
                    );
                    // Abort the DSP thread to prevent memory leak/orphans since stream failed
                    is_dsp_running.store(false, Ordering::Relaxed);
                    engine = match dsp_thread.join() {
                        Ok(returned_engine) => returned_engine,
                        Err(error) => {
                            log::error!("DSP worker failed while returning engine: {error:?}");
                            return;
                        }
                    };

                    std::thread::sleep(retry_delay);
                    retry_delay = next_retry_delay(retry_delay);
                    continue;
                }
            };

            if let Err(e) = stream.play() {
                runtime_settings_arc.write().stream_status = DeviceStreamStatus::Retrying {
                    reason: e.to_string(),
                };
                log::error!(
                    "Monitor: Failed to play stream: {}. Retrying in {:?}...",
                    e,
                    retry_delay
                );
                // Abort the DSP thread cleanly
                is_dsp_running.store(false, Ordering::Relaxed);
                engine = match dsp_thread.join() {
                    Ok(returned_engine) => returned_engine,
                    Err(error) => {
                        log::error!("DSP worker failed while returning engine: {error:?}");
                        return;
                    }
                };

                std::thread::sleep(retry_delay);
                retry_delay = next_retry_delay(retry_delay);
                continue;
            }

            {
                let mut runtime = runtime_settings_arc.write();
                runtime.actual_stream = Some(actual_config);
                runtime.stream_status = DeviceStreamStatus::Running;
            }
            log::info!("Monitor: Audio stream is successfully running.");
            let stream_started_at = Instant::now();

            // ---------------------------------------------------------
            // Active Polling Loop (~10 FPS)
            // ---------------------------------------------------------
            let restart_reason = loop {
                if restart_rx.try_recv().is_ok() {
                    log::info!("Monitor: Restart signal received from CPAL callback.");
                    break RestartReason::StreamError;
                }
                let latest_config = active_config_arc.read().clone();
                let latest_dsp_config = runtime_settings_arc.read().requested_dsp;

                if latest_config != current_config_pref || latest_dsp_config != current_dsp_config {
                    log::info!(
                        "Monitor: Audio configuration changed by user. Restarting stream..."
                    );
                    break RestartReason::ConfigurationChanged;
                }

                if latest_config.device_id.is_none() {
                    if let Some(default_dev) = current_host.default_output_device() {
                        if let Ok(ref default_id) = default_dev.id() {
                            if let Some(ref playing_device_id_some) = playing_device_id {
                                if default_id != playing_device_id_some {
                                    log::info!(
                                        "Monitor: OS Default device changed from '{}' to '{}'. Restarting stream...",
                                        playing_device_id_some,
                                        default_id
                                    );
                                    break RestartReason::DefaultDeviceChanged;
                                }
                            }
                        }
                    }
                }

                std::thread::sleep(Duration::from_millis(100));
            };

            // CLEANUP: Drop the active stream. This safely releases the hardware handle.
            drop(stream);

            // CLEANUP: Signal DSP Thread to stop gracefully and join it to prevent memory leaks
            is_dsp_running.store(false, Ordering::Relaxed);
            engine = match dsp_thread.join() {
                Ok(returned_engine) => returned_engine,
                Err(error) => {
                    log::error!("Failed to join DSP worker: {error:?}");
                    return;
                }
            };

            match restart_reason {
                RestartReason::StreamError
                    if stream_started_at.elapsed() < STABLE_STREAM_DURATION =>
                {
                    log::warn!(
                        "Audio stream failed shortly after startup. Retrying in {:?}...",
                        retry_delay
                    );
                    std::thread::sleep(retry_delay);
                    retry_delay = next_retry_delay(retry_delay);
                }
                _ => {
                    // A stream that ran stably, or an intentional routing/config
                    // change, starts a fresh retry cycle.
                    retry_delay = INITIAL_RETRY_DELAY;
                    std::thread::sleep(Duration::from_millis(500));
                }
            }
        }
    });

    log::info!("Successfully initialized Audio backend and Monitor thread");
    Ok(())
}

fn actual_stream_config(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    requested_host_name: Option<&str>,
    callback_buffer_size: u32,
) -> ActualDeviceStreamConfig {
    let host_name = requested_host_name
        .map(str::to_string)
        .unwrap_or_else(|| cpal::default_host().id().name().to_string());
    let device_id = device
        .id()
        .map(|id| id.to_string())
        .unwrap_or_else(|_| "Unavailable".to_string());
    let device_name = device
        .description()
        .map(|description| description.to_string())
        .unwrap_or_else(|_| device_id.clone());
    ActualDeviceStreamConfig {
        host_name,
        device_id,
        device_name,
        sample_rate: config.sample_rate,
        callback_buffer_size,
        channels: config.channels,
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "backend tests fail immediately when deterministic fixtures violate their invariants"
)]
mod tests {
    use super::{
        INITIAL_RETRY_DELAY, MAX_RETRY_DELAY, automatic_host, next_retry_delay, push_output_frames,
        select_output_config, write_output_data,
    };
    use cpal::{SampleFormat, SupportedBufferSize, SupportedStreamConfigRange};
    use rtrb::RingBuffer;

    #[test]
    fn automatic_host_is_the_cpal_platform_default() {
        assert_eq!(automatic_host().id(), cpal::default_host().id());
    }

    #[test]
    fn stream_retry_delay_is_capped() {
        let mut delay = INITIAL_RETRY_DELAY;

        delay = next_retry_delay(delay);
        assert_eq!(delay.as_secs(), 4);
        delay = next_retry_delay(delay);
        assert_eq!(delay.as_secs(), 8);
        delay = next_retry_delay(delay);
        assert_eq!(delay, MAX_RETRY_DELAY);
        assert_eq!(next_retry_delay(delay), MAX_RETRY_DELAY);
    }

    #[test]
    fn device_output_is_finite_and_in_cpals_nominal_range() {
        let (mut producer, mut consumer) = RingBuffer::new(1);
        producer.push([f32::NAN, 2.0]).unwrap();

        let mut output = [42.0_f32; 2];
        write_output_data(&mut output, &mut consumer);

        assert_eq!(output, [0.0, 1.0]);
    }

    #[test]
    fn quiet_float_samples_are_not_quantized_or_gated() {
        let (mut producer, mut consumer) = RingBuffer::new(1);
        producer.push([1.0e-6, -1.0e-6]).unwrap();

        let mut output = [0.0_f32; 2];
        write_output_data(&mut output, &mut consumer);

        assert_eq!(output, [1.0e-6, -1.0e-6]);
    }

    #[test]
    fn stream_config_prefers_f32_over_enumeration_order() {
        let configs = [
            supported_config(SampleFormat::U8, 44_100, 96_000),
            supported_config(SampleFormat::I16, 44_100, 96_000),
            supported_config(SampleFormat::F32, 44_100, 96_000),
        ];

        let (selected, used_fallback_rate) = select_output_config(configs, 48_000, 48_000).unwrap();

        assert_eq!(selected.sample_format(), SampleFormat::F32);
        assert_eq!(selected.sample_rate(), 48_000);
        assert!(!used_fallback_rate);
    }

    #[test]
    fn stream_config_keeps_high_precision_when_rate_falls_back() {
        let configs = [
            supported_config(SampleFormat::I16, 44_100, 96_000),
            supported_config(SampleFormat::F32, 44_100, 96_000),
        ];

        let (selected, used_fallback_rate) =
            select_output_config(configs, 192_000, 48_000).unwrap();

        assert_eq!(selected.sample_format(), SampleFormat::F32);
        assert_eq!(selected.sample_rate(), 48_000);
        assert!(used_fallback_rate);
    }

    fn supported_config(
        sample_format: SampleFormat,
        min_sample_rate: u32,
        max_sample_rate: u32,
    ) -> SupportedStreamConfigRange {
        SupportedStreamConfigRange::new(
            2,
            min_sample_rate,
            max_sample_rate,
            SupportedBufferSize::Unknown,
            sample_format,
        )
    }

    #[test]
    fn malformed_callback_tail_does_not_shift_stereo_frames() {
        let (mut producer, mut consumer) = RingBuffer::new(2);
        producer.push([0.25, -0.25]).unwrap();
        producer.push([0.5, -0.5]).unwrap();

        let mut malformed_output = [1.0_f32; 1];
        write_output_data(&mut malformed_output, &mut consumer);
        assert_eq!(malformed_output, [0.0]);

        let mut aligned_output = [0.0_f32; 4];
        write_output_data(&mut aligned_output, &mut consumer);
        assert_eq!(aligned_output, [0.25, -0.25, 0.5, -0.5]);
    }

    #[test]
    fn engine_output_is_queued_as_complete_frames() {
        let (mut producer, mut consumer) = RingBuffer::new(2);

        assert!(push_output_frames(&mut producer, &[0.25, -0.25, 0.5, -0.5]));
        assert_eq!(consumer.pop().unwrap(), [0.25, -0.25]);
        assert_eq!(consumer.pop().unwrap(), [0.5, -0.5]);
        assert!(!push_output_frames(&mut producer, &[0.25]));
    }
}
