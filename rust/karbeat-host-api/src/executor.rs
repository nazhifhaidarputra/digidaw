use std::{
    fmt,
    path::PathBuf,
    sync::{
        Arc,
        atomic::AtomicBool,
    },
};

use karbeat_plugin_api::prelude::ParameterSpec;

use crate::{
    ExternalPluginInstanceHandle, HostCapabilities, HostError, PluginDescriptor, PluginFormat,
    PluginState, PreparedProcessor, ProcessingConfig,
    scanner::{ScanProgress, ScanResult},
};

/// Thread-safe progress observer used by isolated format scanners.
pub type ScanProgressCallback = Arc<dyn Fn(ScanProgress) + Send + Sync>;

/// Description of one format-specific discovery request.
#[derive(Clone)]
pub struct ScanRequest {
    /// Roots to inspect in addition to format defaults.
    pub directories: Vec<PathBuf>,
    /// Maximum duration allowed for each isolated module probe.
    pub timeout_seconds: u64,
    /// Whether quarantined modules should be probed again.
    pub retry_quarantined: bool,
    /// Cooperative cancellation flag owned by the discovery session.
    pub cancelled: Arc<AtomicBool>,
    /// Optional path used to persist format-specific scanner state.
    pub cache_path: Option<PathBuf>,
    /// Optional observer called after each module is handled.
    pub progress: Option<ScanProgressCallback>,
}

impl fmt::Debug for ScanRequest {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("ScanRequest")
            .field("directories", &self.directories)
            .field("timeout_seconds", &self.timeout_seconds)
            .field("retry_quarantined", &self.retry_quarantined)
            .field("cancelled", &self.cancelled.load(std::sync::atomic::Ordering::Relaxed))
            .field("cache_path", &self.cache_path)
            .field("has_progress_observer", &self.progress.is_some())
            .finish()
    }
}

/// Inputs required to create and prepare a new external processor.
#[derive(Clone, Debug)]
pub struct PrepareRequest {
    /// Installed plugin class to instantiate.
    pub descriptor: PluginDescriptor,
    /// Audio layout and execution mode for the new endpoint.
    pub config: ProcessingConfig,
    /// Optional persisted state restored before the endpoint is transferred.
    pub state: Option<PluginState>,
}

/// Prepared native instance and its exclusive processor transfer.
pub struct PreparedExternalPlugin {
    /// Format-aware runtime handle owned by the executor.
    pub instance: ExternalPluginInstanceHandle,
    /// Optional facilities exposed by the instance.
    pub capabilities: HostCapabilities,
    /// Controller parameters discovered during preparation.
    pub parameters: Vec<ParameterSpec>,
    /// Fresh state captured after preparation and optional restoration.
    pub state: PluginState,
    /// Exclusive processor endpoint reserved for audio-engine publication.
    pub processor: PreparedProcessor,
}

/// One normalized parameter mutation.
#[derive(Clone, Copy, Debug)]
pub struct SetParameterRequest {
    /// Target external instance.
    pub instance: ExternalPluginInstanceHandle,
    /// Format-native parameter identifier.
    pub parameter: u32,
    /// Normalized value accepted by the controller.
    pub value: f64,
}

/// One parameter formatting request.
#[derive(Clone, Copy, Debug)]
pub struct ParameterTextRequest {
    /// Target external instance.
    pub instance: ExternalPluginInstanceHandle,
    /// Format-native parameter identifier.
    pub parameter: u32,
    /// Normalized value to format.
    pub value: f64,
}

/// One parameter text parsing request.
#[derive(Clone, Debug)]
pub struct ParseParameterRequest {
    /// Target external instance.
    pub instance: ExternalPluginInstanceHandle,
    /// Format-native parameter identifier.
    pub parameter: u32,
    /// Plugin-specific display text.
    pub text: String,
}

/// One normalized/plain parameter conversion request.
#[derive(Clone, Copy, Debug)]
pub struct ConvertParameterRequest {
    /// Target external instance.
    pub instance: ExternalPluginInstanceHandle,
    /// Format-native parameter identifier.
    pub parameter: u32,
    /// Value in the source domain.
    pub value: f64,
    /// Converts plain to normalized when true, normalized to plain otherwise.
    pub to_normalized: bool,
}

/// Native editor presentation request.
#[derive(Clone, Debug)]
pub struct OpenEditorRequest {
    /// Target external instance.
    pub instance: ExternalPluginInstanceHandle,
    /// Project-derived label shown in the host window title.
    pub context: String,
}

/// Request to clone a live instance from a freshly captured state.
#[derive(Clone, Copy, Debug)]
pub struct DuplicateRequest {
    /// Source instance.
    pub instance: ExternalPluginInstanceHandle,
}

/// Request to prepare a replacement for a new realtime configuration.
#[derive(Clone, Copy, Debug)]
pub struct ReconfigureRequest {
    /// Source instance whose live state and layout are copied.
    pub instance: ExternalPluginInstanceHandle,
    /// New sample rate.
    pub sample_rate: u32,
    /// New maximum block size.
    pub max_block_size: usize,
}

/// Request to prepare an independent non-realtime rendering instance.
#[derive(Clone, Copy, Debug)]
pub struct OfflinePrepareRequest {
    /// Source instance whose live state and layout are copied.
    pub instance: ExternalPluginInstanceHandle,
    /// Offline rendering sample rate.
    pub sample_rate: u32,
    /// Offline rendering maximum block size.
    pub max_block_size: usize,
    /// Requested main output channel count.
    pub output_channels: usize,
}

/// Static-dispatch contract implemented once by every supported external plugin ABI.
#[allow(async_fn_in_trait, reason = "executors are statically dispatched and never trait objects")]
pub trait PluginFormatExecutor: Clone + Send + Sync + 'static {
    /// ABI handled by this executor.
    fn format(&self) -> PluginFormat;
    /// Conventional discovery roots for this ABI.
    fn default_scan_paths(&self) -> Vec<PathBuf>;
    /// Discovers descriptors beneath the supplied roots.
    async fn scan(&self, request: ScanRequest) -> Result<ScanResult, HostError>;
    /// Creates, prepares, restores, and transfers a new instance.
    async fn prepare(&self, request: PrepareRequest) -> Result<PreparedExternalPlugin, HostError>;
    /// Returns optional features exposed by a live instance.
    async fn capabilities(
        &self,
        instance: ExternalPluginInstanceHandle,
    ) -> Result<HostCapabilities, HostError>;
    /// Captures fresh opaque native state.
    async fn capture_state(
        &self,
        instance: ExternalPluginInstanceHandle,
    ) -> Result<PluginState, HostError>;
    /// Restores opaque native state.
    async fn restore_state(
        &self,
        instance: ExternalPluginInstanceHandle,
        state: PluginState,
    ) -> Result<(), HostError>;
    /// Applies one normalized controller value.
    async fn set_parameter(&self, request: SetParameterRequest) -> Result<(), HostError>;
    /// Formats one normalized controller value.
    async fn parameter_text(&self, request: ParameterTextRequest) -> Result<String, HostError>;
    /// Parses controller display text.
    async fn parse_parameter(&self, request: ParseParameterRequest) -> Result<f64, HostError>;
    /// Converts a controller value between normalized and plain domains.
    async fn convert_parameter(&self, request: ConvertParameterRequest) -> Result<f64, HostError>;
    /// Opens or focuses the instance editor.
    async fn open_editor(&self, request: OpenEditorRequest) -> Result<(), HostError>;
    /// Closes the instance editor.
    async fn close_editor(
        &self,
        instance: ExternalPluginInstanceHandle,
    ) -> Result<(), HostError>;
    /// Restores the instance's processing intent after publication.
    async fn resume(&self, instance: ExternalPluginInstanceHandle) -> Result<(), HostError>;
    /// Creates a suspended duplicate of a live instance.
    async fn duplicate(&self, request: DuplicateRequest) -> Result<PreparedExternalPlugin, HostError>;
    /// Creates a suspended realtime replacement.
    async fn reconfigure(
        &self,
        request: ReconfigureRequest,
    ) -> Result<PreparedExternalPlugin, HostError>;
    /// Creates and starts an independent offline instance.
    async fn prepare_offline(
        &self,
        request: OfflinePrepareRequest,
    ) -> Result<PreparedExternalPlugin, HostError>;
    /// Closes editors and destroys a retired native instance.
    async fn destroy(&self, instance: ExternalPluginInstanceHandle) -> Result<(), HostError>;
}
