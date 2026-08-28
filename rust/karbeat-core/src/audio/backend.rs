use std::{
    str::FromStr,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::{Duration, Instant},
};

use anyhow::{Context, Result, anyhow};
use cpal::{
    DeviceId, OutputCallbackInfo,
    traits::{DeviceTrait, HostTrait, StreamTrait},
};
use parking_lot::Mutex;
use rtrb::{Consumer, RingBuffer};
use serde::{Deserialize, Serialize};

use crate::{
    audio::{
        engine::{AudioEngine, AudioEngineTelemetry},
        event::TransportFeedback,
    },
    commands::{AudioCommand, TelemetryRegistration},
    context::DawContext,
    message::TelemetryRegistry,
};

/// Macro to generate the stream building logic
/// $device: cpal device
/// $config: cpal config
/// $ctx: The AudioContext (moved into the closure)
/// $consumer: The RingBuffer consumer (moved into the closure)
/// $sample_type: The primitive type (f32, i16, etc)
/// $converter: A closure |f32_sample| -> $sample_type
/// Macro to generate the stream building logic
/// $device: cpal device
/// $config: cpal config
/// $consumer: The RingBuffer consumer (moved into the closure)
/// $sample_type: The primitive type (f32, i16, etc)
/// $converter: A closure |f32_sample| -> $sample_type
macro_rules! run_stream {
    (
        $device:expr,
        $config:expr,
        $consumer:expr,
        $sample_type:ty,
        $converter:expr,
        $err_fn:expr
    ) => {{
        let mut consumer = $consumer;
        // Internal buffer for reading from ringbuffer before conversion
        let mut read_buffer: Vec<f32> = Vec::new();

        $device.build_output_stream(
            &$config,
            move |data: &mut [$sample_type], _: &OutputCallbackInfo| {
                let samples_needed = data.len();

                if read_buffer.len() != samples_needed {
                    read_buffer.resize(samples_needed, 0.0);
                }

                // Simply pop from the Lock-Free RingBuffer.
                // If it's empty (underrun), output silence instead of blocking.
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

    // Resolve initial device and config to create the engine exactly once
    let (device, config, sample_format) = get_device_and_config(&config_pref)?;

    // Extract actual values granted by the OS instead of relying on preferences
    let sample_rate = config.sample_rate;
    let channels = config.channels as usize;
    let engine_block_size = match config.buffer_size {
        cpal::BufferSize::Fixed(size) => size as usize,
        cpal::BufferSize::Default => config_pref.buffer_size.unwrap_or(1024) as usize,
    };

    // Sync actual OS values back to the active configuration immediately
    {
        let mut active_cfg = active_config_arc.write();
        active_cfg.sample_rate = Some(sample_rate);
        active_cfg.buffer_size = Some(engine_block_size as u32);
        active_cfg.host_name = config_pref.host_name;
        active_cfg.device_id = config_pref.device_id;
    }

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

    let (engine_telemetry, mixer_consumer) = AudioEngineTelemetry::new();

    let (telemetry_reg_sender, telemetry_reg_receiver) =
        std::sync::mpsc::sync_channel::<TelemetryRegistration>(64);

    let engine = AudioEngine::new(
        command_consumer,
        pos_producer,
        feedback_producer,
        sample_rate,
        channels as u16,
        initial_bpm,
        engine_block_size,
        engine_telemetry,
        telemetry_reg_sender,
    );

    let telemetry_registry = TelemetryRegistry::new(mixer_consumer);

    ctx.update_telemetry_reg(telemetry_registry);
    ctx.telemetry_reg_receiver = Some(Mutex::new(telemetry_reg_receiver));

    let engine_arc = Arc::new(Mutex::new(engine));
    let monitor_engine = Arc::clone(&engine_arc);

    // Spawn the Device Monitor Thread
    std::thread::spawn(move || {
        enum RestartReason {
            StreamError,
            ConfigurationChanged,
            DefaultDeviceChanged,
        }

        let mut retry_delay = INITIAL_RETRY_DELAY;

        loop {
            log::info!("Monitor: Attempting to build and start audio stream...");

            let mut current_config_pref = active_config_arc.read().clone();

            let (device, config, sample_format) = match get_device_and_config(&current_config_pref)
            {
                Ok(res) => res,
                Err(e) => {
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

            let sample_rate = config.sample_rate;
            let channels = config.channels as usize;
            let engine_block_size = match config.buffer_size {
                cpal::BufferSize::Fixed(size) => size as usize,
                cpal::BufferSize::Default => {
                    current_config_pref.buffer_size.unwrap_or(1024) as usize
                }
            };

            let playing_device_id = device.id().ok();
            let current_host = resolve_host(current_config_pref.host_name.as_deref());

            // Sync actual OS values back to the active configuration immediately to prevent restart loops
            {
                let mut cfg = active_config_arc.write();
                cfg.sample_rate = Some(sample_rate);
                cfg.buffer_size = Some(engine_block_size as u32);
                current_config_pref = cfg.clone(); // Crucial: update local tracking to silence the polling loop
            }

            {
                let mut eng = monitor_engine.lock();
                eng.process_command(AudioCommand::UpdateAudioConfig {
                    sample_rate: Some(sample_rate),
                    buffer_size: Some(engine_block_size),
                });
            }

            // High capacity to decouple DSP Thread variation from CPAL callback speed
            let ring_buffer_capacity = 8192;
            let (mut producer, consumer) = RingBuffer::<f32>::new(ring_buffer_capacity);
            let mut staging_buffer = vec![0.0; engine_block_size * channels];

            // Setup Dedicated DSP Thread State
            let is_dsp_running = Arc::new(AtomicBool::new(true));
            let is_dsp_running_clone = Arc::clone(&is_dsp_running);
            let engine_dsp = Arc::clone(&monitor_engine);
            let block_samples = engine_block_size * channels;

            // Pre-fill ring buffer to create a latency cushion to withstand OS scheduling jitter
            let prefill_blocks = (ring_buffer_capacity / 2) / block_samples;
            for _ in 0..prefill_blocks {
                {
                    let mut eng = engine_dsp.lock();
                    eng.process(&mut staging_buffer);
                }
                for &sample in &staging_buffer {
                    let _ = producer.push(sample);
                }
            }

            // 3. Spawn the Dedicated DSP Thread
            let dsp_thread = std::thread::spawn(move || {
                // Pinning this thread priority to high/audio could be done here in the future
                while is_dsp_running_clone.load(Ordering::Relaxed) {
                    // Make sure there is enough space to write a full block safely
                    if producer.slots() >= block_samples {
                        {
                            let mut engine = engine_dsp.lock();
                            engine.process(&mut staging_buffer);
                        }
                        for &sample in &staging_buffer {
                            let _ = producer.push(sample); // Guaranteed to succeed based on slots check
                        }
                    } else {
                        // Sleep slightly to prevent a 100% CPU busy-wait loop
                        std::thread::sleep(std::time::Duration::from_millis(1));
                    }
                }
                log::info!("DSP Thread explicitly shut down gracefully.");
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
                cpal::SampleFormat::F32 => {
                    run_stream!(device, config, consumer, f32, |s| s, err_fn)
                }
                cpal::SampleFormat::I32 => run_stream!(
                    device,
                    config,
                    consumer,
                    i32,
                    |s: f32| (s * (i32::MAX as f32)).clamp(i32::MIN as f32, i32::MAX as f32) as i32,
                    err_fn
                ),
                cpal::SampleFormat::I16 => run_stream!(
                    device,
                    config,
                    consumer,
                    i16,
                    |s: f32| (s * (i16::MAX as f32)).clamp(i16::MIN as f32, i16::MAX as f32) as i16,
                    err_fn
                ),
                cpal::SampleFormat::U16 => run_stream!(
                    device,
                    config,
                    consumer,
                    u16,
                    |s: f32| ((s + 1.0) * 0.5 * (u16::MAX as f32)).clamp(0.0, u16::MAX as f32)
                        as u16,
                    err_fn
                ),
                cpal::SampleFormat::U8 => run_stream!(
                    device,
                    config,
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
                    log::error!(
                        "Monitor: Failed to build stream: {}. Retrying in {:?}...",
                        e,
                        retry_delay
                    );
                    // Abort the DSP thread to prevent memory leak/orphans since stream failed
                    is_dsp_running.store(false, Ordering::Relaxed);
                    let _ = dsp_thread.join();

                    std::thread::sleep(retry_delay);
                    retry_delay = next_retry_delay(retry_delay);
                    continue;
                }
            };

            if let Err(e) = stream.play() {
                log::error!(
                    "Monitor: Failed to play stream: {}. Retrying in {:?}...",
                    e,
                    retry_delay
                );
                // Abort the DSP thread cleanly
                is_dsp_running.store(false, Ordering::Relaxed);
                let _ = dsp_thread.join();

                std::thread::sleep(retry_delay);
                retry_delay = next_retry_delay(retry_delay);
                continue;
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

                if latest_config != current_config_pref {
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
            if let Err(e) = dsp_thread.join() {
                log::error!("Failed to join DSP thread cleanly: {:?}", e);
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

#[cfg(test)]
mod tests {
    use super::{INITIAL_RETRY_DELAY, MAX_RETRY_DELAY, automatic_host, next_retry_delay};

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
}
