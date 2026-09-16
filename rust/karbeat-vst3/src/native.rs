//! Native UI-loop gateway. Only message payloads and exclusive audio endpoints cross threads.

use crate::Vst3PluginHost;
use karbeat_host::{
    HostCapabilities, HostError, HostInstanceId, NativeEditorBinding, NativeEditorEvent,
    NativeSurfacePreference, NativeUiDispatcher, NativeUiPlatform, NativeWindow, NativeWindowId,
    NativeWindowIdAllocator, NativeWindowSize, NativeWindowSpec, PluginController,
    PluginDescriptor, PluginEditorManager, PluginInstanceManager, PluginState, PreparedProcessor,
    ProcessingConfig, StateOperation, StateResult, StateTransaction, StateTransactionControl,
    SystemNativeUi,
};
use karbeat_plugin_api::prelude::ParameterSpec;
use std::{
    cell::RefCell,
    collections::HashMap,
    ffi::c_char,
    rc::Rc,
    sync::{
        OnceLock,
        mpsc::{self, Receiver, SyncSender},
    },
    time::Duration,
};

/// ABI shared with the small native desktop-runner window service.
/// All callbacks are invoked only on the native application's UI thread.
#[repr(C)]
#[derive(Clone, Copy)]
pub struct NativeWindowApi {
    pub version: u32,
    /// 1 = X11 window ID, 2 = HWND, 3 = NSView pointer.
    pub parent_kind: u32,
    pub create: unsafe extern "C" fn(*const c_char, u32, u32, *mut usize) -> usize,
    pub destroy: unsafe extern "C" fn(usize),
    pub focus: unsafe extern "C" fn(usize),
    pub resize: unsafe extern "C" fn(usize, u32, u32) -> bool,
    /// Bit 0: close requested, bit 1: resized. Output dimensions are content dimensions.
    pub poll: unsafe extern "C" fn(usize, *mut u32, *mut u32) -> u32,
    pub set_title: unsafe extern "C" fn(usize, *const c_char) -> bool,
    pub set_resizable: unsafe extern "C" fn(usize, bool) -> bool,
}

type NativeBinding = NativeEditorBinding<<SystemNativeUi as NativeUiPlatform>::Window>;

pub struct NativeHost {
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

/// A suspended instance ready for acknowledged engine publication. The native owner retains
/// teardown responsibility if publication fails or the transfer is abandoned.
pub struct PreparedNativeInstance {
    pub instance: HostInstanceId,
    pub capabilities: HostCapabilities,
    pub parameters: Vec<ParameterSpec>,
    pub state: PluginState,
    pub processor: PreparedProcessor,
}

/// A control-worker state request. Cancellation never destroys native resources on its caller.
pub struct NativeStateRequest {
    control: StateTransactionControl,
    response: Receiver<Result<StateResult, HostError>>,
}
impl NativeStateRequest {
    pub fn cancel(&self) -> bool {
        self.control.cancel()
    }

    pub fn wait(self, timeout: Duration) -> Result<StateResult, HostError> {
        if ON_UI_THREAD.with(std::cell::Cell::get) {
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
        })();
        match result {
            Ok(prepared) => Ok(prepared),
            Err(operation) => match self.destroy(instance) {
                Ok(()) => Err(operation),
                Err(cleanup) => Err(HostError::LifecycleCleanup {
                    operation: Box::new(operation),
                    cleanup: Box::new(cleanup),
                }),
            },
        }
    }

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
}
impl Drop for NativeHost {
    fn drop(&mut self) {
        let windows = self.windows.keys().copied().collect::<Vec<_>>();
        for id in windows {
            drop(self.close_editor(id));
        }
    }
}

type Task = Box<dyn FnOnce(&mut NativeHost) + Send>;
static SENDER: OnceLock<SyncSender<Task>> = OnceLock::new();
thread_local! {
    static RUNTIME: RefCell<Option<(NativeHost, Receiver<Task>)>> = const { RefCell::new(None) };
    static ON_UI_THREAD: std::cell::Cell<bool> = const { std::cell::Cell::new(false) };
}

pub fn available() -> bool {
    SENDER.get().is_some()
}

/// Captures fresh opaque state without holding an engine or project lock on the native UI thread.
pub fn capture_state(instance: HostInstanceId) -> Result<PluginState, HostError> {
    let request = call(move |native| native.request_state(instance, StateOperation::Capture))?;
    match request.wait(Duration::from_secs(30))? {
        StateResult::Captured(state) => Ok(state),
        StateResult::Restored | StateResult::ParametersFlushed => Err(HostError::InvalidTransition),
    }
}

/// Captures fresh state and prepares an independent duplicate with the source configuration.
/// The duplicate stays suspended until its caller publishes and resumes it. Dropping the
/// returned transfer schedules destruction on the native UI owner.
pub fn duplicate_instance(instance: HostInstanceId) -> Result<PreparedNativeInstance, HostError> {
    prepare_copy(instance, |_| {}, false)
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
    call(move |owner| {
        let descriptor = owner.host.descriptor(instance)?.clone();
        let mut config = owner.host.processing_config(instance)?.clone();
        configure(&mut config);
        let prepared = owner.create_prepared(&descriptor, &config, Some(&state))?;
        if start {
            owner.host.resume(prepared.instance)?;
        }
        Ok(prepared)
    })
}

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
    if ON_UI_THREAD.with(std::cell::Cell::get) {
        return Err(HostError::WrongThread);
    }
    let sender = SENDER.get().ok_or(HostError::Unsupported(
        "native desktop host is not initialized",
    ))?;
    let (reply, response) = mpsc::sync_channel(1);
    let status = std::sync::Arc::new(std::sync::atomic::AtomicU8::new(0));
    let task_status = status.clone();
    sender
        .try_send(Box::new(move |host| {
            if task_status
                .compare_exchange(
                    0,
                    1,
                    std::sync::atomic::Ordering::AcqRel,
                    std::sync::atomic::Ordering::Acquire,
                )
                .is_err()
            {
                return;
            }
            drop(reply.try_send(action(host)));
        }))
        .map_err(|_| HostError::Busy)?;
    match response.recv_timeout(Duration::from_secs(30)) {
        Ok(result) => result,
        Err(mpsc::RecvTimeoutError::Timeout) => {
            if status
                .compare_exchange(
                    0,
                    2,
                    std::sync::atomic::Ordering::AcqRel,
                    std::sync::atomic::Ordering::Acquire,
                )
                .is_ok()
            {
                Err(HostError::NativeDispatch(
                    "UI request timed out before execution".into(),
                ))
            } else {
                // Once a native mutation starts, wait for its actual result. Reporting a
                // timeout here could orphan a successfully created instance or editor.
                response
                    .recv()
                    .map_err(|error| HostError::NativeDispatch(error.to_string()))?
            }
        }
        Err(error) => Err(HostError::NativeDispatch(error.to_string())),
    }
}

/// Drives queued lifecycle/editor work from the existing native application's event loop.
///
/// # Safety
/// `api` must point to a callback table beginning with its u32 ABI version. Version 2 tables
/// must be complete and their functions must remain loaded until
/// shutdown. Repeated calls must come from the same OS main thread. No callback may reenter poll.
pub unsafe fn poll(api: *const NativeWindowApi) {
    if api.is_null() {
        return;
    }
    // SAFETY: Read only the common version field before accessing the rest of the ABI table.
    if unsafe { api.cast::<u32>().read() } != 2 {
        return;
    }
    RUNTIME.with(|runtime| {
        let Ok(mut runtime) = runtime.try_borrow_mut() else {
            return;
        };
        if runtime.is_none() {
            drop(NativeUiDispatcher::initialize());
            if SENDER.get().is_some() {
                return;
            }
            let Ok((native_ui, _wake_handle)) = SystemNativeUi::initialize() else {
                return;
            };
            let (sender, receiver) = mpsc::sync_channel(128);
            if SENDER.set(sender).is_err() {
                return;
            }
            ON_UI_THREAD.with(|ui| ui.set(true));
            *runtime = Some((
                NativeHost {
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
                    control_retirements: Vec::new(),
                },
                receiver,
            ));
        }
        if let Some((host, receiver)) = runtime.as_mut() {
            for _ in 0..64 {
                match receiver.try_recv() {
                    Ok(task) => task(host),
                    Err(_) => break,
                }
            }
            host.pump();
        }
    });
}
