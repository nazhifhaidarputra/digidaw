//! Format-independent native editor windows and UI-owner dispatch.
//!
//! Platform objects and windows remain on the native UI owner. Raw handles returned by this
//! module are valid only while the corresponding [`NativeWindow`] remains alive.

mod binding;
/// Operating-system native-window implementations and the selected platform alias.
pub mod platform;
mod runtime;
mod traits;
mod types;

pub use binding::*;
pub use platform::SystemNativeUi;
pub use runtime::*;
pub use traits::*;
pub use types::*;

#[cfg(test)]
mod tests;
