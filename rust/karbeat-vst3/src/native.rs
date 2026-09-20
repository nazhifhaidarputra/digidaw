//! Native UI-loop gateway. Only message payloads and exclusive audio endpoints cross threads.

use crate::{
    Vst3PluginHost,
    instance::{MIDI_MAPPING_QUERY_COUNT, Vst3PrepareJob},
};
use glib::ControlFlow;
use karbeat_host::{
    HostCapabilities, HostError, HostInstanceId, HostStateCapture, NativeEditorBinding,
    NativeEditorEvent, NativeSurfacePreference, NativeUiDispatcher, NativeUiPlatform, NativeWindow,
    NativeWindowId, NativeWindowIdAllocator, NativeWindowSize, NativeWindowSpec, PluginController,
    PluginDescriptor, PluginEditorManager, PluginFormat, PluginIdentity, PluginInstanceManager,
    PluginState, PreparedProcessor, ProcessingConfig, StateOperation, StateResult,
    StateTransaction, StateTransactionControl, SystemNativeUi,
};
use karbeat_plugin_api::prelude::ParameterSpec;
use std::{
    cell::RefCell,
    collections::{HashMap, VecDeque},
    rc::Rc,
    sync::{
        atomic::{AtomicBool, Ordering},
        mpsc::{self, Receiver, SyncSender},
    },
    time::Duration,
};

type NativeBinding = NativeEditorBinding<<SystemNativeUi as NativeUiPlatform>::Window>;
const MIDI_MAPPING_QUERIES_PER_TICK: usize = 64;
const MAX_PREPARE_JOBS: usize = 128;
const _: () = assert!(MIDI_MAPPING_QUERIES_PER_TICK < MIDI_MAPPING_QUERY_COUNT);

/// Native-UI-thread runtime that owns the VST3 host, editor windows, and pending lifecycle work.
///
/// Requests reach this owner through [`call`]. Its periodic pump advances bounded preparation
/// and state transactions, retires returned processors, services native events, and coalesces
/// parameter-state flushes without moving COM or window objects to worker threads.
pub struct NativeHost {
    /// VST3 backend whose COM objects share this runtime's native UI thread.
    pub host: Vst3PluginHost,
    native_ui: SystemNativeUi,
    window_ids: NativeWindowIdAllocator,
    windows: HashMap<HostInstanceId, Rc<RefCell<NativeBinding>>>,
    window_owners: HashMap<NativeWindowId, HostInstanceId>,
    editor_contexts: HashMap<HostInstanceId, String>,
    events: Vec<karbeat_host::HostEvent>,
    event_overflow: Option<HostInstanceId>,
    parameter_flush_due: HashMap<HostInstanceId, std::time::Instant>,
    retirements: HashMap<HostInstanceId, NativeRetirement>,
    state_requests: HashMap<HostInstanceId, PendingState>,
    prepare_jobs: VecDeque<PendingPrepare>,
    control_retirements: Vec<Box<dyn FnMut() -> bool>>,
}

struct NativeRetirement {
    queue: karbeat_host::ProcessorRetirement,
    returned: bool,
}

struct PendingState {
    transaction: StateTransaction,
    reply: Option<SyncSender<Result<StateResult, HostError>>>,
}

struct PendingPrepare {
    instance: HostInstanceId,
    state: Option<PluginState>,
    job: Vst3PrepareJob,
    reply: SyncSender<Result<PreparedNativeInstance, HostError>>,
}

/// A suspended instance ready for acknowledged engine publication. The native owner retains
/// teardown responsibility if publication fails or the transfer is abandoned.
pub struct PreparedNativeInstance {
    /// Runtime handle of the suspended native instance.
    pub instance: HostInstanceId,
    /// Features reported by the prepared plugin.
    pub capabilities: HostCapabilities,
    /// Parameter specifications discovered from the plugin controller.
    pub parameters: Vec<ParameterSpec>,
    /// Fresh opaque component and controller state captured after preparation.
    pub state: PluginState,
    /// Single-owner processor transfer reserved for publication to the audio engine.
    pub processor: PreparedProcessor,
}

/// A control-worker state request. Cancellation never destroys native resources on its caller.
pub struct NativeStateRequest {
    control: StateTransactionControl,
    response: Receiver<Result<StateResult, HostError>>,
}

/// Completion for a cooperative production preparation job.
pub struct NativePrepareRequest {
    response: Receiver<Result<PreparedNativeInstance, HostError>>,
}
impl NativePrepareRequest {
    /// Waits for cooperative preparation to finish off the native UI thread.
    ///
    /// A timeout does not abandon the in-flight native instance: once the first wait expires,
    /// this method waits without a deadline so ownership and cleanup cannot be lost.
    pub fn wait(self, timeout: Duration) -> Result<PreparedNativeInstance, HostError> {
        if NativeUiDispatcher::is_owner_thread() {
            return Err(HostError::WrongThread);
        }
        match self.response.recv_timeout(timeout) {
            Ok(result) => result,
            Err(mpsc::RecvTimeoutError::Timeout) => self
                .response
                .recv()
                .map_err(|error| HostError::NativeDispatch(error.to_string()))?,
            Err(error) => Err(HostError::NativeDispatch(error.to_string())),
        }
    }
}
impl NativeStateRequest {
    /// Requests cancellation before the state transaction begins and reports whether it won.
    ///
    /// Cancellation is cooperative; the native owner still polls the transaction to complete
    /// any required suspension cleanup.
    pub fn cancel(&self) -> bool {
        self.control.cancel()
    }

    /// Waits for state capture, restore, or parameter flushing off the native UI thread.
    ///
    /// On timeout the request is cancelled if it has not started. If execution has begun, this
    /// waits for the definitive result so suspension and resume sequencing remains owned by the
    /// native runtime.
    pub fn wait(self, timeout: Duration) -> Result<StateResult, HostError> {
        if NativeUiDispatcher::is_owner_thread() {
            return Err(HostError::WrongThread);
        }
        match self.response.recv_timeout(timeout) {
            Ok(result) => result,
            Err(mpsc::RecvTimeoutError::Timeout) => {
                if self.control.cancel() || self.control.is_cancelled() {
                    Err(HostError::NativeDispatch("state request timed out before execution; suspension cleanup remains scheduled".into()))
                } else {
                    self.response
                        .recv()
                        .map_err(|error| HostError::NativeDispatch(error.to_string()))?
                }
            }
            Err(error) => Err(HostError::NativeDispatch(error.to_string())),
        }
    }
}
impl Drop for NativeStateRequest {
    fn drop(&mut self) {
        self.control.cancel();
    }
}

impl NativeHost {
    /// Reserves return capacity before a control command can enter the DSP queue.
    pub fn prepare_control<T: Send + 'static>(
        &mut self,
        payload: T,
    ) -> Result<karbeat_host::ControlTransfer<T>, HostError> {
        if self.control_retirements.len() >= 128 {
            return Err(HostError::Busy);
        }
        let (transfer, mut retirement) = karbeat_host::ControlTransfer::new(payload);
        self.control_retirements
            .push(Box::new(move || retirement.collect()));
        Ok(transfer)
    }

    /// Creates, prepares, optionally restores, snapshots, and transfers an instance synchronously.
    ///
    /// Any failure triggers instance cleanup; if cleanup also fails, both errors are preserved in
    /// [`HostError::LifecycleCleanup`]. This method must run on the native owner.
    pub fn create_prepared(
        &mut self,
        descriptor: &PluginDescriptor,
        config: &ProcessingConfig,
        state: Option<&PluginState>,
    ) -> Result<PreparedNativeInstance, HostError> {
        config.validate()?;
        let instance = self.host.create(descriptor)?;
        let result = (|| {
            self.host.prepare(instance, config)?;
            self.finish_prepared(instance, state)
        })();
        result.map_err(|operation| self.cleanup_failed_creation(instance, operation))
    }

    /// Queues cooperative instance preparation and returns a worker-side completion handle.
    ///
    /// MIDI controller mappings are resolved in bounded batches by the native pump. At most
    /// `MAX_PREPARE_JOBS` jobs are retained; overload returns [`HostError::Busy`].
    pub fn request_prepared(
        &mut self,
        descriptor: PluginDescriptor,
        config: ProcessingConfig,
        state: Option<PluginState>,
    ) -> Result<NativePrepareRequest, HostError> {
        config.validate()?;
        if self.prepare_jobs.len() >= MAX_PREPARE_JOBS {
            return Err(HostError::Busy);
        }
        let instance = self.host.create(&descriptor)?;
        let job = match self.host.begin_prepare(instance, &config) {
            Ok(job) => job,
            Err(operation) => return Err(self.cleanup_failed_creation(instance, operation)),
        };
        let (reply, response) = mpsc::sync_channel(1);
        self.prepare_jobs.push_back(PendingPrepare {
            instance,
            state,
            job,
            reply,
        });
        Ok(NativePrepareRequest { response })
    }

    fn finish_prepared(
        &mut self,
        instance: HostInstanceId,
        state: Option<&PluginState>,
    ) -> Result<PreparedNativeInstance, HostError> {
        if let Some(state) = state {
            self.host.restore_state(instance, state)?;
        }
        let capabilities = self.host.capabilities(instance)?;
        let parameters = self.host.parameters(instance)?;
        let state = self.host.save_state(instance)?;
        let processor = self.take_processor(instance)?;
        Ok(PreparedNativeInstance {
            instance,
            capabilities,
            parameters,
            state,
            processor,
        })
    }

    fn cleanup_failed_creation(
        &mut self,
        instance: HostInstanceId,
        operation: HostError,
    ) -> HostError {
        match self.destroy(instance) {
            Ok(()) => operation,
            Err(cleanup) => HostError::LifecycleCleanup {
                operation: Box::new(operation),
                cleanup: Box::new(cleanup),
            },
        }
    }

    /// Starts one asynchronous state transaction for `id`.
    ///
    /// Concurrent requests for the same instance and requests beyond the bounded table capacity
    /// return [`HostError::Busy`]. The returned handle controls cancellation and completion.
    pub fn request_state(
        &mut self,
        id: HostInstanceId,
        operation: StateOperation,
    ) -> Result<NativeStateRequest, HostError> {
        if self.state_requests.len() >= 128 || self.state_requests.contains_key(&id) {
            return Err(HostError::Busy);
        }
        self.host.is_processing(id)?;
        let (transaction, control) = StateTransaction::new(id, operation);
        let (reply, response) = mpsc::sync_channel(1);
        self.state_requests.insert(
            id,
            PendingState {
                transaction,
                reply: Some(reply),
            },
        );
        Ok(NativeStateRequest { control, response })
    }
    /// Prepare an exclusive endpoint for engine publication with reserved return capacity.
    pub fn take_processor(
        &mut self,
        id: HostInstanceId,
    ) -> Result<karbeat_host::PreparedProcessor, HostError> {
        if self.retirements.contains_key(&id) {
            return Err(HostError::InvalidTransition);
        }
        let endpoint = self.host.take_processor(id)?;
        let (endpoint, retirement) = endpoint.prepare_transfer()?;
        self.retirements.insert(
            id,
            NativeRetirement {
                queue: retirement,
                returned: false,
            },
        );
        Ok(endpoint)
    }
    /// Creates and attaches the plugin editor to a host-owned native window, or focuses it if open.
    ///
    /// Window creation remains hidden until attachment succeeds. Any attachment or presentation
    /// failure closes the plugin view and tears down the partially created binding.
    pub fn open_editor(&mut self, id: HostInstanceId) -> Result<(), HostError> {
        if let Some(binding) = self.windows.get(&id) {
            binding.borrow_mut().request_focus()?;
            return Ok(());
        }
        let size = self.host.editor_size(id)?;
        let constraints = self.host.editor_constraints(id)?;
        let preferred_surface = self.host.editor_surface_preference(id)?;
        if matches!(preferred_surface, NativeSurfacePreference::Require(kind) if !self.native_ui.capabilities().supports(kind))
        {
            return Err(HostError::Unsupported(
                "VST3 native editor requires X11/XWayland on Linux",
            ));
        }
        let title = self.editor_title(id, self.editor_contexts.get(&id).map(String::as_str))?;
        let window_id = self.window_ids.allocate()?;
        let window = self.native_ui.create_window(
            window_id,
            &NativeWindowSpec {
                title: &title,
                initial_size: size,
                constraints,
                initially_visible: false,
                preferred_surface,
            },
        )?;
        let binding = Rc::new(RefCell::new(NativeEditorBinding::new(window)?));
        let resize_binding = Rc::downgrade(&binding);
        self.host.set_editor_resize_handler(
            id,
            Rc::new(move |width, height| {
                let Ok(size) = NativeWindowSize::new(width, height) else {
                    return false;
                };
                resize_binding.upgrade().is_some_and(|binding| {
                    binding
                        .try_borrow_mut()
                        .is_ok_and(|mut binding| binding.resize_window(size).is_ok())
                })
            }),
        )?;
        let parent = binding.borrow().window()?.parent_handle()?;
        if let Err(error) = self.host.open_editor(id, &parent) {
            drop(self.host.close_editor(id));
            return Err(error);
        }
        let show_result = (|| {
            let mut binding = binding.borrow_mut();
            binding.mark_attached()?;
            binding.show()?;
            binding.request_focus()
        })();
        if let Err(error) = show_result {
            drop(self.host.close_editor(id));
            let mut binding = binding.borrow_mut();
            binding.begin_close();
            drop(binding.finish_close());
            return Err(error.into());
        }
        self.window_owners.insert(window_id, id);
        self.windows.insert(id, binding);
        Ok(())
    }
    fn editor_title(&self, id: HostInstanceId, context: Option<&str>) -> Result<String, HostError> {
        let descriptor = self.host.descriptor(id)?;
        let context = context.map_or_else(|| format!("Instance {}", id.0), str::to_owned);
        Ok(format!("DigiDAW — {} — {context}", descriptor.name))
    }
    /// Applies project context labels without replacing the editor or its processing instance.
    pub fn set_editor_context(
        &mut self,
        id: HostInstanceId,
        context: String,
    ) -> Result<(), HostError> {
        let title = self.editor_title(id, Some(&context))?;
        if let Some(binding) = self.windows.get(&id) {
            binding.borrow_mut().window_mut()?.set_title(&title)?;
        }
        self.editor_contexts.insert(id, context);
        Ok(())
    }
    /// Detaches the plugin editor and then destroys its host-owned native window.
    ///
    /// If plugin detachment fails, the binding is restored to the open-window table so ownership
    /// is not lost and the caller can retry.
    pub fn close_editor(&mut self, id: HostInstanceId) -> Result<(), HostError> {
        let Some(binding) = self.windows.remove(&id) else {
            return self.host.close_editor(id);
        };
        let window_id = binding.borrow().id();
        binding.borrow_mut().begin_close();
        if let Err(error) = self.host.close_editor(id) {
            self.windows.insert(id, binding);
            return Err(error);
        }
        binding.borrow_mut().finish_close()?;
        self.window_owners.remove(&window_id);
        Ok(())
    }
    /// Closes the editor and destroys a native instance after pending state work has finished.
    ///
    /// Returns [`HostError::Busy`] while a state transaction still owns the instance.
    pub fn destroy(&mut self, id: HostInstanceId) -> Result<(), HostError> {
        if self.state_requests.contains_key(&id) {
            return Err(HostError::Busy);
        }
        self.close_editor(id)?;
        self.host.destroy(id)?;
        self.editor_contexts.remove(&id);
        self.parameter_flush_due.remove(&id);
        Ok(())
    }
    /// Drains queued control/editor events and reports any bounded-queue overflow once.
    ///
    /// When the 4,096-event queue discarded an oldest event, a final `QueueOverflow` event is
    /// appended for the affected instance and the overflow marker is cleared.
    pub fn take_events(&mut self) -> Vec<karbeat_host::HostEvent> {
        let mut events = std::mem::take(&mut self.events);
        if let Some(instance) = self.event_overflow.take() {
            events.push(karbeat_host::HostEvent::QueueOverflow { instance });
        }
        events
    }

    fn push_event(&mut self, event: karbeat_host::HostEvent) {
        if self.events.len() == 4096 {
            let dropped = self.events.remove(0);
            self.event_overflow = Some(match dropped {
                karbeat_host::HostEvent::BeginEdit { instance, .. }
                | karbeat_host::HostEvent::EndEdit { instance, .. }
                | karbeat_host::HostEvent::ParameterChanged { instance, .. }
                | karbeat_host::HostEvent::RestartRequested { instance, .. }
                | karbeat_host::HostEvent::EditorClosed { instance }
                | karbeat_host::HostEvent::QueueOverflow { instance } => instance,
            });
        }
        self.events.push(event);
    }
    fn pump(&mut self) {
        self.pump_prepare_job();
        self.control_retirements
            .retain_mut(|retirement| !retirement());
        let mut completed = Vec::new();
        for (&id, request) in &mut self.state_requests {
            if let Some(result) = request.transaction.poll(&mut self.host) {
                completed.push((id, result));
            }
        }
        for (id, result) in completed {
            if let Some(request) = self.state_requests.remove(&id) {
                if let Some(reply) = request.reply {
                    drop(reply.try_send(result));
                } else if let Err(error) = result {
                    log::error!("VST3 idle parameter flush: {error}");
                }
            }
        }
        let mut retired = Vec::new();
        for (&id, retirement) in &mut self.retirements {
            if let Some(endpoint) = retirement.queue.take() {
                drop(endpoint);
                retirement.returned = true;
            }
            if retirement.queue.is_abandoned() {
                retirement.returned = true;
            }
            if retirement.returned && retirement.queue.is_abandoned() {
                retired.push(id);
            }
        }
        for id in retired {
            match self.destroy(id) {
                Ok(()) | Err(HostError::UnknownInstance(_)) => {
                    self.retirements.remove(&id);
                }
                Err(HostError::Busy) => {}
                Err(error) => {
                    log::error!("VST3 endpoint teardown: {error}");
                }
            }
        }
        if let Err(error) = self.host.pump() {
            log::error!("VST3 native loop: {error}");
        }
        let mut native_events = Vec::new();
        if let Err(error) = self
            .native_ui
            .poll_events(|event| native_events.push(event))
        {
            log::error!("native editor event loop: {error}");
        }
        let mut closed = Vec::new();
        for event in native_events {
            let Some(id) = self.window_owners.get(&event.window()).copied() else {
                continue;
            };
            let Some(binding) = self.windows.get(&id) else {
                continue;
            };
            let editor_event = match binding.borrow_mut().handle_event(event) {
                Ok(event) => event,
                Err(error) => {
                    log::warn!("native editor event: {error}");
                    continue;
                }
            };
            match editor_event {
                NativeEditorEvent::ExternalResize(size) => {
                    if let Err(error) = self.host.resize_editor(id, size.width, size.height) {
                        log::debug!("VST3 editor size unchanged: {error}");
                        if let Ok(accepted) = self.host.editor_size(id)
                            && accepted != size
                            && let Err(resize_error) = binding.borrow_mut().resize_window(accepted)
                        {
                            log::warn!("VST3 native window resize restore: {resize_error}");
                        }
                    }
                }
                NativeEditorEvent::CloseRequested | NativeEditorEvent::Destroyed => {
                    if !closed.contains(&id) {
                        closed.push(id);
                    }
                }
                NativeEditorEvent::Ignored
                | NativeEditorEvent::ProgrammaticResizeAcknowledged
                | NativeEditorEvent::ScaleFactorChanged(_)
                | NativeEditorEvent::FocusChanged(_) => {}
            }
        }
        for id in closed {
            if let Err(error) = self.close_editor(id) {
                log::warn!("VST3 editor close: {error}");
            }
            self.push_event(karbeat_host::HostEvent::EditorClosed { instance: id });
        }
        if let Err(error) = self.native_ui.pump() {
            log::error!("native editor flush: {error}");
        }
        let now = std::time::Instant::now();
        for event in self.host.drain_events() {
            if let karbeat_host::HostEvent::ParameterChanged { instance, .. } = &event {
                self.parameter_flush_due
                    .insert(*instance, now + Duration::from_millis(50));
            }
            self.push_event(event);
        }
        let due: Vec<_> = self
            .parameter_flush_due
            .iter()
            .filter(|(id, deadline)| **deadline <= now && !self.state_requests.contains_key(id))
            .map(|(&id, _)| id)
            .collect();
        for id in due {
            if self.state_requests.len() >= 128 {
                break;
            }
            self.parameter_flush_due.remove(&id);
            if self.host.has_pending_parameters(id).unwrap_or(false) {
                let (transaction, _) = StateTransaction::new(id, StateOperation::FlushParameters);
                self.state_requests.insert(
                    id,
                    PendingState {
                        transaction,
                        reply: None,
                    },
                );
            }
        }
    }

    fn pump_prepare_job(&mut self) {
        let Some(mut pending) = self.prepare_jobs.pop_front() else {
            return;
        };
        let result = match self.host.advance_prepare(
            pending.instance,
            &mut pending.job,
            MIDI_MAPPING_QUERIES_PER_TICK,
        ) {
            Ok(false) => {
                self.prepare_jobs.push_back(pending);
                return;
            }
            Ok(true) => self.finish_prepared(pending.instance, pending.state.as_ref()),
            Err(error) => Err(error),
        };
        let result =
            result.map_err(|operation| self.cleanup_failed_creation(pending.instance, operation));
        drop(pending.reply.try_send(result));
    }
}
impl Drop for NativeHost {
    fn drop(&mut self) {
        let windows = self.windows.keys().copied().collect::<Vec<_>>();
        for id in windows {
            drop(self.close_editor(id));
        }
    }
}

thread_local! {
    static RUNTIME: RefCell<Option<NativeHost>> = const { RefCell::new(None) };
}
static RUNTIME_READY: AtomicBool = AtomicBool::new(false);

/// Reports whether the thread-local native runtime has completed lazy initialization.
///
/// This is an acquire load paired with the release store performed after the runtime and its
/// periodic pump have been installed.
pub fn available() -> bool {
    RUNTIME_READY.load(Ordering::Acquire)
}

/// Control-side state capture capability for the VST3 native owner.
pub struct NativeStateCapture;

impl HostStateCapture for NativeStateCapture {
    fn capture_state(
        &self,
        identity: &PluginIdentity,
        instance: HostInstanceId,
    ) -> Result<PluginState, HostError> {
        if identity.format != PluginFormat::Vst3 {
            return Err(HostError::Unsupported("VST3 state capture"));
        }
        capture_state(instance)
    }
}

/// Captures fresh opaque state without holding an engine or project lock on the native UI thread.
pub fn capture_state(instance: HostInstanceId) -> Result<PluginState, HostError> {
    let request = call(move |native| native.request_state(instance, StateOperation::Capture))?;
    match request.wait(Duration::from_secs(30))? {
        StateResult::Captured(state) => Ok(state),
        StateResult::Restored | StateResult::ParametersFlushed => Err(HostError::InvalidTransition),
    }
}

/// Prepares a production instance cooperatively while its caller waits off the UI owner.
pub fn prepare_instance(
    descriptor: PluginDescriptor,
    config: ProcessingConfig,
    state: Option<PluginState>,
) -> Result<PreparedNativeInstance, HostError> {
    let request = call(move |owner| owner.request_prepared(descriptor, config, state))?;
    request.wait(Duration::from_secs(30))
}

/// Captures fresh state and prepares an independent duplicate with the source configuration.
/// The duplicate stays suspended until its caller publishes and resumes it. Dropping the
/// returned transfer schedules destruction on the native UI owner.
pub fn duplicate_instance(instance: HostInstanceId) -> Result<PreparedNativeInstance, HostError> {
    prepare_copy(instance, |_| {}, false)
}

/// Captures live state and prepares a suspended replacement for a realtime DSP configuration.
pub fn prepare_reconfigured_instance(
    instance: HostInstanceId,
    sample_rate: u32,
    max_block_size: usize,
) -> Result<PreparedNativeInstance, HostError> {
    prepare_copy(
        instance,
        move |config| {
            config.sample_rate = f64::from(sample_rate);
            config.max_block_size = config.max_block_size.max(max_block_size);
            config.offline = false;
        },
        false,
    )
}

/// Captures live state and creates an independent offline endpoint on the native UI owner.
pub fn prepare_offline_instance(
    instance: HostInstanceId,
    sample_rate: u32,
    max_block_size: usize,
    output_channels: usize,
) -> Result<PreparedNativeInstance, HostError> {
    prepare_copy(
        instance,
        move |config| {
            config.sample_rate = f64::from(sample_rate);
            config.max_block_size = max_block_size;
            config.main_output_channels = output_channels;
            if config.main_input_channels != 0 {
                config.main_input_channels = output_channels;
            }
            if config.sidechain_channels != 0 {
                config.sidechain_channels = output_channels;
            }
            config.offline = true;
        },
        true,
    )
}

fn prepare_copy(
    instance: HostInstanceId,
    configure: impl FnOnce(&mut ProcessingConfig) + Send + 'static,
    start: bool,
) -> Result<PreparedNativeInstance, HostError> {
    let state = capture_state(instance)?;
    let (descriptor, mut config) = call(move |owner| {
        Ok((
            owner.host.descriptor(instance)?.clone(),
            owner.host.processing_config(instance)?.clone(),
        ))
    })?;
    configure(&mut config);
    let prepared = prepare_instance(descriptor, config, Some(state))?;
    if start {
        let prepared_id = prepared.instance;
        call(move |owner| owner.host.resume(prepared_id))?;
    }
    Ok(prepared)
}

/// Restores opaque component/controller state through the native owner's state transaction.
///
/// The calling worker waits up to 30 seconds before requesting cooperative cancellation or
/// waiting for an already-started transaction to complete.
pub fn restore_state(instance: HostInstanceId, state: PluginState) -> Result<(), HostError> {
    let request =
        call(move |native| native.request_state(instance, StateOperation::Restore(state)))?;
    match request.wait(Duration::from_secs(30))? {
        StateResult::Restored => Ok(()),
        StateResult::Captured(_) | StateResult::ParametersFlushed => {
            Err(HostError::InvalidTransition)
        }
    }
}

/// Called by API/control workers, never the audio or native UI thread.
/// A bounded request queue rejects overload instead of silently dropping lifecycle commands.
pub fn call<T: Send + 'static>(
    action: impl FnOnce(&mut NativeHost) -> Result<T, HostError> + Send + 'static,
) -> Result<T, HostError> {
    if NativeUiDispatcher::is_owner_thread() {
        return Err(HostError::WrongThread);
    }
    let dispatcher = NativeUiDispatcher::initialize()?;
    let request = dispatcher.dispatch(move || Ok(with_native_host(action)))?;
    request.wait(Duration::from_secs(30))?
}

fn with_native_host<T>(
    action: impl FnOnce(&mut NativeHost) -> Result<T, HostError>,
) -> Result<T, HostError> {
    RUNTIME.with(|runtime| {
        let mut runtime = runtime
            .try_borrow_mut()
            .map_err(|_| HostError::WrongThread)?;
        if runtime.is_none() {
            let (native_ui, _) = SystemNativeUi::initialize()?;
            *runtime = Some(NativeHost {
                host: Vst3PluginHost::new(),
                native_ui,
                window_ids: NativeWindowIdAllocator::default(),
                windows: HashMap::new(),
                window_owners: HashMap::new(),
                editor_contexts: HashMap::new(),
                events: Vec::new(),
                event_overflow: None,
                parameter_flush_due: HashMap::new(),
                retirements: HashMap::new(),
                state_requests: HashMap::new(),
                prepare_jobs: VecDeque::new(),
                control_retirements: Vec::new(),
            });
            karbeat_host::install_ui_interval(Duration::from_millis(8), pump_runtime)?;
            RUNTIME_READY.store(true, Ordering::Release);
        }
        action(runtime.as_mut().ok_or(HostError::WrongThread)?)
    })
}

fn pump_runtime() -> ControlFlow {
    RUNTIME.with(|runtime| {
        let Ok(mut runtime) = runtime.try_borrow_mut() else {
            return ControlFlow::Continue;
        };
        let Some(host) = runtime.as_mut() else {
            return ControlFlow::Break;
        };
        host.pump();
        ControlFlow::Continue
    })
}
