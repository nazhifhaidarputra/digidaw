//! Native UI-loop gateway. Only message payloads and exclusive audio endpoints cross threads.

use crate::Vst3PluginHost;
use karbeat_host::{
    HostCapabilities, HostError, HostInstanceId, PluginController, PluginDescriptor,
    PluginEditorManager, PluginInstanceManager, PluginState, PreparedProcessor, ProcessingConfig,
    StateOperation, StateResult, StateTransaction, StateTransactionControl,
};
use karbeat_plugin_api::prelude::ParameterSpec;
use raw_window_handle::{AppKitWindowHandle, RawWindowHandle, Win32WindowHandle, XlibWindowHandle};
use std::{
    cell::RefCell,
    collections::HashMap,
    ffi::{CString, c_char},
    num::NonZeroIsize,
    ptr::NonNull,
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

struct Window {
    token: usize,
    api: NativeWindowApi,
}
impl Drop for Window {
    fn drop(&mut self) {
        // SAFETY: Window token was created by this backend and the editor has already detached.
        unsafe { (self.api.destroy)(self.token) };
    }
}

pub struct NativeHost {
    pub host: Vst3PluginHost,
    api: NativeWindowApi,
    windows: HashMap<HostInstanceId, Rc<Window>>,
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
        if let Some(window) = self.windows.get(&id) {
            // SAFETY: Stored native window token remains live on this UI thread.
            unsafe { (window.api.focus)(window.token) };
            return Ok(());
        }
        let (width, height) = self.host.editor_size(id)?;
        let resizable = self.host.editor_resizable(id)?;
        let title = self.editor_title(id, self.editor_contexts.get(&id).map(String::as_str))?;
        let mut parent = 0;
        // SAFETY: Title and writable parent output live through creation on the native UI thread.
        let token = unsafe { (self.api.create)(title.as_ptr(), width, height, &raw mut parent) };
        if token == 0 || parent == 0 {
            if token != 0 {
                // SAFETY: Reclaim a window whose backend failed to expose an editor parent.
                unsafe { (self.api.destroy)(token) };
            }
            self.host.close_editor(id)?;
            return Err(HostError::Unsupported(
                "native editor window unavailable (Linux requires X11/XWayland)",
            ));
        }
        let window = Rc::new(Window {
            token,
            api: self.api,
        });
        // SAFETY: The newly created window is live on its UI thread, before editor attachment.
        if !unsafe { (self.api.set_resizable)(token, resizable) } {
            self.host.close_editor(id)?;
            return Err(HostError::NativeDispatch(
                "could not configure editor window controls".into(),
            ));
        }
        let handle = match self.api.parent_kind {
            1 => RawWindowHandle::Xlib(XlibWindowHandle::new(
                std::ffi::c_ulong::try_from(parent).map_err(|_| HostError::InvalidConfiguration)?,
            )),
            2 => RawWindowHandle::Win32(Win32WindowHandle::new(
                NonZeroIsize::new(
                    isize::try_from(parent).map_err(|_| HostError::InvalidConfiguration)?,
                )
                .ok_or(HostError::InvalidConfiguration)?,
            )),
            3 => RawWindowHandle::AppKit(AppKitWindowHandle::new(
                NonNull::new(std::ptr::with_exposed_provenance_mut(parent))
                    .ok_or(HostError::InvalidConfiguration)?,
            )),
            _ => return Err(HostError::Unsupported("native window ABI parent kind")),
        };
        let resize_window = Rc::downgrade(&window);
        self.host.set_editor_resize_handler(
            id,
            Rc::new(move |width, height| {
                resize_window.upgrade().is_some_and(|window| {
                    // SAFETY: Upgraded owner retains the token while the native backend resizes it.
                    unsafe { (window.api.resize)(window.token, width, height) }
                })
            }),
        )?;
        if let Err(error) = self.host.open_editor(id, handle) {
            drop(self.host.close_editor(id));
            return Err(error);
        }
        // SAFETY: Editor attached successfully to this live native parent.
        unsafe { (self.api.focus)(token) };
        self.windows.insert(id, window);
        Ok(())
    }
    fn editor_title(
        &self,
        id: HostInstanceId,
        context: Option<&str>,
    ) -> Result<CString, HostError> {
        let descriptor = self.host.descriptor(id)?;
        let context = context.map_or_else(|| format!("Instance {}", id.0), str::to_owned);
        CString::new(format!("DigiDAW — {} — {context}", descriptor.name))
            .map_err(|_| HostError::InvalidState("editor title contains a null character".into()))
    }
    /// Applies project context labels without replacing the editor or its processing instance.
    pub fn set_editor_context(
        &mut self,
        id: HostInstanceId,
        context: String,
    ) -> Result<(), HostError> {
        let title = self.editor_title(id, Some(&context))?;
        if let Some(window) = self.windows.get(&id) {
            // SAFETY: The title and retained window remain live throughout the native UI call.
            if !unsafe { (window.api.set_title)(window.token, title.as_ptr()) } {
                return Err(HostError::NativeDispatch(
                    "could not update editor window title".into(),
                ));
            }
        }
        self.editor_contexts.insert(id, context);
        Ok(())
    }
    pub fn close_editor(&mut self, id: HostInstanceId) -> Result<(), HostError> {
        self.host.close_editor(id)?;
        self.windows.remove(&id);
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
        let mut closed = Vec::new();
        for (&id, window) in &self.windows {
            let (mut width, mut height) = (0, 0);
            // SAFETY: Poll is nonblocking, token is live, and dimensions are writable outputs.
            let flags = unsafe { (window.api.poll)(window.token, &raw mut width, &raw mut height) };
            if flags & 1 != 0 {
                closed.push(id);
            } else if flags & 2 != 0 {
                if let Err(error) = self.host.resize_editor(id, width, height) {
                    log::debug!("VST3 editor size unchanged: {error}");
                    if let Ok((accepted_width, accepted_height)) = self.host.editor_size(id) {
                        if (width, height) != (accepted_width, accepted_height) {
                            // SAFETY: Restore this live native client's size after a rejected resize.
                            if !unsafe {
                                (window.api.resize)(window.token, accepted_width, accepted_height)
                            } {
                                log::warn!(
                                    "VST3 native window could not restore editor dimensions"
                                );
                            }
                        }
                    }
                }
            }
        }
        for id in closed {
            if let Err(error) = self.close_editor(id) {
                log::warn!("VST3 editor close: {error}");
            }
            self.push_event(karbeat_host::HostEvent::EditorClosed { instance: id });
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
    // SAFETY: A version-2 runner guarantees the complete callback table and retained callbacks.
    let api = unsafe { *api };
    RUNTIME.with(|runtime| {
        let Ok(mut runtime) = runtime.try_borrow_mut() else {
            return;
        };
        if runtime.is_none() {
            if SENDER.get().is_some() {
                return;
            }
            let (sender, receiver) = mpsc::sync_channel(128);
            if SENDER.set(sender).is_err() {
                return;
            }
            ON_UI_THREAD.with(|ui| ui.set(true));
            *runtime = Some((
                NativeHost {
                    host: Vst3PluginHost::new(),
                    api,
                    windows: HashMap::new(),
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
