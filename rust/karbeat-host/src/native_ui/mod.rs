//! Format-independent native editor windows and UI-owner dispatch.
//!
//! Platform objects and windows remain on the native UI owner. Raw handles returned by this
//! module are valid only while the corresponding [`NativeWindow`] remains alive.

mod binding;
pub mod platform;
#[cfg(target_os = "linux")]
mod runtime;
mod traits;
mod types;

pub use binding::*;
pub use platform::SystemNativeUi;
#[cfg(target_os = "linux")]
pub use runtime::*;
pub use traits::*;
pub use types::*;

#[cfg(test)]
mod tests;
