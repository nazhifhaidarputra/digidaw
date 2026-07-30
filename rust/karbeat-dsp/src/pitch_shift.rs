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

#[allow(non_camel_case_types, dead_code)]
mod ffi {
    use std::os::raw::{c_double, c_float, c_int, c_uint};

    // Opaque handle returned by rubberband_live_new()
    pub enum RubberBandLiveState_ {}
    pub type RubberBandLiveState = *mut RubberBandLiveState_;

    pub type RubberBandOptions = c_int;

    // Option flags relevant to the live shifter
    pub const OPTION_WINDOW_SHORT: RubberBandOptions = 0x0000_0000;
    pub const OPTION_WINDOW_MEDIUM: RubberBandOptions = 0x0010_0000;
    pub const OPTION_FORMANT_SHIFTED: RubberBandOptions = 0x0000_0000;
    pub const OPTION_CHANNELS_APART: RubberBandOptions = 0x0000_0000;

    extern "C" {
        pub fn rubberband_live_new(
            sample_rate: c_uint,
            channels: c_uint,
            options: RubberBandOptions,
        ) -> RubberBandLiveState;

        pub fn rubberband_live_delete(state: RubberBandLiveState);

        pub fn rubberband_live_reset(state: RubberBandLiveState);

        pub fn rubberband_live_set_pitch_scale(state: RubberBandLiveState, scale: c_double);

        pub fn rubberband_live_get_pitch_scale(state: RubberBandLiveState) -> c_double;

        pub fn rubberband_live_set_formant_scale(state: RubberBandLiveState, scale: c_double);

        /// Returns the fixed block size the library expects on each `shift()` call.
        pub fn rubberband_live_get_block_size(state: RubberBandLiveState) -> c_uint;

        /// Returns the start delay (latency) in samples.
        pub fn rubberband_live_get_start_delay(state: RubberBandLiveState) -> c_uint;

        /// Process exactly `getBlockSize()` frames.
        ///
        /// `input`  — pointer to an array of `channels` const-float pointers
        /// `output` — pointer to an array of `channels` float pointers
        pub fn rubberband_live_shift(
            state: RubberBandLiveState,
            input: *const *const c_float,
            output: *const *mut c_float,
        );
    }
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
    fn new(sample_rate: u32, channels: usize) -> Option<Self> {
        let options =
            ffi::OPTION_WINDOW_SHORT | ffi::OPTION_FORMANT_SHIFTED | ffi::OPTION_CHANNELS_APART;

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
        // Using SmallVec-style stack storage for up to 8 channels.
        let mut in_ptrs: [*const f32; 8] = [std::ptr::null(); 8];
        let mut out_ptrs: [*mut f32; 8] = [std::ptr::null_mut(); 8];

        for (ch, slice) in channels_data.iter_mut().enumerate() {
            in_ptrs[ch] = slice.as_ptr();
            out_ptrs[ch] = slice.as_mut_ptr();
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
}

impl Clone for PitchShiftEngine {
    fn clone(&self) -> Self {
        // RbLiveShifter is not Clone (it's an FFI resource); create a fresh
        // engine instead of duplicating the C++ object.
        let mut e = Self::base_default();
        e.pitch_ratio = self.pitch_ratio.clone();
        e.sample_rate = self.sample_rate;
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

        // Rebuild the shifter if config changed.
        let needs_rebuild = self
            .shifter
            .as_ref()
            .map_or(true, |s| s.channels != channels || self.sample_rate != sr);

        if needs_rebuild {
            self.sample_rate = sr;
            self.channels = channels;
            self.shifter = RbLiveShifter::new(sr, channels).map(Box::new);

            // Size the staging buffers to the shifter's block size.
            let block = self.shifter_block_size();
            self.input_staging = vec![vec![0.0_f32; block]; channels];
            self.output_staging = vec![vec![0.0_f32; block * 4]; channels];
            self.staging_fill = 0;
            self.output_pending = 0;
            self.output_read_pos = 0;
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

        // Lazy init: create the shifter on first call if prepare() wasn't
        // called explicitly.
        if self.shifter.is_none() || self.channels != channels {
            self.prepare(self.sample_rate as f32, channels);
        }

        // Update pitch scale from parameter every block (real-time safe).
        let ratio = self.pitch_ratio.get() as f64;
        let is_unity = (ratio - 1.0).abs() < 1e-3;

        // Only bypass once nothing is in flight — otherwise we strand
        // already-staged/shifted audio and desync the ring buffer.
        if is_unity && self.staging_fill == 0 && self.output_pending == 0 {
            self.last_pitch_ratio = ratio;
            return; // channels_data already holds the dry copy from Pitcher::process
        }

        if let Some(s) = &self.shifter {
            if (s.state.as_ptr() as usize) != 0 {
                s.set_pitch_scale(ratio);
            }
        }
        self.last_pitch_ratio = ratio;

        let block = self.shifter_block_size();

        let mut in_pos = 0usize;
        let mut out_pos = 0usize;

        while in_pos < num_frames || out_pos < num_frames {
            // ---- Drain any pending output first ----
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

            // ---- Fill the staging buffer ----
            let space = block - self.staging_fill;
            let avail = (num_frames - in_pos).min(space);

            for ch in 0..channels {
                let dst = &mut self.input_staging[ch];
                dst[self.staging_fill..self.staging_fill + avail]
                    .copy_from_slice(&channels_data[ch][in_pos..in_pos + avail]);
            }
            self.staging_fill += avail;
            in_pos += avail;

            // ---- If we have a full block, run the shifter ----
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
                } // <-- ptrs (and the mutable borrow of input_staging) dropped here

                // Append processed block to output ring.
                let out_len = self.output_staging[0].len();
                let write_pos = (self.output_read_pos + self.output_pending) % out_len;

                // Calculate how many samples we can write before hitting the end of the ring buffer
                let space_until_wrap = out_len - write_pos;
                let first_chunk = block.min(space_until_wrap);
                let second_chunk = block - first_chunk;

                for ch in 0..channels {
                    // 1. Write up to the boundary using a lightning-fast memory copy
                    self.output_staging[ch][write_pos..write_pos + first_chunk]
                        .copy_from_slice(&self.input_staging[ch][..first_chunk]);

                    // 2. Wrap around and write the remainder (if any)
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
