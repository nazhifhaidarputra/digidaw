use std::path::PathBuf;

use karbeat_plugin_api::prelude::ParameterSpec;

use crate::{
    HostCapabilities, HostError, HostEvent, HostInstanceId, NativeParentHandle,
    NativeSurfacePreference, NativeWindowConstraints, NativeWindowSize, PluginDescriptor,
    PluginFormat, PluginState, ProcessingConfig,
};

pub trait PluginScanner {
    fn format(&self) -> PluginFormat;
    fn default_scan_paths(&self) -> Vec<PathBuf>;
}

/// All methods run on the native UI thread. Processing endpoints have exclusive DSP access.
pub trait PluginInstanceManager {
    fn create(&mut self, descriptor: &PluginDescriptor) -> Result<HostInstanceId, HostError>;
    fn capabilities(&mut self, instance: HostInstanceId) -> Result<HostCapabilities, HostError>;
    fn prepare(
        &mut self,
        instance: HostInstanceId,
        config: &ProcessingConfig,
    ) -> Result<(), HostError>;
    fn take_processor(
        &mut self,
        instance: HostInstanceId,
    ) -> Result<Box<crate::HostedProcessor>, HostError>;
    fn suspend(&mut self, instance: HostInstanceId) -> Result<(), HostError>;
    fn resume(&mut self, instance: HostInstanceId) -> Result<(), HostError>;
    /// Control-side processing intent, including a suspension waiting for its audio acknowledgement.
    fn is_processing(&self, instance: HostInstanceId) -> Result<bool, HostError>;
    /// Fails while an audio endpoint still owns the instance; destruction never runs in DSP.
    fn destroy(&mut self, instance: HostInstanceId) -> Result<(), HostError>;
}

pub trait PluginController {
    fn parameters(&self, instance: HostInstanceId) -> Result<Vec<ParameterSpec>, HostError>;
    fn set_parameter(
        &mut self,
        instance: HostInstanceId,
        parameter: u32,
        value: f64,
    ) -> Result<(), HostError>;
    fn normalized_to_plain(
        &self,
        _instance: HostInstanceId,
        _parameter: u32,
        _value: f64,
    ) -> Result<f64, HostError> {
        Err(HostError::Unsupported("parameter conversion"))
    }
    fn plain_to_normalized(
        &self,
        _instance: HostInstanceId,
        _parameter: u32,
        _value: f64,
    ) -> Result<f64, HostError> {
        Err(HostError::Unsupported("parameter conversion"))
    }
    fn parameter_text(
        &self,
        _instance: HostInstanceId,
        _parameter: u32,
        _value: f64,
    ) -> Result<String, HostError> {
        Err(HostError::Unsupported("parameter formatting"))
    }
    fn parse_parameter(
        &self,
        _instance: HostInstanceId,
        _parameter: u32,
        _text: &str,
    ) -> Result<f64, HostError> {
        Err(HostError::Unsupported("parameter parsing"))
    }
    /// Flush queued control changes while suspended, without capturing plugin state.
    fn flush_parameters(&mut self, _instance: HostInstanceId) -> Result<(), HostError> {
        Err(HostError::Unsupported("parameter flushing"))
    }
    /// Leaves the instance suspended. Use a StateTransaction to preserve its prior running state.
    fn save_state(&mut self, instance: HostInstanceId) -> Result<PluginState, HostError>;
    fn restore_state(
        &mut self,
        instance: HostInstanceId,
        state: &PluginState,
    ) -> Result<(), HostError>;
    fn drain_events(&mut self) -> Vec<HostEvent>;
}

/// Handles are native windows owned by the platform window service, never Flutter views.
pub trait PluginEditorManager {
    fn editor_size(&mut self, instance: HostInstanceId) -> Result<NativeWindowSize, HostError>;
    fn editor_constraints(
        &mut self,
        instance: HostInstanceId,
    ) -> Result<NativeWindowConstraints, HostError>;
    fn editor_surface_preference(
        &self,
        instance: HostInstanceId,
    ) -> Result<NativeSurfacePreference, HostError>;
    fn open_editor(
        &mut self,
        instance: HostInstanceId,
        parent: &NativeParentHandle,
    ) -> Result<(), HostError>;
    fn resize_editor(
        &mut self,
        instance: HostInstanceId,
        width: u32,
        height: u32,
    ) -> Result<(), HostError>;
    fn close_editor(&mut self, instance: HostInstanceId) -> Result<(), HostError>;
}

/// Implemented by Vst3PluginHost; future Lv2PluginHost, ClapPluginHost and AuPluginHost
/// implement the same contracts without introducing format switches in the audio engine.
pub trait DigidawPluginHost:
    PluginScanner + PluginInstanceManager + PluginController + PluginEditorManager
{
}
