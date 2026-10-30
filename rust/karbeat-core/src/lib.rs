//! # Overview
//!
//! Core Package of Karbeat. Handles the persisted project model, file management, and
//! application-independent business logic. The DSP audio engine lives in `karbeat-audio`.
//!
//! The UI-facing API layer lives in the `karbeat-core-api` crate.

#[allow(
    clippy::as_conversions,
    clippy::let_underscore_must_use,
    reason = "project time and identifier conversions are range-validated by domain operations, and observer broadcasts are best-effort"
)]
/// Persisted project domain, file management, and undo/redo history.
pub mod core;
/// Returns heap memory freed by large project swaps to the operating system.
pub mod heap;
/// Re-exported plugin parameter and plugin trait types used by core APIs.
pub mod plugin_types;
#[allow(
    clippy::as_conversions,
    reason = "typed IDs preserve the existing compact integer wire representation"
)]
/// Shared typed identifiers, constants, enums, and bounded scalar types.
pub mod shared;
/// Audio-buffer utility functions shared by project loading and rendering.
pub mod utils;
