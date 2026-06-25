use crate::shared::{GeneratorId, PatternId};


#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PlaybackMode {
    Song,
    Pattern {
        pattern_id: PatternId,
        generator_id: GeneratorId,
    },
}

pub mod helpers {
    /// Helper function to decode 16-bit PCM WAV bytes into a flat f32 array
    pub fn load_internal_wav(bytes: &[u8]) -> Vec<f32> {
        let cursor = std::io::Cursor::new(bytes);
        let Ok(reader) = hound::WavReader::new(cursor) else {
            return Vec::new();
        };

        // Convert 16-bit integer (-32768 to 32767) to f32 (-1.0 to 1.0)
        reader
            .into_samples::<i16>()
            .map(|s| (s.unwrap_or(0) as f32) / 32768.0)
            .collect()
    }
}

pub mod v1 {}

pub mod v2 {
    use std::sync::atomic::{AtomicU32, Ordering};

    use hashbrown::HashMap;
    use karbeat_plugin_api::types_new::MidiEvent;
    use smallvec::SmallVec;
    use super::PlaybackMode;

    use crate::{
        audio::{engine_types::helpers::load_internal_wav, event::PluginTarget},
        commands::{MixerChannelSnapshot, MixerChannelTarget},
        core::project::{
            AudioWaveform, MixerChannel, MixerChannelParams, RoutingConnection, RoutingNode,
        },
        shared::{AutomationId, BusId, GeneratorId, PatternId, TrackId},
    };

    // A global or engine-bound atomic to share with the monitor thread
    pub static DSP_LOAD_PERCENT: AtomicU32 = AtomicU32::new(0);

    pub fn get_current_dsp_load() -> f32 {
        f32::from_bits(DSP_LOAD_PERCENT.load(Ordering::Relaxed))
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
        is_active: bool,
        downbeat_buffer: Vec<f32>,
        offbeat_buffer: Vec<f32>,
        play_index: usize,
        is_playing: bool,
        is_downbeat: bool,
    }

    impl Default for MetronomeState {
        fn default() -> Self {
            let downbeat_bytes = include_bytes!("../../../../assets/audio/metronome_downbeat.wav");
            let offbeat_bytes = include_bytes!("../../../../assets/audio/metronome_offbeat.wav");

            Self {
                is_active: false,
                downbeat_buffer: load_internal_wav(downbeat_bytes),
                offbeat_buffer: load_internal_wav(offbeat_bytes),
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
        pub volume: f32,
        pub pan: f32,
        pub mute: bool,
        pub solo: bool,
        pub inverted_phase: bool,
    }

    impl Default for AudioMixerChannelValues {
        fn default() -> Self {
            Self {
                volume: 0.0, // 0 dB = unity gain
                pan: 0.0,
                mute: false,
                solo: false,
                inverted_phase: false,
            }
        }
    }

    impl AudioMixerChannelValues {
        /// Construct a temporary MixerChannel for use in existing DSP functions.
        /// The returned channel has no effects — only volume/pan/flags are set.
        pub fn to_mixer_channel(&self) -> MixerChannel {
            let mut ch = MixerChannel::default();
            ch.volume.set_base(self.volume);
            ch.pan.set_base(self.pan);
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
                    values.volume = *v;
                }
                MixerChannelParams::Pan(v) => {
                    values.pan = *v;
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
                MixerChannelTarget::Bus(id) => {
                    self.bus_channels.get(id).cloned().unwrap_or_default()
                }
                MixerChannelTarget::Master => self.master.clone(),
            };
            MixerChannelSnapshot {
                target,
                volume: values.volume,
                pan: values.pan,
                mute: values.mute,
                solo: values.solo,
                inverted_phase: values.inverted_phase,
            }
        }
    }

    // =============================================================================
    // Routing Order Helper
    // =============================================================================

    /// Compute a topologically sorted routing order (sources → buses → master)
    /// from plain routing data and known track/bus IDs.
    ///
    /// This replicates MixerState::get_routing_order without needing the full
    /// MixerState on the audio thread.
    pub fn compute_routing_order(
        track_ids: impl Iterator<Item = TrackId>,
        bus_ids: impl Iterator<Item = BusId>,
        routing: &[RoutingConnection],
    ) -> Vec<RoutingNode> {
        use std::collections::HashMap as StdMap;
        use std::collections::VecDeque;

        let bus_ids_vec: Vec<BusId> = bus_ids.collect();

        // All tracks come first
        let mut order: Vec<RoutingNode> = track_ids.map(RoutingNode::Track).collect();

        // Kahn's topological sort for buses
        let mut in_degree: StdMap<BusId, usize> = bus_ids_vec.iter().map(|&id| (id, 0)).collect();
        let mut adj: StdMap<BusId, Vec<BusId>> =
            bus_ids_vec.iter().map(|&id| (id, vec![])).collect();

        for conn in routing {
            if let (RoutingNode::Bus(src), RoutingNode::Bus(dst)) = (conn.source, conn.destination)
            {
                if let Some(neighbors) = adj.get_mut(&src) {
                    neighbors.push(dst);
                }
                if let Some(deg) = in_degree.get_mut(&dst) {
                    *deg += 1;
                }
            }
        }

        let mut queue: VecDeque<BusId> = in_degree
            .iter()
            .filter(|(_, &deg)| deg == 0)
            .map(|(&id, _)| id)
            .collect();

        while let Some(bus_id) = queue.pop_front() {
            order.push(RoutingNode::Bus(bus_id));
            if let Some(neighbors) = adj.get(&bus_id) {
                for &neighbor in neighbors {
                    if let Some(deg) = in_degree.get_mut(&neighbor) {
                        *deg -= 1;
                        if *deg == 0 {
                            queue.push_back(neighbor);
                        }
                    }
                }
            }
        }

        order.push(RoutingNode::Master);
        order
    }
}

pub mod prelude {
    pub use super::v2::*;
}
