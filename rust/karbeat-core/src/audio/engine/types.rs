use hashbrown::HashMap;
use karbeat_plugin_types::Param;
use karbeat_plugin_types::SmoothableParam;
use karbeat_utils::hash::hash_str;
use rodio::math::db_to_linear;

use crate::{
    commands::{MixerChannelSnapshot, MixerChannelTarget},
    core::project::{MixerChannel, MixerChannelParams},
    shared::*,
};

/// Linear amplitude corresponding to the mixer channel's +6 dB maximum gain.
pub const MAX_AMPLITUDE: f64 = 1.99526231497;

// =============================================================================
// Audio Thread Mixer Channel State
// =============================================================================

/// DSP parameter values for a single mixer channel, owned exclusively by the
/// audio thread. Volume is stored in dB (same units as MixerChannel).
#[derive(Clone, Debug)]
pub struct AudioMixerChannelValues {
    /// Smoothed channel gain in decibels.
    pub volume: Param<f32>,
    /// Smoothed stereo pan in the inclusive range -1.0 to 1.0.
    pub pan: Param<f32>,
    /// Smoothed post-fader peak magnitude, expressed as linear amplitude.
    pub magnitude: f32,
    /// Whether channel output is suppressed.
    pub mute: bool,
    /// Whether this channel participates in solo filtering.
    pub solo: bool,
    /// Whether output samples have their polarity inverted.
    pub inverted_phase: bool,
    smoothing_sample_rate: u32,
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
            magnitude: 0.0,
            mute: false,
            solo: false,
            inverted_phase: false,
            smoothing_sample_rate: 0,
        }
    }
}

impl AudioMixerChannelValues {
    /// Creates audio-thread channel values from serialized mixer parameters and flags.
    pub fn new(volume: f32, pan: f32, mute: bool, solo: bool, inverted_phase: bool) -> Self {
        let _initial_vol = if volume <= -100.0 {
            0.0
        } else {
            db_to_linear(volume)
        };
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
            magnitude: 0.0,
            mute,
            solo,
            inverted_phase,
            smoothing_sample_rate: 0,
        }
    }

    /// Configures 15 ms volume and pan smoothing when the engine sample rate changes.
    pub fn prepare_smoothing(&mut self, sample_rate: u32) {
        if self.smoothing_sample_rate == sample_rate {
            return;
        }
        self.volume.set_smoothing_time(0.015, f64::from(sample_rate));
        self.pan.set_smoothing_time(0.015, f64::from(sample_rate));
        self.smoothing_sample_rate = sample_rate;
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

    /// Capture the loudest finite sample in a processed block. The magnitude
    /// is decayed once per audio block by the engine, producing a fast peak
    /// response with a readable release rather than a flickering raw value.
    pub fn observe_magnitude(&mut self, buffer: &[f32]) {
        let block_peak = buffer.iter().fold(0.0_f32, |peak, sample| {
            if sample.is_finite() {
                peak.max(sample.abs())
            } else {
                peak
            }
        });
        self.magnitude = self.magnitude.max(block_peak);
    }

    /// Applies a clamped per-block release factor to the stored peak meter value.
    pub fn decay_magnitude(&mut self, release_factor: f32) {
        self.magnitude *= release_factor.clamp(0.0, 1.0);
        if self.magnitude < 1.0e-6 {
            self.magnitude = 0.0;
        }
    }
}

/// Audio-thread-owned collection of mixer channel DSP values.
/// Updated exclusively via AudioCommand::SetMixerChannelParameter.
#[derive(Clone, Debug, Default)]
pub struct AudioMixerState {
    /// Per-track channel values, created lazily when commands reference a track.
    pub track_channels: HashMap<TrackId, AudioMixerChannelValues>,
    /// Per-bus channel values, created lazily when commands reference a bus.
    pub bus_channels: HashMap<BusId, AudioMixerChannelValues>,
    /// Master output channel values.
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
            MixerChannelTarget::Track(id) => self.track_channels.get(id),
            MixerChannelTarget::Bus(id) => self.bus_channels.get(id),
            MixerChannelTarget::Master => Some(&self.master),
        };
        MixerChannelSnapshot {
            target,
            request_id: None,
            magnitude: values.map_or(0.0, |values| values.magnitude),
            volume: values.map_or(0.0, |values| values.volume.get()),
            pan: values.map_or(0.0, |values| values.pan.get()),
            mute: values.is_some_and(|values| values.mute),
            solo: values.is_some_and(|values| values.solo),
            inverted_phase: values.is_some_and(|values| values.inverted_phase),
        }
    }
}

#[cfg(test)]
mod mixer_meter_tests {
    use super::*;

    #[test]
    fn channel_magnitude_tracks_peak_and_ignores_invalid_samples() {
        let mut channel = AudioMixerChannelValues::default();

        channel.observe_magnitude(&[0.1, -0.75, f32::NAN, 0.5]);
        assert!((channel.magnitude - 0.75).abs() < f32::EPSILON);

        channel.observe_magnitude(&[0.2, -0.1]);
        assert!((channel.magnitude - 0.75).abs() < f32::EPSILON);
    }

    #[test]
    fn channel_magnitude_decays_and_is_included_in_snapshot() {
        let mut mixer = AudioMixerState::default();
        mixer.master.magnitude = 0.8;
        mixer.master.decay_magnitude(0.5);

        let snapshot = mixer.snapshot(MixerChannelTarget::Master);
        assert!((snapshot.magnitude - 0.4).abs() < f32::EPSILON);
    }
}
