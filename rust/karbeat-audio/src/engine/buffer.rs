/// Mutable interleaved `f32` storage for one audio processing block.
///
/// Implementors may carry additional metadata, such as media timestamps, while
/// exposing only their decoded audio samples to the engine.
pub trait AudioBuffer {
    /// Returns the interleaved samples in this block.
    fn samples(&self) -> &[f32];

    /// Returns the interleaved samples in this block for in-place rendering.
    fn samples_mut(&mut self) -> &mut [f32];
}

impl AudioBuffer for [f32] {
    fn samples(&self) -> &[f32] {
        self
    }

    fn samples_mut(&mut self) -> &mut [f32] {
        self
    }
}

impl AudioBuffer for Vec<f32> {
    fn samples(&self) -> &[f32] {
        self.as_slice()
    }

    fn samples_mut(&mut self) -> &mut [f32] {
        self.as_mut_slice()
    }
}

impl<const N: usize> AudioBuffer for [f32; N] {
    fn samples(&self) -> &[f32] {
        self.as_slice()
    }

    fn samples_mut(&mut self) -> &mut [f32] {
        self.as_mut_slice()
    }
}

#[cfg(test)]
mod tests {
    use super::AudioBuffer;

    struct MediaAudioBlock {
        timestamp_micros: u64,
        samples: Vec<f32>,
    }

    impl AudioBuffer for MediaAudioBlock {
        fn samples(&self) -> &[f32] {
            &self.samples
        }

        fn samples_mut(&mut self) -> &mut [f32] {
            &mut self.samples
        }
    }

    #[test]
    fn custom_media_block_exposes_audio_without_losing_metadata() {
        let mut block = MediaAudioBlock {
            timestamp_micros: 42,
            samples: vec![1.0, -1.0],
        };

        block.samples_mut().fill(0.0);

        assert_eq!(block.samples(), [0.0, 0.0]);
        assert_eq!(block.timestamp_micros, 42);
    }
}
