//! Asynchronous, format-independent control facade for external plugin execution.
//!
//! Requests use a bounded Tokio channel and one-shot completion while an OS-agnostic local
//! executor drives concrete VST3, CLAP, and LV2 executors. Format routing is exhaustive and
//! statically dispatched; audio-thread processor transfer remains in the shared API crate.
//! A Tokio watch signal stops admission, drains accepted work, and marks the service unavailable.

use std::{path::PathBuf, sync::OnceLock};

use async_executor::LocalExecutor;
use tokio::sync::{mpsc, oneshot, watch};

pub use karbeat_host_api::*;

const HOST_REQUEST_CAPACITY: usize = 128;
static DEFAULT_CLIENT: OnceLock<HostClient> = OnceLock::new();

/// Concrete executor slots for the three supported external plugin formats.
#[derive(Clone)]
pub struct PluginExecutors<V, C, L> {
    vst3: V,
    clap: C,
    lv2: L,
}

impl<V, C, L> PluginExecutors<V, C, L>
where
    V: PluginFormatExecutor,
    C: PluginFormatExecutor,
    L: PluginFormatExecutor,
{
    /// Creates the statically dispatched executor set.
    pub fn new(vst3: V, clap: C, lv2: L) -> Self {
        debug_assert_eq!(vst3.format(), PluginFormat::Vst3);
        debug_assert_eq!(clap.format(), PluginFormat::Clap);
        debug_assert_eq!(lv2.format(), PluginFormat::Lv2);
        Self { vst3, clap, lv2 }
    }

    async fn scan(
        &self,
        format: PluginFormat,
        request: ScanRequest,
    ) -> Result<scanner::ScanResult, HostError> {
        match format {
            PluginFormat::Vst3 => self.vst3.scan(request).await,
            PluginFormat::Clap => self.clap.scan(request).await,
            PluginFormat::Lv2 => self.lv2.scan(request).await,
        }
    }

    fn default_scan_paths(&self, format: PluginFormat) -> Vec<PathBuf> {
        match format {
            PluginFormat::Vst3 => self.vst3.default_scan_paths(),
            PluginFormat::Clap => self.clap.default_scan_paths(),
            PluginFormat::Lv2 => self.lv2.default_scan_paths(),
        }
    }

    async fn prepare(&self, request: PrepareRequest) -> Result<PreparedExternalPlugin, HostError> {
        match request.descriptor.identity.format {
            PluginFormat::Vst3 => self.vst3.prepare(request).await,
            PluginFormat::Clap => self.clap.prepare(request).await,
            PluginFormat::Lv2 => self.lv2.prepare(request).await,
        }
    }

    async fn capabilities(
        &self,
        instance: ExternalPluginInstanceHandle,
    ) -> Result<HostCapabilities, HostError> {
        match instance.format {
            PluginFormat::Vst3 => self.vst3.capabilities(instance).await,
            PluginFormat::Clap => self.clap.capabilities(instance).await,
            PluginFormat::Lv2 => self.lv2.capabilities(instance).await,
        }
    }

    async fn capture_state(
        &self,
        instance: ExternalPluginInstanceHandle,
    ) -> Result<PluginState, HostError> {
        match instance.format {
            PluginFormat::Vst3 => self.vst3.capture_state(instance).await,
            PluginFormat::Clap => self.clap.capture_state(instance).await,
            PluginFormat::Lv2 => self.lv2.capture_state(instance).await,
        }
    }

    async fn restore_state(
        &self,
        instance: ExternalPluginInstanceHandle,
        state: PluginState,
    ) -> Result<(), HostError> {
        match instance.format {
            PluginFormat::Vst3 => self.vst3.restore_state(instance, state).await,
            PluginFormat::Clap => self.clap.restore_state(instance, state).await,
            PluginFormat::Lv2 => self.lv2.restore_state(instance, state).await,
        }
    }

    async fn set_parameter(&self, request: SetParameterRequest) -> Result<(), HostError> {
        match request.instance.format {
            PluginFormat::Vst3 => self.vst3.set_parameter(request).await,
            PluginFormat::Clap => self.clap.set_parameter(request).await,
            PluginFormat::Lv2 => self.lv2.set_parameter(request).await,
        }
    }

    async fn parameter_text(&self, request: ParameterTextRequest) -> Result<String, HostError> {
        match request.instance.format {
            PluginFormat::Vst3 => self.vst3.parameter_text(request).await,
            PluginFormat::Clap => self.clap.parameter_text(request).await,
            PluginFormat::Lv2 => self.lv2.parameter_text(request).await,
        }
    }

    async fn parse_parameter(&self, request: ParseParameterRequest) -> Result<f64, HostError> {
        match request.instance.format {
            PluginFormat::Vst3 => self.vst3.parse_parameter(request).await,
            PluginFormat::Clap => self.clap.parse_parameter(request).await,
            PluginFormat::Lv2 => self.lv2.parse_parameter(request).await,
        }
    }

    async fn convert_parameter(&self, request: ConvertParameterRequest) -> Result<f64, HostError> {
        match request.instance.format {
            PluginFormat::Vst3 => self.vst3.convert_parameter(request).await,
            PluginFormat::Clap => self.clap.convert_parameter(request).await,
            PluginFormat::Lv2 => self.lv2.convert_parameter(request).await,
        }
    }

    async fn open_editor(&self, request: OpenEditorRequest) -> Result<(), HostError> {
        match request.instance.format {
            PluginFormat::Vst3 => self.vst3.open_editor(request).await,
            PluginFormat::Clap => self.clap.open_editor(request).await,
            PluginFormat::Lv2 => self.lv2.open_editor(request).await,
        }
    }

    async fn close_editor(
        &self,
        instance: ExternalPluginInstanceHandle,
    ) -> Result<(), HostError> {
        match instance.format {
            PluginFormat::Vst3 => self.vst3.close_editor(instance).await,
            PluginFormat::Clap => self.clap.close_editor(instance).await,
            PluginFormat::Lv2 => self.lv2.close_editor(instance).await,
        }
    }

    async fn resume(&self, instance: ExternalPluginInstanceHandle) -> Result<(), HostError> {
        match instance.format {
            PluginFormat::Vst3 => self.vst3.resume(instance).await,
            PluginFormat::Clap => self.clap.resume(instance).await,
            PluginFormat::Lv2 => self.lv2.resume(instance).await,
        }
    }

    async fn duplicate(&self, request: DuplicateRequest) -> Result<PreparedExternalPlugin, HostError> {
        match request.instance.format {
            PluginFormat::Vst3 => self.vst3.duplicate(request).await,
            PluginFormat::Clap => self.clap.duplicate(request).await,
            PluginFormat::Lv2 => self.lv2.duplicate(request).await,
        }
    }

    async fn reconfigure(
        &self,
        request: ReconfigureRequest,
    ) -> Result<PreparedExternalPlugin, HostError> {
        match request.instance.format {
            PluginFormat::Vst3 => self.vst3.reconfigure(request).await,
            PluginFormat::Clap => self.clap.reconfigure(request).await,
            PluginFormat::Lv2 => self.lv2.reconfigure(request).await,
        }
    }

    async fn prepare_offline(
        &self,
        request: OfflinePrepareRequest,
    ) -> Result<PreparedExternalPlugin, HostError> {
        match request.instance.format {
            PluginFormat::Vst3 => self.vst3.prepare_offline(request).await,
            PluginFormat::Clap => self.clap.prepare_offline(request).await,
            PluginFormat::Lv2 => self.lv2.prepare_offline(request).await,
        }
    }

    async fn destroy(&self, instance: ExternalPluginInstanceHandle) -> Result<(), HostError> {
        match instance.format {
            PluginFormat::Vst3 => self.vst3.destroy(instance).await,
            PluginFormat::Clap => self.clap.destroy(instance).await,
            PluginFormat::Lv2 => self.lv2.destroy(instance).await,
        }
    }
}

enum HostRequest {
    DefaultScanPaths {
        format: PluginFormat,
        reply: oneshot::Sender<Result<Vec<PathBuf>, HostError>>,
    },
    Scan {
        format: PluginFormat,
        request: ScanRequest,
        reply: oneshot::Sender<Result<scanner::ScanResult, HostError>>,
    },
    Prepare { request: PrepareRequest, reply: oneshot::Sender<Result<PreparedExternalPlugin, HostError>> },
    Capabilities { instance: ExternalPluginInstanceHandle, reply: oneshot::Sender<Result<HostCapabilities, HostError>> },
    CaptureState { instance: ExternalPluginInstanceHandle, reply: oneshot::Sender<Result<PluginState, HostError>> },
    RestoreState { instance: ExternalPluginInstanceHandle, state: PluginState, reply: oneshot::Sender<Result<(), HostError>> },
    SetParameter { request: SetParameterRequest, reply: oneshot::Sender<Result<(), HostError>> },
    ParameterText { request: ParameterTextRequest, reply: oneshot::Sender<Result<String, HostError>> },
    ParseParameter { request: ParseParameterRequest, reply: oneshot::Sender<Result<f64, HostError>> },
    ConvertParameter { request: ConvertParameterRequest, reply: oneshot::Sender<Result<f64, HostError>> },
    OpenEditor { request: OpenEditorRequest, reply: oneshot::Sender<Result<(), HostError>> },
    CloseEditor { instance: ExternalPluginInstanceHandle, reply: oneshot::Sender<Result<(), HostError>> },
    Resume { instance: ExternalPluginInstanceHandle, reply: oneshot::Sender<Result<(), HostError>> },
    Duplicate { request: DuplicateRequest, reply: oneshot::Sender<Result<PreparedExternalPlugin, HostError>> },
    Reconfigure { request: ReconfigureRequest, reply: oneshot::Sender<Result<PreparedExternalPlugin, HostError>> },
    PrepareOffline { request: OfflinePrepareRequest, reply: oneshot::Sender<Result<PreparedExternalPlugin, HostError>> },
    Destroy { instance: ExternalPluginInstanceHandle, reply: oneshot::Sender<Result<(), HostError>> },
}

/// Cloneable format-independent client used by application and core control code.
#[derive(Clone)]
pub struct HostClient {
    tx: mpsc::Sender<HostRequest>,
    shutdown: watch::Sender<bool>,
    available: watch::Receiver<bool>,
}

impl HostClient {
    /// Returns the application-composed client used by context-free discovery entry points.
    pub fn global() -> Result<Self, HostError> {
        DEFAULT_CLIENT
            .get()
            .cloned()
            .ok_or(HostError::RuntimeUnavailable)
    }

    /// Creates a disconnected client suitable for tests that do not execute external plugins.
    pub fn unavailable() -> Self {
        let (tx, rx) = mpsc::channel(1);
        let (shutdown, _) = watch::channel(false);
        let (_, available) = watch::channel(false);
        drop(rx);
        Self {
            tx,
            shutdown,
            available,
        }
    }

    async fn submit<T>(
        &self,
        request: impl FnOnce(oneshot::Sender<Result<T, HostError>>) -> HostRequest,
    ) -> Result<T, HostError> {
        if *self.shutdown.borrow() || !*self.available.borrow() {
            return Err(HostError::RuntimeUnavailable);
        }
        let (reply, receive) = oneshot::channel();
        self.tx.try_send(request(reply)).map_err(|error| match error {
            mpsc::error::TrySendError::Full(_) => HostError::QueueFull,
            mpsc::error::TrySendError::Closed(_) => HostError::RuntimeUnavailable,
        })?;
        receive.await.map_err(|_| HostError::RuntimeUnavailable)?
    }

    /// Stops request admission and waits for accepted control work to finish.
    pub async fn shutdown(&self) {
        let mut available = self.available.clone();
        let _ = self.shutdown.send(true);
        while *available.borrow() && available.changed().await.is_ok() {}
    }

    /// Returns whether the service still accepts control requests.
    pub fn is_available(&self) -> bool {
        *self.available.borrow()
    }

    /// Returns conventional discovery roots for one format.
    pub async fn default_scan_paths(&self, format: PluginFormat) -> Result<Vec<PathBuf>, HostError> {
        self.submit(|reply| HostRequest::DefaultScanPaths { format, reply }).await
    }
    /// Returns conventional discovery roots from every supported format executor.
    pub async fn default_scan_paths_all(&self) -> Result<Vec<PathBuf>, HostError> {
        let mut paths = self.default_scan_paths(PluginFormat::Vst3).await?;
        paths.extend(self.default_scan_paths(PluginFormat::Clap).await?);
        paths.extend(self.default_scan_paths(PluginFormat::Lv2).await?);
        paths.sort_unstable();
        paths.dedup();
        Ok(paths)
    }
    /// Discovers descriptors through the selected format executor.
    pub async fn scan(&self, format: PluginFormat, request: ScanRequest) -> Result<scanner::ScanResult, HostError> {
        self.submit(|reply| HostRequest::Scan { format, request, reply }).await
    }
    /// Discovers plugins through all permanent executor slots.
    pub async fn scan_all(&self, request: ScanRequest) -> Result<scanner::ScanResult, HostError> {
        let mut combined = scanner::ScanResult::default();
        for format in [PluginFormat::Vst3, PluginFormat::Clap, PluginFormat::Lv2] {
            match self.scan(format, request.clone()).await {
                Ok(mut result) => {
                    combined.plugins.append(&mut result.plugins);
                    combined.failures.append(&mut result.failures);
                    combined.cancelled |= result.cancelled;
                }
                Err(HostError::Unsupported(_)) => {}
                Err(error) => return Err(error),
            }
        }
        Ok(combined)
    }
    /// Creates and prepares a new external instance.
    pub async fn prepare(&self, request: PrepareRequest) -> Result<PreparedExternalPlugin, HostError> {
        self.submit(|reply| HostRequest::Prepare { request, reply }).await
    }
    /// Returns optional facilities exposed by a live instance.
    pub async fn capabilities(&self, instance: ExternalPluginInstanceHandle) -> Result<HostCapabilities, HostError> {
        self.submit(|reply| HostRequest::Capabilities { instance, reply }).await
    }
    /// Captures fresh opaque native state.
    pub async fn capture_state(&self, instance: ExternalPluginInstanceHandle) -> Result<PluginState, HostError> {
        self.submit(|reply| HostRequest::CaptureState { instance, reply }).await
    }
    /// Restores opaque native state.
    pub async fn restore_state(&self, instance: ExternalPluginInstanceHandle, state: PluginState) -> Result<(), HostError> {
        self.submit(|reply| HostRequest::RestoreState { instance, state, reply }).await
    }
    /// Applies a normalized controller parameter.
    pub async fn set_parameter(&self, request: SetParameterRequest) -> Result<(), HostError> {
        self.submit(|reply| HostRequest::SetParameter { request, reply }).await
    }
    /// Formats a normalized controller parameter.
    pub async fn parameter_text(&self, request: ParameterTextRequest) -> Result<String, HostError> {
        self.submit(|reply| HostRequest::ParameterText { request, reply }).await
    }
    /// Parses controller display text.
    pub async fn parse_parameter(&self, request: ParseParameterRequest) -> Result<f64, HostError> {
        self.submit(|reply| HostRequest::ParseParameter { request, reply }).await
    }
    /// Converts a controller value between normalized and plain domains.
    pub async fn convert_parameter(&self, request: ConvertParameterRequest) -> Result<f64, HostError> {
        self.submit(|reply| HostRequest::ConvertParameter { request, reply }).await
    }
    /// Opens or focuses the instance editor.
    pub async fn open_editor(&self, request: OpenEditorRequest) -> Result<(), HostError> {
        self.submit(|reply| HostRequest::OpenEditor { request, reply }).await
    }
    /// Closes the instance editor.
    pub async fn close_editor(&self, instance: ExternalPluginInstanceHandle) -> Result<(), HostError> {
        self.submit(|reply| HostRequest::CloseEditor { instance, reply }).await
    }
    /// Restores processing after an endpoint is published.
    pub async fn resume(&self, instance: ExternalPluginInstanceHandle) -> Result<(), HostError> {
        self.submit(|reply| HostRequest::Resume { instance, reply }).await
    }
    /// Creates a suspended duplicate.
    pub async fn duplicate(&self, request: DuplicateRequest) -> Result<PreparedExternalPlugin, HostError> {
        self.submit(|reply| HostRequest::Duplicate { request, reply }).await
    }
    /// Creates a suspended realtime replacement.
    pub async fn reconfigure(&self, request: ReconfigureRequest) -> Result<PreparedExternalPlugin, HostError> {
        self.submit(|reply| HostRequest::Reconfigure { request, reply }).await
    }
    /// Creates and starts an offline rendering instance.
    pub async fn prepare_offline(&self, request: OfflinePrepareRequest) -> Result<PreparedExternalPlugin, HostError> {
        self.submit(|reply| HostRequest::PrepareOffline { request, reply }).await
    }
    /// Destroys a retired native instance on its owner.
    pub async fn destroy(&self, instance: ExternalPluginInstanceHandle) -> Result<(), HostError> {
        self.submit(|reply| HostRequest::Destroy { instance, reply }).await
    }
}

impl HostStateCapture for HostClient {
    fn capture_state(
        &self,
        identity: &PluginIdentity,
        instance: HostInstanceId,
    ) -> Result<PluginState, HostError> {
        futures_lite::future::block_on(self.capture_state(ExternalPluginInstanceHandle {
            format: identity.format,
            id: instance,
        }))
    }
}

/// Owns startup of the bounded asynchronous host request service.
pub struct PluginHostService;

impl PluginHostService {
    /// Starts a local executor on a control thread and returns its cloneable client.
    pub fn start<V, C, L>(vst3: V, clap: C, lv2: L) -> Result<HostClient, HostError>
    where
        V: PluginFormatExecutor,
        C: PluginFormatExecutor,
        L: PluginFormatExecutor,
    {
        let (tx, receiver) = mpsc::channel(HOST_REQUEST_CAPACITY);
        let (shutdown, shutdown_receiver) = watch::channel(false);
        let (availability, available) = watch::channel(true);
        std::thread::Builder::new()
            .name("external-plugin-host".into())
            .spawn(move || {
                run_service(
                    receiver,
                    shutdown_receiver,
                    availability,
                    PluginExecutors::new(vst3, clap, lv2),
                )
            })
            .map_err(HostError::Io)?;
        let client = HostClient {
            tx,
            shutdown,
            available,
        };
        drop(DEFAULT_CLIENT.set(client.clone()));
        Ok(client)
    }
}

fn run_service<V, C, L>(
    mut receiver: mpsc::Receiver<HostRequest>,
    mut shutdown: watch::Receiver<bool>,
    availability: watch::Sender<bool>,
    executors: PluginExecutors<V, C, L>,
)
where
    V: PluginFormatExecutor,
    C: PluginFormatExecutor,
    L: PluginFormatExecutor,
{
    let executor = LocalExecutor::new();
    futures_lite::future::block_on(executor.run(async {
        loop {
            let request = futures_lite::future::race(receiver.recv(), async {
                drop(shutdown.changed().await);
                None
            })
            .await;
            let Some(request) = request else {
                receiver.close();
                break;
            };
            let request_executors = executors.clone();
            executor
                .spawn(handle_request(request_executors, request))
                .detach();
        }
        while let Some(request) = receiver.recv().await {
            let request_executors = executors.clone();
            executor
                .spawn(handle_request(request_executors, request))
                .detach();
        }
        while !executor.is_empty() {
            futures_lite::future::yield_now().await;
        }
    }));
    let _ = availability.send(false);
}

async fn handle_request<V, C, L>(executors: PluginExecutors<V, C, L>, request: HostRequest)
where
    V: PluginFormatExecutor,
    C: PluginFormatExecutor,
    L: PluginFormatExecutor,
{
    macro_rules! complete {
        ($reply:ident, $operation:expr) => {
            if !$reply.is_closed() {
                drop($reply.send($operation.await));
            }
        };
    }
    match request {
        HostRequest::DefaultScanPaths { format, reply } => {
            if !reply.is_closed() {
                drop(reply.send(Ok(executors.default_scan_paths(format))));
            }
        }
        HostRequest::Scan { format, request, reply } => complete!(reply, executors.scan(format, request)),
        HostRequest::Prepare { request, reply } => complete!(reply, executors.prepare(request)),
        HostRequest::Capabilities { instance, reply } => complete!(reply, executors.capabilities(instance)),
        HostRequest::CaptureState { instance, reply } => complete!(reply, executors.capture_state(instance)),
        HostRequest::RestoreState { instance, state, reply } => complete!(reply, executors.restore_state(instance, state)),
        HostRequest::SetParameter { request, reply } => complete!(reply, executors.set_parameter(request)),
        HostRequest::ParameterText { request, reply } => complete!(reply, executors.parameter_text(request)),
        HostRequest::ParseParameter { request, reply } => complete!(reply, executors.parse_parameter(request)),
        HostRequest::ConvertParameter { request, reply } => complete!(reply, executors.convert_parameter(request)),
        HostRequest::OpenEditor { request, reply } => complete!(reply, executors.open_editor(request)),
        HostRequest::CloseEditor { instance, reply } => complete!(reply, executors.close_editor(instance)),
        HostRequest::Resume { instance, reply } => complete!(reply, executors.resume(instance)),
        HostRequest::Duplicate { request, reply } => complete!(reply, executors.duplicate(request)),
        HostRequest::Reconfigure { request, reply } => complete!(reply, executors.reconfigure(request)),
        HostRequest::PrepareOffline { request, reply } => complete!(reply, executors.prepare_offline(request)),
        HostRequest::Destroy { instance, reply } => complete!(reply, executors.destroy(instance)),
    }
}
