//! UI-owned plugin instance, parameter, state, and editor lifecycle.

use std::{
    cell::UnsafeCell,
    ffi::{CStr, CString, c_void},
    rc::Rc,
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicU32, Ordering},
    },
};

use karbeat_host_api::{
    HostError, NativeParentHandle, ParameterExchange, PluginDescriptor, PluginState,
    ProcessingConfig, ProcessingGate, native_host::EditorResizeHandler,
};
use karbeat_plugin_api::prelude::ParameterSpec;
use karbeat_utils::typestate::InvalidState;

use crate::{
    atoms::{PositionUrids, atom_ring},
    editor::{DEFAULT_SIZE, EditorLink, EditorPlan, EditorSetup, Lv2Editor},
    plugin::PluginInstance,
    ports::PluginModel,
    state::{self, PortValue},
    urid,
    uris::{ATOM, MIDI_EVENT, TIME},
    world::{Lv2Bundle, unhostable},
    wrapper::{Dsp, DspLink, DspUrids, ProcessorSlot},
};

/// Smallest ring for atoms an editor sends to its plugin.
const MIN_TO_DSP_BYTES: usize = 32 * 1024;
/// Smallest ring for atoms a plugin sends to its editor.
const MIN_TO_EDITOR_BYTES: usize = 64 * 1024;
/// Largest ring allocated for either direction.
const MAX_RING_BYTES: usize = 2 * 1024 * 1024;

karbeat_utils::typestate! {
    /// Processing lifecycle of one instance, as its UI owner last left it.
    ///
    /// The audio thread can finish suspending on its own after a busy suspension, so
    /// `Running` records the owner's last successful resume, not the gate's current state.
    machine InstanceLifecycle {
        shared: (),
        erased: AnyInstanceLifecycle,
        states {
            /// Created, or being prepared again; no processing configuration applies.
            Unprepared as UnpreparedInstance {}
            /// Prepared for `config` with processing suspended.
            Prepared as PreparedInstance { config: ProcessingConfig }
            /// Prepared for `config` and resumed.
            Running as RunningInstance { config: ProcessingConfig }
        }
        transitions {
            // Preparation starts only once processing is suspended.
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

fn dsp_urids() -> DspUrids {
    let atom = |name: &str| urid::map_str(&format!("{ATOM}{name}"));
    let time = |name: &str| urid::map_str(&format!("{TIME}{name}"));
    DspUrids {
        sequence: atom("Sequence"),
        chunk: atom("Chunk"),
        midi_event: urid::map_str(MIDI_EVENT),
        position: PositionUrids {
            object: atom("Object"),
            position: time("Position"),
            long: atom("Long"),
            int: atom("Int"),
            float: atom("Float"),
            frame: time("frame"),
            speed: time("speed"),
            bar: time("bar"),
            bar_beat: time("barBeat"),
            beat_unit: time("beatUnit"),
            beats_per_bar: time("beatsPerBar"),
            beats_per_minute: time("beatsPerMinute"),
        },
    }
}

pub(crate) struct Lv2Instance {
    pub descriptor: PluginDescriptor,
    pub model: PluginModel,
    pub exchange: Arc<ParameterExchange>,
    specs: Vec<ParameterSpec>,
    control_symbols: Vec<CString>,
    lifecycle: AnyInstanceLifecycle,
    /// Declared before the slot so an editor is always destroyed before its plugin instance.
    editor: Option<Lv2Editor>,
    editor_plan: Option<EditorPlan>,
    editor_link: Option<EditorLink>,
    editor_size: Option<(u32, u32)>,
    resize_handler: Option<EditorResizeHandler>,
    pub slot: Option<Arc<ProcessorSlot>>,
    pub endpoint_taken: bool,
    /// `LV2_Handle` of the current plugin instance, shared with editors through
    /// `instance-access`.
    plugin_handle: *mut c_void,
    bundle: Rc<Lv2Bundle>,
}

impl Lv2Instance {
    pub fn create(bundle: Rc<Lv2Bundle>, descriptor: PluginDescriptor) -> Result<Self, HostError> {
        let unavailable = |message: &str| HostError::Module {
            path: bundle.path.clone(),
            message: message.to_owned(),
        };
        let plugin = bundle.plugin(&descriptor.identity.native_id)?;
        if let Some(reason) = unhostable(&plugin, &bundle.uris) {
            log::warn!("{}: LV2 plugin cannot be hosted: {reason}", descriptor.name);
            return Err(HostError::Unsupported("LV2 plugin cannot be hosted"));
        }
        let model = PluginModel::read(&plugin, &bundle.world, &bundle.uris)?;
        if !model.has_main_output() {
            return Err(HostError::Unsupported("plugin has no main audio output"));
        }
        let specs = model
            .controls
            .iter()
            .map(|control| control.spec(control.to_normalized(control.range.default)))
            .collect::<Vec<_>>();
        let control_symbols = model
            .controls
            .iter()
            .map(|control| CString::new(control.symbol.as_str()))
            .collect::<Result<Vec<_>, _>>()
            .map_err(|_| unavailable("a port symbol contains a NUL byte"))?;
        let values = specs
            .iter()
            .map(|spec| (spec.id, spec.value))
            .collect::<Vec<_>>();
        Ok(Self {
            editor_plan: EditorPlan::discover(&plugin, &bundle.world, &bundle.uris),
            descriptor,
            model,
            exchange: ParameterExchange::new(&values),
            specs,
            control_symbols,
            lifecycle: AnyInstanceLifecycle::unprepared(),
            editor: None,
            editor_link: None,
            editor_size: None,
            resize_handler: None,
            slot: None,
            endpoint_taken: false,
            plugin_handle: std::ptr::null_mut(),
            bundle,
        })
    }

    /// Processing configuration the instance is prepared for, if any.
    pub fn config(&self) -> Option<&ProcessingConfig> {
        self.lifecycle.config()
    }

    /// Whether the owner last resumed processing.
    pub fn is_running(&self) -> bool {
        matches!(self.lifecycle, AnyInstanceLifecycle::Running(_))
    }

    /// Parameter specifications carrying the current normalized values.
    pub fn parameters(&self) -> Vec<ParameterSpec> {
        self.specs
            .iter()
            .zip(&self.exchange.parameters)
            .map(|(spec, parameter)| {
                let mut spec = spec.clone();
                spec.value = parameter.get();
                spec
            })
            .collect()
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

    /// Instantiates the plugin for `config`, replacing any earlier plugin instance.
    ///
    /// LV2 fixes the sample rate at instantiation, so every preparation creates a new plugin
    /// instance. Current control values carry over; plugin-internal state does not, which is
    /// why the native owner restores captured state after preparing a copy.
    pub fn prepare(&mut self, config: &ProcessingConfig) -> Result<(), HostError> {
        config.validate()?;
        self.suspend()?;
        self.advance(AnyInstanceLifecycle::begin_prepare)?;
        // An open editor may hold the old plugin handle through `instance-access`.
        self.close_editor();
        let record = self
            .bundle
            .plugin_record(&self.descriptor.identity.native_id)?;
        let instance =
            PluginInstance::instantiate(record, &self.model, config).inspect_err(|error| {
                log::warn!(
                    "{}: LV2 instantiation failed: {error}",
                    self.descriptor.name
                )
            })?;
        self.plugin_handle = instance.handle();
        let (dsp_link, editor_link) = self.editor_rings();
        let mut dsp = Dsp::new(instance, config.clone(), &self.model, dsp_urids(), dsp_link);
        for (control, parameter) in self.model.controls.iter().zip(&self.exchange.parameters) {
            dsp.set_control(control.index, control.to_plain(parameter.get()));
            parameter.pending.store(false, Ordering::Release);
        }
        if let Some(slot) = &self.slot {
            // SAFETY: suspend succeeded before preparation, excluding all DSP access.
            unsafe { *slot.dsp.get() = dsp };
        } else {
            self.slot = Some(Arc::new(ProcessorSlot {
                gate: ProcessingGate::default(),
                dsp: UnsafeCell::new(dsp),
                latency: AtomicU32::new(0),
                endpoint_alive: AtomicBool::new(false),
                editor_open: AtomicBool::new(false),
                control_outputs: self
                    .model
                    .control_outputs
                    .iter()
                    .map(|_| AtomicU32::new(0))
                    .collect(),
            }));
        }
        self.editor_link = editor_link;
        self.advance(|lifecycle| lifecycle.finish_prepare(config.clone()))?;
        // LV2 reports latency through a control output, which only a rendered block updates.
        self.flush_parameters()
    }

    /// Creates the message rings between an editor and the audio path, when both exist.
    fn editor_rings(&self) -> (Option<DspLink>, Option<EditorLink>) {
        let has_atoms = !self.model.atom_inputs.is_empty() || !self.model.atom_outputs.is_empty();
        if self.editor_plan.is_none() || !has_atoms {
            return (None, None);
        }
        let largest_input = self
            .model
            .atom_inputs
            .iter()
            .map(|port| port.capacity)
            .max()
            .unwrap_or(0);
        let outputs: usize = self
            .model
            .atom_outputs
            .iter()
            .map(|port| port.capacity)
            .sum();
        let (to_dsp, from_editor) = atom_ring(
            largest_input
                .saturating_mul(2)
                .clamp(MIN_TO_DSP_BYTES, MAX_RING_BYTES),
        );
        let (to_editor, from_dsp) = atom_ring(
            outputs
                .saturating_mul(2)
                .clamp(MIN_TO_EDITOR_BYTES, MAX_RING_BYTES),
        );
        (
            Some(DspLink {
                from_editor,
                to_editor,
            }),
            Some(EditorLink { to_dsp, from_dsp }),
        )
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
            // SAFETY: Exclusive suspended DSP access; the block delivers cached edits and lets
            // the plugin report its latency.
            let dsp = unsafe { &mut *slot.dsp.get() };
            dsp.flush(&self.exchange, slot);
        }
        Ok(())
    }

    pub fn save_state(&mut self) -> Result<PluginState, HostError> {
        self.flush_parameters()?;
        let Some(slot) = &self.slot else {
            return Err(HostError::InvalidTransition);
        };
        let ports = self
            .model
            .controls
            .iter()
            .zip(&self.control_symbols)
            .zip(&self.exchange.parameters)
            .map(|((control, symbol), parameter)| PortValue {
                symbol: symbol.clone(),
                value: control.to_plain(parameter.get()),
            })
            .collect::<Vec<_>>();
        // SAFETY: `flush_parameters` left processing suspended, so the UI owner has exclusive
        // access to the plugin instance.
        let dsp = unsafe { &*slot.dsp.get() };
        state::capture(
            &self.bundle,
            &self.descriptor.identity,
            dsp.instance(),
            &ports,
        )
    }

    pub fn restore_state(&mut self, state: &PluginState) -> Result<(), HostError> {
        state::validate(&self.descriptor.identity, state)?;
        self.suspend()?;
        let Some(slot) = &self.slot else {
            return Err(HostError::InvalidTransition);
        };
        let mut restored = Vec::new();
        // SAFETY: Processing is suspended, so the UI owner has exclusive access to the plugin
        // instance while it restores.
        let dsp = unsafe { &*slot.dsp.get() };
        state::restore(
            &self.bundle,
            &self.descriptor.identity,
            dsp.instance(),
            state,
            &mut |symbol: &CStr, plain: f32| restored.push((symbol.to_owned(), plain)),
        )?;
        // SAFETY: As above; the shared borrow used for restoring has ended.
        let dsp = unsafe { &mut *slot.dsp.get() };
        for (symbol, plain) in restored {
            let Some(position) = self
                .control_symbols
                .iter()
                .position(|candidate| *candidate == symbol)
            else {
                continue;
            };
            if let (Some(control), Some(parameter)) = (
                self.model.controls.get(position),
                self.exchange.parameters.get(position),
            ) {
                let normalized = control.to_normalized(plain);
                dsp.set_control(control.index, control.to_plain(normalized));
                parameter
                    .value
                    .store(normalized.to_bits(), Ordering::Release);
                parameter.pending.store(false, Ordering::Release);
            }
        }
        Ok(())
    }

    /// Whether the plugin describes an editor this host can embed.
    pub const fn has_editor(&self) -> bool {
        self.editor_plan.is_some()
    }

    /// Whether the user may resize the editor window.
    pub fn editor_resizable(&self) -> Result<bool, HostError> {
        self.editor_plan
            .as_ref()
            .map(|plan| plan.resizable)
            .ok_or(HostError::Unsupported("native editor"))
    }

    /// Client size of the open editor, of the last one, or the size used before one exists.
    pub fn editor_size(&self) -> (u32, u32) {
        self.editor
            .as_ref()
            .and_then(Lv2Editor::size)
            .or(self.editor_size)
            .unwrap_or(DEFAULT_SIZE)
    }

    pub fn set_editor_resize_handler(&mut self, handler: EditorResizeHandler) {
        if let Some(editor) = &self.editor {
            editor.set_resize_handler(handler.clone());
        }
        self.resize_handler = Some(handler);
    }

    pub fn open_editor(&mut self, parent: &NativeParentHandle) -> Result<(), HostError> {
        if self.editor.is_some() {
            return Ok(());
        }
        let plan = self
            .editor_plan
            .as_ref()
            .ok_or(HostError::Unsupported("native editor"))?;
        let (Some(slot), Some(config)) = (self.slot.as_ref(), self.lifecycle.config()) else {
            return Err(HostError::InvalidTransition);
        };
        let setup = EditorSetup {
            instance: self.plugin_handle,
            sample_rate: config.sample_rate,
            exchange: self.exchange.clone(),
            model: &self.model,
            resize: self.resize_handler.clone(),
        };
        let editor = Lv2Editor::open(plan, parent, &setup, &mut self.editor_link)?;
        slot.editor_open.store(true, Ordering::Release);
        self.editor = Some(editor);
        Ok(())
    }

    pub fn resize_editor(&mut self, width: u32, height: u32) -> Result<(), HostError> {
        let editor = self.editor.as_ref().ok_or(HostError::InvalidTransition)?;
        if !self.editor_resizable()? {
            return Err(HostError::Unsupported("editor has a fixed size"));
        }
        editor.resize(width, height)
    }

    pub fn close_editor(&mut self) {
        let Some(editor) = self.editor.take() else {
            return;
        };
        if let Some(slot) = &self.slot {
            slot.editor_open.store(false, Ordering::Release);
        }
        self.editor_size = editor.size().or(self.editor_size);
        if let Some(mut link) = editor.close() {
            // Messages the plugin queued for the closed editor mean nothing to the next one.
            link.from_dsp.drain(|_, _, _| {});
            self.editor_link = Some(link);
        }
    }

    /// Services the open editor and reports whether the plugin closed it.
    pub fn pump_editor(&mut self) -> bool {
        let (Some(editor), Some(slot)) = (&mut self.editor, &self.slot) else {
            return false;
        };
        editor.pump(&self.model, slot);
        if !editor.closed_by_plugin() {
            return false;
        }
        self.close_editor();
        true
    }
}

impl Drop for Lv2Instance {
    fn drop(&mut self) {
        // The editor goes first: it may reach the plugin instance directly.
        self.close_editor();
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "the fixture walks transitions known to be valid"
)]
mod tests {
    use super::*;

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
        // A rejected transition hands the unchanged state back.
        let (lifecycle, _) = lifecycle.resumed().err().unwrap();
        assert!(lifecycle.config().is_none());
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
        assert!(matches!(suspended, AnyInstanceLifecycle::Prepared(_)));
        assert_eq!(suspended.config(), Some(&config()));
    }
}
