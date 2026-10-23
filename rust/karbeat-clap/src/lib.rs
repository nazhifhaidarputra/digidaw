//! CLAP discovery, UI-thread lifecycle management, and exclusive audio processing.
//!
//! `clack-host` loads plugin entries and wraps the CLAP ABI; this crate maps it onto DigiDAW's
//! format-independent host contracts. The host is available on Linux and Windows, where the
//! shared native UI runtime runs; other platforms keep an executor that reports the format as
//! unsupported.
//!
//! # Native instance transfer audit
//!
//! `ProcessorSlot` is the only manually `Sync` container. Its private `UnsafeCell<Dsp>` holds the
//! activated audio processor and its preallocated buffers and event queue. Processing accesses
//! it under a `ProcessingGate` guard; activation, parameter flushes, and state access it only
//! after UI-side suspension acknowledgement. The UI instance retains the slot's final `Arc`, so
//! the plugin is deactivated and destroyed there. The plugin instance, its editor, its timers
//! and file descriptors, and the module entry remain with the non-transferable UI owner.
//!
//! CLAP calls `start_processing`, `process`, `reset`, and an active `params.flush` audio-thread
//! functions. Whichever side holds exclusive DSP access makes them, and the thread-check
//! extension reports that thread as the audio thread for the duration. This is not a promise
//! that a plugin is otherwise thread-safe.
//!
//! # Limits
//!
//! * Only the main input, the first other input (as the sidechain), and the main output are
//!   routed. Further ports receive silence or have their output discarded.
//! * Hidden parameters are not exposed. Parameter modulation and per-note automation are not
//!   sent.
//! * Discovery runs each module's entry in the isolated scanner helper, because loading a CLAP
//!   module runs plugin code.
//!
//! ```compile_fail
//! fn requires_send<T: Send>() {}
//! requires_send::<karbeat_clap::ClapPluginHost>();
//! ```
//! ```compile_fail
//! fn requires_sync<T: Sync>() {}
//! requires_sync::<karbeat_clap::ClapPluginHost>();
//! ```

#[cfg(any(target_os = "linux", target_os = "windows"))]
mod backend;
#[cfg(any(target_os = "linux", target_os = "windows"))]
mod editor;
#[cfg(any(target_os = "linux", target_os = "windows"))]
mod events;
#[cfg(any(target_os = "linux", target_os = "windows"))]
mod executor;
#[cfg(any(target_os = "linux", target_os = "windows"))]
mod host;
/// CLAP module discovery, loading, and plugin enumeration.
#[cfg(any(target_os = "linux", target_os = "windows"))]
pub mod module;
/// Native UI-loop gateway for the CLAP backend.
#[cfg(any(target_os = "linux", target_os = "windows"))]
pub mod native;
#[cfg(any(target_os = "linux", target_os = "windows"))]
mod parameters;
#[cfg(any(target_os = "linux", target_os = "windows"))]
mod plugin;
#[cfg(any(target_os = "linux", target_os = "windows"))]
mod wrapper;

#[cfg(not(any(target_os = "linux", target_os = "windows")))]
mod stub;

#[cfg(any(target_os = "linux", target_os = "windows"))]
pub use backend::ClapPluginHost;
#[cfg(any(target_os = "linux", target_os = "windows"))]
pub use executor::ClapExecutor;
#[cfg(not(any(target_os = "linux", target_os = "windows")))]
pub use stub::ClapExecutor;
#[cfg(any(target_os = "linux", target_os = "windows"))]
pub use wrapper::ClapProcessor;

/// Loads one CLAP module and lists the plugins it provides.
///
/// This runs plugin code, so hosts call it from the isolated scanner helper.
///
/// # Errors
///
/// Returns an error when the module cannot be loaded or its entry provides no plugin factory.
pub fn probe_module(
    path: &std::path::Path,
) -> Result<Vec<karbeat_host_api::PluginDescriptor>, karbeat_host_api::HostError> {
    #[cfg(any(target_os = "linux", target_os = "windows"))]
    return module::ClapModule::load(path).and_then(|module| module.descriptors());
    #[cfg(not(any(target_os = "linux", target_os = "windows")))]
    {
        let _unsupported = path;
        Err(karbeat_host_api::HostError::Unsupported(
            "CLAP hosting is not available on this platform",
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use karbeat_host_api::{PluginFormat, PluginFormatExecutor};

    #[test]
    fn occupies_the_clap_dispatch_slot() {
        assert_eq!(ClapExecutor.format(), PluginFormat::Clap);
    }
}
