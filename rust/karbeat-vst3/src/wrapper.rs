//! Exclusive audio endpoint. All VST3 initialization, state, and GUI work stays with its UI owner.

use crate::{
    api::{EventList, ParameterChanges},
    context::ParameterExchange,
};
use karbeat_host_api::{HostError, PluginDescriptor, PluginKind, ProcessingConfig, ProcessingGate};
use karbeat_plugin_api::prelude::{
    AudioBuffers, AudioPlugin, BusConfig, MidiMessage, NoteExpressionType, ParameterSpec,
    ProcessContext,
};
use std::{
    cell::UnsafeCell,
    ptr,
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicU32, Ordering},
    },
};
use vst3::{
    ComPtr, ComWrapper,
    Steinberg::{
        Vst::{self, IAudioProcessor, IAudioProcessorTrait, IEventList, IParameterChanges},
        kResultOk,
    },
};

pub(crate) struct Dsp {
    pub processor: ComPtr<IAudioProcessor>,
    pub config: ProcessingConfig,
    input_channels: Vec<usize>,
    output_channels: Vec<usize>,
    input32: Vec<Vec<f32>>,
    output32: Vec<Vec<f32>>,
    input64: Vec<Vec<f64>>,
    output64: Vec<Vec<f64>>,
    input_ptrs32: Vec<*mut f32>,
    output_ptrs32: Vec<*mut f32>,
    input_ptrs64: Vec<*mut f64>,
    output_ptrs64: Vec<*mut f64>,
    input_buses: Vec<Vst::AudioBusBuffers>,
    output_buses: Vec<Vst::AudioBusBuffers>,
    events: ComWrapper<EventList>,
    output_events: ComWrapper<EventList>,
    changes: ComWrapper<ParameterChanges>,
    output_changes: ComWrapper<ParameterChanges>,
    pub use_f64: bool,
    pub processing: bool,
    pub midi_mapping: [[Option<u32>; 130]; 16],
    note_ids: [Option<u64>; 2048],
    active_keys: [bool; 2048],
    recover_notes: bool,
}

impl Dsp {
    pub fn new(
        processor: ComPtr<IAudioProcessor>,
        config: ProcessingConfig,
        inputs: Vec<usize>,
        outputs: Vec<usize>,
        ids: &[u32],
        use_f64: bool,
    ) -> Self {
        let input_count: usize = inputs.iter().sum();
        let output_count: usize = outputs.iter().sum();
        let frames = config.max_block_size;
        Self {
            processor,
            config,
            input32: (0..input_count).map(|_| vec![0.0; frames]).collect(),
            output32: (0..output_count).map(|_| vec![0.0; frames]).collect(),
            input64: (0..if use_f64 { input_count } else { 0 })
                .map(|_| vec![0.0; frames])
                .collect(),
            output64: (0..if use_f64 { output_count } else { 0 })
                .map(|_| vec![0.0; frames])
                .collect(),
            input_ptrs32: vec![ptr::null_mut(); input_count],
            output_ptrs32: vec![ptr::null_mut(); output_count],
            input_ptrs64: vec![ptr::null_mut(); input_count],
            output_ptrs64: vec![ptr::null_mut(); output_count],
            input_buses: inputs.iter().map(|_| empty_bus()).collect(),
            output_buses: outputs.iter().map(|_| empty_bus()).collect(),
            input_channels: inputs,
            output_channels: outputs,
            events: ComWrapper::new(EventList::default()),
            output_events: ComWrapper::new(EventList::default()),
            changes: ComWrapper::new(ParameterChanges::new(ids)),
            output_changes: ComWrapper::new(ParameterChanges::new(ids)),
            use_f64,
            processing: false,
            midi_mapping: [[None; 130]; 16],
            note_ids: [None; 2048],
            active_keys: [false; 2048],
            recover_notes: false,
        }
    }

    pub fn stop(&mut self) -> Result<(), HostError> {
        if self.processing {
            // SAFETY: Called only after the processing gate is suspended.
            let code = unsafe { self.processor.setProcessing(0) };
            if code != kResultOk {
                return Err(HostError::PluginCall {
                    operation: "setProcessing(false)",
                    code,
                });
            }
            self.processing = false;
        }
        Ok(())
    }

    pub fn start(&mut self) -> Result<(), HostError> {
        if !self.processing {
            // SAFETY: Component was prepared/activated by the UI owner, with DSP suspended.
            let code = unsafe { self.processor.setProcessing(1) };
            if code != kResultOk {
                return Err(HostError::PluginCall {
                    operation: "setProcessing(true)",
                    code,
                });
            }
            self.processing = true;
        }
        Ok(())
    }

    pub fn flush(&mut self, exchange: &ParameterExchange) -> Result<(), HostError> {
        self.events.clear();
        self.output_events.clear();
        self.changes.clear();
        self.output_changes.clear();
        for parameter in &exchange.parameters {
            if parameter.pending.swap(false, Ordering::AcqRel) {
                self.changes.push(parameter.id, 0, parameter.get());
            }
        }
        let mut data = self.process_data(0, ptr::null_mut());
        // SAFETY: All parameter storage is preallocated and lives through this zero-sample call.
        let code = unsafe { self.processor.process(&raw mut data) };
        if code == kResultOk {
            Ok(())
        } else {
            Err(HostError::PluginCall {
                operation: "processor.flush",
                code,
            })
        }
    }

    fn process_data(&mut self, frames: i32, context: *mut Vst::ProcessContext) -> Vst::ProcessData {
        Vst::ProcessData {
            processMode: if self.config.offline { 2 } else { 0 },
            symbolicSampleSize: i32::from(self.use_f64),
            numSamples: frames,
            numInputs: if frames == 0 {
                0
            } else {
                i32::try_from(self.input_buses.len()).unwrap_or(0)
            },
            numOutputs: if frames == 0 {
                0
            } else {
                i32::try_from(self.output_buses.len()).unwrap_or(0)
            },
            inputs: if frames == 0 {
                ptr::null_mut()
            } else {
                self.input_buses.as_mut_ptr()
            },
            outputs: if frames == 0 {
                ptr::null_mut()
            } else {
                self.output_buses.as_mut_ptr()
            },
            inputParameterChanges: self
                .changes
                .as_com_ref::<IParameterChanges>()
                .map_or(ptr::null_mut(), |p| p.as_ptr()),
            outputParameterChanges: self
                .output_changes
                .as_com_ref::<IParameterChanges>()
                .map_or(ptr::null_mut(), |p| p.as_ptr()),
            inputEvents: self
                .events
                .as_com_ref::<IEventList>()
                .map_or(ptr::null_mut(), |p| p.as_ptr()),
            outputEvents: self
                .output_events
                .as_com_ref::<IEventList>()
                .map_or(ptr::null_mut(), |p| p.as_ptr()),
            processContext: context,
        }
    }

    pub fn process(
        &mut self,
        buffers: &mut AudioBuffers,
        context: &ProcessContext,
        exchange: &ParameterExchange,
    ) {
        let frames = buffers
            .main_outputs
            .first()
            .and_then(|b| b.channel_data.first())
            .map_or(0, |c| c.len());
        if frames == 0 || frames > self.config.max_block_size || !self.processing {
            silence(buffers);
            return;
        }
        for plane in &mut self.input32 {
            plane[..frames].fill(0.0);
        }
        for plane in &mut self.output32 {
            plane[..frames].fill(0.0);
        }
        let sources = buffers
            .main_inputs
            .iter()
            .chain(buffers.aux_inputs.iter())
            .flat_map(|b| b.channel_data.iter());
        for (source, destination) in sources.zip(&mut self.input32) {
            let count = frames.min(source.len());
            destination[..count].copy_from_slice(&source[..count]);
        }
        if self.use_f64 {
            for (source, destination) in self.input32.iter().zip(&mut self.input64) {
                for (source, destination) in source[..frames].iter().zip(&mut destination[..frames])
                {
                    *destination = f64::from(*source);
                }
            }
            for plane in &mut self.output64 {
                plane[..frames].fill(0.0);
            }
        }
        for (plane, pointer) in self.input32.iter_mut().zip(&mut self.input_ptrs32) {
            *pointer = plane.as_mut_ptr();
        }
        for (plane, pointer) in self.output32.iter_mut().zip(&mut self.output_ptrs32) {
            *pointer = plane.as_mut_ptr();
        }
        for (plane, pointer) in self.input64.iter_mut().zip(&mut self.input_ptrs64) {
            *pointer = plane.as_mut_ptr();
        }
        for (plane, pointer) in self.output64.iter_mut().zip(&mut self.output_ptrs64) {
            *pointer = plane.as_mut_ptr();
        }
        fill_buses(
            &mut self.input_buses,
            &self.input_channels,
            &mut self.input_ptrs32,
            &mut self.input_ptrs64,
            self.use_f64,
        );
        fill_buses(
            &mut self.output_buses,
            &self.output_channels,
            &mut self.output_ptrs32,
            &mut self.output_ptrs64,
            self.use_f64,
        );
        self.events.clear();
        self.output_events.clear();
        self.changes.clear();
        self.output_changes.clear();
        for parameter in &exchange.parameters {
            if parameter.pending.swap(false, Ordering::AcqRel)
                && !self.changes.push(parameter.id, 0, parameter.get())
            {
                exchange.overflow.store(true, Ordering::Relaxed);
            }
        }
        for change in context.param_changes {
            if change.sample_offset < frames
                && !self.changes.push(
                    change.param_id,
                    i32::try_from(change.sample_offset).unwrap_or(0),
                    f64::from(change.normalized_value),
                )
            {
                exchange.overflow.store(true, Ordering::Relaxed);
            }
        }
        if self.recover_notes {
            for (index, active) in self.active_keys.iter_mut().enumerate() {
                if *active {
                    self.events.push(note_event(
                        false,
                        i16::try_from(index / 128).unwrap_or(0),
                        i16::try_from(index % 128).unwrap_or(0),
                        0.0,
                        -1,
                        0,
                    ));
                    *active = false;
                }
            }
            self.note_ids.fill(None);
            self.recover_notes = false;
        }
        {
            for midi in context.midi_events {
                if midi.sample_offset >= frames {
                    continue;
                }
                let offset = i32::try_from(midi.sample_offset).unwrap_or(0);
                let event = match &midi.data {
                    MidiMessage::NoteOn {
                        note_id,
                        channel,
                        key,
                        velocity,
                    } if *channel < 16 && *key < 128 => {
                        let native_id = note_id
                            .and_then(|id| {
                                let index = self.note_ids.iter().position(Option::is_none)?;
                                self.note_ids[index] = Some(id);
                                i32::try_from(index).ok()
                            })
                            .unwrap_or(-1);
                        self.active_keys[usize::from(*channel) * 128 + usize::from(*key)] = true;
                        Some(note_event(
                            true,
                            i16::from(*channel),
                            i16::from(*key),
                            f32::from(*velocity) / 127.0,
                            native_id,
                            offset,
                        ))
                    }
                    MidiMessage::NoteOff {
                        note_id,
                        channel,
                        key,
                    } if *channel < 16 && *key < 128 => {
                        let native_id = note_id
                            .and_then(|id| {
                                let index = self.note_ids.iter().position(|&n| n == Some(id))?;
                                self.note_ids[index] = None;
                                i32::try_from(index).ok()
                            })
                            .unwrap_or(-1);
                        self.active_keys[usize::from(*channel) * 128 + usize::from(*key)] = false;
                        Some(note_event(
                            false,
                            i16::from(*channel),
                            i16::from(*key),
                            0.0,
                            native_id,
                            offset,
                        ))
                    }
                    MidiMessage::ControlChange {
                        channel,
                        controller,
                        value,
                    } if *channel < 16 && *controller < 128 => {
                        if let Some(id) =
                            self.midi_mapping[usize::from(*channel)][usize::from(*controller)]
                        {
                            self.changes.push(id, offset, f64::from(*value) / 127.0);
                        }
                        None
                    }
                    MidiMessage::PitchBend { channel, value } if *channel < 16 => {
                        if let Some(id) = self.midi_mapping[usize::from(*channel)][129] {
                            self.changes.push(
                                id,
                                offset,
                                ((f64::from(*value) + 8192.0) / 16383.0).clamp(0.0, 1.0),
                            );
                        }
                        None
                    }
                    MidiMessage::NoteExpression {
                        note_id,
                        expression,
                        value,
                    } => {
                        let native = self.note_ids.iter().position(|&id| id == Some(*note_id));
                        native.and_then(|id| {
                            let type_id = match expression {
                                NoteExpressionType::Volume => 0,
                                NoteExpressionType::Pan => 1,
                                NoteExpressionType::Tuning => 2,
                                NoteExpressionType::Vibrato => 3,
                                NoteExpressionType::Brightness => 5,
                                NoteExpressionType::Pressure => return None,
                            };
                            Some(Vst::Event {
                                busIndex: 0,
                                sampleOffset: offset,
                                ppqPosition: 0.0,
                                flags: 0,
                                r#type: 4,
                                __field0: Vst::Event__type0 {
                                    noteExpressionValue: Vst::NoteExpressionValueEvent {
                                        noteId: i32::try_from(id).unwrap_or(-1),
                                        typeId: type_id,
                                        value: f64::from(*value),
                                    },
                                },
                            })
                        })
                    }
                    _ => None,
                };
                if let Some(event) = event {
                    if !self.events.push(event) {
                        self.recover_notes = true;
                        exchange.overflow.store(true, Ordering::Relaxed);
                    }
                }
            }
        }
        let mut transport = transport_context(context, self.config.sample_rate);
        let mut data = self.process_data(i32::try_from(frames).unwrap_or(0), &raw mut transport);
        // SAFETY: Gate grants exclusive DSP ownership; all pointers refer to preallocated storage
        // or this stack context and remain valid until the synchronous process call returns.
        let code = unsafe { self.processor.process(&raw mut data) };
        if code != kResultOk {
            exchange.process_error.store(code, Ordering::Release);
            silence(buffers);
            return;
        }
        self.output_changes.for_each_last(|id, value| {
            if let Some(parameter) = exchange.parameter(id) {
                parameter.value.store(value.to_bits(), Ordering::Release);
                parameter.edits.fetch_or(2, Ordering::Relaxed);
            }
        });
        let destinations = buffers
            .main_outputs
            .iter_mut()
            .chain(buffers.aux_outputs.iter_mut())
            .flat_map(|b| b.channel_data.iter_mut());
        for (index, destination) in destinations.enumerate() {
            let count = frames.min(destination.len());
            if self.use_f64 {
                if let Some(source) = self.output64.get(index) {
                    for (source, destination) in
                        source[..count].iter().zip(&mut destination[..count])
                    {
                        *destination = narrow_sample(*source);
                    }
                } else {
                    destination[..count].fill(0.0);
                }
            } else if let Some(source) = self.output32.get(index) {
                destination[..count].copy_from_slice(&source[..count]);
            } else {
                destination[..count].fill(0.0);
            }
        }
    }
}

#[allow(
    clippy::cast_possible_truncation,
    clippy::as_conversions,
    reason = "VST3 f64 samples must narrow to the engine's f32 sample representation"
)]
fn narrow_sample(value: f64) -> f32 {
    if value.is_finite() { value as f32 } else { 0.0 }
}

fn empty_bus() -> Vst::AudioBusBuffers {
    Vst::AudioBusBuffers {
        numChannels: 0,
        silenceFlags: 0,
        __field0: Vst::AudioBusBuffers__type0 {
            channelBuffers32: ptr::null_mut(),
        },
    }
}
fn fill_buses(
    buses: &mut [Vst::AudioBusBuffers],
    channels: &[usize],
    pointers32: &mut [*mut f32],
    pointers64: &mut [*mut f64],
    use_f64: bool,
) {
    let mut offset = 0;
    for (bus, &count) in buses.iter_mut().zip(channels) {
        bus.numChannels = i32::try_from(count).unwrap_or(0);
        bus.silenceFlags = 0;
        bus.__field0 = if use_f64 {
            Vst::AudioBusBuffers__type0 {
                channelBuffers64: pointers64[offset..].as_mut_ptr(),
            }
        } else {
            Vst::AudioBusBuffers__type0 {
                channelBuffers32: pointers32[offset..].as_mut_ptr(),
            }
        };
        offset += count;
    }
}
fn note_event(
    on: bool,
    channel: i16,
    pitch: i16,
    velocity: f32,
    id: i32,
    offset: i32,
) -> Vst::Event {
    Vst::Event {
        busIndex: 0,
        sampleOffset: offset,
        ppqPosition: 0.0,
        flags: 0,
        r#type: u16::from(!on),
        __field0: if on {
            Vst::Event__type0 {
                noteOn: Vst::NoteOnEvent {
                    channel,
                    pitch,
                    tuning: 0.0,
                    velocity,
                    length: 0,
                    noteId: id,
                },
            }
        } else {
            Vst::Event__type0 {
                noteOff: Vst::NoteOffEvent {
                    channel,
                    pitch,
                    velocity,
                    noteId: id,
                    tuning: 0.0,
                },
            }
        },
    }
}
fn transport_context(context: &ProcessContext, sample_rate: f64) -> Vst::ProcessContext {
    use Vst::ProcessContext_::StatesAndFlags_::*;
    let mut flags = kTempoValid | kTimeSigValid | kProjectTimeMusicValid | kBarPositionValid;
    if context.is_playing {
        flags |= kPlaying;
    }
    if context.is_recording {
        flags |= kRecording;
    }
    if context.loop_start_beat.is_some() && context.loop_end_beat.is_some() {
        flags |= kCycleActive | kCycleValid;
    }
    // SAFETY: This ABI record contains only integer/float/plain-record fields.
    let mut result: Vst::ProcessContext = unsafe { std::mem::zeroed() };
    result.state = flags;
    result.sampleRate = sample_rate;
    result.projectTimeSamples = i64::try_from(context.project_time_samples).unwrap_or(i64::MAX);
    result.projectTimeMusic = context.beat_position;
    result.barPositionMusic = context.bar_position;
    result.tempo = context.bpm;
    result.timeSigNumerator = i32::from(context.time_sig_numerator);
    result.timeSigDenominator = i32::from(context.time_sig_denominator);
    result.cycleStartMusic = context.loop_start_beat.unwrap_or(0.0);
    result.cycleEndMusic = context.loop_end_beat.unwrap_or(0.0);
    result
}
pub(crate) fn silence(buffers: &mut AudioBuffers) {
    for bus in buffers
        .main_outputs
        .iter_mut()
        .chain(buffers.aux_outputs.iter_mut())
    {
        for channel in bus.channel_data.iter_mut() {
            channel.fill(0.0);
        }
    }
}

pub(crate) struct ProcessorSlot {
    pub gate: ProcessingGate,
    pub dsp: UnsafeCell<Dsp>,
    pub latency: AtomicU32,
    pub tail: AtomicU32,
    pub endpoint_alive: AtomicBool,
}
// SAFETY: Only the non-cloneable audio endpoint accesses dsp while holding gate.enter().
// The UI owner accesses it only after suspension acknowledgement. The UI owner retains an Arc
// until the endpoint is retired, so all COM releases and module teardown happen on the UI thread.
unsafe impl Send for ProcessorSlot {}
// SAFETY: Shared access exposes only atomics; mutable DSP access is serialized by ProcessingGate.
unsafe impl Sync for ProcessorSlot {}

/// Exclusive real-time endpoint for one prepared VST3 instance.
///
/// Processing enters the shared [`ProcessingGate`] before touching `ProcessorSlot::dsp`; UI-side
/// preparation, state, and teardown may access that DSP state only after suspension has been
/// acknowledged. Dropping the endpoint publishes `endpoint_alive = false` but leaves native COM
/// destruction to the UI owner that retains the slot.
pub struct Vst3Processor {
    pub(crate) slot: Arc<ProcessorSlot>,
    pub(crate) exchange: Arc<ParameterExchange>,
    pub(crate) descriptor: PluginDescriptor,
    pub(crate) specs: Vec<ParameterSpec>,
    pub(crate) bypass: bool,
    pub(crate) reset_pending: bool,
    pub(crate) latency_seen: u32,
    pub(crate) bypass_delay: karbeat_host_api::bypass::BypassDelay,
}
impl Drop for Vst3Processor {
    fn drop(&mut self) {
        self.slot.endpoint_alive.store(false, Ordering::Release);
    }
}
impl AudioPlugin for Vst3Processor {
    fn name(&self) -> &str {
        &self.descriptor.name
    }
    fn vendor(&self) -> &str {
        &self.descriptor.vendor
    }
    fn version(&self) -> &str {
        &self.descriptor.version
    }
    fn category(&self) -> karbeat_plugin_api::types::PluginCategory {
        match self.descriptor.kind {
            PluginKind::Instrument => karbeat_plugin_api::types::PluginCategory::Instrument,
            PluginKind::Effect => karbeat_plugin_api::types::PluginCategory::Effect,
            PluginKind::MidiEffect => karbeat_plugin_api::types::PluginCategory::MidiEffect,
        }
    }
    fn prepare(&mut self, _sample_rate: f32, _max_buffer_size: usize) {}
    fn reset(&mut self) {
        self.reset_pending = true;
    }
    fn can_apply_io_layout(&self, inputs: &[BusConfig], outputs: &[BusConfig]) -> bool {
        inputs.iter().chain(outputs).all(|b| b.channel_count <= 2)
    }
    fn set_io_layout(&mut self, _inputs: &[BusConfig], _outputs: &[BusConfig]) {}
    fn process(&mut self, buffers: &mut AudioBuffers, context: &ProcessContext) {
        let guard = self.slot.gate.enter();
        let suspended = guard.is_none() || self.bypass;
        if self.descriptor.kind != PluginKind::Instrument {
            self.bypass_delay.process(buffers, suspended);
        }
        if guard.is_some() && !self.bypass {
            // SAFETY: Gate excludes UI reconfiguration and any other processing call.
            let dsp = unsafe { &mut *self.slot.dsp.get() };
            dsp.recover_notes |= std::mem::take(&mut self.reset_pending);
            dsp.process(buffers, context, &self.exchange);
        } else {
            self.reset_pending |= !context.midi_events.is_empty();
            if self.descriptor.kind == PluginKind::Instrument {
                silence(buffers);
            }
        }
    }
    fn set_bypass(&mut self, bypass: bool) {
        self.reset_pending |= self.bypass != bypass;
        self.bypass = bypass;
    }
    fn latency_samples(&self) -> u32 {
        self.slot.latency.load(Ordering::Acquire)
    }
    fn tail_samples(&self) -> u32 {
        self.slot.tail.load(Ordering::Acquire)
    }
    fn has_latency_changed(&mut self) -> bool {
        let latency = self.latency_samples();
        let changed = latency != self.latency_seen;
        self.latency_seen = latency;
        changed
    }
    fn set_parameter(&mut self, id: u32, value: f32) {
        if value.is_finite() {
            if let Some(parameter) = self.exchange.parameter(id) {
                parameter.set(f64::from(value).clamp(0.0, 1.0), 0);
            }
        }
    }
    fn get_parameter(&self, id: u32) -> f32 {
        self.exchange
            .parameter(id)
            .map_or(0.0, |p| narrow_sample(p.get()))
    }
    fn apply_automation(&mut self, id: u32, value: f32) {
        self.set_parameter(id, value);
    }
    fn clear_automation(&mut self, _id: u32) {}
    fn default_parameters(&self) -> karbeat_plugin_api::traits::HashMap<u32, f32> {
        self.specs
            .iter()
            .map(|p| (p.id, narrow_sample(p.default_value)))
            .collect()
    }
    fn static_parameter_specs() -> Vec<ParameterSpec> {
        Vec::new()
    }
    fn get_parameter_specs(&self) -> Vec<ParameterSpec> {
        self.specs.clone()
    }
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

#[cfg(test)]
#[allow(non_snake_case, reason = "VST3 ABI names")]
#[allow(
    clippy::unwrap_used,
    reason = "test COM interfaces and fixtures must be present"
)]
mod tests {
    use super::*;
    use std::cell::Cell;
    use vst3::Steinberg::{
        Vst::{IEventListTrait, IParamValueQueueTrait, IParameterChangesTrait},
        kNotImplemented, kResultFalse,
    };
    use vst3::{Class, ComRef};

    #[derive(Clone, Copy, Debug, PartialEq)]
    struct FlushRecord {
        samples: i32,
        input_count: i32,
        output_count: i32,
        null_buses: bool,
        parameter: u32,
        offset: i32,
        value: f64,
        notes: [(u16, i16, i32); 4],
    }

    struct FlushProcessor(Cell<Option<FlushRecord>>);
    impl Class for FlushProcessor {
        type Interfaces = (IAudioProcessor,);
    }
    impl IAudioProcessorTrait for FlushProcessor {
        unsafe fn setBusArrangements(&self, _: *mut u64, _: i32, _: *mut u64, _: i32) -> i32 {
            kNotImplemented
        }
        unsafe fn getBusArrangement(&self, _: i32, _: i32, _: *mut u64) -> i32 {
            kNotImplemented
        }
        unsafe fn canProcessSampleSize(&self, _: i32) -> i32 {
            kResultOk
        }
        unsafe fn getLatencySamples(&self) -> u32 {
            0
        }
        unsafe fn setupProcessing(&self, _: *mut Vst::ProcessSetup) -> i32 {
            kResultOk
        }
        unsafe fn setProcessing(&self, _: u8) -> i32 {
            kResultOk
        }
        unsafe fn getTailSamples(&self) -> u32 {
            0
        }
        unsafe fn process(&self, data: *mut Vst::ProcessData) -> i32 {
            // SAFETY: Dsp provides its live process data and parameter interfaces for this call.
            let data = unsafe { &*data };
            // SAFETY: inputParameterChanges is retained by Dsp during processing.
            let changes =
                unsafe { ComRef::<IParameterChanges>::from_raw(data.inputParameterChanges) }
                    .unwrap();
            // SAFETY: The test queues exactly one parameter before flushing.
            let queue = unsafe { changes.getParameterData(0) };
            // SAFETY: The returned queue belongs to the live parameter changes collection.
            let queue = unsafe { ComRef::<Vst::IParamValueQueue>::from_raw(queue) }.unwrap();
            let (mut offset, mut value) = (-1, -1.0);
            // SAFETY: Both scalar outputs are writable for the test queue's first point.
            unsafe { queue.getPoint(0, &raw mut offset, &raw mut value) };
            // SAFETY: The parameter queue remains live throughout this call.
            let parameter = unsafe { queue.getParameterId() };
            let mut notes = [(u16::MAX, -1, -1); 4];
            // SAFETY: The event list is retained by Dsp during the synchronous process call.
            if let Some(events) = unsafe { ComRef::<IEventList>::from_raw(data.inputEvents) } {
                for (index, note) in notes.iter_mut().enumerate() {
                    let mut event = note_event(false, 0, 0, 0.0, -1, 0);
                    // SAFETY: getEvent checks the index and writes to a valid event record.
                    if unsafe { events.getEvent(i32::try_from(index).unwrap(), &raw mut event) }
                        != kResultOk
                    {
                        break;
                    }
                    let pitch = match event.r#type {
                        // SAFETY: Each union member is selected by the corresponding event type.
                        0 => unsafe { event.__field0.noteOn.pitch },
                        // SAFETY: Type 1 carries a NoteOffEvent.
                        1 => unsafe { event.__field0.noteOff.pitch },
                        _ => -1,
                    };
                    *note = (event.r#type, pitch, event.sampleOffset);
                }
            }
            self.0.set(Some(FlushRecord {
                samples: data.numSamples,
                input_count: data.numInputs,
                output_count: data.numOutputs,
                null_buses: data.inputs.is_null() && data.outputs.is_null(),
                parameter,
                offset,
                value,
                notes,
            }));
            kResultOk
        }
    }

    #[test]
    fn zero_sample_state_flush_delivers_edits_without_consuming_audio_errors() {
        let processor = ComWrapper::new(FlushProcessor(Cell::new(None)));
        let config = ProcessingConfig {
            sample_rate: 48_000.0,
            max_block_size: 128,
            main_input_channels: 2,
            main_output_channels: 2,
            sidechain_channels: 0,
            offline: false,
        };
        let mut dsp = Dsp::new(
            processor.to_com_ptr::<IAudioProcessor>().unwrap(),
            config,
            vec![2],
            vec![2],
            &[77],
            false,
        );
        let exchange = ParameterExchange::new(&[(77, 0.0)]);
        exchange.parameter(77).unwrap().set(0.75, 0);
        dsp.flush(&exchange).unwrap();
        assert_eq!(
            processor.0.get(),
            Some(FlushRecord {
                samples: 0,
                input_count: 0,
                output_count: 0,
                null_buses: true,
                parameter: 77,
                offset: 0,
                value: 0.75,
                notes: [(u16::MAX, -1, -1); 4],
            })
        );
        assert!(
            !exchange
                .parameter(77)
                .unwrap()
                .pending
                .load(Ordering::Acquire)
        );
        exchange
            .process_error
            .store(kResultFalse, Ordering::Release);
        exchange.parameter(77).unwrap().set(0.5, 0);
        dsp.flush(&exchange).unwrap();
        assert_eq!(exchange.process_error.load(Ordering::Acquire), kResultFalse);
    }

    fn render_notes(endpoint: &mut Vst3Processor, midi: &[karbeat_plugin_api::prelude::MidiEvent]) {
        endpoint.set_parameter(77, 0.5);
        let mut samples = [0.0_f32; 32];
        let mut channels: [&mut [f32]; 1] = [&mut samples];
        let mut output = [karbeat_plugin_api::prelude::AudioBusBuffer {
            channel_data: &mut channels,
            is_silent: false,
        }];
        endpoint.process(
            &mut AudioBuffers {
                main_inputs: &mut [],
                main_outputs: &mut output,
                aux_inputs: &mut [],
                aux_outputs: &mut [],
            },
            &ProcessContext {
                bpm: 120.0,
                time_sig_numerator: 4,
                time_sig_denominator: 4,
                is_playing: true,
                is_recording: false,
                mode: karbeat_plugin_api::prelude::ProcessingMode::Realtime,
                project_time_seconds: 0.0,
                project_time_samples: 0,
                beat_position: 0.0,
                bar_position: 0.0,
                loop_start_beat: None,
                loop_end_beat: None,
                midi_events: midi,
                param_changes: &[],
            },
        );
    }

    #[test]
    fn bypass_suspension_and_reset_release_old_notes_without_discarding_new_notes() {
        use karbeat_host_api::{PluginFormat, PluginIdentity, PluginKind};
        use karbeat_plugin_api::prelude::MidiEvent;
        for scenario in 0..3 {
            let processor = ComWrapper::new(FlushProcessor(Cell::new(None)));
            let mut dsp = Dsp::new(
                processor.to_com_ptr::<IAudioProcessor>().unwrap(),
                ProcessingConfig {
                    sample_rate: 48_000.0,
                    max_block_size: 32,
                    main_input_channels: 0,
                    main_output_channels: 1,
                    sidechain_channels: 0,
                    offline: false,
                },
                vec![],
                vec![1],
                &[77],
                false,
            );
            dsp.processing = true;
            let slot = Arc::new(ProcessorSlot {
                gate: ProcessingGate::default(),
                dsp: UnsafeCell::new(dsp),
                latency: AtomicU32::new(0),
                tail: AtomicU32::new(0),
                endpoint_alive: AtomicBool::new(true),
            });
            slot.gate.resume().unwrap();
            let mut endpoint = Vst3Processor {
                slot: slot.clone(),
                exchange: ParameterExchange::new(&[(77, 0.0)]),
                descriptor: PluginDescriptor {
                    identity: PluginIdentity {
                        format: PluginFormat::Vst3,
                        native_id: "fixture".into(),
                    },
                    path: "fixture.vst3".into(),
                    name: "Fixture".into(),
                    vendor: String::new(),
                    version: "1".into(),
                    kind: PluginKind::Instrument,
                },
                specs: Vec::new(),
                bypass: false,
                reset_pending: false,
                latency_seen: 0,
                bypass_delay: karbeat_host_api::bypass::BypassDelay::new(1, 0).unwrap(),
            };
            let note_on = |key, note_id| MidiEvent {
                sample_offset: 7,
                data: MidiMessage::NoteOn {
                    note_id: Some(note_id),
                    channel: 0,
                    key,
                    velocity: 100,
                },
            };
            render_notes(&mut endpoint, &[note_on(60, 10)]);
            assert_eq!(processor.0.get().unwrap().notes[0], (0, 60, 7));
            if scenario == 0 {
                endpoint.set_bypass(true);
            } else {
                slot.gate.suspend().unwrap();
            }
            if scenario == 2 {
                endpoint.reset();
            } else {
                render_notes(
                    &mut endpoint,
                    &[MidiEvent {
                        sample_offset: 13,
                        data: MidiMessage::NoteOff {
                            note_id: Some(10),
                            channel: 0,
                            key: 60,
                        },
                    }],
                );
            }
            if scenario == 0 {
                endpoint.set_bypass(false);
            } else {
                slot.gate.resume().unwrap();
            }
            render_notes(&mut endpoint, &[note_on(64, 11)]);
            let notes = processor.0.get().unwrap().notes;
            assert_eq!(notes[0], (1, 60, 0));
            assert_eq!(notes[1], (0, 64, 7));
            render_notes(&mut endpoint, &[]);
            assert_eq!(processor.0.get().unwrap().notes[0].0, u16::MAX);
        }
    }
}
