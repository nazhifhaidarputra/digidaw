use karbeat_plugin_api::types::AudioBuffers;

/// Prepared dry-path delay, advanced during active processing to preserve suspension timing.
pub struct BypassDelay {
    channels: Vec<Vec<f32>>,
    cursor: usize,
    latency: usize,
}

impl BypassDelay {
    /// Allocates a per-channel dry delay line for the processor's reported latency.
    ///
    /// # Errors
    ///
    /// Rejects more than two channels, latency above 1,048,576 frames, or allocation failure.
    pub fn new(channels: usize, latency: usize) -> Result<Self, crate::HostError> {
        if channels > 2 || latency > 1_048_576 {
            return Err(crate::HostError::InvalidConfiguration);
        }
        let mut delay = Vec::with_capacity(channels);
        for _ in 0..channels {
            let mut channel = Vec::new();
            channel
                .try_reserve_exact(latency)
                .map_err(|_| crate::HostError::InvalidConfiguration)?;
            channel.resize(latency, 0.0);
            delay.push(channel);
        }
        Ok(Self {
            channels: delay,
            cursor: 0,
            latency,
        })
    }

    /// Returns the fixed delay length in frames.
    pub fn latency(&self) -> usize {
        self.latency
    }

    /// Always record dry input; write outputs only when bypass or suspension is active.
    pub fn process(&mut self, buffers: &mut AudioBuffers, render: bool) {
        let frames = buffers
            .main_outputs
            .iter()
            .flat_map(|bus| bus.channel_data.iter())
            .map(|channel| channel.len())
            .max()
            .unwrap_or(0);
        for frame in 0..frames {
            let mut input = buffers
                .main_inputs
                .iter()
                .flat_map(|bus| bus.channel_data.iter());
            for (index, output) in buffers
                .main_outputs
                .iter_mut()
                .flat_map(|bus| bus.channel_data.iter_mut())
                .enumerate()
            {
                let dry = input
                    .next()
                    .and_then(|channel| channel.get(frame))
                    .copied()
                    .unwrap_or(0.0);
                let sample = if self.latency == 0 {
                    dry
                } else if let Some(delay) = self.channels.get_mut(index) {
                    let previous = delay[self.cursor];
                    delay[self.cursor] = dry;
                    previous
                } else {
                    0.0
                };
                if render {
                    if let Some(output) = output.get_mut(frame) {
                        *output = sample;
                    }
                }
            }
            if self.latency > 0 {
                self.cursor += 1;
                if self.cursor == self.latency {
                    self.cursor = 0;
                }
            }
        }
        if render {
            for bus in buffers.aux_outputs.iter_mut() {
                for channel in bus.channel_data.iter_mut() {
                    channel.fill(0.0);
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use karbeat_plugin_api::types::AudioBusBuffer;

    #[test]
    #[allow(clippy::unwrap_used, reason = "test buffer configuration is valid")]
    fn suspension_uses_dry_history_from_active_blocks_and_silences_missing_inputs() {
        let mut delay = BypassDelay::new(2, 3).unwrap();
        let mut input = [1.0, 2.0];
        let mut left = [9.0; 2];
        let mut right = [9.0; 2];
        let mut inputs = [&mut input[..]];
        let mut outputs = [&mut left[..], &mut right[..]];
        let mut inputs = [AudioBusBuffer {
            channel_data: &mut inputs,
            is_silent: false,
        }];
        let mut outputs = [AudioBusBuffer {
            channel_data: &mut outputs,
            is_silent: false,
        }];
        delay.process(
            &mut AudioBuffers {
                main_inputs: &mut inputs,
                main_outputs: &mut outputs,
                aux_inputs: &mut [],
                aux_outputs: &mut [],
            },
            false,
        );
        assert_eq!(left, [9.0; 2]);
        let mut input = [3.0, 4.0, 5.0, 6.0];
        let mut left = [9.0; 4];
        let mut right = [9.0; 4];
        let mut inputs = [&mut input[..]];
        let mut outputs = [&mut left[..], &mut right[..]];
        let mut inputs = [AudioBusBuffer {
            channel_data: &mut inputs,
            is_silent: false,
        }];
        let mut outputs = [AudioBusBuffer {
            channel_data: &mut outputs,
            is_silent: false,
        }];
        delay.process(
            &mut AudioBuffers {
                main_inputs: &mut inputs,
                main_outputs: &mut outputs,
                aux_inputs: &mut [],
                aux_outputs: &mut [],
            },
            true,
        );
        assert_eq!(left, [0.0, 1.0, 2.0, 3.0]);
        assert_eq!(right, [0.0; 4]);
    }
}
