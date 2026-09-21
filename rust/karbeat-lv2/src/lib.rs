//! LV2 format executor slot.

use karbeat_host_api::{
    ConvertParameterRequest, DuplicateRequest, ExternalPluginInstanceHandle, HostCapabilities,
    HostError, OfflinePrepareRequest, OpenEditorRequest, ParameterTextRequest,
    ParseParameterRequest, PluginFormat, PluginFormatExecutor, PluginState,
    PrepareRequest, PreparedExternalPlugin, ReconfigureRequest, ScanRequest, SetParameterRequest,
};

/// Statically dispatched LV2 executor.
#[derive(Clone, Copy, Debug, Default)]
pub struct Lv2Executor;

impl Lv2Executor {
    fn unsupported<T>() -> Result<T, HostError> {
        Err(HostError::Unsupported("LV2 hosting is not implemented"))
    }
}

impl PluginFormatExecutor for Lv2Executor {
    fn format(&self) -> PluginFormat { PluginFormat::Lv2 }
    fn default_scan_paths(&self) -> Vec<std::path::PathBuf> { Vec::new() }
    async fn scan(&self, _: ScanRequest) -> Result<karbeat_host_api::scanner::ScanResult, HostError> { Self::unsupported() }
    async fn prepare(&self, _: PrepareRequest) -> Result<PreparedExternalPlugin, HostError> { Self::unsupported() }
    async fn capabilities(&self, _: ExternalPluginInstanceHandle) -> Result<HostCapabilities, HostError> { Self::unsupported() }
    async fn capture_state(&self, _: ExternalPluginInstanceHandle) -> Result<PluginState, HostError> { Self::unsupported() }
    async fn restore_state(&self, _: ExternalPluginInstanceHandle, _: PluginState) -> Result<(), HostError> { Self::unsupported() }
    async fn set_parameter(&self, _: SetParameterRequest) -> Result<(), HostError> { Self::unsupported() }
    async fn parameter_text(&self, _: ParameterTextRequest) -> Result<String, HostError> { Self::unsupported() }
    async fn parse_parameter(&self, _: ParseParameterRequest) -> Result<f64, HostError> { Self::unsupported() }
    async fn convert_parameter(&self, _: ConvertParameterRequest) -> Result<f64, HostError> { Self::unsupported() }
    async fn open_editor(&self, _: OpenEditorRequest) -> Result<(), HostError> { Self::unsupported() }
    async fn close_editor(&self, _: ExternalPluginInstanceHandle) -> Result<(), HostError> { Self::unsupported() }
    async fn resume(&self, _: ExternalPluginInstanceHandle) -> Result<(), HostError> { Self::unsupported() }
    async fn duplicate(&self, _: DuplicateRequest) -> Result<PreparedExternalPlugin, HostError> { Self::unsupported() }
    async fn reconfigure(&self, _: ReconfigureRequest) -> Result<PreparedExternalPlugin, HostError> { Self::unsupported() }
    async fn prepare_offline(&self, _: OfflinePrepareRequest) -> Result<PreparedExternalPlugin, HostError> { Self::unsupported() }
    async fn destroy(&self, _: ExternalPluginInstanceHandle) -> Result<(), HostError> { Self::unsupported() }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn occupies_the_lv2_dispatch_slot() {
        assert_eq!(Lv2Executor.format(), PluginFormat::Lv2);
    }
}
