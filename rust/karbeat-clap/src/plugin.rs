//! UI-owned CLAP plugin instance: activation, parameters, state, the editor, and the
//! main-thread services the plugin asked for.

use std::{
    cell::{RefCell, RefMut, UnsafeCell},
    ffi::CString,
    rc::Rc,
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicU32, Ordering},
    },
    time::Instant,
};

use clack_extensions::{
    audio_ports::{AudioPortFlags, AudioPortInfoBuffer, PluginAudioPorts},
    gui::PluginGui,
    latency::PluginLatency,
    note_ports::{NotePortInfoBuffer, PluginNotePorts},
    params::{ParamInfoBuffer, PluginParams},
    render::{PluginRender, RenderMode},
    state::PluginState as PluginStateExtension,
    timer::{PluginTimer, TimerId},
};
use clack_host::{
    host::HostInfo, plugin::PluginInstance, process::PluginAudioConfiguration, utils::ClapId,
};
use karbeat_host_api::{
    EDIT_CHANGED, HostError, NativeParentHandle, ParameterExchange, PluginDescriptor,
    PluginIdentity, PluginState, ProcessingConfig, ProcessingGate,
    native_host::EditorResizeHandler,
};
use karbeat_plugin_api::prelude::ParameterSpec;
use karbeat_utils::typestate::InvalidState;

use crate::{
    editor::{self, ClapEditor},
    events::NoteInput,
    host::{ClapHostHandlers, ClapHostMainThreadHandler, ClapHostSharedHandler},
    module::ClapModule,
    parameters::{self, ClapParameter},
    wrapper::{AudioContext, Dsp, PortLayout, ProcessorSlot},
};

const STATE_VERSION: u32 = 1;
const MAX_STATE_BYTES: usize = 64 * 1024 * 1024;
/// Largest latency a plugin may report, matching the bypass delay's limit.
const MAX_LATENCY_FRAMES: u32 = 1_048_576;
/// Client size used until an editor reports its own.
const DEFAULT_EDITOR_SIZE: (u32, u32) = (640, 480);

karbeat_utils::typestate! {
    /// Processing lifecycle of one instance, as its UI owner last left it.
    ///
    /// The audio thread can finish suspending on its own after a busy suspension, so
    /// `Running` records the owner's last successful resume, not the gate's current state.
    machine InstanceLifecycle {
        shared: (),
        erased: AnyInstanceLifecycle,
        states {
            /// Created, or being activated again; no processing configuration applies.
            Unprepared as UnpreparedInstance {}
            /// Activated for `config` with processing suspended.
            Prepared as PreparedInstance { config: ProcessingConfig }
            /// Activated for `config` and resumed.
            Running as RunningInstance { config: ProcessingConfig }
        }
        transitions {
            // Activation starts only once processing is suspended.
            Unprepared | Prepared => Unprepared: fn begin_prepare(shared, state) {
                Unprepared {}
            }

            Unprepared => Prepared: fn finish_prepare(shared, state, config: ProcessingConfig) {
                Prepared { config }
            }

            // Resuming a running instance is valid; see the note on `Running` above.
            Prepared | Running => Running: fn resumed(shared, state) {
                Running { config: state.config }
            }

            Prepared | Running => Prepared: fn suspended(shared, state) {
                Prepared { config: state.config }
            }
        }
    }
}

impl AnyInstanceLifecycle {
    fn unprepared() -> Self {
        InstanceLifecycle {
            shared: (),
            state: Unprepared {},
        }
        .into()
    }

    fn config(&self) -> Option<&ProcessingConfig> {
        match self {
            Self::Unprepared(_) => None,
            Self::Prepared(instance) => Some(&instance.state.config),
            Self::Running(instance) => Some(&instance.state.config),
        }
    }
}

/// Plugin extensions the host uses, queried once after instantiation.
#[derive(Clone, Copy)]
struct Extensions {
    params: Option<PluginParams>,
    state: Option<PluginStateExtension>,
    gui: Option<PluginGui>,
    latency: Option<PluginLatency>,
    audio_ports: Option<PluginAudioPorts>,
    note_ports: Option<PluginNotePorts>,
    render: Option<PluginRender>,
    timer: Option<PluginTimer>,
    #[cfg(target_os = "linux")]
    posix_fd: Option<clack_extensions::posix_fd::PluginPosixFd>,
}

/// Rejects envelopes this backend did not write for this plugin.
fn validate(identity: &PluginIdentity, state: &PluginState) -> Result<(), HostError> {
    if state.version != STATE_VERSION
        || state.identity != *identity
        || state.component.len() > MAX_STATE_BYTES
        || state
            .controller
            .as_ref()
            .is_some_and(|controller| controller.len() > MAX_STATE_BYTES)
    {
        return Err(HostError::InvalidState(
            "unsupported state version, identity, or size".into(),
        ));
    }
    Ok(())
}

fn plugin_call(operation: &'static str) -> HostError {
    HostError::PluginCall {
        operation,
        code: -1,
    }
}

pub(crate) struct ClapInstance {
    pub descriptor: PluginDescriptor,
    pub exchange: Arc<ParameterExchange>,
    parameters: Arc<[ClapParameter]>,
    note_input: Option<NoteInput>,
    lifecycle: AnyInstanceLifecycle,
    layout: PortLayout,
    editor: Option<ClapEditor>,
    editor_supported: bool,
    editor_size: Option<(u32, u32)>,
    resize_handler: Option<EditorResizeHandler>,
    restart_pending: bool,
    due_timers: Vec<u32>,
    extensions: Extensions,
    pub slot: Option<Arc<ProcessorSlot>>,
    pub endpoint_taken: bool,
    /// Declared after the slot, so the plugin outlives its deactivated audio processor.
    plugin: RefCell<PluginInstance<ClapHostHandlers>>,
    /// Declared last, so the entry outlives the plugin created from it.
    _module: Rc<ClapModule>,
}

impl ClapInstance {
    pub fn create(module: Rc<ClapModule>, descriptor: PluginDescriptor) -> Result<Self, HostError> {
        let unavailable = |message: &str| HostError::Module {
            path: module.path.clone(),
            message: message.to_owned(),
        };
        let id = CString::new(descriptor.identity.native_id.as_str())
            .map_err(|_| unavailable("plugin ID contains a NUL byte"))?;
        let info = HostInfo::new("DigiDAW", "DigiDAW", "", env!("CARGO_PKG_VERSION"))
            .map_err(|_| unavailable("host information contains a NUL byte"))?;
        let label = descriptor.name.clone();
        let mut plugin = PluginInstance::<ClapHostHandlers>::new(
            |_| ClapHostSharedHandler::new(&label),
            |shared| ClapHostMainThreadHandler::new(shared),
            module.entry(),
            &id,
            &info,
        )
        .map_err(|error| {
            tracing::warn!("{label}: CLAP instantiation failed: {error}");
            unavailable(&error.to_string())
        })?;
        let shared = plugin.plugin_shared_handle();
        let extensions = Extensions {
            params: shared.get_extension(),
            state: shared.get_extension(),
            gui: shared.get_extension(),
            latency: shared.get_extension(),
            audio_ports: shared.get_extension(),
            note_ports: shared.get_extension(),
            render: shared.get_extension(),
            timer: shared.get_extension(),
            #[cfg(target_os = "linux")]
            posix_fd: shared.get_extension(),
        };
        let handle = plugin.plugin_handle();
        let editor_supported = extensions
            .gui
            .is_some_and(|gui| editor::supported(gui, &handle));
        let note_input = extensions.note_ports.and_then(|ports| {
            if ports.count(&handle, true) == 0 {
                return None;
            }
            let mut buffer = NotePortInfoBuffer::new();
            let port = ports.get(&handle, 0, true, &mut buffer)?;
            NoteInput::choose(port.supported_dialects, port.preferred_dialect)
        });
        let mut list = Vec::new();
        let mut values = Vec::new();
        if let Some(params) = extensions.params {
            let mut buffer = ParamInfoBuffer::new();
            for index in 0..params.count(&handle) {
                if let Some(parameter) = params
                    .get_info(&handle, index, &mut buffer)
                    .and_then(|info| ClapParameter::from_info(&info))
                {
                    list.push(parameter);
                }
            }
            list = parameters::sorted(list);
            for parameter in &list {
                let plain = ClapId::from_raw(parameter.id)
                    .and_then(|id| params.get_value(&handle, id))
                    .unwrap_or(parameter.default);
                values.push((parameter.id, parameter.to_normalized(plain)));
            }
        }
        Ok(Self {
            descriptor,
            exchange: ParameterExchange::new(&values),
            parameters: Arc::from(list),
            note_input,
            lifecycle: AnyInstanceLifecycle::unprepared(),
            layout: PortLayout::default(),
            editor: None,
            editor_supported,
            editor_size: None,
            resize_handler: None,
            restart_pending: false,
            due_timers: Vec::new(),
            extensions,
            slot: None,
            endpoint_taken: false,
            plugin: RefCell::new(plugin),
            _module: module,
        })
    }

    /// Borrows the plugin for a main-thread call.
    ///
    /// A plugin that calls back into the host never reaches this cell, so a failed borrow only
    /// means the owner re-entered itself.
    fn plugin(&self) -> Result<RefMut<'_, PluginInstance<ClapHostHandlers>>, HostError> {
        self.plugin.try_borrow_mut().map_err(|_| HostError::Busy)
    }

    /// Processing configuration the instance is prepared for, if any.
    pub fn config(&self) -> Option<&ProcessingConfig> {
        self.lifecycle.config()
    }

    /// Whether the owner last resumed processing.
    pub fn is_running(&self) -> bool {
        matches!(self.lifecycle, AnyInstanceLifecycle::Running(_))
    }

    /// Whether a sidechain input can be fed.
    pub fn has_sidechain(&self) -> bool {
        self.layout.sidechain.is_some()
    }

    /// Parameter specifications carrying the current normalized values.
    pub fn parameters(&self) -> Vec<ParameterSpec> {
        self.parameters
            .iter()
            .zip(&self.exchange.parameters)
            .map(|(parameter, shared)| parameter.spec(shared.get()))
            .collect()
    }

    pub fn parameter(&self, id: u32) -> Result<&ClapParameter, HostError> {
        self.parameters
            .binary_search_by_key(&id, |parameter| parameter.id)
            .ok()
            .and_then(|position| self.parameters.get(position))
            .ok_or(HostError::InvalidParameter(id))
    }

    /// Applies a run-time lifecycle transition, keeping the current state when it is not
    /// valid from it.
    fn advance(
        &mut self,
        transition: impl FnOnce(
            AnyInstanceLifecycle,
        )
            -> Result<AnyInstanceLifecycle, (AnyInstanceLifecycle, InvalidState)>,
    ) -> Result<(), HostError> {
        let current = std::mem::replace(&mut self.lifecycle, AnyInstanceLifecycle::unprepared());
        match transition(current) {
            Ok(next) => {
                self.lifecycle = next;
                Ok(())
            }
            Err((unchanged, _)) => {
                self.lifecycle = unchanged;
                Err(HostError::InvalidTransition)
            }
        }
    }

    /// Activates the plugin for `config`, deactivating an earlier activation first.
    ///
    /// The plugin keeps its state across activations; current parameter values are delivered
    /// again once it is active.
    pub fn prepare(&mut self, config: &ProcessingConfig) -> Result<(), HostError> {
        config.validate()?;
        self.suspend()?;
        self.advance(AnyInstanceLifecycle::begin_prepare)?;
        self.deactivate()?;
        let layout = self.read_layout()?;
        if layout.main_output.is_none() {
            return Err(HostError::Unsupported("plugin has no main audio output"));
        }
        if !layout.within_limits() {
            return Err(HostError::Unsupported(
                "plugin audio port has too many channels",
            ));
        }
        let configuration = PluginAudioConfiguration {
            sample_rate: config.sample_rate,
            min_frames_count: 1,
            max_frames_count: u32::try_from(config.max_block_size)
                .map_err(|_| HostError::InvalidConfiguration)?,
        };
        let (processor, latency) = {
            let mut plugin = self.plugin()?;
            if let Some(render) = self.extensions.render {
                let mode = if config.offline {
                    RenderMode::Offline
                } else {
                    RenderMode::Realtime
                };
                if render.set(&plugin.plugin_handle(), mode).is_err() {
                    tracing::debug!("{}: CLAP render mode was not changed", self.descriptor.name);
                }
            }
            let processor = plugin.activate(|_, _| (), configuration).map_err(|error| {
                tracing::warn!("{}: CLAP activation failed: {error}", self.descriptor.name);
                plugin_call("clap.activate")
            })?;
            let latency = self
                .extensions
                .latency
                .map_or(0, |latency| latency.get(&plugin.plugin_handle()));
            (processor, latency.min(MAX_LATENCY_FRAMES))
        };
        let dsp = Dsp::new(
            processor.into(),
            config.clone(),
            layout.clone(),
            self.parameters.clone(),
            self.extensions.params,
            self.note_input,
        );
        if let Some(slot) = &self.slot {
            // SAFETY: Suspension succeeded above, excluding all DSP access; the previous
            // processor was taken back and deactivated.
            unsafe { *slot.dsp.get() = dsp };
            slot.latency.store(latency, Ordering::Release);
        } else {
            self.slot = Some(Arc::new(ProcessorSlot {
                gate: ProcessingGate::default(),
                dsp: UnsafeCell::new(dsp),
                latency: AtomicU32::new(latency),
                endpoint_alive: AtomicBool::new(false),
            }));
        }
        self.layout = layout;
        self.advance(|lifecycle| lifecycle.finish_prepare(config.clone()))?;
        self.flush_parameters()
    }

    /// Reads the plugin's audio ports, which may only change while it is inactive.
    fn read_layout(&self) -> Result<PortLayout, HostError> {
        let Some(ports) = self.extensions.audio_ports else {
            return Ok(PortLayout::default());
        };
        let mut plugin = self.plugin()?;
        let handle = plugin.plugin_handle();
        let mut buffer = AudioPortInfoBuffer::new();
        let mut read = |is_input: bool| {
            (0..ports.count(&handle, is_input))
                .map(|index| {
                    ports
                        .get(&handle, index, is_input, &mut buffer)
                        .map_or((0, false), |port| {
                            (
                                port.channel_count,
                                port.flags.contains(AudioPortFlags::IS_MAIN),
                            )
                        })
                })
                .collect::<Vec<_>>()
        };
        let inputs = read(true);
        let outputs = read(false);
        Ok(PortLayout::new(&inputs, &outputs))
    }

    /// Takes the processor back from the suspended slot, stops it, and deactivates the plugin.
    fn deactivate(&mut self) -> Result<(), HostError> {
        let Some(slot) = &self.slot else {
            return Ok(());
        };
        // SAFETY: Callers suspend processing first, so the owner has exclusive DSP access.
        let dsp = unsafe { &mut *slot.dsp.get() };
        let Some(processor) = dsp.take_processor() else {
            return Ok(());
        };
        let stopped = {
            // Stopping processing is an audio-thread call, made while DSP access is exclusive.
            let _audio = AudioContext::enter();
            processor.into_stopped()
        };
        drop(stopped);
        self.plugin()?.try_deactivate().map_err(|error| {
            tracing::error!(
                "{}: CLAP deactivation failed: {error}",
                self.descriptor.name
            );
            plugin_call("clap.deactivate")
        })
    }

    pub fn suspend(&mut self) -> Result<(), HostError> {
        if let Some(slot) = &self.slot {
            slot.gate.suspend()?;
        }
        // An unprepared instance has nothing to suspend and stays as it is.
        drop(self.advance(AnyInstanceLifecycle::suspended));
        Ok(())
    }

    pub fn resume(&mut self) -> Result<(), HostError> {
        if self.config().is_none() {
            return Err(HostError::InvalidTransition);
        }
        let slot = self.slot.as_ref().ok_or(HostError::InvalidTransition)?;
        if !slot.gate.is_suspended() {
            return Err(HostError::InvalidTransition);
        }
        slot.gate.resume()?;
        self.advance(AnyInstanceLifecycle::resumed)
    }

    pub fn flush_parameters(&mut self) -> Result<(), HostError> {
        self.suspend()?;
        if let Some(slot) = &self.slot {
            // SAFETY: Exclusive suspended DSP access; the flush delivers cached edits.
            let dsp = unsafe { &mut *slot.dsp.get() };
            dsp.flush(&self.exchange);
        }
        Ok(())
    }

    pub fn save_state(&mut self) -> Result<PluginState, HostError> {
        self.flush_parameters()?;
        let identity = self.descriptor.identity.clone();
        let Some(extension) = self.extensions.state else {
            // Without the state extension the parameter values are the whole state.
            let values = self
                .parameters
                .iter()
                .zip(&self.exchange.parameters)
                .map(|(parameter, shared)| (parameter.id, parameter.to_plain(shared.get())))
                .collect::<Vec<_>>();
            return Ok(PluginState {
                version: STATE_VERSION,
                identity,
                component: Vec::new(),
                controller: Some(parameters::encode_values(&values)),
            });
        };
        let mut component = Vec::new();
        extension
            .save(&self.plugin()?.plugin_handle(), &mut component)
            .map_err(|_| plugin_call("clap.state.save"))?;
        if component.len() > MAX_STATE_BYTES {
            return Err(HostError::InvalidState(
                "plugin state exceeds the size limit".into(),
            ));
        }
        Ok(PluginState {
            version: STATE_VERSION,
            identity,
            component,
            controller: None,
        })
    }

    pub fn restore_state(&mut self, state: &PluginState) -> Result<(), HostError> {
        validate(&self.descriptor.identity, state)?;
        self.suspend()?;
        if !state.component.is_empty() {
            let extension = self.extensions.state.ok_or_else(|| {
                HostError::InvalidState("plugin cannot restore saved state".into())
            })?;
            extension
                .load(
                    &self.plugin()?.plugin_handle(),
                    &mut std::io::Cursor::new(&state.component),
                )
                .map_err(|_| plugin_call("clap.state.load"))?;
            self.read_values(false)?;
        }
        if let Some(controller) = &state.controller {
            let values = parameters::decode_values(controller)
                .ok_or_else(|| HostError::InvalidState("malformed parameter values".into()))?;
            for (id, plain) in values {
                let Ok(position) = self.parameters.binary_search_by_key(&id, |p| p.id) else {
                    continue;
                };
                if let (Some(parameter), Some(shared)) = (
                    self.parameters.get(position),
                    self.exchange.parameters.get(position),
                ) {
                    shared.set(parameter.to_normalized(plain), 0);
                }
            }
            self.flush_parameters()?;
        }
        Ok(())
    }

    /// Reads every parameter's value from the plugin.
    ///
    /// After a state load the plugin's values replace pending edits. When the plugin reports a
    /// change on its own, pending edits are kept and changed values are reported to the host.
    fn read_values(&self, report: bool) -> Result<(), HostError> {
        let Some(params) = self.extensions.params else {
            return Ok(());
        };
        let mut plugin = self.plugin()?;
        let handle = plugin.plugin_handle();
        for (parameter, shared) in self.parameters.iter().zip(&self.exchange.parameters) {
            if report && shared.pending.load(Ordering::Acquire) {
                continue;
            }
            let Some(plain) =
                ClapId::from_raw(parameter.id).and_then(|id| params.get_value(&handle, id))
            else {
                continue;
            };
            let normalized = parameter.to_normalized(plain);
            let previous = shared.get();
            shared.value.store(normalized.to_bits(), Ordering::Release);
            shared.pending.store(false, Ordering::Release);
            if report && (previous - normalized).abs() > f64::EPSILON {
                shared.mark_user_edited();
                shared.edits.fetch_or(EDIT_CHANGED, Ordering::Relaxed);
            }
        }
        Ok(())
    }

    /// Formats a normalized value with the plugin's own text, or as a plain number.
    pub fn parameter_text(&self, id: u32, normalized: f64) -> Result<String, HostError> {
        let plain = self.parameter(id)?.to_plain(normalized);
        if let (Some(params), Some(clap_id)) = (self.extensions.params, ClapId::from_raw(id)) {
            let mut buffer = [0_u8; 256];
            if let Ok(text) =
                params.value_to_text(&self.plugin()?.plugin_handle(), clap_id, plain, &mut buffer)
            {
                return Ok(String::from_utf8_lossy(text).into_owned());
            }
        }
        Ok(if plain.abs() >= 100.0 {
            format!("{plain:.1}")
        } else {
            format!("{plain:.3}")
        })
    }

    /// Parses display text with the plugin's own parser, or as a plain number.
    pub fn parse_parameter(&self, id: u32, text: &str) -> Result<f64, HostError> {
        let parameter = self.parameter(id)?;
        let text = text.trim();
        if let (Some(params), Some(clap_id), Ok(native)) = (
            self.extensions.params,
            ClapId::from_raw(id),
            CString::new(text),
        ) && let Some(plain) =
            params.text_to_value(&self.plugin()?.plugin_handle(), clap_id, &native)
        {
            return Ok(parameter.to_normalized(plain));
        }
        text.parse::<f64>()
            .ok()
            .filter(|plain| plain.is_finite())
            .map(|plain| parameter.to_normalized(plain))
            .ok_or(HostError::InvalidParameter(id))
    }

    /// Whether the plugin can embed an editor in the host's window.
    pub const fn has_editor(&self) -> bool {
        self.editor_supported
    }

    /// Creates the editor, which is needed before its size can be read.
    fn ensure_editor(&mut self) -> Result<(), HostError> {
        if self.editor.is_some() {
            return Ok(());
        }
        let gui = self
            .extensions
            .gui
            .filter(|_| self.editor_supported)
            .ok_or(HostError::Unsupported("native editor"))?;
        let editor = ClapEditor::create(gui, &self.plugin()?.plugin_handle())?;
        self.editor = Some(editor);
        Ok(())
    }

    /// Whether the user may resize the editor window.
    pub fn editor_resizable(&mut self) -> Result<bool, HostError> {
        self.ensure_editor()?;
        Ok(self.editor.as_ref().is_some_and(ClapEditor::resizable))
    }

    /// Client size of the editor, of the last one, or the size used before one reports it.
    pub fn editor_size(&mut self) -> Result<(u32, u32), HostError> {
        self.ensure_editor()?;
        let reported = match &self.editor {
            Some(editor) => editor.size(&self.plugin()?.plugin_handle()),
            None => None,
        };
        Ok(reported.or(self.editor_size).unwrap_or(DEFAULT_EDITOR_SIZE))
    }

    pub fn set_editor_resize_handler(&mut self, handler: EditorResizeHandler) {
        self.resize_handler = Some(handler);
    }

    pub fn open_editor(&mut self, parent: &NativeParentHandle) -> Result<(), HostError> {
        self.ensure_editor()?;
        let mut plugin = self.plugin.try_borrow_mut().map_err(|_| HostError::Busy)?;
        let editor = self.editor.as_mut().ok_or(HostError::InvalidTransition)?;
        editor.attach(&plugin.plugin_handle(), parent)
    }

    pub fn resize_editor(&mut self, width: u32, height: u32) -> Result<(), HostError> {
        let editor = self.editor.as_ref().ok_or(HostError::InvalidTransition)?;
        editor.resize(
            &self.plugin()?.plugin_handle(),
            width,
            height,
            self.resize_handler.as_ref(),
        )
    }

    pub fn close_editor(&mut self) {
        let Some(editor) = self.editor.take() else {
            return;
        };
        let Ok(mut plugin) = self.plugin.try_borrow_mut() else {
            // Only a re-entrant close gets here; the outer call still owns the plugin.
            tracing::error!(
                "{}: CLAP editor closed while the plugin was in use",
                self.descriptor.name
            );
            self.editor = Some(editor);
            return;
        };
        let handle = plugin.plugin_handle();
        self.editor_size = editor.size(&handle).or(self.editor_size);
        editor.destroy(&handle);
    }

    /// Services the plugin's main-thread requests, timers, and descriptors, and reports whether
    /// the plugin closed its editor.
    pub fn pump(&mut self) -> bool {
        let Ok(mut plugin) = self.plugin.try_borrow_mut() else {
            return false;
        };
        let (callback, restart, flush, closed, resize) = plugin.access_shared_handler(|host| {
            (
                host.callback_requested.swap(false, Ordering::AcqRel),
                host.restart_requested.swap(false, Ordering::AcqRel),
                host.flush_requested.swap(false, Ordering::AcqRel),
                host.editor_closed.swap(false, Ordering::AcqRel),
                host.take_resize_request(),
            )
        });
        if callback {
            plugin.call_on_main_thread_callback();
        }
        if let Some(timer) = self.extensions.timer {
            let due = &mut self.due_timers;
            plugin.access_handler(|host| host.due_timers(Instant::now(), due));
            for &id in due.iter() {
                if plugin.access_handler(|host| host.has_timer(id)) {
                    timer.on_timer(&plugin.plugin_handle(), TimerId(id));
                }
            }
        }
        #[cfg(target_os = "linux")]
        if let Some(descriptors) = self.extensions.posix_fd {
            let registered = plugin.access_handler(|host| {
                host.fds
                    .try_borrow()
                    .map(|fds| fds.clone())
                    .unwrap_or_default()
            });
            for (fd, flags) in registered {
                let Some(ready) = fd_ready(fd, flags) else {
                    continue;
                };
                let still_registered = plugin.access_handler(|host| {
                    host.fds
                        .try_borrow()
                        .is_ok_and(|fds| fds.iter().any(|(registered, _)| *registered == fd))
                });
                if still_registered {
                    descriptors.on_fd(&plugin.plugin_handle(), fd, ready);
                }
            }
        }
        let values_changed = plugin.access_handler(|host| host.values_changed.replace(false));
        drop(plugin);
        self.restart_pending |= restart;
        if values_changed && let Err(error) = self.read_values(true) {
            tracing::debug!("{}: CLAP values not read: {error}", self.descriptor.name);
        }
        // A running instance receives the plugin's output in its next block.
        if flush
            && !self.is_running()
            && let Err(error) = self.flush_parameters()
        {
            tracing::debug!("{}: CLAP parameter flush: {error}", self.descriptor.name);
        }
        if let (Some((width, height)), Some(handler)) = (resize, &self.resize_handler)
            && self.editor.is_some()
            && handler(width, height)
        {
            self.editor_size = Some((width, height));
        }
        if closed && self.editor.is_some() {
            self.close_editor();
            return true;
        }
        false
    }

    /// Activates the plugin again after it asked for a restart, keeping it running if it was.
    ///
    /// Returns [`HostError::Busy`] while an audio block still owns the processor; the request
    /// stays pending for a later call.
    pub fn restart_if_requested(&mut self) -> Result<(), HostError> {
        if !self.restart_pending {
            return Ok(());
        }
        let Some(config) = self.config().cloned() else {
            self.restart_pending = false;
            return Ok(());
        };
        let running = self.is_running();
        if let Some(slot) = &self.slot {
            slot.gate.suspend()?;
        }
        self.restart_pending = false;
        self.prepare(&config)?;
        if running {
            self.resume()?;
        }
        Ok(())
    }
}

impl Drop for ClapInstance {
    fn drop(&mut self) {
        self.close_editor();
        let exclusive = self
            .slot
            .as_ref()
            .is_none_or(|slot| Arc::strong_count(slot) == 1 && slot.gate.suspend().is_ok());
        if !exclusive {
            tracing::error!(
                "{}: CLAP instance dropped while its processor is in use",
                self.descriptor.name
            );
            return;
        }
        if let Err(error) = self.deactivate() {
            tracing::error!("{}: CLAP teardown: {error}", self.descriptor.name);
        }
    }
}

/// Polls one registered descriptor without blocking and returns the events it is ready for.
#[cfg(target_os = "linux")]
fn fd_ready(
    fd: i32,
    flags: clack_extensions::posix_fd::FdFlags,
) -> Option<clack_extensions::posix_fd::FdFlags> {
    use clack_extensions::posix_fd::FdFlags;
    const POLLIN: i16 = 0x1;
    const POLLOUT: i16 = 0x4;
    const POLLERR: i16 = 0x8;
    const POLLHUP: i16 = 0x10;
    const POLLNVAL: i16 = 0x20;
    #[repr(C)]
    struct PollFd {
        fd: i32,
        events: i16,
        revents: i16,
    }
    unsafe extern "C" {
        fn poll(fds: *mut PollFd, count: std::ffi::c_ulong, timeout: i32) -> i32;
    }
    let mut events = 0;
    if flags.contains(FdFlags::READ) {
        events |= POLLIN;
    }
    if flags.contains(FdFlags::WRITE) {
        events |= POLLOUT;
    }
    let mut descriptor = PollFd {
        fd,
        events,
        revents: 0,
    };
    // SAFETY: One writable record and a zero timeout, so the UI loop never blocks.
    if unsafe { poll(&raw mut descriptor, 1, 0) } <= 0 {
        return None;
    }
    let mut ready = FdFlags::empty();
    if descriptor.revents & POLLIN != 0 {
        ready |= FdFlags::READ;
    }
    if descriptor.revents & POLLOUT != 0 {
        ready |= FdFlags::WRITE;
    }
    if descriptor.revents & (POLLERR | POLLHUP | POLLNVAL) != 0 && flags.contains(FdFlags::ERROR) {
        ready |= FdFlags::ERROR;
    }
    (!ready.is_empty()).then_some(ready)
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "the fixture walks transitions known to be valid"
)]
mod tests {
    use super::*;
    use karbeat_host_api::PluginFormat;

    fn config() -> ProcessingConfig {
        ProcessingConfig {
            sample_rate: 48_000.0,
            max_block_size: 512,
            main_input_channels: 2,
            main_output_channels: 2,
            sidechain_channels: 0,
            offline: false,
        }
    }

    #[test]
    fn lifecycle_keeps_its_configuration_and_rejects_resume_before_preparation() {
        let lifecycle = AnyInstanceLifecycle::unprepared();
        assert!(lifecycle.config().is_none());
        let (lifecycle, _) = lifecycle.resumed().err().unwrap();
        let prepared = lifecycle
            .begin_prepare()
            .ok()
            .unwrap()
            .finish_prepare(config())
            .ok()
            .unwrap();
        assert_eq!(prepared.config(), Some(&config()));
        let running = prepared.resumed().ok().unwrap();
        assert!(matches!(running, AnyInstanceLifecycle::Running(_)));
        let suspended = running.suspended().ok().unwrap();
        assert_eq!(suspended.config(), Some(&config()));
    }

    #[test]
    fn envelopes_for_another_version_or_plugin_are_rejected() {
        let identity = PluginIdentity {
            format: PluginFormat::Clap,
            native_id: "org.example.plugin".into(),
        };
        let mut state = PluginState {
            version: STATE_VERSION,
            identity: identity.clone(),
            component: b"state".to_vec(),
            controller: None,
        };
        assert!(validate(&identity, &state).is_ok());
        state.version += 1;
        assert!(matches!(
            validate(&identity, &state),
            Err(HostError::InvalidState(_))
        ));
        state.version = STATE_VERSION;
        state.identity.format = PluginFormat::Vst3;
        assert!(validate(&identity, &state).is_err());
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn descriptors_report_only_the_events_they_are_ready_for() {
        use clack_extensions::posix_fd::FdFlags;
        use std::io::Write as _;
        use std::os::fd::AsRawFd as _;
        let (reader, mut writer) = std::io::pipe().unwrap();
        assert_eq!(fd_ready(reader.as_raw_fd(), FdFlags::READ), None);
        writer.write_all(b"x").unwrap();
        assert_eq!(
            fd_ready(reader.as_raw_fd(), FdFlags::READ),
            Some(FdFlags::READ)
        );
        assert_eq!(
            fd_ready(writer.as_raw_fd(), FdFlags::WRITE),
            Some(FdFlags::WRITE)
        );
    }
}
