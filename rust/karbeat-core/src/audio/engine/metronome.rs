use crate::{DOWNBEAT_BYTES, OFFBEAT_BYTES, audio::engine::helper::load_internal_wav};

/// A user-supplied click that replaces both built-in metronome sounds.
///
/// Offbeats play it as recorded and downbeats play it an octave higher.
#[derive(Debug, Clone, PartialEq)]
pub struct MetronomeClick {
    /// Mono samples.
    pub samples: Vec<f32>,
    /// Sample rate `samples` were decoded at.
    pub sample_rate: u32,
}

/// Playback rate of a custom click on downbeats: one octave up.
const DOWNBEAT_RATE: f64 = 2.0;

pub struct MetronomeState {
    is_active: bool,
    downbeat_buffer: Vec<f32>,
    offbeat_buffer: Vec<f32>,
    custom_click: Option<MetronomeClick>,
    play_index: usize,
    /// Read position in the custom click, in its own samples.
    custom_position: f64,
    is_playing: bool,
    is_downbeat: bool,
}

impl MetronomeState {
    pub(super) fn set_active(&mut self, active: bool) {
        self.is_active = active;
    }

    /// Replaces the custom click, or restores the built-in sounds with `None`. Returns the
    /// click it replaced so the caller can free it off the audio thread.
    pub(super) fn set_custom_click(
        &mut self,
        click: Option<MetronomeClick>,
    ) -> Option<MetronomeClick> {
        self.is_playing = false;
        std::mem::replace(&mut self.custom_click, click)
    }

    pub(super) fn render(
        &mut self,
        output: &mut [f32],
        channels: usize,
        start_playhead: u32,
        bpm: f32,
        sample_rate: u32,
    ) {
        if !self.is_active || channels == 0 {
            return;
        }

        let samples_per_beat = (60.0 / bpm) * sample_rate as f32;
        if samples_per_beat <= 0.0 {
            return;
        }

        for (frame_index, output_frame) in output.chunks_mut(channels).enumerate() {
            let current_sample = start_playhead + frame_index as u32;
            let is_trigger = if current_sample == 0 {
                true
            } else {
                let previous_beat = ((current_sample - 1) as f32 / samples_per_beat) as u32;
                let current_beat = (current_sample as f32 / samples_per_beat) as u32;
                current_beat > previous_beat
            };

            if is_trigger {
                // Restarting here cuts off whatever is left of the previous click.
                self.is_playing = true;
                self.play_index = 0;
                self.custom_position = 0.0;
                let current_beat = (current_sample as f32 / samples_per_beat) as u32;
                self.is_downbeat = current_beat.is_multiple_of(4);
            }

            if !self.is_playing {
                continue;
            }

            if let Some(click) = &self.custom_click {
                let index = self.custom_position as usize;
                let Some(&current) = click.samples.get(index) else {
                    self.is_playing = false;
                    continue;
                };
                let next = click.samples.get(index + 1).copied().unwrap_or(0.0);
                let fraction = (self.custom_position - index as f64) as f32;
                let sample = current + (next - current) * fraction;
                for output_sample in output_frame {
                    *output_sample += sample;
                }
                let pitch = if self.is_downbeat { DOWNBEAT_RATE } else { 1.0 };
                self.custom_position +=
                    f64::from(click.sample_rate) / f64::from(sample_rate) * pitch;
                continue;
            }

            let source = if self.is_downbeat {
                &self.downbeat_buffer
            } else {
                &self.offbeat_buffer
            };

            if let Some(sample) = source.get(self.play_index) {
                for output_sample in output_frame {
                    *output_sample += sample;
                }
                self.play_index += 1;
            } else {
                self.is_playing = false;
            }
        }
    }
}

impl Default for MetronomeState {
    fn default() -> Self {
        Self {
            is_active: false,
            downbeat_buffer: load_internal_wav(DOWNBEAT_BYTES),
            offbeat_buffer: load_internal_wav(OFFBEAT_BYTES),
            custom_click: None,
            play_index: 0,
            custom_position: 0.0,
            is_playing: false,
            is_downbeat: true,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{MetronomeClick, MetronomeState};

    fn metronome(custom_click: Option<MetronomeClick>) -> MetronomeState {
        MetronomeState {
            is_active: true,
            downbeat_buffer: vec![0.5],
            offbeat_buffer: vec![0.25],
            custom_click,
            play_index: 0,
            custom_position: 0.0,
            is_playing: false,
            is_downbeat: false,
        }
    }

    fn ramp(sample_rate: u32) -> MetronomeClick {
        MetronomeClick {
            samples: vec![1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
            sample_rate,
        }
    }

    #[test]
    fn renders_downbeat_into_each_channel() {
        let mut metronome = metronome(None);
        let mut output = [0.0; 4];

        metronome.render(&mut output, 2, 0, 120.0, 48_000);

        assert_eq!(output, [0.5, 0.5, 0.0, 0.0]);
    }

    #[test]
    fn custom_click_plays_an_octave_up_on_the_downbeat() {
        let mut metronome = metronome(Some(ramp(48_000)));
        let mut output = [0.0; 4];

        // Sample 0 starts bar one: every other sample is read, so it ends in half the time
        metronome.render(&mut output, 1, 0, 120.0, 48_000);

        assert_eq!(output, [1.0, 3.0, 5.0, 0.0]);
    }

    #[test]
    fn custom_click_plays_as_recorded_on_an_offbeat() {
        let mut metronome = metronome(Some(ramp(48_000)));
        let mut output = [0.0; 4];

        // One beat at 120 BPM and 48 kHz is 24000 samples: the second beat of the bar
        metronome.render(&mut output, 1, 24_000, 120.0, 48_000);

        assert_eq!(output, [1.0, 2.0, 3.0, 4.0]);
    }

    #[test]
    fn custom_click_keeps_its_pitch_at_another_engine_rate() {
        let mut metronome = metronome(Some(ramp(24_000)));
        let mut output = [0.0; 4];

        // The click was decoded at half the engine rate, so offbeats read half a sample a frame
        metronome.render(&mut output, 1, 24_000, 120.0, 48_000);

        assert_eq!(output, [1.0, 1.5, 2.0, 2.5]);
    }

    #[test]
    fn next_beat_cuts_off_the_tail_of_a_custom_click() {
        let mut metronome = metronome(Some(ramp(4)));
        let mut output = [0.0; 4];

        // At 4 Hz a beat is two samples long, shorter than the six-sample click
        metronome.render(&mut output, 1, 2, 120.0, 4);

        assert_eq!(output, [1.0, 2.0, 1.0, 2.0]);
    }

    #[test]
    fn replacing_the_custom_click_returns_the_previous_one() {
        let mut metronome = metronome(Some(ramp(48_000)));

        assert_eq!(metronome.set_custom_click(None), Some(ramp(48_000)));
        let mut output = [0.0; 2];
        metronome.render(&mut output, 1, 0, 120.0, 48_000);

        assert_eq!(output, [0.5, 0.0]);
    }
}
