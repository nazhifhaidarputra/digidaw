//! Format-independent discovery and lifecycle contracts for external plugins.
//!
//! # Ownership and lifecycle
//!
//! [`DigidawPluginHost`] and its native components, controllers, editors, and module references
//! belong to the application's native UI thread. The trait deliberately requires neither
//! `Send`, `Sync`, nor `Clone`. Discovery runs on a worker using [`scanner`]; that worker
//! starts an isolated helper per module and returns descriptors, never native objects.
//!
//! | State | Allowed control work | Audio endpoint |
//! | --- | --- | --- |
//! | Created | Inspect, prepare, destroy | Not available |
//! | Prepared / suspended | Capture/restore, reconfigure, take endpoint once, resume | Silence or delayed dry bypass |
//! | Running | Parameters, editor, request suspension | Exclusive processing |
//! | Suspending | Retry suspension on a later UI iteration | Finishes current block, then bypasses |
//! | Retiring | Close editor, collect endpoint, destroy | Returned through reserved queue |
//! | Destroyed | All instance operations fail with a stale-handle error | Not available |
//!
//! A backend issues handles monotonically within its lifetime. Identity persists as
//! [`PluginIdentity`]; [`HostInstanceId`] is a runtime handle and must not be saved in a project.
//! Module paths can change independently of identity.
//!
//! [`ProcessingGate`] admits one processing call at a time. Suspension is nonblocking and
//! returns [`HostError::Busy`] until that call releases its guard. An acquire acknowledgement
//! makes the finished block visible to the UI owner; release on resume publishes preparation
//! to the next block. Only the UI owner resumes or accesses suspended DSP internals.
//! [`StateTransaction`] preserves running intent and must be polled through completion,
//! including cancellation cleanup. Native state calls and reconfiguration never run in DSP.
//!
//! Transfer the exclusive [`HostedProcessor`] through [`PreparedProcessor`], keeping its
//! [`ProcessorRetirement`] on the UI owner. Publish with an acknowledged engine command and
//! resume only after acceptance. A discarded transfer retires automatically. Remove an
//! installed endpoint with `AudioPlugin::retire`, then drain the return queue on the UI thread
//! before destroying the instance or unloading its module. Ordinary `Box` destruction is not
//! an audio-thread removal operation. Stop/join processing and drain pending work before
//! shutting down the UI owner; backend leak guards are emergency containment, not shutdown.
//!
//! Duplication and export capture fresh state, create another native instance, prepare it for
//! its destination, and restore that state. Copying descriptors, state bytes, or parameter
//! metadata never shares a processor. There is no trait-object cloning requirement.
//!
//! # Thread transfer checks
//!
//! The prepared endpoint can move to an audio worker:
//! ```
//! fn requires_send<T: Send>() {}
//! requires_send::<karbeat_host::PreparedProcessor>();
//! ```
//! Shared mutable processing and cloning are deliberately unavailable:
//! ```compile_fail
//! fn requires_sync<T: Sync>() {}
//! requires_sync::<karbeat_host::HostedProcessor>();
//! ```
//! ```compile_fail
//! fn requires_clone<T: Clone>() {}
//! requires_clone::<karbeat_host::PreparedProcessor>();
//! ```

mod control;
mod lifecycle;
pub mod native_ui;
mod processor;
pub mod scanner;
mod state;
mod traits;
mod types;

pub use control::*;
pub use lifecycle::*;
pub use native_ui::*;
pub use processor::*;
pub use state::*;
pub use traits::*;
pub use types::*;
pub mod bypass;
