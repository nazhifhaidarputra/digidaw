//! Format-independent native editor windows and UI-owner dispatch.
//!
//! Platform objects and windows remain on the native UI owner. Raw handles returned by this
//! module are valid only while the corresponding [`NativeWindow`] remains alive.

mod binding;
mod traits;
mod types;

pub use binding::*;
pub use traits::*;
pub use types::*;

#[cfg(test)]
mod tests;
