//! Exclusive audio endpoint. Instantiation, state, and editor work stay with the UI owner.

use std::{
    cell::UnsafeCell,
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicU32, Ordering},
    },
};

use karbeat_host_api::{
    ParameterExchange, PluginDescriptor, PluginKind, ProcessingConfig, ProcessingGate,
    bypass::BypassDelay,
    channels::{adapt_channels, silence},
};
use karbeat_plugin_api::prelude::{
    AudioBuffers, AudioPlugin, BusConfig, MidiMessage, NoteExpressionType, ParameterSpec,
    ProcessContext,
};

use crate::{
    atoms::{
        AtomBuffer, AtomReceiver, AtomSender, Position, PositionUrids, midi_bytes,
        pitch_bend_bytes, position_body,
    },
    parameters::ControlPort,
    plugin::PluginInstance,
    ports::{AudioRole, PluginModel},
};

/// Frames rendered to deliver parameter edits and learn latency while no audio block runs.
const FLUSH_FRAMES: usize = 32;
/// One slot per MIDI channel and key.
const KEY_SLOTS: usize = 16 * 128;
/// Largest latency a plugin may report, matching the bypass delay's limit.
const MAX_LATENCY_FRAMES: f32 = 1_048_576.0;

/// URIDs the audio path needs, mapped once at preparation.
#[derive(Clone, Copy, Debug, Default)]
pub(crate) struct DspUrids {
    pub sequence: u32,
    pub chunk: u32,
    pub midi_event: u32,
    pub position: PositionUrids,
}

/// Audio-side ends of the editor message rings.
pub(crate) struct DspLink {
    pub from_editor: AtomReceiver,
    pub to_editor: AtomSender,
}

/// Transport facts last reported to the plugin, used to send positions only when they change.
#[derive(Clone, Copy, PartialEq)]
struct TransportMemo {
    playing: bool,
    tempo: u64,
    numerator: u8,
    denominator: u8,
    next_frame: u64,
}

pub(crate) struct Dsp {
    instance: PluginInstance,
    pub config: ProcessingConfig,
    controls: Arc<[ControlPort]>,
    audio_inputs: Vec<AudioRole>,
    audio_outputs: Vec<AudioRole>,
    input_planes: Vec<Vec<f32>>,
    output_planes: Vec<Vec<f32>>,
    cv_inputs: Vec<Vec<f32>>,
    /// Written by the plugin and never read; CV is not routed.
    _cv_outputs: Vec<Vec<f32>>,
    atom_inputs: Vec<AtomBuffer>,
    atom_outputs: Vec<AtomBuffer>,
    atom_input_ports: Vec<u32>,
    atom_output_ports: Vec<u32>,
    control_outputs: Vec<u32>,
    midi_input: Option<usize>,
    position_input: Option<usize>,
    latency_port: Option<u32>,
    urids: DspUrids,
    transport: Option<TransportMemo>,
    note_ids: [Option<u64>; KEY_SLOTS],
    active_keys: [bool; KEY_SLOTS],
    pub recover_notes: bool,
    link: Option<DspLink>,
}

impl Dsp {
    /// Allocates every port buffer for the prepared block size and connects the instance's
    /// audio, CV, and atom ports to them, once. The buffers are never resized afterwards.
    pub fn new(
        mut instance: PluginInstance,
        config: ProcessingConfig,
        model: &PluginModel,
        urids: DspUrids,
        link: Option<DspLink>,
    ) -> Self {
        let frames = config.max_block_size;
        let planes = |ports: &mut dyn Iterator<Item = u32>, instance: &mut PluginInstance| {
            ports
                .map(|port| {
                    let mut plane = vec![0.0_f32; frames];
                    // SAFETY: The plane's heap storage is owned by the `Dsp` being built,
                    // outlives the instance's use of it, and is never reallocated.
                    unsafe { instance.connect(port, plane.as_mut_ptr().cast()) };
                    plane
                })
                .collect::<Vec<_>>()
        };
        let sequences = |ports: &[crate::ports::AtomPort], instance: &mut PluginInstance| {
            ports
                .iter()
                .map(|port| {
                    let mut buffer = AtomBuffer::new(port.capacity);
                    // SAFETY: As for the audio planes; the buffer's storage never moves.
                    unsafe { instance.connect(port.index, buffer.as_mut_ptr().cast()) };
                    buffer
                })
                .collect::<Vec<_>>()
        };
        if let Some(port) = model.free_wheeling {
            instance.set_control(port, if config.offline { 1.0 } else { 0.0 });
        }
        Self {
            input_planes: planes(
                &mut model.audio_inputs.iter().map(|port| port.index),
                &mut instance,
            ),
            output_planes: planes(
                &mut model.audio_outputs.iter().map(|port| port.index),
                &mut instance,
            ),
            cv_inputs: planes(&mut model.cv_inputs.iter().copied(), &mut instance),
            _cv_outputs: planes(&mut model.cv_outputs.iter().copied(), &mut instance),
            atom_inputs: sequences(&model.atom_inputs, &mut instance),
            atom_outputs: sequences(&model.atom_outputs, &mut instance),
            atom_input_ports: model.atom_inputs.iter().map(|port| port.index).collect(),
            atom_output_ports: model.atom_outputs.iter().map(|port| port.index).collect(),
            control_outputs: model.control_outputs.clone(),
            midi_input: model.atom_inputs.iter().position(|port| port.supports_midi),
            position_input: model
                .atom_inputs
                .iter()
                .position(|port| port.supports_position),
            latency_port: model.latency,
            audio_inputs: model.audio_inputs.iter().map(|port| port.role).collect(),
            audio_outputs: model.audio_outputs.iter().map(|port| port.role).collect(),
            controls: model.controls.clone(),
            instance,
            config,
            urids,
            transport: None,
            note_ids: [None; KEY_SLOTS],
            active_keys: [false; KEY_SLOTS],
            recover_notes: false,
            link,
        }
    }

    /// Borrows the plugin instance for control-side work while processing is suspended.
    pub const fn instance(&self) -> &PluginInstance {
        &self.instance
    }

    /// Writes a plain value to a control input while processing is suspended.
    pub fn set_control(&mut self, port: u32, plain: f32) {
        self.instance.set_control(port, plain);
    }

    /// Delivers pending parameter edits through a short silent block whose audio is discarded,
    /// and publishes the latency the plugin reports afterwards.
    ///
    /// LV2 plugins read control ports only inside `run`, and plugins such as LSP's work out
    /// their latency while rendering, so both need a block even when no audio is playing.
    pub fn flush(&mut self, exchange: &ParameterExchange, slot: &ProcessorSlot) {
        let frames = FLUSH_FRAMES.min(self.config.max_block_size);
        self.clear_planes(frames);
        self.begin_events();
        self.apply_parameters(exchange);
        self.queue_editor_atoms(exchange);
        self.run(frames);
        self.publish_latency(slot);
    }

    pub fn process(
        &mut self,
        buffers: &mut AudioBuffers,
        context: &ProcessContext,
        exchange: &ParameterExchange,
        slot: &ProcessorSlot,
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
        self.clear_planes(frames);
        if let Some(source) = buffers.main_inputs.first() {
            self.load_role(AudioRole::Main, &*source.channel_data, frames);
        }
        if let Some(source) = buffers.aux_inputs.first() {
            self.load_role(AudioRole::Sidechain, &*source.channel_data, frames);
        }
        self.begin_events();
        self.apply_parameters(exchange);
        self.apply_automation(context, exchange, frames);
        self.queue_editor_atoms(exchange);
        self.queue_transport(context, frames, exchange);
        self.queue_midi(context, frames, exchange);
        self.run(frames);
        self.publish_latency(slot);
        if slot.editor_open.load(Ordering::Acquire) {
            self.publish_to_editor(slot, exchange);
        }
        silence(buffers);
        if let Some(destination) = buffers.main_outputs.first_mut() {
            let mut main: [&[f32]; 2] = [&[], &[]];
            let mut count = 0;
            for (plane, _) in self
                .output_planes
                .iter()
                .zip(&self.audio_outputs)
                .filter(|(_, role)| **role == AudioRole::Main)
            {
                if let Some(source) = main.get_mut(count) {
                    *source = plane;
                    count += 1;
                }
            }
            if let Some(sources) = main.get(..count) {
                adapt_channels(sources, destination.channel_data, frames);
            }
        }
    }

    fn clear_planes(&mut self, frames: usize) {
        for plane in self
            .input_planes
            .iter_mut()
            .chain(&mut self.output_planes)
            .chain(&mut self.cv_inputs)
        {
            if let Some(block) = plane.get_mut(..frames) {
                block.fill(0.0);
            }
        }
    }

    /// Maps one engine bus onto the plugin's input ports of `role`.
    fn load_role<S: AsRef<[f32]>>(&mut self, role: AudioRole, sources: &[S], frames: usize) {
        let mut ports = self
            .input_planes
            .iter_mut()
            .zip(&self.audio_inputs)
            .filter(|(_, port_role)| **port_role == role)
            .map(|(plane, _)| plane.as_mut_slice());
        match (ports.next(), ports.next()) {
            (Some(first), Some(second)) => adapt_channels(sources, &mut [first, second], frames),
            (Some(first), None) => adapt_channels(sources, &mut [first], frames),
            _ => {}
        }
    }

    fn begin_events(&mut self) {
        for sequence in &mut self.atom_inputs {
            sequence.begin_input(self.urids.sequence);
        }
    }

    fn apply_parameters(&mut self, exchange: &ParameterExchange) {
        for (control, parameter) in self.controls.iter().zip(&exchange.parameters) {
            if parameter.pending.swap(false, Ordering::AcqRel) {
                self.instance
                    .set_control(control.index, control.to_plain(parameter.get()));
            }
        }
    }

    /// Applies the engine's automation points. Control ports are block-rate, so the last point
    /// of a block decides the value.
    fn apply_automation(
        &mut self,
        context: &ProcessContext,
        exchange: &ParameterExchange,
        frames: usize,
    ) {
        for change in context.param_changes {
            if change.sample_offset >= frames || !change.normalized_value.is_finite() {
                continue;
            }
            let Ok(position) = self
                .controls
                .binary_search_by_key(&change.param_id, |control| control.index)
            else {
                continue;
            };
            let normalized = f64::from(change.normalized_value).clamp(0.0, 1.0);
            if let Some(control) = self.controls.get(position) {
                self.instance
                    .set_control(control.index, control.to_plain(normalized));
            }
            if let Some(parameter) = exchange.parameters.get(position) {
                parameter
                    .value
                    .store(normalized.to_bits(), Ordering::Release);
            }
        }
    }

    /// Forwards atoms written by the editor to their input ports at the start of the block.
    fn queue_editor_atoms(&mut self, exchange: &ParameterExchange) {
        let Some(link) = &mut self.link else {
            return;
        };
        let (ports, sequences) = (&self.atom_input_ports, &mut self.atom_inputs);
        link.from_editor.drain(|port, atom_type, parts| {
            let sequence = ports
                .iter()
                .position(|candidate| *candidate == port)
                .and_then(|position| sequences.get_mut(position));
            if let Some(sequence) = sequence
                && !sequence.append(0, atom_type, parts)
            {
                exchange.overflow.store(true, Ordering::Relaxed);
            }
        });
    }

    fn queue_transport(
        &mut self,
        context: &ProcessContext,
        frames: usize,
        exchange: &ParameterExchange,
    ) {
        let advance = if context.is_playing {
            u64::try_from(frames).unwrap_or(0)
        } else {
            0
        };
        let current = TransportMemo {
            playing: context.is_playing,
            tempo: context.bpm.to_bits(),
            numerator: context.time_sig_numerator,
            denominator: context.time_sig_denominator,
            next_frame: context.project_time_samples,
        };
        let unchanged = self.transport == Some(current);
        self.transport = Some(TransportMemo {
            next_frame: context.project_time_samples.saturating_add(advance),
            ..current
        });
        let Some(sequence) = self
            .position_input
            .and_then(|position| self.atom_inputs.get_mut(position))
        else {
            return;
        };
        if unchanged {
            return;
        }
        let bar = context.bar_position.floor();
        let body = position_body(
            &self.urids.position,
            &Position {
                frame: i64::try_from(context.project_time_samples).unwrap_or(i64::MAX),
                speed: if context.is_playing { 1.0 } else { 0.0 },
                bar: whole(bar),
                bar_beat: single(
                    (context.bar_position - bar) * f64::from(context.time_sig_numerator),
                ),
                beat_unit: i32::from(context.time_sig_denominator),
                beats_per_bar: f32::from(context.time_sig_numerator),
                beats_per_minute: single(context.bpm),
            },
        );
        if !sequence.append(0, self.urids.position.object, [&body, &[]]) {
            exchange.overflow.store(true, Ordering::Relaxed);
        }
    }

    fn queue_midi(
        &mut self,
        context: &ProcessContext,
        frames: usize,
        exchange: &ParameterExchange,
    ) {
        let Some(sequence) = self
            .midi_input
            .and_then(|position| self.atom_inputs.get_mut(position))
        else {
            self.recover_notes = false;
            return;
        };
        let midi = self.urids.midi_event;
        let mut delivered = true;
        if self.recover_notes {
            for (slot, active) in self.active_keys.iter_mut().enumerate() {
                if std::mem::take(active) {
                    let (channel, key) = slot_key(slot);
                    delivered &=
                        sequence.append(0, midi, [&midi_bytes(0x80, channel, key, 0), &[]]);
                }
            }
            self.note_ids.fill(None);
            self.recover_notes = false;
        }
        // Sequences must be time-ordered, so an out-of-order event is moved up to its predecessor.
        let mut last_offset = 0;
        for event in context.midi_events {
            if event.sample_offset >= frames {
                continue;
            }
            let offset = event.sample_offset.max(last_offset);
            let bytes = match &event.data {
                MidiMessage::NoteOn {
                    note_id,
                    channel,
                    key,
                    velocity,
                } if *channel < 16 && *key < 128 => {
                    let slot = key_slot(*channel, *key);
                    if let Some(active) = self.active_keys.get_mut(slot) {
                        *active = true;
                    }
                    if let Some(id) = self.note_ids.get_mut(slot) {
                        *id = *note_id;
                    }
                    Some(midi_bytes(0x90, *channel, *key, (*velocity).min(127)))
                }
                MidiMessage::NoteOff { channel, key, .. } if *channel < 16 && *key < 128 => {
                    let slot = key_slot(*channel, *key);
                    if let Some(active) = self.active_keys.get_mut(slot) {
                        *active = false;
                    }
                    if let Some(id) = self.note_ids.get_mut(slot) {
                        *id = None;
                    }
                    Some(midi_bytes(0x80, *channel, *key, 0))
                }
                MidiMessage::ControlChange {
                    channel,
                    controller,
                    value,
                } if *channel < 16 && *controller < 128 => {
                    Some(midi_bytes(0xB0, *channel, *controller, (*value).min(127)))
                }
                MidiMessage::PitchBend { channel, value } if *channel < 16 => {
                    Some(pitch_bend_bytes(*channel, *value))
                }
                // MIDI 1.0 has one per-note expression: polyphonic key pressure.
                MidiMessage::NoteExpression {
                    note_id,
                    expression: NoteExpressionType::Pressure,
                    value,
                } => self
                    .note_ids
                    .iter()
                    .position(|id| *id == Some(*note_id))
                    .map(|slot| {
                        let (channel, key) = slot_key(slot);
                        midi_bytes(0xA0, channel, key, seven_bit(*value))
                    }),
                _ => None,
            };
            if let Some(bytes) = bytes {
                last_offset = offset;
                let time = i64::try_from(offset).unwrap_or(0);
                delivered &= sequence.append(time, midi, [&bytes, &[]]);
            }
        }
        if !delivered {
            self.recover_notes = true;
            exchange.overflow.store(true, Ordering::Relaxed);
        }
    }

    /// Runs the plugin for `frames`, which the caller keeps within the prepared block size.
    fn run(&mut self, frames: usize) {
        for buffer in &mut self.atom_outputs {
            buffer.begin_output(self.urids.chunk);
        }
        // SAFETY: The caller holds exclusive DSP access, and every port was connected in `new`
        // to a buffer allocated for the prepared maximum block size.
        unsafe { self.instance.run(u32::try_from(frames).unwrap_or(0)) };
    }

    fn publish_latency(&self, slot: &ProcessorSlot) {
        if let Some(reported) = self
            .latency_port
            .and_then(|port| self.instance.control(port))
        {
            slot.latency
                .store(latency_frames(reported), Ordering::Release);
        }
    }

    /// Copies control outputs and atom output events to the editor's side of the instance.
    fn publish_to_editor(&mut self, slot: &ProcessorSlot, exchange: &ParameterExchange) {
        for (shared, port) in slot.control_outputs.iter().zip(&self.control_outputs) {
            if let Some(value) = self.instance.control(*port) {
                shared.store(value.to_bits(), Ordering::Relaxed);
            }
        }
        let Some(link) = &mut self.link else {
            return;
        };
        for (buffer, port) in self.atom_outputs.iter().zip(&self.atom_output_ports) {
            buffer.events(self.urids.sequence, |atom_type, body| {
                let sent = link.to_editor.send(*port, atom_type, body);
                if !sent {
                    exchange.overflow.store(true, Ordering::Relaxed);
                }
                sent
            });
        }
    }
}

fn key_slot(channel: u8, key: u8) -> usize {
    usize::from(channel) * 128 + usize::from(key)
}

fn slot_key(slot: usize) -> (u8, u8) {
    (
        u8::try_from(slot / 128).unwrap_or(0),
        u8::try_from(slot % 128).unwrap_or(0),
    )
}

#[allow(
    clippy::as_conversions,
    clippy::cast_possible_truncation,
    clippy::cast_sign_loss,
    reason = "the reported latency is clamped to a small non-negative frame count first"
)]
fn latency_frames(reported: f32) -> u32 {
    if reported.is_finite() {
        reported.round().clamp(0.0, MAX_LATENCY_FRAMES) as u32
    } else {
        0
    }
}

#[allow(
    clippy::as_conversions,
    clippy::cast_possible_truncation,
    reason = "transport values are reported to plugins in single precision"
)]
fn single(value: f64) -> f32 {
    if value.is_finite() { value as f32 } else { 0.0 }
}

#[allow(
    clippy::as_conversions,
    clippy::cast_possible_truncation,
    reason = "a floored bar number is far inside the 64-bit range"
)]
fn whole(value: f64) -> i64 {
    if value.is_finite() { value as i64 } else { 0 }
}

#[allow(
    clippy::as_conversions,
    clippy::cast_possible_truncation,
    clippy::cast_sign_loss,
    reason = "the normalized value is clamped to the seven-bit MIDI range first"
)]
fn seven_bit(normalized: f32) -> u8 {
    if normalized.is_finite() {
        (normalized.clamp(0.0, 1.0) * 127.0).round() as u8
    } else {
        0
    }
}

pub(crate) struct ProcessorSlot {
    pub gate: ProcessingGate,
    pub dsp: UnsafeCell<Dsp>,
    pub latency: AtomicU32,
    pub endpoint_alive: AtomicBool,
    /// Set by the UI owner while an editor wants control and atom output notifications.
    pub editor_open: AtomicBool,
    /// Bits of each control output's last value, in port order.
    pub control_outputs: Box<[AtomicU32]>,
}

// SAFETY: Only the non-cloneable audio endpoint accesses `dsp` while holding `gate.enter()`. The
// UI owner accesses it only after suspension acknowledgement, and keeps an `Arc` until the
// endpoint is retired, so the plugin instance and its worker are always destroyed there.
unsafe impl Send for ProcessorSlot {}
// SAFETY: Shared access exposes only atomics; mutable DSP access is serialized by the gate.
unsafe impl Sync for ProcessorSlot {}

/// Exclusive real-time endpoint for one prepared LV2 instance.
///
/// Processing enters the shared [`ProcessingGate`] before touching `ProcessorSlot::dsp`; UI-side
/// preparation, state, and teardown may access that DSP state only after suspension has been
/// acknowledged. Dropping the endpoint publishes `endpoint_alive = false` but leaves the plugin
/// instance to the UI owner that retains the slot.
pub struct Lv2Processor {
    pub(crate) slot: Arc<ProcessorSlot>,
    pub(crate) exchange: Arc<ParameterExchange>,
    pub(crate) descriptor: PluginDescriptor,
    pub(crate) specs: Vec<ParameterSpec>,
    pub(crate) bypass: bool,
    pub(crate) reset_pending: bool,
    pub(crate) latency_seen: u32,
    pub(crate) bypass_delay: BypassDelay,
}

impl Drop for Lv2Processor {
    fn drop(&mut self) {
        self.slot.endpoint_alive.store(false, Ordering::Release);
    }
}

impl AudioPlugin for Lv2Processor {
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
            dsp.process(buffers, context, &self.exchange, &self.slot);
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
            parameter.mark_user_edited();
        }
    }
    fn get_parameter(&self, id: u32) -> f32 {
        self.exchange
            .parameter(id)
            .map_or(0.0, |parameter| single(parameter.get()))
    }
    fn apply_automation(&mut self, id: u32, value: f32) {
        if value.is_finite()
            && let Some(parameter) = self.exchange.parameter(id)
            && !parameter.is_user_edited()
        {
            parameter.set(f64::from(value).clamp(0.0, 1.0), 0);
        }
    }
    fn clear_automation(&mut self, _id: u32) {}
    fn clear_parameter_overrides(&mut self) {
        for parameter in &self.exchange.parameters {
            parameter.clear_user_edited();
        }
    }
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reported_latency_is_rounded_and_bounded() {
        assert_eq!(latency_frames(63.6), 64);
        assert_eq!(latency_frames(-5.0), 0);
        assert_eq!(latency_frames(f32::NAN), 0);
        assert_eq!(latency_frames(f32::INFINITY), 0);
        assert_eq!(latency_frames(9.0e9), 1_048_576);
    }

    #[test]
    fn key_slots_round_trip_channel_and_key() {
        assert_eq!(slot_key(key_slot(9, 60)), (9, 60));
        assert_eq!(key_slot(15, 127), KEY_SLOTS - 1);
        assert_eq!(seven_bit(0.5), 64);
        assert_eq!(seven_bit(4.0), 127);
        assert_eq!(seven_bit(f32::NAN), 0);
    }
}
