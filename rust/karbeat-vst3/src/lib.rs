//! VST3 discovery, UI-thread lifecycle management, and exclusive audio processing.
//!
//! # Native interface transfer audit
//!
//! `ProcessorSlot` is the only manually `Send + Sync` native-interface container. Its private
//! `UnsafeCell<Dsp>` holds the processing interface and preallocated process data. Processing
//! and reset access it under a `ProcessingGate` guard; preparation, state flush, start, and
//! stop access it only after UI-side suspension acknowledgement. Teardown checks that no
//! endpoint remains. The UI instance retains the slot's final `Arc` so native references and
//! buffers are released there. The component, edit controller, editor, factory, and run loop
//! remain in the non-transferable UI owner.
//!
//! This follows Steinberg's [threading model](https://steinbergmedia.github.io/vst3_dev_portal/pages/Technical%2BDocumentation/API%2BDocumentation/Index.html):
//! initialization and controller work run on the UI thread; `process` can run on an audio
//! thread, and `setProcessing` may run on either. Our gate serializes those calls. This is not
//! a promise that arbitrary plugin interfaces are thread-safe.
//!
//! ```compile_fail
//! fn requires_send<T: Send>() {}
//! requires_send::<karbeat_vst3::Vst3PluginHost>();
//! ```
//! ```compile_fail
//! fn requires_sync<T: Sync>() {}
//! requires_sync::<karbeat_vst3::Vst3PluginHost>();
//! ```

pub mod api;
mod context;
mod editor;
mod host;
mod instance;
/// VST3 bundle discovery, dynamic loading, factory enumeration, and class-ID conversion.
pub mod module;
pub mod native;
mod run_loop;
mod wrapper;

pub use host::Vst3PluginHost;
pub use wrapper::Vst3Processor;
