use std::path::PathBuf;

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub enum PluginFormat {
    Vst3,
    Lv2,
    Clap,
    Au,
}

/// Format-native identity, independent of installation location and UI registry IDs.
#[derive(Clone, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub struct PluginIdentity {
    pub format: PluginFormat,
    pub native_id: String,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum PluginKind {
    Instrument,
    Effect,
    MidiEffect,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct PluginDescriptor {
    pub identity: PluginIdentity,
    pub path: PathBuf,
    pub name: String,
    pub vendor: String,
    pub version: String,
    pub kind: PluginKind,
}

/// IDs are never reused during a host's lifetime.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub struct HostInstanceId(pub u64);

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct HostCapabilities {
    pub controller: bool,
    pub editor: bool,
    pub sidechain: bool,
    pub offline: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ProcessingConfig {
    pub sample_rate: f64,
    pub max_block_size: usize,
    pub main_input_channels: usize,
    pub main_output_channels: usize,
    pub sidechain_channels: usize,
    pub offline: bool,
}

impl ProcessingConfig {
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
    pub version: u32,
    pub identity: PluginIdentity,
    pub component: Vec<u8>,
    pub controller: Option<Vec<u8>>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum HostEvent {
    BeginEdit {
        instance: HostInstanceId,
        parameter: u32,
    },
    ParameterChanged {
        instance: HostInstanceId,
        parameter: u32,
        value: f64,
    },
    EndEdit {
        instance: HostInstanceId,
        parameter: u32,
    },
    RestartRequested {
        instance: HostInstanceId,
        flags: u32,
    },
    EditorClosed {
        instance: HostInstanceId,
    },
    QueueOverflow {
        instance: HostInstanceId,
    },
}

#[derive(Debug, thiserror::Error)]
pub enum HostError {
    #[error("plugin operation must run on the native UI thread")]
    WrongThread,
    #[error("unknown or retired plugin instance {0:?}")]
    UnknownInstance(HostInstanceId),
    #[error("plugin instance is busy; wait for audio suspension acknowledgement")]
    Busy,
    #[error("plugin state request was cancelled before execution")]
    Cancelled,
    #[error("could not resume plugin processing: {resume}; state operation error: {operation:?}")]
    StateResume {
        operation: Option<Box<HostError>>,
        resume: Box<HostError>,
    },
    #[error("plugin operation failed: {operation}; rollback also failed: {cleanup}")]
    LifecycleCleanup {
        operation: Box<HostError>,
        cleanup: Box<HostError>,
    },
    #[error("invalid plugin lifecycle transition")]
    InvalidTransition,
    #[error("invalid audio configuration")]
    InvalidConfiguration,
    #[error("unsupported plugin capability: {0}")]
    Unsupported(&'static str),
    #[error("plugin module {path:?}: {message}")]
    Module { path: PathBuf, message: String },
    #[error("plugin operation {operation} failed with result {code}")]
    PluginCall { operation: &'static str, code: i32 },
    #[error("invalid plugin state: {0}")]
    InvalidState(String),
    #[error("plugin parameter {0} is unavailable or its value is invalid")]
    InvalidParameter(u32),
    #[error("plugin scanner protocol: {0}")]
    Scanner(String),
    #[error("native plugin dispatch: {0}")]
    NativeDispatch(String),
    #[error(transparent)]
    NativeUi(#[from] crate::native_ui::NativeUiError),
    #[error("plugin I/O: {0}")]
    Io(#[from] std::io::Error),
}
