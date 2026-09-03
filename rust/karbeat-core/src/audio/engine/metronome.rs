use crate::{DOWNBEAT_BYTES, OFFBEAT_BYTES, audio::engine::helper::load_internal_wav};

pub struct MetronomeState {
    is_active: bool,
    downbeat_buffer: Vec<f32>,
    offbeat_buffer: Vec<f32>,
    play_index: usize,
    is_playing: bool,
    is_downbeat: bool,
}

impl MetronomeState {
    pub(super) fn set_active(&mut self, active: bool) {
        self.is_active = active;
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
                self.is_playing = true;
                self.play_index = 0;
                let current_beat = (current_sample as f32 / samples_per_beat) as u32;
                self.is_downbeat = current_beat.is_multiple_of(4);
            }

            if !self.is_playing {
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
            play_index: 0,
            is_playing: false,
            is_downbeat: true,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::MetronomeState;

    #[test]
    fn renders_downbeat_into_each_channel() {
        let mut metronome = MetronomeState {
            is_active: true,
            downbeat_buffer: vec![0.5],
            offbeat_buffer: vec![0.25],
            play_index: 0,
            is_playing: false,
            is_downbeat: false,
        };
        let mut output = [0.0; 4];

        metronome.render(&mut output, 2, 0, 120.0, 48_000);

        assert_eq!(output, [0.5, 0.5, 0.0, 0.0]);
    }
}
