use crate::{
    audio::event::TransportFeedback,
    shared::{GeneratorId, PatternId, constants::f64::PPQ},
};

#[derive(Debug, Clone, Copy, PartialEq)]
/// Selects which timeline advances during an engine render block.
pub enum PlaybackMode {
    /// Render the arranged song timeline.
    Song,
    /// Render one pattern through a specific generator, independently of song playback.
    Pattern {
        /// Pattern whose notes are scheduled.
        pattern_id: PatternId,
        /// Generator receiving the pattern's MIDI events.
        generator_id: GeneratorId,
    },
}

#[derive(Debug, Clone)]
/// Mutable audio-thread transport state for arranged song playback.
pub struct SongPlaybackState {
    /// Whether the song playhead advances.
    pub is_playing: bool,
    /// Whether playback wraps at the project loop boundary.
    pub is_looping: bool,
    /// Whether recording is active.
    pub is_recording: bool,
    /// Current song playhead in samples.
    pub playhead_samples: u32,
    /// Cached one-based beat index.
    pub current_beat: usize,
    /// Cached one-based bar index.
    pub current_bar: usize,
    /// Sample position at which transport feedback was last emitted.
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
/// Mutable audio-thread transport state for independent pattern audition.
pub struct PatternPlaybackState {
    /// Whether the pattern playhead advances.
    pub is_playing: bool,
    /// Current pattern playhead in samples.
    pub playhead_samples: u32,
    /// Cached one-based beat index.
    pub current_beat: usize,
    /// Cached one-based bar index.
    pub current_bar: usize,
    /// Sample position at which pattern feedback was last emitted.
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

#[derive(Clone)]
pub(super) struct TransportState {
    pub bpm: f32,
    pub time_sig_numerator: u8,
    pub time_sig_denominator: u8,
    pub song: SongPlaybackState,
    pub pattern: PatternPlaybackState,
    pub mode: PlaybackMode,
}

impl TransportState {
    pub fn new(bpm: f32) -> Self {
        Self {
            bpm,
            time_sig_numerator: 4,
            time_sig_denominator: 4,
            song: SongPlaybackState::default(),
            pattern: PatternPlaybackState::default(),
            mode: PlaybackMode::Song,
        }
    }

    pub fn is_playing(&self) -> bool {
        match self.mode {
            PlaybackMode::Song => self.song.is_playing,
            PlaybackMode::Pattern { .. } => self.pattern.is_playing,
        }
    }

    pub fn reset_song(&mut self) {
        self.song.playhead_samples = 0;
        self.song.current_beat = 1;
        self.song.current_bar = 1;
        self.song.last_emitted_samples = 0;
    }

    pub fn reset_pattern(&mut self) {
        self.pattern.playhead_samples = 0;
        self.pattern.current_beat = 1;
        self.pattern.current_bar = 1;
        self.pattern.last_emitted_samples = 0;
    }

    pub fn recalculate_song_position(&mut self, sample_rate: u32) {
        let Some(samples_per_beat) = self.samples_per_beat(sample_rate) else {
            return;
        };
        self.song.current_beat = self.song.playhead_samples as usize / samples_per_beat + 1;
        self.song.current_bar = (self.song.current_beat - 1) / 4 + 1;
    }

    pub fn recalculate_pattern_position(&mut self, sample_rate: u32) {
        let Some(samples_per_beat) = self.samples_per_beat(sample_rate) else {
            return;
        };
        self.pattern.current_beat = self.pattern.playhead_samples as usize / samples_per_beat + 1;
        self.pattern.current_bar = (self.pattern.current_beat - 1) / 4 + 1;
    }

    pub fn position_feedback(
        &self,
        sample_rate: u32,
        is_playing: Option<bool>,
    ) -> TransportFeedback {
        let is_playing = is_playing.unwrap_or_else(|| self.is_playing());
        let is_pattern_mode = matches!(self.mode, PlaybackMode::Pattern { .. });

        TransportFeedback {
            samples: self.song.playhead_samples,
            ticks: self.samples_to_ticks(self.song.playhead_samples, sample_rate),
            beat: self.song.current_beat,
            bar: self.song.current_bar,
            tempo: self.bpm,
            sample_rate,
            is_playing,
            is_looping: self.song.is_looping,
            is_recording: self.song.is_recording,
            is_pattern_playing: self.pattern.is_playing,
            is_pattern_mode,
            pattern_samples: self.pattern.playhead_samples,
            pattern_ticks: self.samples_to_ticks(self.pattern.playhead_samples, sample_rate),
            pattern_beat: self.pattern.current_beat,
            pattern_bar: self.pattern.current_bar,
        }
    }

    fn samples_per_beat(&self, sample_rate: u32) -> Option<usize> {
        if self.bpm <= 0.0 {
            return None;
        }
        let samples_per_beat = ((60.0 / self.bpm) * sample_rate as f32) as usize;
        (samples_per_beat > 0).then_some(samples_per_beat)
    }

    fn samples_to_ticks(&self, samples: u32, sample_rate: u32) -> u32 {
        if self.bpm <= 0.0 || sample_rate == 0 {
            return 0;
        }
        (samples as f64 * (self.bpm as f64 / 60.0) * (PPQ / sample_rate as f64)) as u32
    }
}

#[cfg(test)]
mod tests {
    use super::TransportState;

    #[test]
    fn recalculates_song_and_pattern_positions() {
        let mut transport = TransportState::new(120.0);
        transport.song.playhead_samples = 48_000;
        transport.pattern.playhead_samples = 96_000;

        transport.recalculate_song_position(48_000);
        transport.recalculate_pattern_position(48_000);

        assert_eq!(
            (transport.song.current_beat, transport.song.current_bar),
            (3, 1)
        );
        assert_eq!(
            (
                transport.pattern.current_beat,
                transport.pattern.current_bar
            ),
            (5, 2)
        );
    }
}
