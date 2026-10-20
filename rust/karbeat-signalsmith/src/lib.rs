//! Signalsmith Stretch bindings for Karbeat.
//!
//! `build.rs` compiles the vendored, header-only library (see `vendor/README.md`) behind the
//! small C ABI in `src/shim.cpp`, and generates [`ffi`] from its header `src/shim.h`. This is the only crate that touches
//! Signalsmith directly; everything else goes through [`Stretcher`], its safe owner.
//!
//! Channel buffers are passed as slices of per-channel samples, at most [`MAX_CHANNELS`] of
//! them. Pointer tables are built on the stack, so calls on the processing path do not
//! allocate.

mod stretcher;

pub use stretcher::Stretcher;

#[allow(
    non_camel_case_types,
    non_snake_case,
    non_upper_case_globals,
    dead_code,
    reason = "bindgen preserves the names of the C ABI"
)]
pub mod ffi {
    include!(concat!(env!("OUT_DIR"), "/signalsmith_bindings.rs"));
}

/// Most channels one instance accepts, matching the stack pointer tables passed to the C API.
pub const MAX_CHANNELS: usize = 8;

/// Why a Signalsmith call could not be made.
#[derive(Debug, Clone, Copy, PartialEq, Eq, thiserror::Error)]
pub enum SsError {
    #[error("Signalsmith Stretch could not create an instance")]
    CreateFailed,
    #[error("{0} channels requested; Signalsmith instances take 1 to {MAX_CHANNELS}")]
    UnsupportedChannels(usize),
    #[error("expected {expected} channel buffers, got {got}")]
    ChannelMismatch { expected: usize, got: usize },
    #[error("value does not fit the Signalsmith C API")]
    OutOfRange,
}

/// Converts a frame count to the C API's `int`.
fn to_c_int(value: usize) -> Result<i32, SsError> {
    i32::try_from(value).map_err(|_| SsError::OutOfRange)
}

/// Converts an `int` returned by the C API to a frame count.
fn from_c_int(value: i32) -> usize {
    usize::try_from(value).unwrap_or(0)
}

/// Read pointers to the first `expected` channels, and the shortest channel's length.
fn read_pointers<C: AsRef<[f32]>>(
    channels: &[C],
    expected: usize,
) -> Result<([*const f32; MAX_CHANNELS], usize), SsError> {
    if channels.len() != expected || expected > MAX_CHANNELS {
        return Err(SsError::ChannelMismatch {
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
) -> Result<([*mut f32; MAX_CHANNELS], usize), SsError> {
    if channels.len() != expected || expected > MAX_CHANNELS {
        return Err(SsError::ChannelMismatch {
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
