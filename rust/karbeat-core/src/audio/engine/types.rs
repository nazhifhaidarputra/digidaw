use std::sync::atomic::{AtomicU32, Ordering};

use hashbrown::{HashMap, HashSet};
use karbeat_plugin_api::types::{MidiEvent, ZeroCopyBuffer};
use karbeat_plugin_types::Param;
use karbeat_utils::hash::hash_str;
use rodio::math::db_to_linear;
use smallvec::SmallVec;
use triple_buffer::Input;

use crate::{
    audio::{engine::helper::load_internal_wav, event::PluginTarget},
    commands::{MixerChannelSnapshot, MixerChannelTarget},
    core::project::{AudioWaveform, MixerChannel, MixerChannelParams},
    shared::*,
    DOWNBEAT_BYTES, OFFBEAT_BYTES,
};

/// A snapshot of a single plugin's current state (Params + Custom Buffers)
#[derive(Clone, Default)]
pub struct PluginTelemetrySnapshot {
    pub parameters: Vec<(u32, f32)>,
    pub buffers: HashMap<String, ZeroCopyBuffer>,
}

/// A unified snapshot of the entire mixer state.
/// This is extremely cheap to clone and push, so we can do the whole mixer at once.
#[derive(Clone, Default)]
pub struct MixerTelemetrySnapshot {
    pub tracks: HashMap<TrackId, MixerChannelSnapshot>,
    pub buses: HashMap<BusId, MixerChannelSnapshot>,
    pub master: Option<MixerChannelSnapshot>,
}

/// Audio-thread-owned telemetry state.
/// The engine writes into triple-buffer `Input` producers; the UI thread reads
/// from the matching `Output` consumers held in `TelemetryRegistry`.
pub struct AudioEngineTelemetry {
    /// Triple-buffer producer for the full mixer snapshot (all tracks + buses + master).
    pub mixer_telemetry_producer: Input<MixerTelemetrySnapshot>,

    /// Per-plugin triple-buffer producers — keyed by `PluginTarget`.
    /// A new entry is inserted when a plugin is added, and removed when it is removed.
    pub param_telemetry_producers: HashMap<PluginTarget, Input<PluginTelemetrySnapshot>>,

    /// Flag to check whether the UI really needs this data (e.g opening mixer screen)
    pub mixer_snapshot_active: bool,

    /// Track the subscription
    pub active_telemetry_subscriptions: HashMap<PluginTarget, HashSet<String>>,
}

impl AudioEngineTelemetry {
    /// Create a new telemetry instance.
    /// Returns the matching `Output` consumers that should be placed in `TelemetryRegistry`.
    pub fn new() -> (Self, triple_buffer::Output<MixerTelemetrySnapshot>) {
        let (mixer_input, mixer_output) =
            triple_buffer::triple_buffer(&MixerTelemetrySnapshot::default());

        let this = Self {
            mixer_telemetry_producer: mixer_input,
            param_telemetry_producers: HashMap::new(),
            mixer_snapshot_active: false,
            active_telemetry_subscriptions: HashMap::new(),
        };

        (this, mixer_output)
    }

    /// Create a fresh, detached instance for use in the export engine.
    /// The export engine never needs to push telemetry to the UI, so these
    /// producers are simply discarded after export.
    pub fn new_for_export() -> Self {
        let (mixer_input, _) = triple_buffer::triple_buffer(&MixerTelemetrySnapshot::default());

        Self {
            mixer_telemetry_producer: mixer_input,
            param_telemetry_producers: HashMap::new(),
            mixer_snapshot_active: false,
            active_telemetry_subscriptions: HashMap::new(),
        }
    }
}

// A global or engine-bound atomic to share with the monitor thread
pub static DSP_LOAD_PERCENT: AtomicU32 = AtomicU32::new(0);

pub fn get_current_dsp_load() -> f32 {
    f32::from_bits(DSP_LOAD_PERCENT.load(Ordering::Relaxed))
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PlaybackMode {
    Song,
    Pattern {
        pattern_id: PatternId,
        generator_id: GeneratorId,
    },
}

#[derive(Debug, Clone)]
pub struct SongPlaybackState {
    pub is_playing: bool,
    pub is_looping: bool,
    pub is_recording: bool,
    pub playhead_samples: u32,
    pub current_beat: usize,
    pub current_bar: usize,
    pub last_emitted_samples: u32,
}

impl Default for SongPlaybackState {
    fn default() -> Self {
        Self {
            is_playing: false,
            is_looping: false,
            is_recording: false,
            playhead_samples: 0,
            current_beat: 1,
            current_bar: 1,
            last_emitted_samples: 0,
        }
    }
}

#[derive(Debug, Clone)]
pub struct PatternPlaybackState {
    pub is_playing: bool,
    pub playhead_samples: u32,
    pub current_beat: usize,
    pub current_bar: usize,
    pub last_emitted_samples: u32,
}

impl Default for PatternPlaybackState {
    fn default() -> Self {
        Self {
            is_playing: false,
            playhead_samples: 0,
            current_beat: 1,
            current_bar: 1,
            last_emitted_samples: 0,
        }
    }
}

/// Simple delay ring buffer for Plugin Delay Compensation (PDC)
#[derive(Clone, Default)]
pub struct DelayLine {
    buffer: Vec<f32>,
    write_pos: usize,
    delay_samples: usize,
}

impl DelayLine {
    pub fn set_delay(&mut self, delay_samples: usize, channels: usize) {
        let required_len = delay_samples * channels;
        if self.delay_samples != delay_samples || self.buffer.len() != required_len {
            self.delay_samples = delay_samples;
            self.buffer.resize(required_len, 0.0);
            self.buffer.fill(0.0);
            self.write_pos = 0;
        }
    }

    #[inline(always)]
    pub fn process_block(&mut self, buffer: &mut [f32], channels: usize) {
        if self.delay_samples == 0 {
            return;
        }

        let buf_len = self.buffer.len();
        for i in (0..buffer.len()).step_by(channels) {
            for c in 0..channels {
                let delay_idx = self.write_pos + c;
                let out = self.buffer[delay_idx];
                self.buffer[delay_idx] = buffer[i + c];
                buffer[i + c] = out;
            }
            self.write_pos = (self.write_pos + channels) % buf_len;
        }
    }
}

#[derive(Clone)]
pub struct LiveLfo {
    pub rate_hz: f32,
    pub phase: f32, // Ticks from 0.0 to 1.0
}

#[derive(Clone)]
pub enum LiveModulationSource {
    LFO(LiveLfo),
    Automation { lane_id: AutomationId },
    PeakController { source: PluginTarget }, // E.g., holds an envelope follower
}

/// Lightweight voice reference - the actual plugin lives in AudioPluginState
pub struct GeneratorVoice {
    pub id: GeneratorId,
    pub track_id: TrackId,
    // Events queued for the CURRENT buffer block only
    pub midi_events: SmallVec<[MidiEvent; 4]>,
    // pub automation_events: SmallVec<[GeneratorAutomationEvent; 4]>,
    // Track if this generator is persistent or temporary
    pub active: bool,
    pub playing_keys: Vec<u8>,
    //////////////////////////////////////////////////
    /// Tail Handling
    //////////////////////////////////////////////////
    pub tail_remaining: Option<u32>,
}

impl GeneratorVoice {
    pub fn new(id: GeneratorId, track_id: TrackId, active: bool) -> Self {
        Self {
            id,
            track_id,
            midi_events: SmallVec::new(),
            // automation_events: SmallVec::new(),
            active,
            playing_keys: Vec::new(),
            tail_remaining: None,
        }
    }
}

pub struct AudioVoice {
    pub track_id: TrackId,
    pub waveform: AudioWaveform,
    /// Where in the output buffer do we start writing? (0 to buffer_len)
    pub output_offset_samples: usize,
    /// Where in the source WAV file do we start reading?
    pub source_read_index: f64,
    /// The specific start point in the source (from clip.trim_start)
    pub start_boundary: f64,
    /// The specific end point in the source (from clip.trim_start)
    pub end_boundary: f64,
    pub clip_elapsed_samples: u32,
    pub clip_loop_length: u32,
}

pub struct PreviewVoice {
    pub waveform: AudioWaveform,
    pub current_frame: f64,
    pub is_finished: bool,
    pub volume: f32,
}

impl PreviewVoice {
    pub fn new(waveform: AudioWaveform, volume: f32) -> Self {
        Self {
            waveform,
            current_frame: 0.0,
            is_finished: false,
            volume,
        }
    }
}

pub struct MetronomeState {
    pub(super) is_active: bool,
    pub(super) downbeat_buffer: Vec<f32>,
    pub(super) offbeat_buffer: Vec<f32>,
    pub(super) play_index: usize,
    pub(super) is_playing: bool,
    pub(super) is_downbeat: bool,
}

impl Default for MetronomeState {
    fn default() -> Self {
        Self {
            is_active: false,
            downbeat_buffer: load_internal_wav(DOWNBEAT_BYTES),
            offbeat_buffer: load_internal_wav(OFFBEAT_BYTES),
            play_index: 0,
            is_playing: false,
            is_downbeat: true,
        }
    }
}

// =============================================================================
// Audio Thread Mixer Channel State
// =============================================================================

/// DSP parameter values for a single mixer channel, owned exclusively by the
/// audio thread. Volume is stored in dB (same units as MixerChannel).
#[derive(Clone, Debug)]
pub struct AudioMixerChannelValues {
    pub volume: Param<f32>,
    pub pan: Param<f32>,
    pub mute: bool,
    pub solo: bool,
    pub inverted_phase: bool,
}

impl Default for AudioMixerChannelValues {
    fn default() -> Self {
        Self {
            volume: Param::new_f32(
                hash_str("mix_chan_vol"),
                "Mixer Channel Volume",
                "",
                0.0,
                -100.0,
                6.0,
                0.1,
            ), // 0 dB = unity gain
            pan: Param::new_f32(
                hash_str("mix_chan_pan"),
                "Mixer Channel Pan",
                "",
                0.0,
                -1.0,
                1.0,
                0.01,
            ),
            mute: false,
            solo: false,
            inverted_phase: false,
        }
    }
}

impl AudioMixerChannelValues {
    pub fn new(volume: f32, pan: f32, mute: bool, solo: bool, inverted_phase: bool) -> Self {
        let initial_vol = if volume <= -100.0 { 0.0 } else { db_to_linear(volume) };
        Self {
            volume: Param::new_f32(
                hash_str("mix_chan_vol"),
                "Mixer Channel Volume",
                "",
                volume,
                -100.0,
                6.0,
                0.1,
            ), // 0 dB = unity gain
            pan: Param::new_f32(
                hash_str("mix_chan_pan"),
                "Mixer Channel Pan",
                "",
                pan,
                -1.0,
                1.0,
                0.01,
            ),
            mute,
            solo,
            inverted_phase
        }
    }
    /// Construct a temporary MixerChannel for use in existing DSP functions.
    /// The returned channel has no effects — only volume/pan/flags are set.
    pub fn to_mixer_channel(&self) -> MixerChannel {
        let mut ch = MixerChannel::default();
        ch.volume.set_base(self.volume.get());
        ch.pan.set_base(self.pan.get());
        ch.mute = self.mute;
        ch.solo = self.solo;
        ch.inverted_phase = self.inverted_phase;
        ch
    }
}

/// Audio-thread-owned collection of mixer channel DSP values.
/// Updated exclusively via AudioCommand::SetMixerChannelParameter.
#[derive(Clone, Debug, Default)]
pub struct AudioMixerState {
    pub track_channels: HashMap<TrackId, AudioMixerChannelValues>,
    pub bus_channels: HashMap<BusId, AudioMixerChannelValues>,
    pub master: AudioMixerChannelValues,
}

impl AudioMixerState {
    /// Apply a MixerChannelParams mutation to the target channel.
    pub fn apply(&mut self, target: &MixerChannelTarget, param: &MixerChannelParams) {
        let values = match target {
            MixerChannelTarget::Track(id) => self.track_channels.entry(*id).or_default(),
            MixerChannelTarget::Bus(id) => self.bus_channels.entry(*id).or_default(),
            MixerChannelTarget::Master => &mut self.master,
        };
        match param {
            MixerChannelParams::Volume(v) => {
                values.volume.set_base(*v);
            }
            MixerChannelParams::Pan(v) => {
                values.pan.set_base(*v);
            }
            MixerChannelParams::Mute(v) => {
                values.mute = *v;
            }
            MixerChannelParams::Solo(v) => {
                values.solo = *v;
            }
            MixerChannelParams::InvertedPhase(v) => {
                values.inverted_phase = *v;
            }
        }
    }

    /// Return a snapshot of the target channel's current values.
    pub fn snapshot(&self, target: MixerChannelTarget) -> MixerChannelSnapshot {
        let values = match &target {
            MixerChannelTarget::Track(id) => {
                self.track_channels.get(id).cloned().unwrap_or_default()
            }
            MixerChannelTarget::Bus(id) => self.bus_channels.get(id).cloned().unwrap_or_default(),
            MixerChannelTarget::Master => self.master.clone(),
        };
        MixerChannelSnapshot {
            target,
            volume: values.volume.get(),
            pan: values.pan.get(),
            mute: values.mute,
            solo: values.solo,
            inverted_phase: values.inverted_phase,
        }
    }
}