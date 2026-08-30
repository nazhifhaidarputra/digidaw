pub struct DeviceRateBridge {
    input_rate: u32,
    output_rate: u32,
    channels: usize,
    source_position: f64,
    previous_frame: Vec<f32>,
    has_previous_frame: bool,
    output: Vec<f32>,
    output_len: usize,
}

impl DeviceRateBridge {
    pub fn new(
        input_rate: u32,
        output_rate: u32,
        channels: usize,
        maximum_input_frames: usize,
    ) -> anyhow::Result<Self> {
        anyhow::ensure!(input_rate > 0, "DSP sample rate must be positive");
        anyhow::ensure!(output_rate > 0, "Device sample rate must be positive");
        anyhow::ensure!(channels > 0, "Channel count must be positive");
        anyhow::ensure!(maximum_input_frames > 0, "DSP block size must be positive");
        let maximum_output_frames = ((maximum_input_frames + 1) as f64 * f64::from(output_rate)
            / f64::from(input_rate))
        .ceil() as usize
            + 2;
        Ok(Self {
            input_rate,
            output_rate,
            channels,
            source_position: 0.0,
            previous_frame: vec![0.0; channels],
            has_previous_frame: false,
            output: vec![0.0; maximum_output_frames * channels],
            output_len: 0,
        })
    }

    pub fn maximum_output_samples(&self) -> usize {
        self.output.len()
    }

    pub fn process<'a>(&'a mut self, input: &[f32]) -> &'a [f32] {
        let input_frames = input.len() / self.channels;
        if input_frames == 0 || !input.len().is_multiple_of(self.channels) {
            self.output_len = 0;
            return &self.output[..0];
        }

        if !self.has_previous_frame {
            self.previous_frame.copy_from_slice(&input[..self.channels]);
            self.source_position = 1.0;
            self.has_previous_frame = true;
        }

        let step = f64::from(self.input_rate) / f64::from(self.output_rate);
        let mut output_frames = 0;
        while self.source_position < input_frames as f64 {
            let base = self.source_position.floor() as usize;
            let fraction = (self.source_position - base as f64) as f32;
            let output_offset = output_frames * self.channels;
            if output_offset + self.channels > self.output.len() {
                break;
            }
            for channel in 0..self.channels {
                let current = if base == 0 {
                    self.previous_frame[channel]
                } else {
                    input[(base - 1) * self.channels + channel]
                };
                let next = input[base * self.channels + channel];
                self.output[output_offset + channel] = current + (next - current) * fraction;
            }
            output_frames += 1;
            self.source_position += step;
        }

        self.source_position -= input_frames as f64;
        let last_frame_offset = (input_frames - 1) * self.channels;
        self.previous_frame
            .copy_from_slice(&input[last_frame_offset..last_frame_offset + self.channels]);
        self.output_len = output_frames * self.channels;
        &self.output[..self.output_len]
    }
}

#[cfg(test)]
mod tests {
    use super::DeviceRateBridge;

    #[test]
    fn equal_rates_preserve_continuity_across_blocks() {
        let mut bridge = DeviceRateBridge::new(48_000, 48_000, 1, 4).unwrap();
        let first = bridge.process(&[0.0, 1.0, 2.0, 3.0]).to_vec();
        let second = bridge.process(&[4.0, 5.0, 6.0, 7.0]).to_vec();
        assert_eq!(first, vec![0.0, 1.0, 2.0]);
        assert_eq!(second, vec![3.0, 4.0, 5.0, 6.0]);
    }

    #[test]
    fn mismatched_rates_have_stable_long_run_frame_count() {
        let mut bridge = DeviceRateBridge::new(44_100, 48_000, 2, 441).unwrap();
        let input = vec![0.25; 441 * 2];
        let mut output_frames = 0;
        for _ in 0..100 {
            output_frames += bridge.process(&input).len() / 2;
        }
        assert!((output_frames as isize - 48_000).abs() <= 2);
    }

    #[test]
    fn output_storage_capacity_does_not_change_during_processing() {
        let mut bridge = DeviceRateBridge::new(44_100, 96_000, 2, 64).unwrap();
        let capacity = bridge.maximum_output_samples();
        let input = vec![0.0; 64 * 2];
        for _ in 0..10_000 {
            let output = bridge.process(&input);
            assert!(output.len() <= capacity);
        }
        assert_eq!(bridge.maximum_output_samples(), capacity);
    }
}
