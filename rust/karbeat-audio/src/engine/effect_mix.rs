//! Host dry/wet blend of one effect slot, for plugins without a mix control of their own.

use super::routing::DelayLine;
use karbeat_core::core::project::plugin::effect_mix_param;
use karbeat_plugin_types::Param;
use karbeat_utils::types::NormalizedF32;

/// Dry/wet blend of an effect slot.
///
/// The dry signal is held back by the plugin's latency so it lines up with the wet signal.
/// A change of mix, by hand or by automation, ramps across one block. At a full mix the slot
/// costs nothing extra.
#[derive(Clone)]
pub struct EffectMix {
    /// The mix the user set, with automation applied on top.
    amount: Param<f32>,
    /// Mix at the end of the last processed block.
    current: NormalizedF32,
    /// One delay line per channel, sized to the plugin latency off the render loop.
    dry_delay: Vec<DelayLine>,
    /// Whether the last block fed the dry delay lines. Lines that sat idle hold stale audio
    /// and are cleared before they are fed again.
    feeding: bool,
}

impl Default for EffectMix {
    fn default() -> Self {
        Self::new(NormalizedF32::new(NormalizedF32::MAX))
    }
}

impl EffectMix {
    /// A blend at `mix`.
    pub fn new(mix: NormalizedF32) -> Self {
        Self {
            amount: effect_mix_param(mix),
            current: mix,
            dry_delay: Vec::new(),
            feeding: false,
        }
    }

    /// The mix the user set, without automation.
    #[inline]
    pub fn value(&self) -> NormalizedF32 {
        NormalizedF32::new(self.amount.get_base())
    }

    /// Sets the user's mix; the next block ramps to it.
    #[inline]
    pub fn set(&mut self, mix: NormalizedF32) {
        self.amount.set_base(mix.get());
    }

    /// Plays an automation or modulation value, normalized to 0.0..=1.0.
    #[inline]
    pub fn apply_automation(&mut self, normalized: f32) {
        self.amount.apply_automation(normalized);
    }

    /// The mix the next block ramps to.
    #[inline]
    fn target(&self) -> NormalizedF32 {
        NormalizedF32::new(self.amount.get())
    }

    /// Whether the next block blends in any dry signal.
    #[inline]
    pub fn is_blending(&self) -> bool {
        self.target().get() < NormalizedF32::MAX || self.current.get() < NormalizedF32::MAX
    }

    /// Sizes the dry delay lines to `latency` frames. Allocates; runs on command and latency
    /// replanning paths, never inside the render loop.
    pub fn sync_delay(&mut self, latency: u32, channels: usize) {
        self.dry_delay.resize_with(channels, DelayLine::default);
        let delay = usize::try_from(latency).unwrap_or(usize::MAX);
        for line in &mut self.dry_delay {
            line.set_delay(delay, 1);
        }
    }

    /// Copies the slot input into `dry` when the slot blends. Returns whether it did.
    pub fn capture_dry(
        &mut self,
        input: &[Vec<f32>],
        dry: &mut [Vec<f32>],
        channels: usize,
        frames: usize,
    ) -> bool {
        if !self.is_blending() {
            self.feeding = false;
            return false;
        }
        if !self.feeding {
            self.dry_delay.iter_mut().for_each(DelayLine::clear);
            self.feeding = true;
        }
        for (source, destination) in input.iter().zip(dry.iter_mut()).take(channels) {
            destination[..frames].copy_from_slice(&source[..frames]);
        }
        true
    }

    /// Blends the delayed dry signal into `wet`, ramping from the last block's mix.
    pub fn blend(
        &mut self,
        wet: &mut [Vec<f32>],
        dry: &mut [Vec<f32>],
        channels: usize,
        frames: usize,
    ) {
        let start = self.current.get();
        let end = self.target().get();
        let step = if frames == 0 {
            0.0
        } else {
            (end - start) / frames as f32
        };
        for (channel, (wet, dry)) in wet
            .iter_mut()
            .zip(dry.iter_mut())
            .take(channels)
            .enumerate()
        {
            let dry = &mut dry[..frames];
            if let Some(line) = self.dry_delay.get_mut(channel) {
                line.process_block(dry, 1);
            }
            let mut mix = start;
            for (wet, dry) in wet[..frames].iter_mut().zip(dry.iter()) {
                mix += step;
                *wet = *dry + mix * (*wet - *dry);
            }
        }
        self.current = NormalizedF32::new(end);
    }
}

#[cfg(test)]
mod tests {
    use super::EffectMix;
    use karbeat_utils::types::NormalizedF32;

    fn mix(value: f32) -> EffectMix {
        EffectMix::new(NormalizedF32::new(value))
    }

    fn block(mix: &mut EffectMix, wet: f32, dry: f32, frames: usize) -> Vec<f32> {
        let input = vec![vec![dry; frames]];
        let mut dry_buffers = vec![vec![0.0; frames]];
        assert!(mix.capture_dry(&input, &mut dry_buffers, 1, frames));
        let mut wet_buffers = vec![vec![wet; frames]];
        mix.blend(&mut wet_buffers, &mut dry_buffers, 1, frames);
        wet_buffers.remove(0)
    }

    #[test]
    fn full_mix_skips_the_dry_path() {
        let mut mix = EffectMix::default();
        let mut dry = vec![vec![0.0; 4]];
        assert!(!mix.capture_dry(&[vec![1.0; 4]], &mut dry, 1, 4));
    }

    #[test]
    fn half_mix_averages_dry_and_wet() {
        let mut mix = mix(0.5);
        let out = block(&mut mix, 1.0, 0.0, 4);
        assert!(out.iter().all(|sample| (sample - 0.5).abs() < 1e-6));
    }

    #[test]
    fn mix_change_ramps_over_one_block() {
        let mut mix = mix(1.0);
        mix.set(NormalizedF32::new(0.0));
        let out = block(&mut mix, 1.0, 0.0, 4);
        assert_eq!(out, vec![0.75, 0.5, 0.25, 0.0]);
        // The next block holds the new mix.
        let out = block(&mut mix, 1.0, 0.0, 4);
        assert_eq!(out, vec![0.0; 4]);
        // Back at full wet, the ramp finishes and the slot stops blending.
        mix.set(NormalizedF32::new(1.0));
        let _ = block(&mut mix, 1.0, 0.0, 4);
        assert!(!mix.is_blending());
    }

    #[test]
    fn dry_signal_waits_for_the_plugin_latency() {
        let mut mix = mix(0.0);
        mix.sync_delay(2, 1);
        let input = vec![vec![1.0, 2.0, 3.0, 4.0]];
        let mut dry = vec![vec![0.0; 4]];
        assert!(mix.capture_dry(&input, &mut dry, 1, 4));
        let mut wet = vec![vec![0.0; 4]];
        mix.blend(&mut wet, &mut dry, 1, 4);
        assert_eq!(wet[0], vec![0.0, 0.0, 1.0, 2.0]);
    }

    #[test]
    fn automation_drives_the_mix_without_changing_the_user_value() {
        let mut mix = mix(1.0);
        mix.apply_automation(0.0);
        assert!(mix.is_blending());
        assert_eq!(mix.value().get(), 1.0);
        let out = block(&mut mix, 1.0, 0.0, 4);
        assert_eq!(out[3], 0.0);
    }
}
