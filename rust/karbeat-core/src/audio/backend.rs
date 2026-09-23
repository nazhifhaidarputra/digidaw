use std::{
    str::FromStr,
    sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
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
        engine::{AudioEngine, AudioEngineTelemetry, record_dsp_load},
        event::TransportFeedback,
        rate_bridge::DeviceRateBridge,
    },
    commands::{AudioCommand, TelemetryRegistration},
    context::DawContext,
    message::TelemetryRegistry,
};

static OUTPUT_UNDERRUN_SAMPLES: AtomicU64 = AtomicU64::new(0);
const OUTPUT_CHANNELS: usize = 2;
const OUTPUT_CHANNELS_U16: u16 = 2;
const OUTPUT_CHANNELS_U64: u64 = 2;
type OutputFrame = [f32; OUTPUT_CHANNELS];

/// Returns the cumulative number of device output samples replaced with silence after underruns.
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
fn write_output_data<T>(
    data: &mut [T],
    device_channels: usize,
    consumer: &mut Consumer<OutputFrame>,
) where
    T: SizedSample + FromSample<f32>,
{
    debug_assert!(device_channels >= OUTPUT_CHANNELS);
    let mut output_frames = data.chunks_exact_mut(device_channels);
    for output_frame in &mut output_frames {
        let engine_frame = consumer.pop().unwrap_or_else(|_| {
            OUTPUT_UNDERRUN_SAMPLES.fetch_add(OUTPUT_CHANNELS_U64, Ordering::Relaxed);
            [0.0; OUTPUT_CHANNELS]
        });

        for output in output_frame.iter_mut() {
            *output = T::from_sample(0.0);
        }
        output_frame[0] = T::from_sample(sanitize_output_sample(engine_frame[0]));
        output_frame[1] = T::from_sample(sanitize_output_sample(engine_frame[1]));
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
        let device_channels = usize::from($config.channels);

        $device.build_output_stream(
            &$config,
            move |data: &mut [$sample_type], _: &OutputCallbackInfo| {
                write_output_data(data, device_channels, &mut consumer);
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
    let supported_configs = configs
        .into_iter()
        .filter(|config| usize::from(config.channels()) >= OUTPUT_CHANNELS)
        .filter(|config| output_sample_format_priority(config.sample_format()) > 0)
        .collect::<Vec<_>>();

    let preferred_channels = supported_configs
        .iter()
        .map(cpal::SupportedStreamConfigRange::channels)
        .min_by_key(|channels| (*channels != OUTPUT_CHANNELS_U16, *channels))?;
    let preferred_configs = supported_configs
        .iter()
        .filter(|config| config.channels() == preferred_channels)
        .collect::<Vec<_>>();

    if let Some(config) = preferred_configs
        .iter()
        .filter(|config| {
            config.min_sample_rate() <= target_sample_rate
                && config.max_sample_rate() >= target_sample_rate
        })
        .max_by_key(|config| output_sample_format_priority(config.sample_format()))
    {
        return Some((config.with_sample_rate(target_sample_rate), false));
    }

    preferred_configs
        .iter()
        .max_by_key(|config| output_sample_format_priority(config.sample_format()))
        .map(|config| {
            let sample_rate =
                native_sample_rate.clamp(config.min_sample_rate(), config.max_sample_rate());
            ((*config).clone().with_sample_rate(sample_rate), true)
        })
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
/// Legacy user-selected device configuration, with absent values requesting backend defaults.
pub struct AudioDeviceConfig {
    /// The string name of the CPAL host (e.g., "ASIO", "WASAPI", "CoreAudio")
    pub host_name: Option<String>,
    /// The specific device name chosen by the user
    pub device_name: Option<String>,
    /// Backend-stable device identifier, when the selected backend exposes one.
    pub device_id: Option<String>,
    /// The user's desired sample rate (e.g., 44100, 48000, 96000)
    pub sample_rate: Option<u32>,
    /// The desired block/buffer size (e.g., 256, 512, 1024)
    pub buffer_size: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
/// Output device metadata exposed to the settings UI.
pub struct AudioDeviceInfo {
    /// Backend-specific stable identifier used to reopen the device.
    pub id: String,
    /// Human-readable device name reported by CPAL.
    pub name: String,
    /// Whether this is the selected host's current default output device.
    pub is_default: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
/// Policy used to select the CPAL host.
pub enum OutputHostSelection {
    /// Follow the platform's default host.
    SystemDefault,
    /// Request the host with the contained CPAL name.
    Named(String),
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
/// Policy used to select an output device within a host.
pub enum OutputDeviceSelection {
    /// Follow the host's default output device.
    SystemDefault,
    /// Request a particular device, retaining its name for display and fallback matching.
    Specific {
        /// Backend-specific device identifier.
        id: String,
        /// Human-readable device name captured when selected.
        name: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
/// Persisted output endpoint selection requested by the user.
pub struct RequestedOutputConfig {
    /// Host selection policy.
    pub host: OutputHostSelection,
    /// Device selection policy within the resolved host.
    pub device: OutputDeviceSelection,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
/// DSP timing requested for the engine independently of device-native timing.
pub struct RequestedDspConfig {
    /// Engine sample rate in frames per second.
    pub sample_rate: u32,
    /// Number of frames rendered per engine block.
    pub block_size: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
/// Current lifecycle state of the physical output stream.
pub enum DeviceStreamStatus {
    /// Initial device resolution or stream construction is in progress.
    Starting,
    /// The stream is active and consuming rendered frames.
    Running,
    /// A recoverable failure triggered delayed stream recreation.
    Retrying {
        /// Diagnostic reason for the current retry cycle.
        reason: String,
    },
    /// No usable stream could currently be established.
    Unavailable {
        /// Diagnostic reason the endpoint is unavailable.
        reason: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
/// Concrete configuration negotiated for the active CPAL stream.
pub struct ActualDeviceStreamConfig {
    /// Name of the CPAL host backing the stream.
    pub host_name: String,
    /// Backend-specific identifier of the opened device.
    pub device_id: String,
    /// Display name of the opened device.
    pub device_name: String,
    /// Device stream sample rate in frames per second.
    pub sample_rate: u32,
    /// Callback buffer size in frames.
    pub callback_buffer_size: u32,
    /// Number of interleaved output channels.
    pub channels: u16,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
/// Shared requested and observed state for the engine's output runtime.
pub struct AudioRuntimeSettings {
    /// User-selected host and device policy.
    pub requested_output: RequestedOutputConfig,
    /// Sample rate and block size at which the engine should render.
    pub requested_dsp: RequestedDspConfig,
    /// Negotiated device configuration while a stream is active.
    pub actual_stream: Option<ActualDeviceStreamConfig>,
    /// Current stream startup or recovery state.
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
    } else if host.id().name() == "ASIO" {
        if let Some(default) = host.default_output_device() {
            default
        } else {
            let mut first = None;
            let mut flex_asio = None;
            for device in host.output_devices()? {
                let is_flex_asio = device
                    .description()
                    .is_ok_and(|description| description.to_string().contains("FlexASIO"))
                    || device
                        .id()
                        .is_ok_and(|id| id.to_string().contains("FlexASIO"));
                if is_flex_asio {
                    flex_asio = Some(device);
                    break;
                }
                if first.is_none() {
                    first = Some(device);
                }
            }
            flex_asio
                .or(first)
                .context("no ASIO output device available")?
        }
    } else {
        host.default_output_device()
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
            .context("device does not support output with at least 2 channels")?;

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
    // Sync the passed config into the context's active_audio_config.
    {
        let mut active_cfg = ctx.active_audio_config.write();
        *active_cfg = config_pref.clone();
    }

    let active_config_arc = Arc::clone(&ctx.active_audio_config);
    let runtime_settings_arc = Arc::clone(&ctx.audio_runtime_settings);

    // Resolve once on the caller thread only to initialize the public/runtime state.
    // AudioEngine itself is intentionally NOT created here.
    let (device, config, sample_format) = get_device_and_config(&config_pref)?;

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

    let telemetry_registry = TelemetryRegistry::new(mixer_consumer);
    ctx.update_telemetry_reg(telemetry_registry);
    ctx.telemetry_reg_receiver = Some(Mutex::new(telemetry_reg_receiver));

    // The monitor never owns AudioEngine. It only asks the persistent DSP thread
    // to attach/detach a device-output ring for each CPAL stream incarnation.
    enum DspControl {
        Attach {
            dsp_config: RequestedDspConfig,
            device_sample_rate: u32,
            ready_tx: std::sync::mpsc::SyncSender<Result<Consumer<OutputFrame>, String>>,
        },
        Detach,
    }

    let (dsp_control_tx, dsp_control_rx) = std::sync::mpsc::sync_channel::<DspControl>(1);

    // Persistent DSP thread. AudioEngine is constructed, used, and dropped only here.
    std::thread::spawn(move || {
        let mut engine = AudioEngine::new(
            command_consumer,
            pos_producer,
            feedback_producer,
            initial_dsp_config.sample_rate,
            OUTPUT_CHANNELS_U16,
            initial_bpm,
            initial_dsp_config.block_size as usize,
            engine_telemetry,
            telemetry_reg_sender,
        );

        'dsp_lifetime: loop {
            let attach = match dsp_control_rx.recv() {
                Ok(DspControl::Attach {
                    dsp_config,
                    device_sample_rate,
                    ready_tx,
                }) => (dsp_config, device_sample_rate, ready_tx),
                Ok(DspControl::Detach) => continue,
                Err(_) => break,
            };

            let (dsp_config, device_sample_rate, ready_tx) = attach;

            engine.process_command(AudioCommand::UpdateAudioConfig {
                sample_rate: Some(dsp_config.sample_rate),
                buffer_size: Some(dsp_config.block_size as usize),
            });

            let mut rate_bridge = match DeviceRateBridge::new(
                dsp_config.sample_rate,
                device_sample_rate,
                OUTPUT_CHANNELS,
                dsp_config.block_size as usize,
            ) {
                Ok(bridge) => bridge,
                Err(error) => {
                    let _ = ready_tx.send(Err(error.to_string()));
                    continue;
                }
            };

            let maximum_device_frames = rate_bridge.maximum_output_samples() / OUTPUT_CHANNELS;
            let ring_buffer_capacity =
                (maximum_device_frames * 8).next_power_of_two().max(4_096);
            let (mut producer, consumer) =
                RingBuffer::<OutputFrame>::new(ring_buffer_capacity);
            let mut staging_buffer =
                vec![0.0; dsp_config.block_size as usize * OUTPUT_CHANNELS];

            // Build the latency cushion before the CPAL stream is started.
            let prefill_blocks =
                ((ring_buffer_capacity / 2) / maximum_device_frames).max(1);
            for _ in 0..prefill_blocks {
                engine.process(&mut staging_buffer);
                let queued =
                    push_output_frames(&mut producer, rate_bridge.process(&staging_buffer));
                debug_assert!(queued, "pre-filled output must fit in the ring buffer");
            }

            if ready_tx.send(Ok(consumer)).is_err() {
                // The monitor abandoned this attach attempt.
                continue;
            }

            // Render until the monitor detaches this device stream. The engine itself
            // never crosses the thread boundary and survives all device restarts.
            loop {
                match dsp_control_rx.try_recv() {
                    Ok(DspControl::Detach) => break,
                    Ok(DspControl::Attach { ready_tx, .. }) => {
                        let _ = ready_tx.send(Err(
                            "DSP output was attached before the previous stream detached".into(),
                        ));
                        break;
                    }
                    Err(std::sync::mpsc::TryRecvError::Disconnected) => {
                        break 'dsp_lifetime;
                    }
                    Err(std::sync::mpsc::TryRecvError::Empty) => {}
                }

                if producer.slots() >= maximum_device_frames {
                    let render_started = Instant::now();
                    engine.process(&mut staging_buffer);
                    let queued =
                        push_output_frames(&mut producer, rate_bridge.process(&staging_buffer));
                    debug_assert!(queued, "rendered output must fit in the ring buffer");
                    record_dsp_load(
                        render_started.elapsed().as_secs_f32(),
                        dsp_config.block_size as usize,
                        dsp_config.sample_rate,
                    );
                } else {
                    std::thread::sleep(Duration::from_millis(1));
                }
            }
        }

        // `engine` is dropped here, on the same DSP thread where it was created.
        log::info!("DSP thread shut down; AudioEngine dropped on DSP thread.");
    });

    // Spawn the device monitor thread. This thread never contains AudioEngine.
    std::thread::spawn(move || {
        let mut retry_delay = INITIAL_RETRY_DELAY;

        loop {
            log::info!("Monitor: Attempting to build and start audio stream...");

            let mut current_config_pref = active_config_arc.read().clone();
            let current_dsp_config = runtime_settings_arc.read().requested_dsp;

            let (device, config, sample_format) =
                match get_device_and_config(&current_config_pref) {
                    Ok(res) => res,
                    Err(e) => {
                        runtime_settings_arc.write().stream_status =
                            DeviceStreamStatus::Retrying {
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

            {
                let mut cfg = active_config_arc.write();
                cfg.sample_rate = Some(device_sample_rate);
                cfg.buffer_size = Some(device_buffer_size as u32);
                current_config_pref = cfg.clone();
            }

            // Ask the DSP thread to create the rate bridge + output ring. The returned
            // Consumer is the only DSP-owned data path that crosses into the monitor.
            let (ready_tx, ready_rx) =
                std::sync::mpsc::sync_channel::<Result<Consumer<OutputFrame>, String>>(1);

            if dsp_control_tx
                .send(DspControl::Attach {
                    dsp_config: current_dsp_config,
                    device_sample_rate,
                    ready_tx,
                })
                .is_err()
            {
                log::error!("DSP thread exited; audio monitor cannot continue.");
                return;
            }

            let consumer = match ready_rx.recv() {
                Ok(Ok(consumer)) => consumer,
                Ok(Err(error)) => {
                    runtime_settings_arc.write().stream_status =
                        DeviceStreamStatus::Unavailable {
                            reason: error.clone(),
                        };
                    log::error!("Could not configure DSP output path: {error}");
                    std::thread::sleep(retry_delay);
                    retry_delay = next_retry_delay(retry_delay);
                    continue;
                }
                Err(error) => {
                    log::error!("DSP thread exited while attaching output: {error}");
                    return;
                }
            };

            let (restart_tx, restart_rx) = std::sync::mpsc::sync_channel::<()>(1);
            let tx_clone = restart_tx.clone();
            let err_config_arc = Arc::clone(&active_config_arc);

            let err_fn = move |err: cpal::StreamError| {
                match err {
                    cpal::StreamError::DeviceNotAvailable => {
                        log::error!(
                            "Audio device disconnected: {}. Triggering restart...",
                            err
                        );
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

                            let parts: Vec<&str> =
                                err_msg.split("buffer size changed to:").collect();
                            if parts.len() > 1 {
                                let num_str = parts[1]
                                    .trim()
                                    .chars()
                                    .take_while(|c| c.is_ascii_digit())
                                    .collect::<String>();
                                if let Ok(new_size) = num_str.parse::<u32>() {
                                    let mut cfg = err_config_arc.write();
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
                        log::error!(
                            "Audio stream invalidated by the OS. Triggering restart..."
                        );
                        let _ = tx_clone.try_send(());
                    }
                }
            };

            let stream_result = match sample_format {
                cpal::SampleFormat::I8 => run_stream!(device, config, consumer, i8, err_fn),
                cpal::SampleFormat::I16 => run_stream!(device, config, consumer, i16, err_fn),
                cpal::SampleFormat::I24 => {
                    run_stream!(device, config, consumer, cpal::I24, err_fn)
                }
                cpal::SampleFormat::I32 => run_stream!(device, config, consumer, i32, err_fn),
                cpal::SampleFormat::I64 => run_stream!(device, config, consumer, i64, err_fn),
                cpal::SampleFormat::U8 => run_stream!(device, config, consumer, u8, err_fn),
                cpal::SampleFormat::U16 => run_stream!(device, config, consumer, u16, err_fn),
                cpal::SampleFormat::U24 => {
                    run_stream!(device, config, consumer, cpal::U24, err_fn)
                }
                cpal::SampleFormat::U32 => run_stream!(device, config, consumer, u32, err_fn),
                cpal::SampleFormat::U64 => run_stream!(device, config, consumer, u64, err_fn),
                cpal::SampleFormat::F32 => run_stream!(device, config, consumer, f32, err_fn),
                cpal::SampleFormat::F64 => run_stream!(device, config, consumer, f64, err_fn),
                _ => Err(cpal::BuildStreamError::StreamConfigNotSupported),
            };

            let stream = match stream_result {
                Ok(stream) => stream,
                Err(e) => {
                    let _ = dsp_control_tx.send(DspControl::Detach);
                    log::error!(
                        "Monitor: Failed to build stream: {}. Retrying in {:?}...",
                        e,
                        retry_delay
                    );
                    std::thread::sleep(retry_delay);
                    retry_delay = next_retry_delay(retry_delay);
                    continue;
                }
            };

            if let Err(e) = stream.play() {
                drop(stream);
                let _ = dsp_control_tx.send(DspControl::Detach);

                runtime_settings_arc.write().stream_status =
                    DeviceStreamStatus::Retrying {
                        reason: e.to_string(),
                    };
                log::error!(
                    "Monitor: Failed to play stream: {}. Retrying in {:?}...",
                    e,
                    retry_delay
                );
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

            let restart_reason = loop {
                if restart_rx.try_recv().is_ok() {
                    log::info!("Monitor: Restart signal received from CPAL callback.");
                    break RestartReason::StreamError;
                }

                let latest_config = active_config_arc.read().clone();
                let latest_dsp_config = runtime_settings_arc.read().requested_dsp;

                if latest_config != current_config_pref
                    || latest_dsp_config != current_dsp_config
                {
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

            // Stop the callback first so it no longer consumes from this ring, then
            // detach the producer/rate bridge on the DSP thread.
            drop(stream);
            if dsp_control_tx.send(DspControl::Detach).is_err() {
                log::error!("DSP thread exited during stream cleanup.");
                return;
            }

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
                    retry_delay = INITIAL_RETRY_DELAY;
                    std::thread::sleep(Duration::from_millis(500));
                }
            }
        }
    });

    log::info!("Successfully initialized Audio backend, DSP thread, and Monitor thread");
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
        write_output_data(&mut output, 2, &mut consumer);

        assert_eq!(output, [0.0, 1.0]);
    }

    #[test]
    fn quiet_float_samples_are_not_quantized_or_gated() {
        let (mut producer, mut consumer) = RingBuffer::new(1);
        producer.push([1.0e-6, -1.0e-6]).unwrap();

        let mut output = [0.0_f32; 2];
        write_output_data(&mut output, 2, &mut consumer);

        assert_eq!(output, [1.0e-6, -1.0e-6]);
    }

    #[test]
    fn stream_config_prefers_f32_over_enumeration_order() {
        let configs = [
            supported_config(2, SampleFormat::U8, 44_100, 96_000),
            supported_config(2, SampleFormat::I16, 44_100, 96_000),
            supported_config(2, SampleFormat::F32, 44_100, 96_000),
        ];

        let (selected, used_fallback_rate) = select_output_config(configs, 48_000, 48_000).unwrap();

        assert_eq!(selected.sample_format(), SampleFormat::F32);
        assert_eq!(selected.sample_rate(), 48_000);
        assert!(!used_fallback_rate);
    }

    #[test]
    fn stream_config_keeps_high_precision_when_rate_falls_back() {
        let configs = [
            supported_config(2, SampleFormat::I16, 44_100, 96_000),
            supported_config(2, SampleFormat::F32, 44_100, 96_000),
        ];

        let (selected, used_fallback_rate) =
            select_output_config(configs, 192_000, 48_000).unwrap();

        assert_eq!(selected.sample_format(), SampleFormat::F32);
        assert_eq!(selected.sample_rate(), 48_000);
        assert!(used_fallback_rate);
    }

    fn supported_config(
        channels: u16,
        sample_format: SampleFormat,
        min_sample_rate: u32,
        max_sample_rate: u32,
    ) -> SupportedStreamConfigRange {
        SupportedStreamConfigRange::new(
            channels,
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
        write_output_data(&mut malformed_output, 2, &mut consumer);
        assert_eq!(malformed_output, [0.0]);

        let mut aligned_output = [0.0_f32; 4];
        write_output_data(&mut aligned_output, 2, &mut consumer);
        assert_eq!(aligned_output, [0.25, -0.25, 0.5, -0.5]);
    }

    #[test]
    fn stream_config_prefers_stereo_then_smallest_multichannel_layout() {
        let configs = [
            supported_config(8, SampleFormat::F32, 44_100, 96_000),
            supported_config(4, SampleFormat::F32, 44_100, 96_000),
            supported_config(2, SampleFormat::I16, 44_100, 96_000),
        ];
        let (selected, _) = select_output_config(configs, 48_000, 48_000).unwrap();
        assert_eq!(selected.channels(), 2);

        let multichannel = [
            supported_config(8, SampleFormat::F32, 44_100, 96_000),
            supported_config(4, SampleFormat::I16, 44_100, 96_000),
        ];
        let (selected, _) = select_output_config(multichannel, 48_000, 48_000).unwrap();
        assert_eq!(selected.channels(), 4);
    }

    #[test]
    fn device_adapter_writes_stereo_to_first_two_channels_and_silences_the_rest() {
        let (mut producer, mut consumer) = RingBuffer::new(1);
        producer.push([0.25, -0.5]).unwrap();

        let mut output = [1.0_f32; 6];
        write_output_data(&mut output, 6, &mut consumer);

        assert_eq!(output, [0.25, -0.5, 0.0, 0.0, 0.0, 0.0]);
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
