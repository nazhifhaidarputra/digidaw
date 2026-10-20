//! Native UI-loop gateway for the CLAP backend.
//!
//! The runtime itself is shared with the other formats; this module binds it to
//! [`ClapPluginHost`] and owns the thread-local slot that keeps the host on the native UI thread.

use std::{cell::RefCell, sync::atomic::AtomicBool};

use karbeat_host_api::{
    HostError, HostInstanceId, PluginDescriptor, PluginInstanceManager, PluginState,
    ProcessingConfig,
    native_host::{self as shared, EditorResizeHandler, NativeBackend},
};

use crate::ClapPluginHost;

pub use shared::PreparedNativeInstance;

/// Native-UI-thread runtime that owns the CLAP host, its editor windows, and pending lifecycle
/// work.
pub type NativeHost = shared::NativeHost<ClapPluginHost>;

thread_local! {
    static RUNTIME: RefCell<Option<NativeHost>> = const { RefCell::new(None) };
}
static RUNTIME_READY: AtomicBool = AtomicBool::new(false);

/// Preparation carried between native-loop iterations.
pub struct ClapPrepareJob {
    config: ProcessingConfig,
}

impl NativeBackend for ClapPluginHost {
    const LABEL: &'static str = "CLAP";
    type PrepareJob = ClapPrepareJob;

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
        config.validate()?;
        PluginInstanceManager::suspend(self, instance)?;
        Ok(ClapPrepareJob {
            config: config.clone(),
        })
    }

    fn advance_prepare(
        &mut self,
        instance: HostInstanceId,
        job: &mut Self::PrepareJob,
    ) -> Result<bool, HostError> {
        // Activation is one plugin call, so there is nothing to spread over iterations.
        PluginInstanceManager::prepare(self, instance, &job.config)?;
        Ok(true)
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
pub fn available() -> bool {
    shared::available::<ClapPluginHost>()
}

/// Captures fresh state without holding an engine or project lock on the native UI thread.
pub async fn capture_state(instance: HostInstanceId) -> Result<PluginState, HostError> {
    shared::capture_state::<ClapPluginHost>(instance).await
}

/// Restores state through the native owner's state transaction.
pub async fn restore_state(instance: HostInstanceId, state: PluginState) -> Result<(), HostError> {
    shared::restore_state::<ClapPluginHost>(instance, state).await
}

/// Prepares a production instance while its caller waits off the UI owner.
pub async fn prepare_instance(
    descriptor: PluginDescriptor,
    config: ProcessingConfig,
    state: Option<PluginState>,
) -> Result<PreparedNativeInstance, HostError> {
    shared::prepare_instance::<ClapPluginHost>(descriptor, config, state).await
}

/// Captures fresh state and prepares an independent, suspended duplicate.
pub async fn duplicate_instance(
    instance: HostInstanceId,
) -> Result<PreparedNativeInstance, HostError> {
    shared::duplicate_instance::<ClapPluginHost>(instance).await
}

/// Captures live state and prepares a suspended replacement for a realtime DSP configuration.
pub async fn prepare_reconfigured_instance(
    instance: HostInstanceId,
    sample_rate: u32,
    max_block_size: usize,
) -> Result<PreparedNativeInstance, HostError> {
    shared::prepare_reconfigured_instance::<ClapPluginHost>(instance, sample_rate, max_block_size)
        .await
}

/// Captures live state and creates an independent offline endpoint on the native UI owner.
pub async fn prepare_offline_instance(
    instance: HostInstanceId,
    sample_rate: u32,
    max_block_size: usize,
    output_channels: usize,
) -> Result<PreparedNativeInstance, HostError> {
    shared::prepare_offline_instance::<ClapPluginHost>(
        instance,
        sample_rate,
        max_block_size,
        output_channels,
    )
    .await
}

/// Called by API/control workers, never the audio or native UI thread.
pub async fn call<T: Send + 'static>(
    action: impl FnOnce(&mut NativeHost) -> Result<T, HostError> + Send + 'static,
) -> Result<T, HostError> {
    shared::call(action).await
}
