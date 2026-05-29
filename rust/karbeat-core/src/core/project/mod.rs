mod index;
// src/core/project/mod.rs

pub mod automation;
pub mod clip;
pub mod clipboard;
pub mod generator;
pub mod mixer;
pub mod plugin;
pub mod track;
pub mod transport;

pub use index::*;
pub use mixer::*;
pub use transport::*;
pub use clip::*;
pub use clipboard::*;
pub use generator::*;
pub use plugin::*;
pub use track::*;
pub use automation::*;