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

use std::ptr::NonNull;
use std::mem::MaybeUninit;

use karbeat_macros::{karbeat_plugin, EnumParam};
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

#[allow(non_camel_case_types, non_snake_case, non_upper_case_globals, dead_code)]
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
unsafe impl Sync for RbLiveShifter {}

impl RbLiveShifter {
    fn new(sample_rate: u32, channels: usize, preserve_formants: bool) -> Option<Self> {
        // OPTIMIZATION 1: Disabled CHANNELS_APART to process stereo as a unified coherent phase
        // let mut options = ffi::OPTION_WINDOW_SHORT
        let mut options = ffi::RubberBandLiveOption_RubberBandLiveOptionWindowShort;
        
        // OPTIMIZATION 2: Only enable formant preservation if explicitly requested
        if preserve_formants {
            // options |= ffi::OPTION_FORMANT_SHIFTED;
            options = ffi::RubberBandOption_RubberBandOptionFormantShifted;
        }

        let state_raw =
            unsafe { ffi::rubberband_live_new(sample_rate as _, channels as _, options) };

        let state = NonNull::new(state_raw)?;
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
        unsafe { ffi::rubberband_live_get_start_delay(self.state.as_ptr()) as usize }
    }

    #[inline]
    fn set_pitch_scale(&self, scale: f64) {
        unsafe { ffi::rubberband_live_set_pitch_scale(self.state.as_ptr(), scale) }
    }

    /// Process exactly `block_size` frames in-place.
    ///
    /// `channels_data` must contain exactly `self.channels` slices, each at
    /// least `self.block_size` samples long.
    fn shift(&self, channels_data: &mut [&mut [f32]]) {
        debug_assert_eq!(channels_data.len(), self.channels);

        // Build the pointer arrays that rubberband_live_shift expects.
        // Using stack storage for up to 8 channels.
        // OPTIMIZATION: Avoid zeroing stack arrays before initializing pointers
        let mut in_ptrs: [MaybeUninit<*const f32>; 8] = unsafe { MaybeUninit::uninit().assume_init() };
        let mut out_ptrs: [MaybeUninit<*mut f32>; 8] = unsafe { MaybeUninit::uninit().assume_init() };

        for (ch, slice) in channels_data.iter_mut().enumerate().take(8) {
            in_ptrs[ch] = MaybeUninit::new(slice.as_ptr());
            out_ptrs[ch] = MaybeUninit::new(slice.as_mut_ptr());
        }

        unsafe {
            ffi::rubberband_live_shift(
                self.state.as_ptr(),
                in_ptrs.as_ptr() as *const *const f32,
                out_ptrs.as_ptr() as *const *mut f32,
            );
        }
    }

    fn reset(&self) {
        unsafe { ffi::rubberband_live_reset(self.state.as_ptr()) }
    }
}

impl Drop for RbLiveShifter {
    fn drop(&mut self) {
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

    /// The underlying rubberband live-shifter instance, created lazily on the
    /// first `process_block()` call so we know the sample rate and channel count.
    #[allow(clippy::box_collection)]
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

    /// How many unread samples are sitting in `output_staging`.
    output_pending: usize,
    output_read_pos: usize,

    last_pitch_ratio: f64,
    last_preserve_formants: bool,
    
    // Tracks consecutive silent frames to trigger smart sleep
    silence_counter: usize,
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
        def.output_pending = 0;
        def.output_read_pos = 0;
        def.last_pitch_ratio = -1.0;
        def.last_preserve_formants = false;
        def.silence_counter = 0;
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
        let channels = channels.max(1).min(8);

        let pf = self.preserve_formants.get();

        // Rebuild the shifter if config changed.
        let needs_rebuild = self
            .shifter
            .as_ref()
            .map_or(true, |s| s.channels != channels || self.sample_rate != sr || self.last_preserve_formants != pf);

        if needs_rebuild {
            self.sample_rate = sr;
            self.channels = channels;
            self.last_preserve_formants = pf;
            self.shifter = RbLiveShifter::new(sr, channels, pf).map(Box::new);

            let block = self.shifter_block_size();
            self.input_staging = vec![vec![0.0_f32; block]; channels];
           
            // reserve some uninitialized space
            let target_cap = block * 4;
            self.output_staging = (0..channels)
                .map(|_| {
                    let mut uninit_buf: Vec<MaybeUninit<f32>> = Vec::with_capacity(target_cap);
                    unsafe {
                        uninit_buf.set_len(target_cap);
                        // Safe cast since MaybeUninit<f32> and f32 have identical layout
                        std::mem::transmute::<Vec<MaybeUninit<f32>>, Vec<f32>>(uninit_buf)
                    }
                })
                .collect();
            self.staging_fill = 0;
            self.output_pending = 0;
            self.output_read_pos = 0;
            self.silence_counter = 0;
        }
    }

    /// Process a block of audio in place.
    ///
    /// The rubberband live-shifter requires fixed-size blocks, but the audio
    /// engine may deliver variable buffer sizes.  We handle this with a simple
    /// staging queue: incoming samples are accumulated until we have a full
    /// shifter block, then processed, and the results are queued for reading.
    pub fn process_block(&mut self, channels_data: &mut [&mut [f32]]) {
        let channels = channels_data.len();
        if channels == 0 {
            return;
        }
        let num_frames = channels_data[0].len();
        if num_frames == 0 {
            return;
        }

        // Lazy init
        let pf = self.preserve_formants.get();
        if self.shifter.is_none() || self.channels != channels || self.last_preserve_formants != pf {
            self.prepare(self.sample_rate as f32, channels);
        }

        // =============================================================
        // OPTIMIZATION 3: SMART SLEEP (Bypass processing on silence)
        // =============================================================
        let mut is_silent = true;
        for ch in channels_data.iter() {
            for &s in ch.iter() {
                if s.abs() > 1e-5 {
                    is_silent = false;
                    break;
                }
            }
            if !is_silent { break; }
        }

        if is_silent {
            self.silence_counter += num_frames;
        } else {
            self.silence_counter = 0;
        }
        // Update pitch scale from parameter every block (real-time safe).
        let ratio = self.pitch_ratio.get() as f64;
        let is_unity = (ratio - 1.0).abs() < 1e-2;

        let tail_length = self.shifter_block_size() * 3;
        
        if (is_silent && self.silence_counter > tail_length) 
            || (is_unity && self.staging_fill == 0 && self.output_pending == 0) 
        {
            if is_silent {
                for ch in channels_data.iter_mut() {
                    ch.fill(0.0);
                }
            }
            self.last_pitch_ratio = ratio;
            return;
        }

        // Only trigger the heavy internal C++ recalculation if the value meaningfully changed
        if (ratio - self.last_pitch_ratio).abs() > 1e-2 {
            if let Some(s) = &self.shifter {
                if (s.state.as_ptr() as usize) != 0 {
                    s.set_pitch_scale(ratio);
                }
            }
            self.last_pitch_ratio = ratio;
        }
        let block = self.shifter_block_size();

        let mut in_pos = 0usize;
        let mut out_pos = 0usize;

        while in_pos < num_frames || out_pos < num_frames {
            // Drain any pending output first
            while out_pos < num_frames && self.output_pending > 0 {
                for ch in 0..channels {
                    let src = self.output_staging[ch][self.output_read_pos];
                    channels_data[ch][out_pos] = src;
                }
                self.output_read_pos = (self.output_read_pos + 1) % self.output_staging[0].len();
                self.output_pending -= 1;
                out_pos += 1;
            }

            if in_pos >= num_frames {
                break;
            }

            // Fill the staging buffer
            let space = block - self.staging_fill;
            let avail = (num_frames - in_pos).min(space);

            for ch in 0..channels {
                let dst = &mut self.input_staging[ch];
                dst[self.staging_fill..self.staging_fill + avail]
                    .copy_from_slice(&channels_data[ch][in_pos..in_pos + avail]);
            }
            self.staging_fill += avail;
            in_pos += avail;

            // run the shifter when the staging buffer is full
            if self.staging_fill == block {
                // Build &mut [&mut [f32]] from the staging buffers and shift.
                // The ptrs borrow ends before we access input_staging below.
                {
                    let mut ptrs: smallvec::SmallVec<[&mut [f32]; 8]> = self
                        .input_staging
                        .iter_mut()
                        .map(|v| v.as_mut_slice())
                        .collect();

                    if let Some(shifter) = &self.shifter {
                        shifter.shift(&mut ptrs);
                    }
                }

                // Append processed block to output ring.
                let out_len = self.output_staging[0].len();
                let write_pos = (self.output_read_pos + self.output_pending) % out_len;

                // Calculate how many samples we can write before hitting the end of the ring buffer
                let space_until_wrap = out_len - write_pos;
                let first_chunk = block.min(space_until_wrap);
                let second_chunk = block - first_chunk;

                for ch in 0..channels {
                    // Write up to the boundary
                    self.output_staging[ch][write_pos..write_pos + first_chunk]
                        .copy_from_slice(&self.input_staging[ch][..first_chunk]);

                    // Wrap remainder
                    if second_chunk > 0 {
                        self.output_staging[ch][..second_chunk]
                            .copy_from_slice(&self.input_staging[ch][first_chunk..]);
                    }
                }

                self.output_pending += block;
                self.staging_fill = 0;
            }
        }
    }

    /// Returns the latency in samples introduced by the live shifter.
    pub fn latency_samples(&self) -> u32 {
        self.shifter
            .as_ref()
            .map(|s| s.start_delay() as u32)
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
        self.output_pending = 0;
        self.output_read_pos = 0;
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
