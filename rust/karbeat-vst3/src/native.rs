//! Native UI-loop gateway. Only message payloads and exclusive audio endpoints cross threads.
//!
//! The runtime itself is shared with the other formats; this module binds it to
//! [`Vst3PluginHost`] and owns the thread-local slot that keeps the host on the native UI thread.

use crate::{
    Vst3PluginHost,
    instance::{MIDI_MAPPING_QUERY_COUNT, Vst3PrepareJob},
};
use karbeat_host_api::{
    HostError, HostInstanceId, PluginDescriptor, PluginState, ProcessingConfig,
    native_host::{self as shared, EditorResizeHandler, NativeBackend},
};
use std::{cell::RefCell, sync::atomic::AtomicBool};

pub use shared::PreparedNativeInstance;

const MIDI_MAPPING_QUERIES_PER_TICK: usize = 64;
const _: () = assert!(MIDI_MAPPING_QUERIES_PER_TICK < MIDI_MAPPING_QUERY_COUNT);

/// Native-UI-thread runtime that owns the VST3 host, editor windows, and pending lifecycle work.
///
/// Requests reach this owner through [`call`]. Its periodic pump advances bounded preparation
/// and state transactions, retires returned processors, services native events, and coalesces
/// parameter-state flushes without moving COM or window objects to worker threads.
pub type NativeHost = shared::NativeHost<Vst3PluginHost>;

thread_local! {
    static RUNTIME: RefCell<Option<NativeHost>> = const { RefCell::new(None) };
}
static RUNTIME_READY: AtomicBool = AtomicBool::new(false);

impl NativeBackend for Vst3PluginHost {
    const LABEL: &'static str = "VST3";
    type PrepareJob = Vst3PrepareJob;

    fn create_on_owner() -> Self {
        Self::new()
    }

    fn with_runtime_slot<R>(action: impl FnOnce(&RefCell<Option<NativeHost>>) -> R) -> R {
        RUNTIME.with(action)
    }

    fn runtime_ready() -> &'static AtomicBool {
        &RUNTIME_READY
    }

    fn begin_prepare(
        &mut self,
        instance: HostInstanceId,
        config: &ProcessingConfig,
    ) -> Result<Self::PrepareJob, HostError> {
        Self::begin_prepare(self, instance, config)
    }

    fn advance_prepare(
        &mut self,
        instance: HostInstanceId,
        job: &mut Self::PrepareJob,
    ) -> Result<bool, HostError> {
        Self::advance_prepare(self, instance, job, MIDI_MAPPING_QUERIES_PER_TICK)
    }

    fn has_pending_parameters(&self, instance: HostInstanceId) -> Result<bool, HostError> {
        Self::has_pending_parameters(self, instance)
    }

    fn pump(&mut self) -> Result<(), HostError> {
        Self::pump(self)
    }

    fn set_editor_resize_handler(
        &mut self,
        instance: HostInstanceId,
        handler: EditorResizeHandler,
    ) -> Result<(), HostError> {
        Self::set_editor_resize_handler(self, instance, handler)
    }

    fn descriptor(&self, instance: HostInstanceId) -> Result<&PluginDescriptor, HostError> {
        Self::descriptor(self, instance)
    }

    fn processing_config(&self, instance: HostInstanceId) -> Result<&ProcessingConfig, HostError> {
        Self::processing_config(self, instance)
    }
}

/// Reports whether the thread-local native runtime has completed lazy initialization.
///
/// This is an acquire load paired with the release store performed after the runtime and its
/// periodic pump have been installed.
pub fn available() -> bool {
    shared::available::<Vst3PluginHost>()
}

/// Captures fresh opaque state without holding an engine or project lock on the native UI thread.
pub async fn capture_state(instance: HostInstanceId) -> Result<PluginState, HostError> {
    shared::capture_state::<Vst3PluginHost>(instance).await
}

/// Prepares a production instance cooperatively while its caller waits off the UI owner.
pub async fn prepare_instance(
    descriptor: PluginDescriptor,
    config: ProcessingConfig,
    state: Option<PluginState>,
) -> Result<PreparedNativeInstance, HostError> {
    shared::prepare_instance::<Vst3PluginHost>(descriptor, config, state).await
}

/// Captures fresh state and prepares an independent duplicate with the source configuration.
/// The duplicate stays suspended until its caller publishes and resumes it. Dropping the
/// returned transfer schedules destruction on the native UI owner.
pub async fn duplicate_instance(
    instance: HostInstanceId,
) -> Result<PreparedNativeInstance, HostError> {
    shared::duplicate_instance::<Vst3PluginHost>(instance).await
}

/// Captures live state and prepares a suspended replacement for a realtime DSP configuration.
pub async fn prepare_reconfigured_instance(
    instance: HostInstanceId,
    sample_rate: u32,
    max_block_size: usize,
) -> Result<PreparedNativeInstance, HostError> {
    shared::prepare_reconfigured_instance::<Vst3PluginHost>(instance, sample_rate, max_block_size)
        .await
}

/// Captures live state and creates an independent offline endpoint on the native UI owner.
pub async fn prepare_offline_instance(
    instance: HostInstanceId,
    sample_rate: u32,
    max_block_size: usize,
    output_channels: usize,
) -> Result<PreparedNativeInstance, HostError> {
    shared::prepare_offline_instance::<Vst3PluginHost>(
        instance,
        sample_rate,
        max_block_size,
        output_channels,
    )
    .await
}

/// Restores opaque component/controller state through the native owner's state transaction.
pub async fn restore_state(instance: HostInstanceId, state: PluginState) -> Result<(), HostError> {
    shared::restore_state::<Vst3PluginHost>(instance, state).await
}

/// Called by API/control workers, never the audio or native UI thread.
/// A bounded request queue rejects overload instead of silently dropping lifecycle commands.
pub async fn call<T: Send + 'static>(
    action: impl FnOnce(&mut NativeHost) -> Result<T, HostError> + Send + 'static,
) -> Result<T, HostError> {
    shared::call(action).await
}
