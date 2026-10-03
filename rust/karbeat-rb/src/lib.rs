//! Rubber Band Library bindings for Karbeat.
//!
//! `build.rs` finds and links the native library (pkg-config on Linux and macOS, the vcpkg
//! tree on Windows, `jniLibs` on Android) and generates [`ffi`] from `rubberband-c.h`. This is
//! the only crate that touches Rubber Band directly; everything else goes through the safe
//! owners here:
//!
//! - [`Stretcher`] wraps `RubberBandStretcher`, for offline and real-time time stretching
//!   and pitch shifting.
//! - [`LiveShifter`] wraps `RubberBandLiveShifter`, the fixed-block, low-latency pitch shifter.
//!
//! Channel buffers are passed as slices of per-channel samples, at most [`MAX_CHANNELS`] of
//! them. Pointer tables are built on the stack, so calls on the processing path do not
//! allocate.

mod live;
mod stretcher;

pub use live::{LiveOptions, LiveShifter};
pub use stretcher::{Stretcher, StretcherOptions};

#[allow(
    non_camel_case_types,
    non_snake_case,
    non_upper_case_globals,
    dead_code,
    reason = "bindgen preserves the names and complete surface of the upstream C API"
)]
pub mod ffi {
    include!(concat!(env!("OUT_DIR"), "/rubberband_bindings.rs"));
}

/// Most channels one instance accepts, matching the stack pointer tables passed to the C API.
pub const MAX_CHANNELS: usize = 8;

/// Why a Rubber Band call could not be made.
#[derive(Debug, Clone, Copy, PartialEq, Eq, thiserror::Error)]
pub enum RbError {
    #[error("Rubber Band could not create an instance")]
    CreateFailed,
    #[error("{0} channels requested; Rubber Band instances take 1 to {MAX_CHANNELS}")]
    UnsupportedChannels(usize),
    #[error("expected {expected} channel buffers, got {got}")]
    ChannelMismatch { expected: usize, got: usize },
    #[error("channel buffers hold {got} frames, {needed} are needed")]
    ShortBuffer { needed: usize, got: usize },
    #[error("value does not fit the Rubber Band C API")]
    OutOfRange,
}

/// Converts a frame count or rate to the C API's `unsigned int`.
fn to_c_uint(value: usize) -> Result<u32, RbError> {
    u32::try_from(value).map_err(|_| RbError::OutOfRange)
}

/// Converts an `unsigned int` returned by the C API to a frame count.
fn from_c_uint(value: u32) -> usize {
    usize::try_from(value).unwrap_or(usize::MAX)
}

/// Validates a channel count given at construction.
fn check_channels(channels: usize) -> Result<u32, RbError> {
    if channels == 0 || channels > MAX_CHANNELS {
        return Err(RbError::UnsupportedChannels(channels));
    }
    to_c_uint(channels)
}

/// Read pointers to the first `expected` channels, and the shortest channel's length.
fn read_pointers<C: AsRef<[f32]>>(
    channels: &[C],
    expected: usize,
) -> Result<([*const f32; MAX_CHANNELS], usize), RbError> {
    if channels.len() != expected || expected > MAX_CHANNELS {
        return Err(RbError::ChannelMismatch {
            expected,
            got: channels.len(),
        });
    }
    let mut pointers = [std::ptr::null(); MAX_CHANNELS];
    let mut frames = usize::MAX;
    for (pointer, channel) in pointers.iter_mut().zip(channels) {
        let channel = channel.as_ref();
        *pointer = channel.as_ptr();
        frames = frames.min(channel.len());
    }
    Ok((pointers, if channels.is_empty() { 0 } else { frames }))
}

/// Write pointers to the first `expected` channels, and the shortest channel's length.
fn write_pointers<C: AsMut<[f32]>>(
    channels: &mut [C],
    expected: usize,
) -> Result<([*mut f32; MAX_CHANNELS], usize), RbError> {
    if channels.len() != expected || expected > MAX_CHANNELS {
        return Err(RbError::ChannelMismatch {
            expected,
            got: channels.len(),
        });
    }
    let empty = channels.is_empty();
    let mut pointers = [std::ptr::null_mut(); MAX_CHANNELS];
    let mut frames = usize::MAX;
    for (pointer, channel) in pointers.iter_mut().zip(channels) {
        let channel = channel.as_mut();
        *pointer = channel.as_mut_ptr();
        frames = frames.min(channel.len());
    }
    Ok((pointers, if empty { 0 } else { frames }))
}
