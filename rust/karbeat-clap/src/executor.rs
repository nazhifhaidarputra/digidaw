use std::path::PathBuf;

use karbeat_host_api::{
    ConvertParameterRequest, DuplicateRequest, ExternalPluginInstanceHandle, HostCapabilities,
    HostError, OfflinePrepareRequest, OpenEditorRequest, ParameterTextRequest,
    ParseParameterRequest, PluginController, PluginFormat, PluginFormatExecutor,
    PluginInstanceManager, PluginState, PrepareRequest, PreparedExternalPlugin, ReconfigureRequest,
    ScanRequest, SetParameterRequest,
    scanner::{ModuleScanner, ScanCache, ScanResult, ScanSettings},
};

use crate::{module, native};

/// Statically dispatched CLAP executor backed by the native UI owner.
#[derive(Clone, Copy, Debug, Default)]
pub struct ClapExecutor;

impl ClapExecutor {
    fn checked(
        instance: ExternalPluginInstanceHandle,
    ) -> Result<karbeat_host_api::HostInstanceId, HostError> {
        if instance.format != PluginFormat::Clap {
            return Err(HostError::Unsupported(
                "non-CLAP handle routed to CLAP executor",
            ));
        }
        Ok(instance.id)
    }

    fn prepared(value: native::PreparedNativeInstance) -> PreparedExternalPlugin {
        PreparedExternalPlugin {
            instance: ExternalPluginInstanceHandle {
                format: PluginFormat::Clap,
                id: value.instance,
            },
            capabilities: value.capabilities,
            parameters: value.parameters,
            state: value.state,
            processor: value.processor,
        }
    }

    /// Runs one blocking scan, including cache load and save.
    ///
    /// Loading a module initialises its entry, which runs plugin code, so each module is probed
    /// by the isolated scanner helper.
    fn scan_blocking(request: ScanRequest) -> Result<ScanResult, HostError> {
        let settings = ScanSettings {
            directories: request.directories,
            timeout_seconds: request.timeout_seconds,
        };
        let helper = karbeat_host_api::scanner::scanner_executable()?;
        let mut cache = if let Some(path) = &request.cache_path {
            ScanCache::load(path)?
        } else {
            ScanCache::default()
        };
        let progress = request.progress;
        let result = karbeat_host_api::scanner::scan(
            &ModuleScanner {
                format: PluginFormat::Clap,
                extension: module::MODULE_EXTENSION,
                probe: &karbeat_host_api::scanner::helper_probe(&helper, PluginFormat::Clap),
            },
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
}

impl PluginFormatExecutor for ClapExecutor {
    fn format(&self) -> PluginFormat {
        PluginFormat::Clap
    }

    fn default_scan_paths(&self) -> Vec<PathBuf> {
        module::default_scan_paths()
    }

    async fn scan(&self, mut request: ScanRequest) -> Result<ScanResult, HostError> {
        request.directories.extend(self.default_scan_paths());
        // The scanner waits on helper processes. Running it on its own thread keeps this
        // executor serving prepare, parameter and editor requests during a scan.
        let (reply, result) = tokio::sync::oneshot::channel();
        std::thread::Builder::new()
            .name("clap-scan".into())
            .spawn(move || drop(reply.send(Self::scan_blocking(request))))?;
        result
            .await
            .map_err(|_| HostError::Scanner("scan thread stopped without a result".into()))?
    }

    async fn prepare(&self, request: PrepareRequest) -> Result<PreparedExternalPlugin, HostError> {
        native::prepare_instance(request.descriptor, request.config, request.state)
            .await
            .map(Self::prepared)
    }

    async fn capabilities(
        &self,
        instance: ExternalPluginInstanceHandle,
    ) -> Result<HostCapabilities, HostError> {
        let id = Self::checked(instance)?;
        native::call(move |owner| owner.host.capabilities(id)).await
    }

    async fn capture_state(
        &self,
        instance: ExternalPluginInstanceHandle,
    ) -> Result<PluginState, HostError> {
        native::capture_state(Self::checked(instance)?).await
    }

    async fn restore_state(
        &self,
        instance: ExternalPluginInstanceHandle,
        state: PluginState,
    ) -> Result<(), HostError> {
        native::restore_state(Self::checked(instance)?, state).await
    }

    async fn set_parameter(&self, request: SetParameterRequest) -> Result<(), HostError> {
        let id = Self::checked(request.instance)?;
        native::call(move |owner| {
            owner
                .host
                .set_parameter(id, request.parameter, request.value)
        })
        .await
    }

    async fn parameter_text(&self, request: ParameterTextRequest) -> Result<String, HostError> {
        let id = Self::checked(request.instance)?;
        native::call(move |owner| {
            owner
                .host
                .parameter_text(id, request.parameter, request.value)
        })
        .await
    }

    async fn parse_parameter(&self, request: ParseParameterRequest) -> Result<f64, HostError> {
        let id = Self::checked(request.instance)?;
        native::call(move |owner| {
            owner
                .host
                .parse_parameter(id, request.parameter, &request.text)
        })
        .await
    }

    async fn convert_parameter(&self, request: ConvertParameterRequest) -> Result<f64, HostError> {
        let id = Self::checked(request.instance)?;
        native::call(move |owner| {
            if request.to_normalized {
                owner
                    .host
                    .plain_to_normalized(id, request.parameter, request.value)
            } else {
                owner
                    .host
                    .normalized_to_plain(id, request.parameter, request.value)
            }
        })
        .await
    }

    async fn open_editor(&self, request: OpenEditorRequest) -> Result<(), HostError> {
        let id = Self::checked(request.instance)?;
        native::call(move |owner| {
            owner.set_editor_context(id, request.context)?;
            owner.open_editor(id)
        })
        .await
    }

    async fn close_editor(&self, instance: ExternalPluginInstanceHandle) -> Result<(), HostError> {
        let id = Self::checked(instance)?;
        native::call(move |owner| owner.close_editor(id)).await
    }

    async fn resume(&self, instance: ExternalPluginInstanceHandle) -> Result<(), HostError> {
        let id = Self::checked(instance)?;
        native::call(move |owner| owner.host.resume(id)).await
    }

    async fn duplicate(
        &self,
        request: DuplicateRequest,
    ) -> Result<PreparedExternalPlugin, HostError> {
        native::duplicate_instance(Self::checked(request.instance)?)
            .await
            .map(Self::prepared)
    }

    async fn reconfigure(
        &self,
        request: ReconfigureRequest,
    ) -> Result<PreparedExternalPlugin, HostError> {
        native::prepare_reconfigured_instance(
            Self::checked(request.instance)?,
            request.sample_rate,
            request.max_block_size,
        )
        .await
        .map(Self::prepared)
    }

    async fn prepare_offline(
        &self,
        request: OfflinePrepareRequest,
    ) -> Result<PreparedExternalPlugin, HostError> {
        native::prepare_offline_instance(
            Self::checked(request.instance)?,
            request.sample_rate,
            request.max_block_size,
            request.output_channels,
        )
        .await
        .map(Self::prepared)
    }

    async fn destroy(&self, instance: ExternalPluginInstanceHandle) -> Result<(), HostError> {
        let id = Self::checked(instance)?;
        native::call(move |owner| owner.destroy(id)).await
    }
}
