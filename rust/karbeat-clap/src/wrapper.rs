//! Exclusive audio endpoint. Instantiation, state, and editor work stay with the UI owner.

use std::{
    cell::{Cell, UnsafeCell},
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicU32, Ordering},
    },
};

use clack_common::events::io::OutputEvents;
use clack_extensions::params::PluginParams;
use clack_host::process::{
    PluginAudioProcessor,
    audio_buffers::{AudioPortBuffer, AudioPortBufferType, AudioPorts, InputChannel},
};
use karbeat_host_api::{
    ParameterExchange, PluginDescriptor, PluginKind, ProcessingConfig, ProcessingGate,
    bypass::BypassDelay,
    channels::{adapt_channels, silence},
};
use karbeat_plugin_api::prelude::{
    AudioBuffers, AudioPlugin, BusConfig, ParameterSpec, ProcessContext,
};

use crate::{
    events::{
        InputQueue, NoteInput, NoteSender, ParameterOutput, queue_automation, queue_pending,
        transport,
    },
    host::ClapHostHandlers,
    parameters::ClapParameter,
};

/// Most channels allocated for one audio port.
const MAX_PORT_CHANNELS: u32 = 64;
/// Process status kept when the plugin fails to start processing.
pub(crate) const START_FAILED: i32 = -2;
/// Process status kept when the plugin reports a processing error.
pub(crate) const PROCESS_FAILED: i32 = -1;

thread_local! {
    static AUDIO_CONTEXT: Cell<bool> = const { Cell::new(false) };
}

/// Whether the current thread holds exclusive DSP access, which CLAP calls the audio thread.
pub(crate) fn in_audio_context() -> bool {
    AUDIO_CONTEXT.with(Cell::get)
}

/// Marks the current thread as the plugin's audio thread until dropped.
pub(crate) struct AudioContext(bool);

impl AudioContext {
    pub fn enter() -> Self {
        Self(AUDIO_CONTEXT.with(|context| context.replace(true)))
    }
}

impl Drop for AudioContext {
    fn drop(&mut self) {
        AUDIO_CONTEXT.with(|context| context.set(self.0));
    }
}

/// Channel counts of the plugin's audio ports and the ones the engine routes.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub(crate) struct PortLayout {
    /// Channels of each input port, in port order.
    pub inputs: Vec<u32>,
    /// Channels of each output port, in port order.
    pub outputs: Vec<u32>,
    pub main_input: Option<usize>,
    /// First input besides the main one, fed from the sidechain route.
    pub sidechain: Option<usize>,
    pub main_output: Option<usize>,
}

impl PortLayout {
    /// Builds the layout from each port's `(channel count, flagged main)`.
    ///
    /// The flagged main port is preferred; without one the first port with channels is main.
    pub fn new(inputs: &[(u32, bool)], outputs: &[(u32, bool)]) -> Self {
        let main = |ports: &[(u32, bool)]| {
            ports
                .iter()
                .position(|(channels, main)| *main && *channels > 0)
                .or_else(|| ports.iter().position(|(channels, _)| *channels > 0))
        };
        let main_input = main(inputs);
        Self {
            sidechain: inputs
                .iter()
                .enumerate()
                .position(|(index, (channels, _))| Some(index) != main_input && *channels > 0),
            main_input,
            main_output: main(outputs),
            inputs: inputs.iter().map(|(channels, _)| *channels).collect(),
            outputs: outputs.iter().map(|(channels, _)| *channels).collect(),
        }
    }

    /// Whether every port can be given the buffers it declares. The plugin reads every channel
    /// it declares, so a port is never given fewer.
    pub fn within_limits(&self) -> bool {
        self.inputs
            .iter()
            .chain(&self.outputs)
            .all(|channels| *channels <= MAX_PORT_CHANNELS)
    }
}

/// Planes for every channel of every port, allocated once for the prepared block size.
fn planes(ports: &[u32], frames: usize) -> Vec<Vec<Vec<f32>>> {
    ports
        .iter()
        .map(|channels| {
            (0..*channels)
                .map(|_| vec![0.0_f32; frames])
                .collect::<Vec<_>>()
        })
        .collect()
}

pub(crate) struct Dsp {
    /// `None` once the owner took the processor back to deactivate the plugin.
    processor: Option<PluginAudioProcessor<ClapHostHandlers>>,
    pub config: ProcessingConfig,
    layout: PortLayout,
    input_planes: Vec<Vec<Vec<f32>>>,
    output_planes: Vec<Vec<Vec<f32>>>,
    input_ports: AudioPorts,
    output_ports: AudioPorts,
    events: InputQueue,
    notes: NoteSender,
    parameters: Arc<[ClapParameter]>,
    params: Option<PluginParams>,
    steady_time: u64,
    pub reset_pending: bool,
}

impl Dsp {
    pub fn new(
        processor: PluginAudioProcessor<ClapHostHandlers>,
        config: ProcessingConfig,
        layout: PortLayout,
        parameters: Arc<[ClapParameter]>,
        params: Option<PluginParams>,
        note_input: Option<NoteInput>,
    ) -> Self {
        let channels = |ports: &[u32]| {
            ports
                .iter()
                .map(|channels| usize::try_from(*channels).unwrap_or(0))
                .sum::<usize>()
        };
        Self {
            input_planes: planes(&layout.inputs, config.max_block_size),
            output_planes: planes(&layout.outputs, config.max_block_size),
            input_ports: AudioPorts::with_capacity(channels(&layout.inputs), layout.inputs.len()),
            output_ports: AudioPorts::with_capacity(
                channels(&layout.outputs),
                layout.outputs.len(),
            ),
            events: InputQueue::new(),
            notes: NoteSender::new(note_input),
            processor: Some(processor),
            config,
            layout,
            parameters,
            params,
            steady_time: 0,
            reset_pending: false,
        }
    }

    /// Hands the processor back to the owner, which stops and deactivates it.
    pub fn take_processor(&mut self) -> Option<PluginAudioProcessor<ClapHostHandlers>> {
        self.processor.take()
    }

    /// Delivers pending parameter edits through the plugin's parameter flush and records the
    /// values it reports back.
    ///
    /// The caller holds exclusive DSP access while processing is suspended. Edits that do not
    /// fit stay pending for the next flush.
    pub fn flush(&mut self, exchange: &ParameterExchange) {
        let _audio = AudioContext::enter();
        self.events.clear();
        if !queue_pending(&mut self.events, exchange, &self.parameters) {
            exchange.overflow.store(true, Ordering::Relaxed);
        }
        let (Some(params), Some(processor)) = (self.params, self.processor.as_mut()) else {
            return;
        };
        let mut output = ParameterOutput {
            exchange,
            parameters: &self.parameters,
        };
        params.flush_active(
            &mut processor.plugin_handle(),
            &self.events.as_input(),
            &mut OutputEvents::from_buffer(&mut output),
        );
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
            .and_then(|bus| bus.channel_data.first())
            .map_or(0, |channel| channel.len());
        if frames == 0 || frames > self.config.max_block_size {
            silence(buffers);
            return;
        }
        let _audio = AudioContext::enter();
        for plane in self
            .input_planes
            .iter_mut()
            .chain(&mut self.output_planes)
            .flatten()
        {
            if let Some(block) = plane.get_mut(..frames) {
                block.fill(0.0);
            }
        }
        if let (Some(source), Some(destination)) = (
            buffers.main_inputs.first(),
            self.layout
                .main_input
                .and_then(|port| self.input_planes.get_mut(port)),
        ) {
            adapt_channels(&*source.channel_data, destination, frames);
        }
        if let (Some(source), Some(destination)) = (
            buffers.aux_inputs.first(),
            self.layout
                .sidechain
                .and_then(|port| self.input_planes.get_mut(port)),
        ) {
            adapt_channels(&*source.channel_data, destination, frames);
        }
        self.events.clear();
        let mut delivered = queue_pending(&mut self.events, exchange, &self.parameters);
        delivered &= queue_automation(
            &mut self.events,
            context,
            exchange,
            &self.parameters,
            frames,
        );
        let notes = self
            .notes
            .queue(&mut self.events, context.midi_events, frames);
        // Lost note events can leave notes hanging, so every held note is released next block.
        self.notes.recover |= !notes;
        if !(delivered && notes) {
            exchange.overflow.store(true, Ordering::Relaxed);
        }
        self.events.sort();
        let transport = transport(context);
        silence(buffers);
        let Some(processor) = self.processor.as_mut() else {
            return;
        };
        if std::mem::take(&mut self.reset_pending) {
            processor.reset();
        }
        let Ok(started) = processor.ensure_processing_started() else {
            exchange
                .process_error
                .store(START_FAILED, Ordering::Release);
            return;
        };
        let inputs = self
            .input_ports
            .with_input_buffers(self.input_planes.iter_mut().map(|port| AudioPortBuffer {
                latency: 0,
                channels: AudioPortBufferType::f32_input_only(port.iter_mut().map(|plane| {
                    InputChannel::variable(plane.get_mut(..frames).unwrap_or_default())
                })),
            }));
        let mut outputs = self
            .output_ports
            .with_output_buffers(self.output_planes.iter_mut().map(|port| {
                AudioPortBuffer {
                    latency: 0,
                    channels: AudioPortBufferType::f32_output_only(
                        port.iter_mut()
                            .map(|plane| plane.get_mut(..frames).unwrap_or_default()),
                    ),
                }
            }));
        let mut output = ParameterOutput {
            exchange,
            parameters: &self.parameters,
        };
        let result = started.process(
            &inputs,
            &mut outputs,
            &self.events.as_input(),
            &mut OutputEvents::from_buffer(&mut output),
            Some(self.steady_time),
            Some(&transport),
        );
        self.steady_time = self
            .steady_time
            .wrapping_add(u64::try_from(frames).unwrap_or(0));
        if result.is_err() {
            exchange
                .process_error
                .store(PROCESS_FAILED, Ordering::Release);
            return;
        }
        if let (Some(destination), Some(sources)) = (
            buffers.main_outputs.first_mut(),
            self.layout
                .main_output
                .and_then(|port| self.output_planes.get(port)),
        ) {
            adapt_channels(sources, destination.channel_data, frames);
        }
    }
}

pub(crate) struct ProcessorSlot {
    pub gate: ProcessingGate,
    pub dsp: UnsafeCell<Dsp>,
    pub latency: AtomicU32,
    pub endpoint_alive: AtomicBool,
}

// SAFETY: Only the non-cloneable audio endpoint accesses `dsp` while holding `gate.enter()`. The
// UI owner accesses it only after suspension acknowledgement, and keeps an `Arc` until the
// endpoint is retired, so the plugin is always deactivated and destroyed there.
unsafe impl Send for ProcessorSlot {}
// SAFETY: Shared access exposes only atomics; mutable DSP access is serialized by the gate.
unsafe impl Sync for ProcessorSlot {}

/// Exclusive real-time endpoint for one prepared CLAP instance.
///
/// Processing enters the shared [`ProcessingGate`] before touching `ProcessorSlot::dsp`; UI-side
/// activation, state, and teardown may access that DSP state only after suspension has been
/// acknowledged. Dropping the endpoint publishes `endpoint_alive = false` but leaves the plugin
/// to the UI owner that retains the slot.
pub struct ClapProcessor {
    pub(crate) slot: Arc<ProcessorSlot>,
    pub(crate) exchange: Arc<ParameterExchange>,
    pub(crate) descriptor: PluginDescriptor,
    pub(crate) specs: Vec<ParameterSpec>,
    pub(crate) bypass: bool,
    pub(crate) reset_pending: bool,
    pub(crate) latency_seen: u32,
    pub(crate) bypass_delay: BypassDelay,
}

impl Drop for ClapProcessor {
    fn drop(&mut self) {
        self.slot.endpoint_alive.store(false, Ordering::Release);
    }
}

impl AudioPlugin for ClapProcessor {
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
            dsp.reset_pending |= std::mem::take(&mut self.reset_pending);
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
    fn has_latency_changed(&mut self) -> bool {
        let latency = self.latency_samples();
        let changed = latency != self.latency_seen;
        self.latency_seen = latency;
        changed
    }
    fn set_parameter(&mut self, id: u32, value: f32) {
        if value.is_finite()
            && let Some(parameter) = self.exchange.parameter(id)
        {
            parameter.set(f64::from(value).clamp(0.0, 1.0), 0);
        }
    }
    fn get_parameter(&self, id: u32) -> f32 {
        self.exchange
            .parameter(id)
            .map_or(0.0, |parameter| single(parameter.get()))
    }
    fn apply_automation(&mut self, id: u32, value: f32) {
        self.set_parameter(id, value);
    }
    fn clear_automation(&mut self, _id: u32) {}
    fn default_parameters(&self) -> karbeat_plugin_api::traits::HashMap<u32, f32> {
        self.specs
            .iter()
            .map(|spec| (spec.id, single(spec.default_value)))
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

#[allow(
    clippy::as_conversions,
    clippy::cast_possible_truncation,
    reason = "the engine reads parameters in single precision"
)]
fn single(value: f64) -> f32 {
    if value.is_finite() { value as f32 } else { 0.0 }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn flagged_main_ports_are_preferred_and_the_next_input_is_the_sidechain() {
        let layout = PortLayout::new(&[(2, false), (2, true), (1, false)], &[(2, true)]);
        assert_eq!(layout.main_input, Some(1));
        assert_eq!(layout.sidechain, Some(0));
        assert_eq!(layout.main_output, Some(0));
        let unflagged = PortLayout::new(&[(0, false), (2, false)], &[(0, true), (2, false)]);
        assert_eq!(unflagged.main_input, Some(1));
        assert_eq!(unflagged.sidechain, None);
        assert_eq!(unflagged.main_output, Some(1));
        assert_eq!(PortLayout::new(&[], &[]).main_output, None);
        assert!(layout.within_limits());
        assert!(!PortLayout::new(&[], &[(MAX_PORT_CHANNELS + 1, true)]).within_limits());
    }

    #[test]
    fn the_audio_context_is_scoped_and_nests() {
        assert!(!in_audio_context());
        {
            let _outer = AudioContext::enter();
            {
                let _inner = AudioContext::enter();
                assert!(in_audio_context());
            }
            assert!(in_audio_context());
        }
        assert!(!in_audio_context());
    }
}
