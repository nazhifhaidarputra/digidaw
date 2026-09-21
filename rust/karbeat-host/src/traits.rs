use std::path::PathBuf;

use karbeat_plugin_api::prelude::ParameterSpec;

use crate::{
    HostCapabilities, HostError, HostEvent, HostInstanceId, NativeParentHandle,
    NativeSurfacePreference, NativeWindowConstraints, NativeWindowSize, PluginDescriptor,
    PluginFormat, PluginState, ProcessingConfig,
};

/// Discovers the native format and conventional search roots supported by a backend.
pub trait PluginScanner {
    /// Returns the plugin format handled by this scanner.
    fn format(&self) -> PluginFormat;
    /// Returns conventional discovery roots without requiring them to exist.
    fn default_scan_paths(&self) -> Vec<PathBuf>;
}

/// Captures live plug-in state through the control owner for the active host backend.
pub trait HostStateCapture: Send + Sync {
    /// Captures fresh state for `instance`, verifying it belongs to `identity` when required.
    fn capture_state(
        &self,
        identity: &crate::PluginIdentity,
        instance: HostInstanceId,
    ) -> Result<PluginState, HostError>;
}

impl<F> HostStateCapture for F
where
    F: Fn(&crate::PluginIdentity, HostInstanceId) -> Result<PluginState, HostError> + Send + Sync,
{
    fn capture_state(
        &self,
        identity: &crate::PluginIdentity,
        instance: HostInstanceId,
    ) -> Result<PluginState, HostError> {
        self(identity, instance)
    }
}

/// All methods run on the native UI thread. Processing endpoints have exclusive DSP access.
pub trait PluginInstanceManager {
    /// Creates a UI-thread-owned instance from a discovery descriptor.
    fn create(&mut self, descriptor: &PluginDescriptor) -> Result<HostInstanceId, HostError>;
    /// Returns facilities exposed by a created instance.
    fn capabilities(&mut self, instance: HostInstanceId) -> Result<HostCapabilities, HostError>;
    /// Configures buses, sample rate, block size, and processing mode while suspended.
    fn prepare(
        &mut self,
        instance: HostInstanceId,
        config: &ProcessingConfig,
    ) -> Result<(), HostError>;
    /// Transfers the instance's single DSP endpoint out of the control owner.
    fn take_processor(
        &mut self,
        instance: HostInstanceId,
    ) -> Result<Box<crate::HostedProcessor>, HostError>;
    /// Requests nonblocking suspension and succeeds only after DSP ownership is released.
    fn suspend(&mut self, instance: HostInstanceId) -> Result<(), HostError>;
    /// Publishes prepared control-side changes and allows audio processing to resume.
    fn resume(&mut self, instance: HostInstanceId) -> Result<(), HostError>;
    /// Control-side processing intent, including a suspension waiting for its audio acknowledgement.
    fn is_processing(&self, instance: HostInstanceId) -> Result<bool, HostError>;
    /// Fails while an audio endpoint still owns the instance; destruction never runs in DSP.
    fn destroy(&mut self, instance: HostInstanceId) -> Result<(), HostError>;
}

/// Parameter, event, and opaque-state operations owned by the native control thread.
pub trait PluginController {
    /// Returns parameter specifications exposed by an instance's controller.
    fn parameters(&self, instance: HostInstanceId) -> Result<Vec<ParameterSpec>, HostError>;
    /// Queues or applies a normalized parameter value through the control interface.
    fn set_parameter(
        &mut self,
        instance: HostInstanceId,
        parameter: u32,
        value: f64,
    ) -> Result<(), HostError>;
    /// Converts a normalized value to the plugin's plain parameter domain.
    fn normalized_to_plain(
        &self,
        _instance: HostInstanceId,
        _parameter: u32,
        _value: f64,
    ) -> Result<f64, HostError> {
        Err(HostError::Unsupported("parameter conversion"))
    }
    /// Converts a plain parameter value to the normalized `[0, 1]` domain.
    fn plain_to_normalized(
        &self,
        _instance: HostInstanceId,
        _parameter: u32,
        _value: f64,
    ) -> Result<f64, HostError> {
        Err(HostError::Unsupported("parameter conversion"))
    }
    /// Asks the plugin to format a normalized value for display.
    fn parameter_text(
        &self,
        _instance: HostInstanceId,
        _parameter: u32,
        _value: f64,
    ) -> Result<String, HostError> {
        Err(HostError::Unsupported("parameter formatting"))
    }
    /// Asks the plugin to parse display text into a normalized value.
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
    /// Leaves the instance suspended. The executor restores prior running intent after state work.
    fn save_state(&mut self, instance: HostInstanceId) -> Result<PluginState, HostError>;
    /// Restores opaque state while the instance remains suspended.
    fn restore_state(
        &mut self,
        instance: HostInstanceId,
        state: &PluginState,
    ) -> Result<(), HostError>;
    /// Drains controller/editor events accumulated since the previous call.
    fn drain_events(&mut self) -> Vec<HostEvent>;
}

/// Handles are native windows owned by the platform window service, never Flutter views.
pub trait PluginEditorManager {
    /// Returns the plugin editor's current client-area dimensions.
    fn editor_size(&mut self, instance: HostInstanceId) -> Result<NativeWindowSize, HostError>;
    /// Returns fixed or resizable bounds reported by the plugin editor.
    fn editor_constraints(
        &mut self,
        instance: HostInstanceId,
    ) -> Result<NativeWindowConstraints, HostError>;
    /// Returns the native surface kind required or preferred by the plugin.
    fn editor_surface_preference(
        &self,
        instance: HostInstanceId,
    ) -> Result<NativeSurfacePreference, HostError>;
    /// Attaches the plugin view to an already-created host native window.
    fn open_editor(
        &mut self,
        instance: HostInstanceId,
        parent: &NativeParentHandle,
    ) -> Result<(), HostError>;
    /// Negotiates and applies a new plugin editor client size.
    fn resize_editor(
        &mut self,
        instance: HostInstanceId,
        width: u32,
        height: u32,
    ) -> Result<(), HostError>;
    /// Detaches and releases the plugin editor view without destroying the processor instance.
    fn close_editor(&mut self, instance: HostInstanceId) -> Result<(), HostError>;
}

/// Implemented by Vst3PluginHost; future Lv2PluginHost, ClapPluginHost and AuPluginHost
/// implement the same contracts without introducing format switches in the audio engine.
pub trait DigidawPluginHost:
    PluginScanner + PluginInstanceManager + PluginController + PluginEditorManager
{
}
