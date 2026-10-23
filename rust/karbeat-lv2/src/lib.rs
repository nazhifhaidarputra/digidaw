//! LV2 discovery, UI-thread lifecycle management, and exclusive audio processing.
//!
//! lilv reads plugin descriptions and instantiates plugins; `lv2-sys` supplies the plugin,
//! editor, and atom ABI the host then calls directly.
//! The host is available on Linux, where LV2 plugins and lilv are installed; other platforms
//! keep an executor that reports the format as unsupported.
//!
//! # Native instance transfer audit
//!
//! `ProcessorSlot` is the only manually `Sync` container. Its private `UnsafeCell<Dsp>` holds
//! the plugin instance and its preallocated buffers. Processing accesses it under a
//! `ProcessingGate` guard; preparation, parameter flushes, and state access it only after
//! UI-side suspension acknowledgement. The UI instance retains the slot's final `Arc`, so the
//! plugin instance is destroyed there. Bundle worlds, editors, and URID records remain with the
//! non-transferable UI owner.
//!
//! LV2 allows `run` on an audio thread while instantiation, state, and editor calls happen
//! elsewhere, provided they never overlap `run`; the gate serializes them. This is not a
//! promise that a plugin is otherwise thread-safe.
//!
//! # Limits
//!
//! * A plugin is hosted only when its required features are among the ones the host provides:
//!   URID map and unmap, options, bounded block length, and worker scheduling.
//! * Loading a bundle reads only its manifest. lilv reads a plugin's description when that
//!   plugin is first used, so a bundle of hundreds of plugins costs one description per
//!   hosted plugin.
//! * CV ports are connected but not routed: inputs receive silence and outputs are discarded.
//!
//! ```compile_fail
//! fn requires_send<T: Send>() {}
//! requires_send::<karbeat_lv2::Lv2PluginHost>();
//! ```
//! ```compile_fail
//! fn requires_sync<T: Sync>() {}
//! requires_sync::<karbeat_lv2::Lv2PluginHost>();
//! ```

#[cfg(target_os = "linux")]
mod atoms;
#[cfg(target_os = "linux")]
mod editor;
#[cfg(target_os = "linux")]
mod executor;
#[cfg(target_os = "linux")]
mod host;
#[cfg(target_os = "linux")]
mod instance;
/// Native UI-loop gateway for the LV2 backend.
#[cfg(target_os = "linux")]
pub mod native;
#[cfg(target_os = "linux")]
mod parameters;
#[cfg(target_os = "linux")]
mod plugin;
#[cfg(target_os = "linux")]
mod ports;
#[cfg(target_os = "linux")]
mod state;
#[cfg(target_os = "linux")]
mod urid;
#[cfg(target_os = "linux")]
mod uris;
#[cfg(target_os = "linux")]
mod worker;
/// LV2 bundle discovery and loading through lilv.
#[cfg(target_os = "linux")]
pub mod world;
#[cfg(target_os = "linux")]
mod wrapper;

#[cfg(not(target_os = "linux"))]
mod stub;

#[cfg(target_os = "linux")]
pub use executor::Lv2Executor;
#[cfg(target_os = "linux")]
pub use host::Lv2PluginHost;
#[cfg(not(target_os = "linux"))]
pub use stub::Lv2Executor;
#[cfg(target_os = "linux")]
pub use wrapper::Lv2Processor;

#[cfg(test)]
mod tests {
    use super::*;
    use karbeat_host_api::{PluginFormat, PluginFormatExecutor};

    #[test]
    fn occupies_the_lv2_dispatch_slot() {
        assert_eq!(Lv2Executor.format(), PluginFormat::Lv2);
    }
}
