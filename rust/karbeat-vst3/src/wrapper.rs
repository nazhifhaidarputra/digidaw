//! Wrapper implmentation of Vst3 Plugin hosted into
//! Digidaw/Karbeat system
//!
//! It covers most common VST3 interface, although not all of them
//! are implemented

use std::{
    cell::{Cell, RefCell},
    sync::Arc,
};

use crate::{
    api::*,
    context::{Vst3EventContext, Vst3HostContext},
    instance::Vst3Instance,
};
use karbeat_plugin_api::prelude::*;
use vst3::{
    ComPtr, ComWrapper,
    Steinberg::{
        FUnknown, IBStream, IPluginBaseTrait, IPluginFactory, TUID,
        Vst::{
            IAudioProcessor, IAudioProcessorTrait, IComponent, IComponentTrait, IConnectionPoint,
            IConnectionPointTrait, IEditController, IEditControllerTrait, IParameterChanges,
            ParamValue, ProcessModes_, ProcessSetup, String128, SymbolicSampleSizes_,
        },
        kResultFalse, kResultOk, kResultTrue, tresult,
    },
};

/// Wrapper for a VST3 plugin instance so it's compatible with the karbeat plugin host system.
#[derive(Clone)]
pub struct Vst3Wrapper {
    // NOTE: Even though Vst3 is not thread-safe, but in reality, the plugin instance never go to
    // other thread. thus it is solely to fulfill the trait contract.
    // in the future, the Send + Sync Trait will be removed from AudioPlugin trait because the plugin
    // are processed using SPSC Ring buffer
    //
    /// Inner value of VST3 Instance with Reference-counted pointer
    inner: Arc<Vst3Instance>,
}

impl Vst3Wrapper {
    /// Standard VST3 host bring-up: create `IComponent` from `cid`, initialize it with the host
    /// context, cast to `IAudioProcessor`, find/create the `IEditController` (separate object or
    /// same object), and connect `IConnectionPoint`s if they're separate objects.
    pub fn create(
        factory: &ComPtr<IPluginFactory>,
        info: Vst3PluginInfo,
        cid: &TUID,
        host_name: impl Into<String>,
    ) -> Result<Self, tresult> {
        let host_context = ComWrapper::new(Vst3HostContext {
            host_name: host_name.into(),
        });
        let event_context = ComWrapper::new(Vst3EventContext { process_mode: 0 });

        // FUnknown is the base of every VST3 interface, so this always succeeds regardless of
        // what's listed in Vst3HostContext's `Interfaces` tuple.
        let host_unknown = host_context
            .to_com_ptr::<FUnknown>()
            .expect("Vst3HostContext must expose FUnknown");

        let component =
            unsafe { create_instance::<IComponent>(factory, cid) }.ok_or(kResultFalse)?;

        let status = unsafe { component.initialize(host_unknown.as_ptr()) };
        if status != kResultOk {
            return Err(status);
        }

        let processor = component
            .as_com_ref()
            .cast::<IAudioProcessor>()
            .ok_or(kResultFalse)?;

        let mut controller_cid: TUID = [0; 16];
        let has_separate_controller =
            unsafe { component.getControllerClassId(&raw mut controller_cid) } == kResultTrue;

        let (edit_ctrl, separate_controller) = if has_separate_controller {
            match unsafe { create_instance::<IEditController>(factory, &controller_cid) } {
                Some(ctrl) => {
                    let ctrl_status = unsafe { ctrl.initialize(host_unknown.as_ptr()) };
                    if ctrl_status != kResultOk {
                        unsafe { component.terminate() };
                        return Err(ctrl_status);
                    }
                    (Some(ctrl), true)
                }
                None => (None, false),
            }
        } else {
            // Single-component plugin: the component implements IEditController itself.
            (component.as_com_ref().cast::<IEditController>(), false)
        };

        let (component_cp, controller_cp) = if separate_controller {
            let cp_a = component.as_com_ref().cast::<IConnectionPoint>();
            let cp_b = edit_ctrl
                .as_ref()
                .and_then(|c| c.as_com_ref().cast::<IConnectionPoint>());
            if let (Some(a), Some(b)) = (&cp_a, &cp_b) {
                unsafe {
                    a.connect(b.as_com_ref().as_ptr().cast());
                    b.connect(a.as_com_ref().as_ptr().cast());
                }
            }
            (cp_a, cp_b)
        } else {
            (None, None)
        };

        let bypass_param_id = edit_ctrl.as_ref().and_then(|ctrl| find_bypass_param(ctrl));

        Ok(Self {
            inner: Arc::new(Vst3Instance {
                class_id: *cid,
                plugin_info: info,
                component,
                processor,
                edit_ctrl,
                separate_controller,
                component_cp,
                controller_cp,
                bypass_param_id,
                pending_changes: RefCell::new(HashMap::new()),
                is_active: Cell::new(false),
                is_processing: Cell::new(false),
                last_pdc_latency: Cell::new(0.0),
                _host_context: host_context,
                _event_context: event_context,
            }),
        })
    }

    pub fn get_class_id(&self) -> TUID {
        self.inner.class_id
    }
}

impl AudioPlugin for Vst3Wrapper {
    fn vendor(&self) -> &str {
        &self.inner.vendor
    }

    fn version(&self) -> &str {
        &self.inner.version
    }

    fn name(&self) -> &str {
        &self.inner.name
    }

    fn category(&self) -> PluginCategory {
        self.inner.category.clone()
    }

    fn can_apply_io_layout(&self, inputs: &[BusConfig], outputs: &[BusConfig]) -> bool {
        // TODO: needs your BusConfig's channel-count field(s) to build the speaker arrangements
        // for IAudioProcessor::getBusArrangement/setBusArrangements. See note at the end.
        let _ = (inputs, outputs);
        true
    }

    fn set_io_layout(&mut self, inputs: &[BusConfig], outputs: &[BusConfig]) {
        // TODO: same as above -- translate BusConfig into speaker arrangement bitmasks and call
        // self.inner.processor.setBusArrangements(...). Stubbed to stereo/stereo for now inside
        // `prepare()`.
        let _ = (inputs, outputs);
    }

    fn set_bypass(&mut self, bypass: bool) {
        let Some(id) = self.inner.bypass_param_id else {
            return;
        };
        let value = if bypass { 1.0 } else { 0.0 };
        if let Some(ctrl) = &self.inner.edit_ctrl {
            unsafe { ctrl.setParamNormalized(id, value) };
        }
        self.inner.pending_changes.borrow_mut().insert(id, value);
    }

    fn has_latency_changed(&mut self) -> bool {
        let current = unsafe { self.inner.processor.getLatencySamples() } as f64;
        let changed = (current - self.inner.last_pdc_latency.get()).abs() > f64::EPSILON;
        self.inner.last_pdc_latency.set(current);
        changed
    }

    fn latency_samples(&self) -> u32 {
        unsafe { self.inner.processor.getLatencySamples() as u32 }
    }

    fn tail_samples(&self) -> u32 {
        unsafe { self.inner.processor.getTailSamples() as u32 }
    }

    fn begin_parameter_edit(&mut self, _id: u32) {
        // No real VST3 host-side counterpart: begin/performEdit/endEdit are called BY the plugin
        // INTO the host's IComponentHandler when its own GUI changes a value. There's nothing to
        // signal in the other direction -- host-driven automation just calls set_parameter /
        // apply_automation directly.
    }

    fn end_parameter_edit(&mut self, _id: u32) {}

    fn plain_to_normalized(&self, id: u32, plain: f32) -> f32 {
        match &self.inner.edit_ctrl {
            Some(ctrl) => unsafe { ctrl.plainParamToNormalized(id, plain as f64) as f32 },
            None => plain,
        }
    }

    fn normalized_to_plain(&self, id: u32, normalized: f32) -> f32 {
        match &self.inner.edit_ctrl {
            Some(ctrl) => unsafe { ctrl.normalizedParamToPlain(id, normalized as f64) as f32 },
            None => normalized,
        }
    }

    fn value_to_string(&self, id: u32, normalized: f32) -> String {
        if let Some(ctrl) = &self.inner.edit_ctrl {
            let mut buf: String128 = [0; 128];
            let status = unsafe { ctrl.getParamStringByValue(id, normalized as f64, &raw mut buf) };
            if status == kResultOk {
                return string128_to_string(&buf);
            }
        }
        format!("{:.2}", self.normalized_to_plain(id, normalized))
    }

    fn string_to_value(&self, id: u32, text: &str) -> Option<f32> {
        let ctrl = self.inner.edit_ctrl.as_ref()?;
        let mut chars: Vec<u16> = text.encode_utf16().collect();
        chars.push(0);
        let mut normalized: ParamValue = 0.0;
        let status = unsafe {
            ctrl.getParamValueByString(id, chars.as_mut_ptr().cast(), &raw mut normalized)
        };
        (status == kResultOk).then_some(normalized as f32)
    }

    fn get_state(&self) -> Vec<u8> {
        let stream = ComWrapper::new(MemoryStream::default());
        let Some(stream_ptr) = stream.to_com_ptr::<IBStream>() else {
            return Vec::new();
        };
        if unsafe { self.inner.component.getState(stream_ptr.as_ptr()) } != kResultOk {
            return Vec::new();
        }
        stream.data.borrow().clone()
    }

    fn set_state(&mut self, state: &[u8]) {
        if state.is_empty() {
            return;
        }
        let stream = ComWrapper::new(MemoryStream {
            data: RefCell::new(state.to_vec()),
            position: Cell::new(0),
        });
        let Some(stream_ptr) = stream.to_com_ptr::<IBStream>() else {
            return;
        };
        unsafe { self.inner.component.setState(stream_ptr.as_ptr()) };
    }

    fn get_factory_presets(&self) -> Vec<(String, Vec<u8>)> {
        // VST3 factory presets live behind IUnitInfo/IProgramListData, which is a separate
        // optional interface most simple hosts skip. Not wired up here.
        Vec::new()
    }

    fn load_preset(&mut self, _index: usize) {}

    fn current_preset_index(&self) -> Option<usize> {
        None
    }

    fn execute_custom_command(&mut self, _command: &str, _payload: &Value) -> Option<Value> {
        None
    }

    fn get_zero_copy_buffer(&self, _name: &str) -> Option<ZeroCopyBuffer> {
        None
    }

    fn get_editor(&mut self) -> Option<Box<dyn PluginEditor>> {
        // TODO: IEditController::createView("editor") gives you an IPlugView; wrapping it as your
        // PluginEditor needs that trait's exact shape (open/close/resize signatures). See note
        // at the end.
        None
    }

    fn prepare(&mut self, sample_rate: f32, max_buffer_size: usize) {
        const STEREO: u64 = 0x03; // kSpeakerL | kSpeakerR -- replace via set_io_layout once wired
        let mut input_arr = STEREO;
        let mut output_arr = STEREO;
        unsafe {
            self.inner
                .processor
                .setBusArrangements(&raw mut input_arr, 1, &raw mut output_arr, 1);
        }

        let mut setup = ProcessSetup {
            processMode: ProcessModes_::kRealtime as i32,
            symbolicSampleSize: SymbolicSampleSizes_::kSample32 as i32,
            maxSamplesPerBlock: max_buffer_size as i32,
            sampleRate: sample_rate as f64,
        };
        if unsafe { self.inner.processor.setupProcessing(&raw mut setup) } != kResultOk {
            return;
        }
        if unsafe { self.inner.component.setActive(1) } == kResultOk {
            self.inner.is_active.set(true);
        }
        if unsafe { self.inner.processor.setProcessing(1) } == kResultOk {
            self.inner.is_processing.set(true);
        }
    }

    fn reset(&mut self) {
        // VST3 has no generic "flush state" call; toggling setProcessing is the accepted way to
        // ask a plugin to clear internal buffers/filters.
        if self.inner.is_processing.get() {
            unsafe { self.inner.processor.setProcessing(0) };
            unsafe { self.inner.processor.setProcessing(1) };
        }
    }

    fn set_parameter(&mut self, id: u32, value: f32) {
        if let Some(ctrl) = &self.inner.edit_ctrl {
            unsafe { ctrl.setParamNormalized(id, value as f64) };
        }
        self.inner
            .pending_changes
            .borrow_mut()
            .insert(id, value as f64);
    }

    fn get_parameter(&self, id: u32) -> f32 {
        self.inner
            .edit_ctrl
            .as_ref()
            .map(|ctrl| unsafe { ctrl.getParamNormalized(id) as f32 })
            .unwrap_or(0.0)
    }

    fn apply_automation(&mut self, id: u32, value: f32) {
        self.inner
            .pending_changes
            .borrow_mut()
            .insert(id, value as f64);
    }

    fn clear_automation(&mut self, id: u32) {
        self.inner.pending_changes.borrow_mut().remove(&id);
    }

    fn default_parameters(&self) -> HashMap<u32, f32> {
        HashMap::new()
    }

    fn static_parameter_specs() -> Vec<ParameterSpec>
    where
        Self: Sized,
    {
        Vec::new()
    }

    fn get_parameter_specs(&self) -> Vec<ParameterSpec> {
        let Some(ctrl) = &self.inner.edit_ctrl else {
            return Vec::new();
        };
        let count = unsafe { ctrl.getParameterCount() };
        let mut specs = Vec::with_capacity(count.max(0) as usize);
        for i in 0..count {
            let mut info = empty_parameter_info();
            if unsafe { ctrl.getParameterInfo(i, &raw mut info) } == kResultOk {
                // TODO: map into your ParameterSpec's real fields -- id, name (string128_to_string
                // on info.title), default (info.defaultNormalizedValue), step_count, flags, etc.
                let _ = &info;
            }
        }
        specs
    }

    fn process(&mut self, buffers: &mut AudioBuffers, context: &ProcessContext) {
        if !self.inner.is_processing.get() {
            return;
        }

        // Drain pending parameter changes into an IParameterChanges block. This is what actually
        // makes set_parameter/apply_automation/set_bypass affect the audio thread -- the earlier
        // setParamNormalized calls only sync the controller/GUI side.
        let param_changes = ComWrapper::new(SimpleParameterChanges::default());
        {
            let mut pending = self.inner.pending_changes.borrow_mut();
            if !pending.is_empty() {
                let mut queues = param_changes.queues.borrow_mut();
                for (&id, &value) in pending.iter() {
                    let queue = ComWrapper::new(SimpleParamValueQueue::default());
                    queue.param_id.set(id);
                    queue.points.borrow_mut().push((0, value)); // applied at block start
                    queues.push(queue);
                }
            }
            pending.clear();
        }
        let param_changes_ptr = param_changes.to_com_ptr::<IParameterChanges>();

        // TODO: this part depends on your AudioBuffers/ProcessContext shape, which I don't have
        // visibility into -- see the note at the end of my reply. Sketch of what's needed:
        //
        // let mut input_ptrs: Vec<*mut f32> = /* one pointer per input channel */;
        // let mut output_ptrs: Vec<*mut f32> = /* one pointer per output channel */;
        // let mut input_bus = AudioBusBuffers {
        //     numChannels: input_ptrs.len() as i32,
        //     silenceFlags: 0,
        //     __field0: AudioBusBuffers__type0 { channelBuffers32: input_ptrs.as_mut_ptr() },
        // };
        // let mut output_bus = AudioBusBuffers { /* same shape */ };
        // let mut data = ProcessData {
        //     processMode: ProcessModes_::kRealtime as i32,
        //     symbolicSampleSize: SymbolicSampleSizes_::kSample32 as i32,
        //     numSamples: /* block length */ as i32,
        //     numInputs: 1,
        //     numOutputs: 1,
        //     inputs: &raw mut input_bus,
        //     outputs: &raw mut output_bus,
        //     inputParameterChanges: param_changes_ptr.as_ref().map_or(ptr::null_mut(), |p| p.as_ptr()),
        //     outputParameterChanges: ptr::null_mut(),
        //     inputEvents: ptr::null_mut(),
        //     outputEvents: ptr::null_mut(),
        //     processContext: ptr::null_mut(), // translate from `context` if you need transport info
        // };
        // unsafe { self.inner.processor.process(&raw mut data) };
        let _ = (buffers, context, param_changes_ptr);
    }

    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}
