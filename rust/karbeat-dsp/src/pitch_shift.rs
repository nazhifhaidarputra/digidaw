//! Pitch Shifting via the Rubber Band Library
//!
//! This module wraps [`RubberBandLiveShifter`] — the real-time, low-latency
//! pitch-only API from the Rubber Band Library — using raw FFI bindings to the
//! published C interface (`rubberband-c.h`).
//!
//! ## Why `RubberBandLiveShifter`?
//!
//! Unlike the general `RubberBandStretcher`, the live shifter:
//! - Accepts and returns a **fixed block size** on every call (no
//!   process/available/retrieve dance).
//! - Is **real-time safe**: no heap allocation, locking, or blocking in the
//!   hot path.
//! - Has lower latency (~50 ms) than a typical stretcher setup.
//!
//! ## Linking
//!
//! `build.rs` emits `cargo:rustc-link-lib=rubberband` so that the linker finds
//! the system-installed `librubberband.so`.

#![allow(
    clippy::as_conversions,
    reason = "the Rubber Band C ABI requires explicit numeric and pointer representation conversions"
)]

use std::ptr::NonNull;

use karbeat_macros::{EnumParam, karbeat_plugin};
use serde::{Deserialize, Serialize};

// ============================================================================
// Public API
// ============================================================================

#[derive(Clone, Debug, Copy, PartialEq, Default, EnumParam, Deserialize, Serialize)]
#[repr(usize)]
pub enum PitchShiftAlgorithm {
    #[default]
    WSOLA = 0,
}

// Keep the old constant names so the plugin doesn't need other changes.
/// The block size reported by `RubberBandLiveShifter::getBlockSize()`.
/// This is the fixed number of frames expected by every `shift()` call.
/// The actual value is queried from the library at construction time; this
/// constant is used only for the plugin's latency/tail report.
pub const GRAIN_SIZE: usize = 512;

// ============================================================================
// Raw FFI — rubberband-c.h (C linkage)
// ============================================================================

#[allow(
    non_camel_case_types,
    non_snake_case,
    non_upper_case_globals,
    dead_code,
    reason = "bindgen preserves the names and complete surface of the upstream C API"
)]
pub mod ffi {
    // This instantly brings in every function, struct, and all the C documentation!
    // Hover over any ffi:: function below in your IDE to see the C++ docs.
    include!(concat!(env!("OUT_DIR"), "/rubberband_bindings.rs"));
}

// ============================================================================
// Safe wrapper
// ============================================================================

/// Safe, `Send`-able wrapper around a `RubberBandLiveShifter` instance.
///
/// The library guarantees that a single instance is thread-safe as long as
/// `shift()` is not called concurrently with `set_pitch_scale()`.
/// Because our audio processing model is single-threaded per plugin, this
/// is trivially satisfied.
struct RbLiveShifter {
    state: NonNull<ffi::RubberBandLiveState_>,
    block_size: usize,
    channels: usize,
}

impl std::fmt::Debug for RbLiveShifter {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("RbLiveShifter")
            .field("block_size", &self.block_size)
            .field("channels", &self.channels)
            .finish()
    }
}

// SAFETY: `RubberBandLiveState` is an opaque heap-allocated C++ object.
// The library documents it as safe to use from a single thread at a time,
// and we uphold that contract.  `AudioPlugin` requires `Send + Sync`, so we
// implement both.  Access is always from the same audio thread in practice.
unsafe impl Send for RbLiveShifter {}
// SAFETY: The host serializes all access to each plugin instance on its audio thread.
unsafe impl Sync for RbLiveShifter {}

impl RbLiveShifter {
    fn new(sample_rate: u32, channels: usize, preserve_formants: bool) -> Option<Self> {
        let mut options = ffi::RubberBandLiveOption_RubberBandLiveOptionWindowShort;
        if preserve_formants {
            options |= ffi::RubberBandLiveOption_RubberBandLiveOptionFormantPreserved;
        }

        let options = options.try_into().ok()?;
        // SAFETY: Arguments satisfy the C API contract and ownership of the returned state is
        // transferred to this wrapper.
        let state_raw =
            unsafe { ffi::rubberband_live_new(sample_rate as _, channels as _, options) };

        let state = NonNull::new(state_raw)?;
        // SAFETY: `state` is a live Rubber Band instance owned by this wrapper.
        let block_size = unsafe { ffi::rubberband_live_get_block_size(state.as_ptr()) } as usize;

        Some(Self {
            state,
            block_size,
            channels,
        })
    }

    #[inline]
    fn block_size(&self) -> usize {
        self.block_size
    }

    #[inline]
    fn start_delay(&self) -> usize {
        // SAFETY: `self.state` remains valid until `Drop` and access is serialized by the host.
        unsafe { ffi::rubberband_live_get_start_delay(self.state.as_ptr()) as usize }
    }

    #[inline]
    fn set_pitch_scale(&self, scale: f64) {
        // SAFETY: `self.state` remains valid until `Drop` and access is serialized by the host.
        unsafe { ffi::rubberband_live_set_pitch_scale(self.state.as_ptr(), scale) }
    }

    fn set_preserve_formants(&self, preserve: bool) {
        let options = if preserve {
            ffi::RubberBandLiveOption_RubberBandLiveOptionFormantPreserved
        } else {
            ffi::RubberBandLiveOption_RubberBandLiveOptionFormantShifted
        };
        // SAFETY: The state is valid and access is serialized with shift().
        unsafe { ffi::rubberband_live_set_formant_option(self.state.as_ptr(), options as _) }
    }

    /// Process one fixed-size block using separate input and output buffers.
    fn shift(&self, input: &[Vec<f32>], output: &mut [Vec<f32>]) {
        assert_eq!(input.len(), self.channels);
        assert_eq!(output.len(), self.channels);
        let mut in_ptrs = [std::ptr::null(); 8];
        let mut out_ptrs = [std::ptr::null_mut(); 8];
        for ch in 0..self.channels {
            assert!(input[ch].len() >= self.block_size);
            assert!(output[ch].len() >= self.block_size);
            in_ptrs[ch] = input[ch].as_ptr();
            out_ptrs[ch] = output[ch].as_mut_ptr();
        }
        // SAFETY: Each initialized channel points to a full block. Rust's borrows
        // keep input and output disjoint, and Rubber Band does not retain pointers.
        unsafe {
            ffi::rubberband_live_shift(self.state.as_ptr(), in_ptrs.as_ptr(), out_ptrs.as_ptr());
        }
    }

    fn reset(&self) {
        // SAFETY: `self.state` remains valid until `Drop` and access is serialized by the host.
        unsafe { ffi::rubberband_live_reset(self.state.as_ptr()) }
    }
}

impl Drop for RbLiveShifter {
    fn drop(&mut self) {
        // SAFETY: This wrapper owns the state and `drop` runs exactly once.
        unsafe { ffi::rubberband_live_delete(self.state.as_ptr()) }
    }
}

// ============================================================================
// WsolaEngine — public name kept for API compatibility with the plugin
// ============================================================================

/// Pitch-shifting engine backed by `RubberBandLiveShifter`.
///
/// The struct is named `WsolaEngine` for backwards compatibility with the
/// plugin's `#[nested]` parameter path (`pitch_shift_engine/pitch_ratio`).
#[derive(Debug)]
#[karbeat_plugin]
pub struct PitchShiftEngine {
    #[param(
        id = "pitch_ratio",
        name = "Pitch Ratio",
        group = "Pitcher",
        min = 0.5,
        max = 2.0,
        default = 1.0,
        step = 0.001
    )]
    pub pitch_ratio: f32,

    #[param(
        id = "preserve_formants",
        name = "Preserve Formants",
        group = "Pitcher",
        default = false
    )]
    pub preserve_formants: bool,

    /// The underlying Rubber Band instance, allocated during prepare().
    #[allow(
        clippy::box_collection,
        reason = "the box keeps the FFI resource address stable while the option changes state"
    )]
    shifter: Option<Box<RbLiveShifter>>,

    /// Sample rate captured at `prepare()`.
    sample_rate: u32,

    /// Active channel count.
    channels: usize,

    /// Internal staging buffers for channels whose block size doesn't align
    /// with the audio engine's buffer size.
    input_staging: Vec<Vec<f32>>,
    output_staging: Vec<Vec<f32>>,

    /// How many valid samples are sitting in `input_staging`.
    staging_fill: usize,

    last_pitch_ratio: f64,
    last_preserve_formants: bool,
}

impl Clone for PitchShiftEngine {
    fn clone(&self) -> Self {
        // RbLiveShifter is not Clone (it's an FFI resource); create a fresh
        // engine instead of duplicating the C++ object.
        let mut e = Self::base_default();
        e.pitch_ratio = self.pitch_ratio.clone();
        e.sample_rate = self.sample_rate;
        e.preserve_formants = self.preserve_formants.clone();
        e.channels = self.channels;
        e
    }
}

impl Default for PitchShiftEngine {
    fn default() -> Self {
        let mut def = Self::base_default();
        def.shifter = None;
        def.sample_rate = 44100;
        def.channels = 2;
        def.input_staging = Vec::new();
        def.output_staging = Vec::new();
        def.staging_fill = 0;
        def.last_pitch_ratio = -1.0;
        def.last_preserve_formants = false;
        def
    }
}

impl PitchShiftEngine {
    // ================================================
    // Public interface
    // ================================================

    /// Called by the plugin when the sample rate or channel count is known.
    pub fn prepare(&mut self, sample_rate: f32, channels: usize) {
        let sr = sample_rate as u32;
        let channels = channels.clamp(1, 8);

        let pf = self.preserve_formants.get();

        // Rebuild the shifter if config changed.
        let needs_rebuild = self
            .shifter
            .as_ref()
            .is_none_or(|s| s.channels != channels || self.sample_rate != sr);

        if needs_rebuild {
            self.sample_rate = sr;
            self.channels = channels;
            self.last_preserve_formants = pf;
            self.shifter = RbLiveShifter::new(sr, channels, pf).map(Box::new);
            self.last_pitch_ratio = -1.0;

            let block = self.shifter_block_size();
            self.input_staging = vec![vec![0.0_f32; block]; channels];

            self.output_staging = vec![vec![0.0; block]; channels];
            self.staging_fill = 0;
        }
        self.update_parameters();
    }

    fn update_parameters(&mut self) {
        if let Some(shifter) = &self.shifter {
            let ratio = f64::from(self.pitch_ratio.get());
            if ratio != self.last_pitch_ratio {
                shifter.set_pitch_scale(ratio);
                self.last_pitch_ratio = ratio;
            }
            let preserve = self.preserve_formants.get();
            if preserve != self.last_preserve_formants {
                shifter.set_preserve_formants(preserve);
                self.last_preserve_formants = preserve;
            }
        }
    }

    /// Process audio in place with one fixed block of staging delay.
    /// The engine must be prepared for the supplied channel count first.
    pub fn process_block(&mut self, channels_data: &mut [&mut [f32]]) {
        if channels_data.is_empty() || self.shifter.is_none() {
            return;
        }
        let num_frames = channels_data[0].len();
        if channels_data.len() != self.channels
            || channels_data.iter().any(|ch| ch.len() != num_frames)
        {
            return;
        }
        self.update_parameters();
        let block = self.shifter_block_size();
        let mut pos = 0;
        while pos < num_frames {
            let count = (block - self.staging_fill).min(num_frames - pos);
            let end = self.staging_fill + count;
            for (ch, data) in channels_data.iter_mut().enumerate() {
                // Capture input before replacing it with the previous block's output.
                self.input_staging[ch][self.staging_fill..end]
                    .copy_from_slice(&data[pos..pos + count]);
                data[pos..pos + count]
                    .copy_from_slice(&self.output_staging[ch][self.staging_fill..end]);
            }
            self.staging_fill = end;
            pos += count;
            if self.staging_fill == block {
                if let Some(shifter) = &self.shifter {
                    shifter.shift(&self.input_staging, &mut self.output_staging);
                }
                self.staging_fill = 0;
            }
        }
    }

    /// Returns the live shifter delay plus one block of staging latency.
    pub fn latency_samples(&self) -> u32 {
        self.shifter
            .as_ref()
            .map(|s| (s.start_delay() + s.block_size()) as u32)
            .unwrap_or(GRAIN_SIZE as u32)
    }

    /// Reset all internal state.
    pub fn reset(&mut self) {
        if let Some(s) = &self.shifter {
            s.reset();
        }
        for buf in &mut self.input_staging {
            buf.fill(0.0);
        }
        for buf in &mut self.output_staging {
            buf.fill(0.0);
        }
        self.staging_fill = 0;
    }

    // ------------------------------------------------------------------
    // Private helpers
    // ------------------------------------------------------------------

    fn shifter_block_size(&self) -> usize {
        self.shifter
            .as_ref()
            .map(|s| s.block_size())
            .unwrap_or(GRAIN_SIZE)
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "test setup requires a live Rubber Band instance"
)]
mod tests {
    use super::*;

    fn render(input: &[f32], sizes: &[usize], ratio: f32) -> Vec<f32> {
        let mut engine = PitchShiftEngine::default();
        engine.pitch_ratio.set_base(ratio);
        engine.prepare(48000.0, 1);
        assert!(engine.shifter.is_some());
        let mut output = input.to_vec();
        let mut pos = 0;
        for size in sizes.iter().cycle() {
            if pos == output.len() {
                break;
            }
            let end = (pos + size).min(output.len());
            engine.process_block(&mut [&mut output[pos..end]]);
            pos = end;
        }
        output
    }

    #[test]
    fn output_is_independent_of_callback_size() {
        let input: Vec<f32> = (0..24000)
            .map(|i| (i as f32 * 0.057).sin() * 0.25)
            .collect();
        for ratio in [0.75, 1.0, 1.005, 1.5] {
            let expected = render(&input, &[512], ratio);
            for sizes in [&[128][..], &[700][..], &[1, 63, 511, 1024, 37][..]] {
                let actual = render(&input, sizes, ratio);
                let error = actual
                    .iter()
                    .zip(&expected)
                    .map(|(a, b)| (a - b).abs())
                    .fold(0.0_f32, f32::max);
                assert!(
                    error < 1e-6,
                    "ratio {ratio}, sizes {sizes:?}: error {error}"
                );
            }
        }
    }

    #[test]
    fn staged_stereo_matches_direct_shifter_through_silence() {
        let mut engine = PitchShiftEngine::default();
        engine.pitch_ratio.set_base(0.75);
        engine.prepare(48000.0, 2);
        let direct = RbLiveShifter::new(48000, 2, false).unwrap();
        direct.set_pitch_scale(0.75);
        let block = direct.block_size();
        assert_eq!(
            engine.latency_samples() as usize,
            direct.start_delay() + block
        );
        let frames = block * 48;
        let input: Vec<Vec<f32>> = (0..2)
            .map(|ch| {
                (0..frames)
                    .map(|i| {
                        if (block * 8..block * 32).contains(&i) {
                            0.0
                        } else {
                            (i as f32 * (0.057 + ch as f32 * 0.021)).sin() * 0.25
                        }
                    })
                    .collect()
            })
            .collect();
        let mut expected = vec![vec![0.0; frames]; 2];
        let mut source = vec![vec![0.0; block]; 2];
        let mut shifted = vec![vec![0.0; block]; 2];
        for pos in (0..frames - block).step_by(block) {
            for ch in 0..2 {
                source[ch].copy_from_slice(&input[ch][pos..pos + block]);
            }
            direct.shift(&source, &mut shifted);
            for ch in 0..2 {
                expected[ch][pos + block..pos + 2 * block].copy_from_slice(&shifted[ch]);
            }
        }
        let mut actual = input.clone();
        let (left, right) = actual.split_at_mut(1);
        for (l, r) in left[0].chunks_mut(137).zip(right[0].chunks_mut(137)) {
            engine.process_block(&mut [l, r]);
        }
        for ch in 0..2 {
            for (a, b) in actual[ch].iter().zip(&expected[ch]) {
                assert!((a - b).abs() < 1e-6);
            }
        }
        engine.reset();
        let mut silent = vec![0.0; frames];
        let mut silent_right = silent.clone();
        engine.process_block(&mut [&mut silent, &mut silent_right]);
        assert!(silent.iter().chain(&silent_right).all(|s| s.abs() < 1e-6));
    }

    #[test]
    fn unity_impulse_matches_reported_latency() {
        let mut engine = PitchShiftEngine::default();
        engine.prepare(48000.0, 1);
        let latency = engine.latency_samples() as usize;
        let mut audio = vec![0.0; latency + 4096];
        audio[0] = 1.0;
        for chunk in audio.chunks_mut(137) {
            engine.process_block(&mut [chunk]);
        }
        let peak = audio
            .iter()
            .enumerate()
            .max_by(|(_, a), (_, b)| a.abs().total_cmp(&b.abs()))
            .map(|(index, _)| index)
            .unwrap();
        assert_eq!(peak, latency);
        assert!(audio[peak] > 0.5);
    }

    #[test]
    fn parameter_changes_keep_prepared_buffers_and_apply_fine_pitch() {
        let mut engine = PitchShiftEngine::default();
        engine.prepare(48000.0, 1);
        let state = engine.shifter.as_ref().unwrap().state;
        let input = engine.input_staging[0].as_ptr();
        let output = engine.output_staging[0].as_ptr();
        engine.pitch_ratio.set_base(1.005);
        engine.preserve_formants.set_base(true);
        engine.process_block(&mut [&mut [0.25; 128]]);
        assert_eq!(engine.shifter.as_ref().unwrap().state, state);
        assert_eq!(engine.input_staging[0].as_ptr(), input);
        assert_eq!(engine.output_staging[0].as_ptr(), output);
        assert_eq!(engine.last_pitch_ratio, f64::from(engine.pitch_ratio.get()));
        assert!(engine.last_preserve_formants);
        assert_eq!(engine.staging_fill, 128);
    }
}
