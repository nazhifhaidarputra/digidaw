//! Translations of the user interface, written in [Fluent](https://projectfluent.org) and
//! embedded at build time.
//!
//! ```text
//! locales/
//!   en-US/           source language; every message starts here
//!     common.ftl     one file per area of the app, see `AREAS`
//!     settings.ftl
//!     …
//!   ja-JP/           translations; a missing message falls back to en-US
//! ```
//!
//! See `README.md` next to this crate for how to add or translate a message.

mod catalog;
mod language;
mod negotiate;

pub use catalog::{AREAS, Arg, format};
pub use language::Language;
pub use negotiate::resolve;

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    reason = "translation tests fail immediately on a broken Fluent file"
)]
mod tests;
