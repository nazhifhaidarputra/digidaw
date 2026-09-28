use std::path::PathBuf;

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
/// Native plugin ABI understood by a host backend.
pub enum PluginFormat {
    /// Steinberg VST3 plugin.
    Vst3,
    /// Linux Audio Developer's Simple Plugin API plugin.
    Lv2,
    /// CLAP plugin.
    Clap,
}

/// Format-native identity, independent of installation location and UI registry IDs.
#[derive(Clone, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub struct PluginIdentity {
    /// ABI used to interpret `native_id` and load the plugin.
    pub format: PluginFormat,
    /// Stable identifier assigned by the native plugin format, independent of its file path.
    pub native_id: String,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
/// High-level processing role advertised by a plugin class.
pub enum PluginKind {
    /// Produces audio, commonly from note or event input.
    Instrument,
    /// Processes an existing audio signal.
    Effect,
    /// Transforms event or note data rather than audio.
    MidiEffect,
}

/// Discovery metadata required to identify and instantiate one native plugin class.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct PluginDescriptor {
    /// Format-native identity persisted independently of installation location.
    pub identity: PluginIdentity,
    /// Module or bundle path used for this installation.
    pub path: PathBuf,
    /// Human-readable class name reported by the plugin.
    pub name: String,
    /// Vendor name reported by the plugin or its factory.
    pub vendor: String,
    /// Plugin version string, if supplied by the native format.
    pub version: String,
    /// Processing role inferred from native class metadata.
    pub kind: PluginKind,
}

/// Runtime-generated host external plugin instance ID handle.
/// IDs are never reused during a host's lifetime.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub struct HostInstanceId(pub u64);

/// Runtime instance handle paired with the ABI executor that owns it.
///
/// The handle is never serialized; projects persist [`PluginIdentity`] instead.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub struct ExternalPluginInstanceHandle {
    /// External plugin ABI used to route control operations.
    pub format: PluginFormat,
    /// Executor-local runtime identifier.
    pub id: HostInstanceId,
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
/// Optional facilities exposed by a created plugin instance.
pub struct HostCapabilities {
    /// Whether a parameter/edit controller is available.
    pub controller: bool,
    /// Whether the instance can create a native editor view.
    pub editor: bool,
    /// Whether a sidechain input bus is available and activatable.
    pub sidechain: bool,
    /// Whether the backend can prepare the instance for offline rendering.
    pub offline: bool,
}

#[derive(Clone, Debug, PartialEq)]
/// Audio layout and execution mode used to prepare a native processor.
pub struct ProcessingConfig {
    /// Processing sample rate in hertz; must be finite and positive.
    pub sample_rate: f64,
    /// Largest block the host may submit after preparation.
    pub max_block_size: usize,
    /// Number of channels requested on the main input bus.
    pub main_input_channels: usize,
    /// Number of channels requested on the main output bus.
    pub main_output_channels: usize,
    /// Number of channels requested on the sidechain input bus.
    pub sidechain_channels: usize,
    /// Whether the processor is being configured for non-real-time rendering.
    pub offline: bool,
}

impl ProcessingConfig {
    /// Validates the format-independent limits enforced before backend preparation.
    ///
    /// Configurations allow at most stereo input/output/sidechain buses, require one or two
    /// output channels, and cap the maximum block size at 65,536 frames.
    pub fn validate(&self) -> Result<(), HostError> {
        if !self.sample_rate.is_finite()
            || self.sample_rate <= 0.0
            || self.max_block_size == 0
            || self.max_block_size > 65_536
            || self.main_input_channels > 2
            || !(1..=2).contains(&self.main_output_channels)
            || self.sidechain_channels > 2
        {
            return Err(HostError::InvalidConfiguration);
        }
        Ok(())
    }
}

/// An opaque, versioned backend state. Native bytes are never interpreted by core.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct PluginState {
    /// Host serialization version for this opaque state envelope.
    pub version: u32,
    /// Plugin identity the native bytes belong to.
    pub identity: PluginIdentity,
    /// Opaque processor/component state returned by the native ABI.
    pub component: Vec<u8>,
    /// Optional opaque controller state when the format exposes it separately.
    pub controller: Option<Vec<u8>>,
}

#[derive(Clone, Debug, PartialEq)]
/// Control and editor notifications emitted by a hosted plugin instance.
pub enum HostEvent {
    /// Begins an automation gesture for a parameter.
    BeginEdit {
        /// Instance that initiated the gesture.
        instance: HostInstanceId,
        /// Format-native parameter identifier.
        parameter: u32,
    },
    /// Reports a normalized parameter value changed by the plugin or editor.
    ParameterChanged {
        /// Instance whose parameter changed.
        instance: HostInstanceId,
        /// Format-native parameter identifier.
        parameter: u32,
        /// New normalized value.
        value: f64,
    },
    /// Ends an automation gesture for a parameter.
    EndEdit {
        /// Instance that ended the gesture.
        instance: HostInstanceId,
        /// Format-native parameter identifier.
        parameter: u32,
    },
    /// Requests host-side restart or reconfiguration using native restart flags.
    RestartRequested {
        /// Instance requesting the restart.
        instance: HostInstanceId,
        /// Bit flags defined by the native plugin format.
        flags: u32,
    },
    /// Reports that the user or platform closed an editor window.
    EditorClosed {
        /// Instance whose editor closed.
        instance: HostInstanceId,
    },
    /// Reports that bounded event storage discarded at least one event.
    QueueOverflow {
        /// Instance associated with the discarded event.
        instance: HostInstanceId,
    },
}

#[derive(Debug, thiserror::Error)]
/// Failures shared by format-independent hosting and native backend implementations.
pub enum HostError {
    /// Operation was invoked from a thread other than the native owner.
    #[error("plugin operation must run on the native UI thread")]
    WrongThread,
    /// Runtime handle no longer identifies a live instance.
    #[error("unknown or retired plugin instance {0:?}")]
    UnknownInstance(HostInstanceId),
    /// Instance cannot transition yet, commonly because an audio block still owns DSP access.
    #[error("plugin instance is busy; wait for audio suspension acknowledgement")]
    Busy,
    /// An isolated discovery scan was cancelled before it completed.
    #[error("plugin discovery was cancelled")]
    Cancelled,
    /// Restoring the prior running state failed after a state operation or suspension failure.
    #[error("could not resume plugin processing: {resume}; state operation error: {operation:?}")]
    StateResume {
        /// State-operation error, if one occurred before resume also failed.
        operation: Option<Box<HostError>>,
        /// Error returned while restoring the previous running state.
        resume: Box<HostError>,
    },
    /// Rolling back a partially completed lifecycle operation also failed.
    #[error("plugin operation failed: {operation}; rollback also failed: {cleanup}")]
    LifecycleCleanup {
        /// Original lifecycle operation failure.
        operation: Box<HostError>,
        /// Additional failure encountered while rolling back partial state.
        cleanup: Box<HostError>,
    },
    /// Requested operation is not legal in the instance's current lifecycle state.
    #[error("invalid plugin lifecycle transition")]
    InvalidTransition,
    /// Processing layout, sample rate, or block-size configuration failed validation.
    #[error("invalid audio configuration")]
    InvalidConfiguration,
    /// Plugin or backend does not implement the requested optional facility.
    #[error("unsupported plugin capability: {0}")]
    Unsupported(&'static str),
    /// Native module loading, initialization, or factory enumeration failed.
    #[error("plugin module {path:?}: {message}")]
    Module {
        /// Module or bundle path involved in the failure.
        path: PathBuf,
        /// Loader or factory diagnostic.
        message: String,
    },
    /// Native plugin interface returned a non-success result code.
    #[error("plugin operation {operation} failed with result {code}")]
    PluginCall {
        /// Native operation that returned a failure result.
        operation: &'static str,
        /// Format-native result code.
        code: i32,
    },
    /// Opaque state envelope or native state bytes were incompatible or malformed.
    #[error("invalid plugin state: {0}")]
    InvalidState(String),
    /// Parameter identifier is unknown or the supplied value is not accepted.
    #[error("plugin parameter {0} is unavailable or its value is invalid")]
    InvalidParameter(u32),
    /// Discovery helper, protocol, descriptor validation, or cache operation failed.
    #[error("plugin scanner protocol: {0}")]
    Scanner(String),
    /// Cross-thread native-owner dispatch failed.
    #[error("native plugin dispatch: {0}")]
    NativeDispatch(String),
    /// The bounded control request queue has no available capacity.
    #[error("external plugin host request queue is full")]
    QueueFull,
    /// The asynchronous host service is shutting down or unavailable.
    #[error("external plugin host runtime is unavailable")]
    RuntimeUnavailable,
    /// Native editor windowing or UI dispatch failed.
    #[error(transparent)]
    NativeUi(#[from] crate::native_ui::NativeUiError),
    /// Filesystem, process, or state-stream I/O failed.
    #[error("plugin I/O: {0}")]
    Io(#[from] std::io::Error),
}
