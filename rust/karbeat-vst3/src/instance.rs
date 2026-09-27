//! UI-owned component, controller, and editor lifecycle.

use crate::{
    api::{MemoryStream, create_instance, string128_to_string},
    bus_layout::{self, BusDescription, BusPlan, BusRole},
    context::{ComponentHandler, ParameterExchange},
    module::{Vst3Module, parse_class_id},
    wrapper::{Dsp, ProcessorSlot},
};
use karbeat_host_api::{
    HostError, PluginDescriptor, PluginState, ProcessingConfig, ProcessingGate,
};
use karbeat_plugin_api::prelude::ParameterSpec;
use std::{
    cell::UnsafeCell,
    ptr,
    rc::Rc,
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicU32, Ordering},
    },
};
use vst3::{
    ComPtr, ComWrapper,
    Steinberg::{Vst::*, *},
};

const MIDI_MAPPING_CHANNELS: usize = 16;
const MIDI_MAPPING_SLOTS: usize = 130;
pub(crate) const MIDI_MAPPING_QUERY_COUNT: usize = MIDI_MAPPING_CHANNELS * MIDI_MAPPING_SLOTS;

fn mapping_batch_end(next: usize, limit: usize) -> usize {
    next.saturating_add(limit).min(MIDI_MAPPING_QUERY_COUNT)
}

pub(crate) struct Vst3PrepareJob {
    dsp: Option<Dsp>,
    mapping: Option<ComPtr<IMidiMapping>>,
    next_mapping: usize,
}

pub(crate) fn check(operation: &'static str, code: i32) -> Result<(), HostError> {
    if code == kResultOk {
        Ok(())
    } else {
        Err(HostError::PluginCall { operation, code })
    }
}

/// Like [`check`], but also accepts `kNotImplemented` for calls the VST3 specification lets
/// plugins leave unimplemented, such as `setProcessing`.
pub(crate) fn check_optional(operation: &'static str, code: i32) -> Result<(), HostError> {
    if code == kNotImplemented {
        Ok(())
    } else {
        check(operation, code)
    }
}

fn describe_buses(
    component: &ComPtr<IComponent>,
    processor: &ComPtr<IAudioProcessor>,
    direction: i32,
) -> Result<Vec<BusDescription>, HostError> {
    // SAFETY: Query initialized component bus metadata on its UI thread.
    let count = unsafe { component.getBusCount(0, direction) };
    if !(0..=64).contains(&count) {
        return Err(HostError::Unsupported("invalid audio bus count"));
    }
    let mut infos = Vec::new();
    for index in 0..count {
        // SAFETY: BusInfo has only scalar/fixed-array fields.
        let mut info: BusInfo = unsafe { std::mem::zeroed() };
        // SAFETY: Bus index is in range and output storage is writable.
        check("component.getBusInfo", unsafe {
            component.getBusInfo(0, direction, index, &raw mut info)
        })?;
        infos.push(info);
    }
    let types = infos.iter().map(|info| info.busType).collect::<Vec<_>>();
    let roles = bus_layout::classify(&types, direction == 0);
    infos
        .iter()
        .zip(roles)
        .enumerate()
        .map(|(index, (info, role))| {
            Ok(BusDescription {
                role,
                native: bus_arrangement(processor, direction, index, info)?,
                default_active: info.flags & BusInfo_::BusFlags_::kDefaultActive != 0,
            })
        })
        .collect()
}

fn bus_arrangement(
    processor: &ComPtr<IAudioProcessor>,
    direction: i32,
    index: usize,
    info: &BusInfo,
) -> Result<u64, HostError> {
    let mut arrangement = 0;
    // SAFETY: Bus index comes from the component's reported range and output is writable.
    let code = unsafe {
        processor.getBusArrangement(
            direction,
            i32::try_from(index).map_err(|_| HostError::InvalidConfiguration)?,
            &raw mut arrangement,
        )
    };
    Ok(if code == kResultOk {
        arrangement
    } else {
        bus_layout::arrangement_for_count(usize::try_from(info.channelCount).unwrap_or(0))
    })
}

fn current_arrangements(
    component: &ComPtr<IComponent>,
    processor: &ComPtr<IAudioProcessor>,
    direction: i32,
    count: usize,
) -> Result<Vec<u64>, HostError> {
    (0..count)
        .map(|index| {
            let native_index = i32::try_from(index).map_err(|_| HostError::InvalidConfiguration)?;
            // SAFETY: BusInfo has only scalar/fixed-array fields.
            let mut info: BusInfo = unsafe { std::mem::zeroed() };
            // SAFETY: Bus index is within the count read before negotiation.
            check("component.getBusInfo", unsafe {
                component.getBusInfo(0, direction, native_index, &raw mut info)
            })?;
            bus_arrangement(processor, direction, index, &info)
        })
        .collect()
}

pub(crate) struct Vst3Instance {
    pub descriptor: PluginDescriptor,
    pub component: Option<ComPtr<IComponent>>,
    pub controller: Option<ComPtr<IEditController>>,
    processor: Option<ComPtr<IAudioProcessor>>,
    component_initialized: bool,
    separate_controller: bool,
    controller_initialized: bool,
    component_connection: Option<ComPtr<IConnectionPoint>>,
    controller_connection: Option<ComPtr<IConnectionPoint>>,
    connected: bool,
    pub active: bool,
    pub running: bool,
    pub config: Option<ProcessingConfig>,
    pub slot: Option<Arc<ProcessorSlot>>,
    pub endpoint_taken: bool,
    pub exchange: Arc<ParameterExchange>,
    pub specs: Vec<ParameterSpec>,
    pub editor: Option<crate::editor::Vst3Editor>,
    pub handler: Option<ComWrapper<ComponentHandler>>,
    _context: ComPtr<FUnknown>,
    _module: Rc<Vst3Module>,
}
impl Vst3Instance {
    pub fn create(
        module: Rc<Vst3Module>,
        descriptor: PluginDescriptor,
        context: ComPtr<FUnknown>,
    ) -> Result<Self, HostError> {
        let class = parse_class_id(&descriptor.identity.native_id)?;
        // SAFETY: Module and host context are live and this function is only called on the UI thread.
        let component = unsafe { create_instance::<IComponent>(module.factory()?, &class) }
            .ok_or(HostError::Unsupported("VST3 audio component"))?;
        let mut instance = Self {
            descriptor,
            component: Some(component),
            controller: None,
            processor: None,
            component_initialized: false,
            separate_controller: false,
            controller_initialized: false,
            component_connection: None,
            controller_connection: None,
            connected: false,
            active: false,
            running: false,
            config: None,
            slot: None,
            endpoint_taken: false,
            exchange: ParameterExchange::new(&[]),
            specs: Vec::new(),
            editor: None,
            handler: None,
            _context: context,
            _module: module,
        };
        let component = instance
            .component
            .as_ref()
            .ok_or(HostError::InvalidTransition)?;
        // SAFETY: Newly created component receives the retained host context on the UI thread.
        check("component.initialize", unsafe {
            component.initialize(instance._context.as_ptr())
        })?;
        instance.component_initialized = true;
        instance.processor = Some(
            component
                .cast::<IAudioProcessor>()
                .ok_or(HostError::Unsupported("VST3 audio processor"))?,
        );
        if let Some(controller) = component.cast::<IEditController>() {
            instance.controller = Some(controller);
        } else {
            let mut controller_id = [0; 16];
            // SAFETY: Writable controller ID is provided to a live initialized component.
            if unsafe { component.getControllerClassId(&raw mut controller_id) } == kResultOk {
                // SAFETY: Factory creates the requested edit-controller interface on this UI thread.
                if let Some(controller) = unsafe {
                    create_instance::<IEditController>(instance._module.factory()?, &controller_id)
                } {
                    instance.separate_controller = true;
                    // SAFETY: New controller receives the same live host context.
                    check("controller.initialize", unsafe {
                        controller.initialize(instance._context.as_ptr())
                    })?;
                    instance.controller_initialized = true;
                    instance.controller = Some(controller);
                }
            }
        }
        if instance.separate_controller {
            instance.component_connection = component.cast::<IConnectionPoint>();
            instance.controller_connection = instance
                .controller
                .as_ref()
                .and_then(|c| c.cast::<IConnectionPoint>());
            if let (Some(a), Some(b)) = (
                &instance.component_connection,
                &instance.controller_connection,
            ) {
                // SAFETY: Both retained connection points belong to this same instance.
                check("component.connect", unsafe { a.connect(b.as_ptr()) })?;
                // SAFETY: Complete the reverse connection on the UI thread.
                let code = unsafe { b.connect(a.as_ptr()) };
                if code != kResultOk {
                    // SAFETY: Undo the successful first connection before unwinding.
                    unsafe { a.disconnect(b.as_ptr()) };
                    check("controller.connect", code)?;
                }
                instance.connected = true;
            }
        }
        instance.specs = instance.read_parameters()?;
        let values = instance
            .specs
            .iter()
            .map(|p| (p.id, p.value))
            .collect::<Vec<_>>();
        instance.exchange = ParameterExchange::new(&values);
        let handler = ComWrapper::new(ComponentHandler {
            exchange: instance.exchange.clone(),
        });
        if let Some(controller) = &instance.controller {
            let pointer = handler
                .as_com_ref::<IComponentHandler>()
                .ok_or(HostError::Unsupported("component handler"))?;
            // SAFETY: Handler is retained for the entire controller lifetime.
            check("controller.setComponentHandler", unsafe {
                controller.setComponentHandler(pointer.as_ptr())
            })?;
        }
        instance.handler = Some(handler);
        Ok(instance)
    }

    pub fn read_parameters(&self) -> Result<Vec<ParameterSpec>, HostError> {
        let Some(controller) = &self.controller else {
            return Ok(Vec::new());
        };
        // SAFETY: Controller is initialized and this code runs on its UI thread.
        let count = unsafe { controller.getParameterCount() };
        if !(0..=65_536).contains(&count) {
            return Err(HostError::InvalidState("invalid parameter count".into()));
        }
        let mut specs = Vec::with_capacity(usize::try_from(count).unwrap_or(0));
        for index in 0..count {
            // SAFETY: ParameterInfo is a plain ABI record of scalars and fixed arrays.
            let mut info: ParameterInfo = unsafe { std::mem::zeroed() };
            // SAFETY: index is within the reported parameter range and info is writable.
            check("controller.getParameterInfo", unsafe {
                controller.getParameterInfo(index, &raw mut info)
            })?;
            // SAFETY: info.id came from this controller's parameter list.
            let current = unsafe { controller.getParamNormalized(info.id) };
            let name = string128_to_string(&info.title);
            let mut spec = ParameterSpec::new_float(
                info.id,
                &name,
                "Parameters",
                current,
                0.0,
                1.0,
                info.defaultNormalizedValue,
                if info.stepCount > 0 {
                    1.0 / f64::from(info.stepCount)
                } else {
                    0.0
                },
            );
            spec.path = format!("vst3/{}", info.id);
            spec.automatable =
                info.flags & ParameterInfo_::ParameterFlags_::kCanAutomate as i32 != 0;
            specs.push(spec);
        }
        specs.sort_by_key(|p| p.id);
        if specs.windows(2).any(|p| p[0].id == p[1].id) {
            return Err(HostError::InvalidState("duplicate parameter IDs".into()));
        }
        Ok(specs)
    }

    pub(crate) fn begin_prepare(
        &mut self,
        config: &ProcessingConfig,
    ) -> Result<Vst3PrepareJob, HostError> {
        config.validate()?;
        self.suspend()?;
        self.config = None;
        let component = self
            .component
            .as_ref()
            .ok_or(HostError::InvalidTransition)?;
        let processor = self
            .processor
            .as_ref()
            .ok_or(HostError::InvalidTransition)?;
        if self.active {
            // SAFETY: DSP is stopped before changing component activation.
            check("component.setActive(false)", unsafe {
                component.setActive(0)
            })?;
            self.active = false;
        }
        let inputs = describe_buses(component, processor, 0)?;
        let outputs = describe_buses(component, processor, 1)?;
        let (mut input_layouts, mut output_layouts) =
            bus_layout::requested(&inputs, &outputs, config)?;
        // SAFETY: Arrangement arrays contain one entry per discovered audio bus and stay live through the call.
        let code = unsafe {
            processor.setBusArrangements(
                input_layouts.as_mut_ptr(),
                i32::try_from(input_layouts.len()).unwrap_or(0),
                output_layouts.as_mut_ptr(),
                i32::try_from(output_layouts.len()).unwrap_or(0),
            )
        };
        if code != kResultOk {
            // kResultFalse means the plugin adapted to its closest supported layout; read back
            // what it actually chose and map the engine's channels onto it.
            log::debug!(
                "{}: setBusArrangements returned {code}; using the plugin's adapted layout",
                self.descriptor.name
            );
            input_layouts = current_arrangements(component, processor, 0, inputs.len())?;
            output_layouts = current_arrangements(component, processor, 1, outputs.len())?;
        }
        let (input_plans, output_plans) =
            bus_layout::resolve(&inputs, &input_layouts, &outputs, &output_layouts, config)?;
        self.activate_buses(component, &input_plans, &output_plans)?;
        // SAFETY: Processor capability query on its control thread.
        let use_f64 = unsafe { processor.canProcessSampleSize(0) } != kResultOk;
        if use_f64 {
            // SAFETY: Query alternative sample precision before setup.
            check("processor.canProcessSampleSize(f64)", unsafe {
                processor.canProcessSampleSize(1)
            })?;
        }
        let mut setup = ProcessSetup {
            processMode: if config.offline { 2 } else { 0 },
            symbolicSampleSize: i32::from(use_f64),
            maxSamplesPerBlock: i32::try_from(config.max_block_size)
                .map_err(|_| HostError::InvalidConfiguration)?,
            sampleRate: config.sample_rate,
        };
        // SAFETY: DSP is stopped and configuration fields are validated.
        check("processor.setupProcessing", unsafe {
            processor.setupProcessing(&raw mut setup)
        })?;
        let ids = self.specs.iter().map(|p| p.id).collect::<Vec<_>>();
        let dsp = Dsp::new(
            processor.clone(),
            config.clone(),
            input_plans,
            output_plans,
            &ids,
            use_f64,
        );
        let mapping = self
            .controller
            .as_ref()
            .and_then(|controller| controller.cast::<IMidiMapping>());
        Ok(Vst3PrepareJob {
            dsp: Some(dsp),
            mapping,
            next_mapping: 0,
        })
    }

    fn activate_buses(
        &self,
        component: &ComPtr<IComponent>,
        input_plans: &[BusPlan],
        output_plans: &[BusPlan],
    ) -> Result<(), HostError> {
        for (direction, plans) in [(0, input_plans), (1, output_plans)] {
            for (index, plan) in plans.iter().enumerate() {
                // SAFETY: Negotiated bus index is valid and DSP is inactive.
                let code = unsafe {
                    component.activateBus(
                        0,
                        direction,
                        i32::try_from(index).unwrap_or(0),
                        u8::from(plan.active),
                    )
                };
                if direction == 1 && plan.role == BusRole::Main {
                    check("component.activateBus(audio)", code)?;
                } else if code != kResultOk {
                    log::warn!(
                        "{}: activateBus(audio, {direction}, {index}) returned {code}",
                        self.descriptor.name
                    );
                }
            }
            // SAFETY: Query event buses on initialized component.
            let count = unsafe { component.getBusCount(1, direction) };
            if !(0..=64).contains(&count) {
                return Err(HostError::Unsupported("invalid event bus count"));
            }
            for index in 0..count {
                // SAFETY: Activate only the first supported event bus in each direction.
                let code =
                    unsafe { component.activateBus(1, direction, index, u8::from(index == 0)) };
                if code != kResultOk {
                    log::warn!(
                        "{}: activateBus(events, {direction}, {index}) returned {code}",
                        self.descriptor.name
                    );
                }
            }
        }
        Ok(())
    }

    pub(crate) fn advance_prepare(
        &mut self,
        job: &mut Vst3PrepareJob,
        max_mapping_queries: usize,
    ) -> Result<bool, HostError> {
        if max_mapping_queries == 0 {
            return Err(HostError::InvalidConfiguration);
        }
        if let Some(mapping) = &job.mapping {
            let end = mapping_batch_end(job.next_mapping, max_mapping_queries);
            let dsp = job.dsp.as_mut().ok_or(HostError::InvalidTransition)?;
            for index in job.next_mapping..end {
                let channel = index / MIDI_MAPPING_SLOTS;
                let cc = index % MIDI_MAPPING_SLOTS;
                let mut id = 0;
                // SAFETY: MIDI mapping queries occur on the controller's UI thread and both
                // indices are within the VST3 channel/controller ranges.
                if unsafe {
                    mapping.getMidiControllerAssignment(
                        0,
                        i16::try_from(channel).unwrap_or(0),
                        i16::try_from(cc).unwrap_or(0),
                        &raw mut id,
                    )
                } == kResultOk
                {
                    dsp.midi_mapping[channel][cc] = Some(id);
                }
            }
            job.next_mapping = end;
        } else {
            job.next_mapping = MIDI_MAPPING_QUERY_COUNT;
        }
        if job.next_mapping < MIDI_MAPPING_QUERY_COUNT {
            return Ok(false);
        }
        let dsp = job.dsp.take().ok_or(HostError::InvalidTransition)?;
        let config = dsp.config.clone();
        let component = self
            .component
            .as_ref()
            .ok_or(HostError::InvalidTransition)?;
        let processor = self
            .processor
            .as_ref()
            .ok_or(HostError::InvalidTransition)?;
        // SAFETY: All negotiated buffers are ready and setupProcessing has succeeded.
        check("component.setActive(true)", unsafe {
            component.setActive(1)
        })?;
        self.active = true;
        // SAFETY: Latency and tail are queried outside processing and cached atomically.
        let latency = unsafe { processor.getLatencySamples() };
        // SAFETY: Processor is initialized and active on this UI thread.
        let tail = unsafe { processor.getTailSamples() };
        if let Some(slot) = &self.slot {
            // SAFETY: suspend succeeded before preparation, excluding all DSP access.
            unsafe { *slot.dsp.get() = dsp };
            slot.latency.store(latency, Ordering::Release);
            slot.tail.store(tail, Ordering::Release);
        } else {
            self.slot = Some(Arc::new(ProcessorSlot {
                gate: ProcessingGate::default(),
                dsp: UnsafeCell::new(dsp),
                latency: AtomicU32::new(latency),
                tail: AtomicU32::new(tail),
                endpoint_alive: AtomicBool::new(false),
            }));
        }
        self.config = Some(config);
        Ok(true)
    }

    pub fn prepare(&mut self, config: &ProcessingConfig) -> Result<(), HostError> {
        let mut job = self.begin_prepare(config)?;
        while !self.advance_prepare(&mut job, MIDI_MAPPING_QUERY_COUNT)? {}
        Ok(())
    }

    /// Applies the parts of a `restartComponent` request the host handles in place.
    ///
    /// A latency change is re-read on this UI owner and published to the audio endpoint, whose
    /// `has_latency_changed` edge then triggers delay-compensation recalculation.
    pub fn apply_restart_flags(&self, flags: i32) {
        if flags & RestartFlags_::kLatencyChanged != 0
            && self.active
            && let (Some(processor), Some(slot)) = (&self.processor, &self.slot)
        {
            // SAFETY: Latency is queried on the owning UI thread of an active processor.
            let latency = unsafe { processor.getLatencySamples() };
            slot.latency.store(latency, Ordering::Release);
        }
        if flags & RestartFlags_::kIoChanged != 0 {
            log::warn!(
                "{}: plugin changed its audio buses; the new layout applies after the next reconfiguration",
                self.descriptor.name
            );
        }
    }

    pub fn suspend(&mut self) -> Result<(), HostError> {
        if let Some(slot) = &self.slot {
            slot.gate.suspend()?;
            // SAFETY: Successful suspension acknowledges the end of all processing access.
            unsafe { &mut *slot.dsp.get() }.stop()?;
        }
        self.running = false;
        Ok(())
    }
    pub fn resume(&mut self) -> Result<(), HostError> {
        if self.config.is_none() {
            return Err(HostError::InvalidTransition);
        }
        let slot = self.slot.as_ref().ok_or(HostError::InvalidTransition)?;
        if !slot.gate.is_suspended() {
            return Err(HostError::InvalidTransition);
        }
        // SAFETY: Suspended gate grants exclusive control-thread access until resume below.
        unsafe { &mut *slot.dsp.get() }.start()?;
        slot.gate.resume()?;
        self.running = true;
        Ok(())
    }
    pub fn flush_parameters(&mut self) -> Result<(), HostError> {
        self.suspend()?;
        if let Some(slot) = &self.slot {
            // SAFETY: Exclusive suspended DSP access; flush cached UI edits before querying state.
            let dsp = unsafe { &mut *slot.dsp.get() };
            dsp.flush(&self.exchange)?;
        }
        Ok(())
    }
    pub fn save_state(&mut self) -> Result<PluginState, HostError> {
        self.flush_parameters()?;
        let component = self
            .component
            .as_ref()
            .ok_or(HostError::InvalidTransition)?;
        let stream = ComWrapper::new(MemoryStream::default());
        let pointer = stream
            .as_com_ref::<IBStream>()
            .ok_or(HostError::Unsupported("state stream"))?;
        // SAFETY: UI-thread state capture occurs while processing is suspended; stream is retained.
        check("component.getState", unsafe {
            component.getState(pointer.as_ptr())
        })?;
        let component_state = stream.data.borrow().clone();
        let controller_state = if let Some(controller) = &self.controller {
            let stream = ComWrapper::new(MemoryStream::default());
            let pointer = stream
                .as_com_ref::<IBStream>()
                .ok_or(HostError::Unsupported("state stream"))?;
            // SAFETY: Controller and writable stream are live on their UI thread.
            let code = unsafe { controller.getState(pointer.as_ptr()) };
            if code == kNotImplemented {
                None
            } else {
                check("controller.getState", code)?;
                Some(stream.data.borrow().clone())
            }
        } else {
            None
        };
        Ok(PluginState {
            version: 1,
            identity: self.descriptor.identity.clone(),
            component: component_state,
            controller: controller_state,
        })
    }
    pub fn restore_state(&mut self, state: &PluginState) -> Result<(), HostError> {
        if state.version != 1
            || state.identity != self.descriptor.identity
            || state.component.len() > 64 * 1024 * 1024
            || state
                .controller
                .as_ref()
                .is_some_and(|s| s.len() > 64 * 1024 * 1024)
        {
            return Err(HostError::InvalidState(
                "unsupported state version, identity, or size".into(),
            ));
        }
        self.suspend()?;
        let component = self
            .component
            .as_ref()
            .ok_or(HostError::InvalidTransition)?;
        let stream = ComWrapper::new(MemoryStream::from_bytes(&state.component));
        let pointer = stream
            .as_com_ref::<IBStream>()
            .ok_or(HostError::Unsupported("state stream"))?;
        // SAFETY: Plugin state is restored on its UI thread with exclusive processor access.
        check("component.setState", unsafe {
            component.setState(pointer.as_ptr())
        })?;
        if let Some(controller) = &self.controller {
            stream.rewind();
            // SAFETY: Same component state is rewound and provided to the controller.
            let code = unsafe { controller.setComponentState(pointer.as_ptr()) };
            if code != kNotImplemented {
                check("controller.setComponentState", code)?;
            }
            if let Some(bytes) = &state.controller {
                let stream = ComWrapper::new(MemoryStream::from_bytes(bytes));
                let pointer = stream
                    .as_com_ref::<IBStream>()
                    .ok_or(HostError::Unsupported("state stream"))?;
                // SAFETY: Controller-only state is restored after component synchronization.
                check("controller.setState", unsafe {
                    controller.setState(pointer.as_ptr())
                })?;
            }
            for parameter in &self.exchange.parameters {
                // SAFETY: Known parameter ID is read from the initialized controller on the UI thread.
                let value = unsafe { controller.getParamNormalized(parameter.id) };
                parameter.value.store(value.to_bits(), Ordering::Release);
                parameter.pending.store(false, Ordering::Release);
            }
        }
        Ok(())
    }
}

impl Drop for Vst3Instance {
    fn drop(&mut self) {
        self.editor.take();
        if let Some(slot) = self.slot.take() {
            // Host destruction checks endpoint ownership before dropping an instance.
            // SAFETY: No audio endpoint remains and destruction runs on the owning UI thread.
            if let Err(error) = unsafe { &mut *slot.dsp.get() }.stop() {
                log::warn!("VST3 stop during teardown: {error}");
            }
        }
        if self.active {
            if let Some(component) = &self.component {
                // SAFETY: Processing is stopped before deactivation.
                unsafe { component.setActive(0) };
            }
        }
        if self.connected {
            if let (Some(a), Some(b)) = (&self.component_connection, &self.controller_connection) {
                // SAFETY: These are the retained mutually connected interfaces.
                unsafe { a.disconnect(b.as_ptr()) };
                // SAFETY: Disconnect the reverse connection before releasing either object.
                unsafe { b.disconnect(a.as_ptr()) };
            }
        }
        if let Some(controller) = &self.controller {
            // SAFETY: Clear the host callback before releasing its owner.
            unsafe { controller.setComponentHandler(ptr::null_mut()) };
            if self.separate_controller && self.controller_initialized {
                // SAFETY: Only separately initialized controllers receive terminate.
                unsafe { controller.terminate() };
            }
        }
        if self.component_initialized {
            if let Some(component) = &self.component {
                // SAFETY: Component is inactive and all processing/editor work is finished.
                unsafe { component.terminate() };
            }
        }
        self.component_connection.take();
        self.controller_connection.take();
        self.controller.take();
        self.processor.take();
        self.component.take();
        self.handler.take();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn midi_mapping_cursor_covers_all_queries_in_bounded_batches() {
        let batch_size = 64;
        let mut next = 0;
        let mut batches = 0;
        while next < MIDI_MAPPING_QUERY_COUNT {
            let end = mapping_batch_end(next, batch_size);
            assert!(end > next);
            assert!(end - next <= batch_size);
            next = end;
            batches += 1;
        }
        assert_eq!(next, 2_080);
        assert_eq!(batches, 33);
    }
}
