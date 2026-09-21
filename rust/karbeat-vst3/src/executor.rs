use karbeat_host_api::{
    ConvertParameterRequest, DuplicateRequest, ExternalPluginInstanceHandle, HostCapabilities,
    HostError, OfflinePrepareRequest, OpenEditorRequest, ParameterTextRequest,
    ParseParameterRequest, PluginController, PluginFormat, PluginFormatExecutor,
    PluginInstanceManager, PluginState, PrepareRequest, PreparedExternalPlugin,
    ReconfigureRequest, ScanRequest, SetParameterRequest,
};

use crate::native;

/// Statically dispatched VST3 executor backed by the native UI owner.
#[derive(Clone, Copy, Debug, Default)]
pub struct Vst3Executor;

impl Vst3Executor {
    fn checked(instance: ExternalPluginInstanceHandle) -> Result<karbeat_host_api::HostInstanceId, HostError> {
        if instance.format != PluginFormat::Vst3 {
            return Err(HostError::Unsupported("non-VST3 handle routed to VST3 executor"));
        }
        Ok(instance.id)
    }

    fn prepared(value: native::PreparedNativeInstance) -> PreparedExternalPlugin {
        PreparedExternalPlugin {
            instance: ExternalPluginInstanceHandle {
                format: PluginFormat::Vst3,
                id: value.instance,
            },
            capabilities: value.capabilities,
            parameters: value.parameters,
            state: value.state,
            processor: value.processor,
        }
    }
}

impl PluginFormatExecutor for Vst3Executor {
    fn format(&self) -> PluginFormat { PluginFormat::Vst3 }

    fn default_scan_paths(&self) -> Vec<std::path::PathBuf> {
        crate::module::default_scan_paths()
    }

    async fn scan(&self, mut request: ScanRequest) -> Result<karbeat_host_api::scanner::ScanResult, HostError> {
        request.directories.extend(self.default_scan_paths());
        let settings = karbeat_host_api::scanner::ScanSettings {
            directories: request.directories,
            timeout_seconds: request.timeout_seconds,
        };
        let helper = karbeat_host_api::scanner::scanner_executable()?;
        let mut cache = if let Some(path) = &request.cache_path {
            karbeat_host_api::scanner::ScanCache::load(path)?
        } else {
            karbeat_host_api::scanner::ScanCache::default()
        };
        let progress = request.progress;
        let result = karbeat_host_api::scanner::scan(
            &helper,
            &settings,
            &mut cache,
            request.retry_quarantined,
            &request.cancelled,
            &mut |update| {
                if let Some(observer) = &progress {
                    observer(update);
                }
            },
        )?;
        if let Some(path) = &request.cache_path {
            cache.save(path)?;
        }
        Ok(result)
    }

    async fn prepare(&self, request: PrepareRequest) -> Result<PreparedExternalPlugin, HostError> {
        native::prepare_instance(request.descriptor, request.config, request.state).await.map(Self::prepared)
    }

    async fn capabilities(&self, instance: ExternalPluginInstanceHandle) -> Result<HostCapabilities, HostError> {
        let id = Self::checked(instance)?;
        native::call(move |owner| owner.host.capabilities(id)).await
    }

    async fn capture_state(&self, instance: ExternalPluginInstanceHandle) -> Result<PluginState, HostError> {
        native::capture_state(Self::checked(instance)?).await
    }

    async fn restore_state(&self, instance: ExternalPluginInstanceHandle, state: PluginState) -> Result<(), HostError> {
        native::restore_state(Self::checked(instance)?, state).await
    }

    async fn set_parameter(&self, request: SetParameterRequest) -> Result<(), HostError> {
        let id = Self::checked(request.instance)?;
        native::call(move |owner| owner.host.set_parameter(id, request.parameter, request.value)).await
    }

    async fn parameter_text(&self, request: ParameterTextRequest) -> Result<String, HostError> {
        let id = Self::checked(request.instance)?;
        native::call(move |owner| owner.host.parameter_text(id, request.parameter, request.value)).await
    }

    async fn parse_parameter(&self, request: ParseParameterRequest) -> Result<f64, HostError> {
        let id = Self::checked(request.instance)?;
        native::call(move |owner| owner.host.parse_parameter(id, request.parameter, &request.text)).await
    }

    async fn convert_parameter(&self, request: ConvertParameterRequest) -> Result<f64, HostError> {
        let id = Self::checked(request.instance)?;
        native::call(move |owner| {
            if request.to_normalized {
                owner.host.plain_to_normalized(id, request.parameter, request.value)
            } else {
                owner.host.normalized_to_plain(id, request.parameter, request.value)
            }
        }).await
    }

    async fn open_editor(&self, request: OpenEditorRequest) -> Result<(), HostError> {
        let id = Self::checked(request.instance)?;
        native::call(move |owner| {
            owner.set_editor_context(id, request.context)?;
            owner.open_editor(id)
        }).await
    }

    async fn close_editor(&self, instance: ExternalPluginInstanceHandle) -> Result<(), HostError> {
        let id = Self::checked(instance)?;
        native::call(move |owner| owner.close_editor(id)).await
    }

    async fn resume(&self, instance: ExternalPluginInstanceHandle) -> Result<(), HostError> {
        let id = Self::checked(instance)?;
        native::call(move |owner| owner.host.resume(id)).await
    }

    async fn duplicate(&self, request: DuplicateRequest) -> Result<PreparedExternalPlugin, HostError> {
        native::duplicate_instance(Self::checked(request.instance)?).await.map(Self::prepared)
    }

    async fn reconfigure(&self, request: ReconfigureRequest) -> Result<PreparedExternalPlugin, HostError> {
        native::prepare_reconfigured_instance(
            Self::checked(request.instance)?,
            request.sample_rate,
            request.max_block_size,
        ).await.map(Self::prepared)
    }

    async fn prepare_offline(&self, request: OfflinePrepareRequest) -> Result<PreparedExternalPlugin, HostError> {
        native::prepare_offline_instance(
            Self::checked(request.instance)?,
            request.sample_rate,
            request.max_block_size,
            request.output_channels,
        ).await.map(Self::prepared)
    }

    async fn destroy(&self, instance: ExternalPluginInstanceHandle) -> Result<(), HostError> {
        let id = Self::checked(instance)?;
        native::call(move |owner| owner.destroy(id)).await
    }
}
