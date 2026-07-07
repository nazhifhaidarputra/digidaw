use std::{str::FromStr, sync::Arc};

use anyhow::{anyhow, Context, Result};
use arc_swap::ArcSwap;
use cpal::{
    traits::{DeviceTrait, HostTrait, StreamTrait},
    DeviceId, OutputCallbackInfo,
};
use hashbrown::HashMap;
use parking_lot::Mutex;
use rtrb::{Consumer, RingBuffer};
use serde::{Deserialize, Serialize};

use crate::{
    audio::{engine::{ActivePluginTelemetrySnapshots, AudioEngine, AudioEngineTelemetry, MixerTelemetrySnapshot}, event::TransportFeedback},
    commands::AudioCommand,
    context::DawContext, message::TelemetryRegistry,
};

#[allow(unused)]
fn host_has_output_device(host: &cpal::Host) -> bool {
    host.output_devices()
        .map(|mut devices| devices.next().is_some())
        .unwrap_or(false)
}

struct AudioContext {
    engine: Arc<Mutex<AudioEngine>>,
    producer: rtrb::Producer<f32>,
    staging_buffer: Vec<f32>,
}

/// Macro to generate the stream building logic
/// $device: cpal device
/// $config: cpal config
/// $ctx: The AudioContext (moved into the closure)
/// $consumer: The RingBuffer consumer (moved into the closure)
/// $sample_type: The primitive type (f32, i16, etc)
/// $converter: A closure |f32_sample| -> $sample_type
macro_rules! run_stream {
    (
        $device:expr,
        $config:expr,
        $audio_ctx:expr,
        $consumer:expr,
        $sample_type:ty,
        $converter:expr,
        $err_fn:expr
    ) => {{
        let mut audio_ctx = $audio_ctx;
        let mut consumer = $consumer;
        // Internal buffer for reading from ringbuffer before conversion
        let mut read_buffer: Vec<f32> = Vec::new();

        $device.build_output_stream(
            &$config,
            move |data: &mut [$sample_type], _: &OutputCallbackInfo| {
                let samples_needed = data.len();

                // Ensure Ring Buffer has enough data
                // While readable samples < needed samples
                while consumer.slots() < samples_needed {
                    // Process fixed block
                    {
                        let mut engine = audio_ctx.engine.lock();
                        engine.process(&mut audio_ctx.staging_buffer);
                    }

                    // Push to RingBuffer
                    // Note: process() fills staging_buffer completely
                    for sample in &audio_ctx.staging_buffer {
                        if let Err(_) = audio_ctx.producer.push(*sample) {
                            break;
                        }
                    }
                }

                if read_buffer.len() != samples_needed {
                    read_buffer.resize(samples_needed, 0.0);
                }

                for i in 0..samples_needed {
                    if let Ok(sample) = consumer.pop() {
                        read_buffer[i] = sample;
                    } else {
                        read_buffer[i] = 0.0;
                    }
                }

                // Write to output with conversion
                for (out, &in_sample) in data.iter_mut().zip(read_buffer.iter()) {
                    *out = $converter(in_sample);
                }
            },
            $err_fn,
            None,
        )
    }};
}

/// Set host to use the optimized host for each platform.
/// - Windows: ASIO, then fallback to WASAPI (low latency)
/// - Android: AAudio (low latency, requires API 26+)
/// - Linux: JACK
/// - Other platforms: default host
fn set_host() -> cpal::Host {
    #[allow(unused_mut)]
    let mut host = cpal::default_host();

    #[cfg(target_os = "windows")]
    {
        // ASIO is only available when the "asio" feature is enabled
        #[cfg(feature = "asio")]
        {
            if let Ok(asio_host) = cpal::host_from_id(cpal::HostId::Asio) {
                if host_has_output_device(&asio_host) {
                    log::info!("Connected to ASIO Host");
                    return asio_host;
                } else {
                    log::warn!(
                        "ASIO host found but no output devices available; falling back to WASAPI"
                    );
                }
            } else {
                log::warn!("ASIO host not available; falling back to WASAPI");
            }
        }

        #[cfg(not(feature = "asio"))]
        log::debug!("ASIO support not compiled in; using WASAPI");

        if let Ok(wasapi_host) = cpal::host_from_id(cpal::HostId::Wasapi) {
            log::info!("Connected to WASAPI Host");
            return wasapi_host;
        }

        log::warn!("WASAPI not available; falling back to default host");
    }

    #[cfg(target_os = "android")]
    {
        match cpal::host_from_id(cpal::HostId::AAudio) {
            Ok(aaudio_host) => {
                log::info!("Connected to AAudio Host");
                return aaudio_host;
            }
            Err(e) => {
                log::warn!("AAudio not available, falling back to default host: {}", e);
            }
        }
    }

    #[cfg(target_os = "linux")]
    {
        // JACK is only available when the "jack" feature is enabled
        #[cfg(feature = "jack")]
        {
            match cpal::host_from_id(cpal::HostId::Jack) {
                Ok(jack_host) => {
                    log::info!("Connected to JACK Host");
                    return jack_host;
                }
                Err(e) => {
                    log::warn!("JACK not available, falling back to default host: {}", e);
                }
            }
        }

        #[cfg(not(feature = "jack"))]
        log::debug!("JACK support not compiled in; using default Linux host (ALSA)");
    }

    #[cfg(any(target_os = "macos", target_os = "ios"))]
    {
        if let Ok(core_audio_host) = cpal::host_from_id(cpal::HostId::CoreAudio) {
            log::info!("Connected to CoreAudio Host");
            return core_audio_host;
        }
    }

    host
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

/// A clean struct to pass back to Flutter for the UI dropdown
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioDeviceInfo {
    pub id: String,
    pub name: String,
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

    set_host()
}

/// Returns a list of available host names on the current OS
pub fn get_available_hosts() -> Vec<String> {
    cpal::available_hosts()
        .into_iter()
        .filter(|h| match h.name() {
            "ASIO" => cfg!(feature = "asio"),
            "JACK" => cfg!(feature = "jack"),
            _ => true,
        })
        .map(|h| h.name().to_string())
        .collect()
}

/// Returns the available output devices for a specific host
pub fn get_output_devices(host_name: String) -> Result<Vec<AudioDeviceInfo>, anyhow::Error> {
    let host_id = cpal::available_hosts()
        .into_iter()
        .find(|h| h.name() == host_name)
        .unwrap_or_else(|| cpal::default_host().id());

    let host = cpal::host_from_id(host_id)?;
    let mut devices = vec![];

    for dev in host.output_devices()? {
        if let (Ok(id), Ok(desc)) = (dev.id(), dev.description()) {
            devices.push(AudioDeviceInfo {
                id: id.to_string(),
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

// Helper to dry up the code and fetch the device repeatedly during restarts
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

    let supported_configs_range = device
        .supported_output_configs()
        .map_err(|e| anyhow!("error querying configs: {e}"))?;

    let supported_config = supported_configs_range
        .filter(|c| c.channels() == 2)
        .find(|c| {
            c.min_sample_rate() <= target_sample_rate && c.max_sample_rate() >= target_sample_rate
        })
        .map(|c| c.with_sample_rate(target_sample_rate))
        .or_else(|| {
            // Fallback: If requested rate fails, force fallback to default native
            log::warn!("Requested sample rate unsupported by device, falling back");
            device
                .supported_output_configs()
                .ok()?
                .find(|c| c.channels() == 2)
                .map(|c| {
                    let clamped =
                        native_sample_rate.clamp(c.min_sample_rate(), c.max_sample_rate());
                    c.with_sample_rate(clamped)
                })
        })
        .context("device does not support stereo (2 channels) output")?;

    let buffer_size = match supported_config.buffer_size() {
        cpal::SupportedBufferSize::Range { min, max } => {
            let desired = config_pref.buffer_size.unwrap_or(1024);
            cpal::BufferSize::Fixed(desired.clamp(*min, *max))
        }
        cpal::SupportedBufferSize::Unknown => cpal::BufferSize::Default,
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
    
    // Create an Arc clone for the background thread to safely observe
    let active_config_arc = Arc::clone(&ctx.active_audio_config);
    
    // Resolve initial device and config to create the engine exactly once
    let (device, config, sample_format) = get_device_and_config(&config_pref)?;

    let sample_rate = config.sample_rate;
    let channels = config.channels as usize;
    let engine_block_size = config_pref.buffer_size.unwrap_or(1024) as usize;

    log::info!(
        "Initial Stream Config: {:?} Hz, {} Channels",
        sample_rate,
        channels
    );
    log::info!("Initial Sample format: {:?}", sample_format);

    ctx.app_state.audio_config.sample_rate = sample_rate;
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

    // create the arc swap pointer
    let mixer_ptr = Arc::new(ArcSwap::from_pointee(MixerTelemetrySnapshot::default()));
    let param_ptr = Arc::new(ArcSwap::from_pointee(ActivePluginTelemetrySnapshots::default()));

    let engine_telemetry = AudioEngineTelemetry {
        mixer_telemetry: mixer_ptr.clone(),
        param_telemetry: param_ptr.clone(),
        mixer_snapshot_active: false,
        active_telemetry_subscriptions: HashMap::new(),
    };
    
    let engine = AudioEngine::new(
        command_consumer,
        pos_producer,
        feedback_producer,
        sample_rate,
        channels as u16,
        initial_bpm,
        engine_block_size,
        engine_telemetry
    );

    let telemetry_registry = TelemetryRegistry {
        mixer_telemetry: mixer_ptr,
        param_telemetry: param_ptr,
    };

    ctx.update_telemetry_reg(telemetry_registry);

    // Create the engine wrapped in Arc<Mutex> so it outlives dropped streams
    let engine_arc = Arc::new(Mutex::new(engine));

    // Create a channel to signal stream restarts from the error callback to the monitor loop
    let (restart_tx, restart_rx) = std::sync::mpsc::channel::<()>();

    let monitor_engine = Arc::clone(&engine_arc);

    // 2. Spawn the Device Monitor Thread
    std::thread::spawn(move || {
        loop {
            log::info!("Monitor: Attempting to build and start audio stream...");

            let current_config_pref = active_config_arc.read().clone();

            let (device, config, sample_format) = match get_device_and_config(&current_config_pref)
            {
                Ok(res) => res,
                Err(e) => {
                    log::error!(
                        "Monitor: Failed to resolve audio device: {}. Retrying in 2s...",
                        e
                    );
                    std::thread::sleep(std::time::Duration::from_secs(2));
                    continue;
                }
            };

            let sample_rate = config.sample_rate;
            let channels = config.channels as usize;
            let engine_block_size = current_config_pref.buffer_size.unwrap_or(1024) as usize;

            let playing_device_id = device.id().ok();
            let current_host = resolve_host(current_config_pref.host_name.as_deref());

            // Notify engine of the active sample rate and buffer size
            // (vital if the newly connected device has a different sample rate to prevent pitch-shifting!)
            {
                let mut eng = monitor_engine.lock();
                eng.process_command(AudioCommand::UpdateAudioConfig {
                    sample_rate: Some(sample_rate),
                    buffer_size: Some(engine_block_size),
                });
            }

            let ring_buffer_capacity = 8192;
            let (producer, consumer) = RingBuffer::<f32>::new(ring_buffer_capacity);
            let staging_buffer = vec![0.0; engine_block_size * channels];

            let audio_ctx = AudioContext {
                engine: Arc::clone(&monitor_engine),
                producer,
                staging_buffer,
            };

            let tx_clone = restart_tx.clone();

            // Callback triggered by CPAL if the stream dies natively (e.g. unplugging a USB interface)
            let err_fn = move |err| {
                log::error!("Audio stream error: {}. Triggering restart...", err);
                let _ = tx_clone.send(());
            };

            let stream_result = match sample_format {
                cpal::SampleFormat::F32 => {
                    run_stream!(device, config, audio_ctx, consumer, f32, |s| s, err_fn)
                }
                cpal::SampleFormat::I32 => run_stream!(
                    device,
                    config,
                    audio_ctx,
                    consumer,
                    i32,
                    |s: f32| (s * (i32::MAX as f32)).clamp(i32::MIN as f32, i32::MAX as f32) as i32,
                    err_fn
                ),
                cpal::SampleFormat::I16 => run_stream!(
                    device,
                    config,
                    audio_ctx,
                    consumer,
                    i16,
                    |s: f32| (s * (i16::MAX as f32)).clamp(i16::MIN as f32, i16::MAX as f32) as i16,
                    err_fn
                ),
                cpal::SampleFormat::U16 => run_stream!(
                    device,
                    config,
                    audio_ctx,
                    consumer,
                    u16,
                    |s: f32| ((s + 1.0) * 0.5 * (u16::MAX as f32)).clamp(0.0, u16::MAX as f32)
                        as u16,
                    err_fn
                ),
                cpal::SampleFormat::U8 => run_stream!(
                    device,
                    config,
                    audio_ctx,
                    consumer,
                    u8,
                    |s: f32| ((s + 1.0) * 0.5 * 255.0).clamp(0.0, 255.0) as u8,
                    err_fn
                ),
                _ => Err(cpal::BuildStreamError::StreamConfigNotSupported),
            };

            let stream = match stream_result {
                Ok(s) => s,
                Err(e) => {
                    log::error!("Monitor: Failed to build stream: {}. Retrying in 2s...", e);
                    std::thread::sleep(std::time::Duration::from_secs(2));
                    continue;
                }
            };

            if let Err(e) = stream.play() {
                log::error!("Monitor: Failed to play stream: {}. Retrying in 2s...", e);
                std::thread::sleep(std::time::Duration::from_secs(2));
                continue;
            }

            log::info!("Monitor: Audio stream is successfully running.");

            // ---------------------------------------------------------
            // Active Polling Loop (~10 FPS)
            // ---------------------------------------------------------
            loop {
                // Did the stream natively die? (e.g. unplugged)
                if restart_rx.try_recv().is_ok() {
                    log::info!("Monitor: Restart signal received from CPAL callback.");
                    break;
                }
                let latest_config = active_config_arc.read().clone();

                // Did the user change settings in the UI?
                if latest_config != current_config_pref
                {
                    log::info!("Monitor: Audio configuration changed by user. Restarting stream...");
                    break;
                }

                // Check if device is actually changed
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
                                    break;
                                }
                            }
                        }
                    }
                }

                // Sleep for ~100ms
                std::thread::sleep(std::time::Duration::from_millis(100));
            }

            // Drop the active stream. This safely releases the hardware handle.
            drop(stream);

            // Give OS drivers a short moment to map routing before we query devices again
            std::thread::sleep(std::time::Duration::from_millis(500));
        }
    });

    log::info!("Successfully initialized Audio backend and Monitor thread");
    Ok(())
}
