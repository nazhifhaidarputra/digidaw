//! Real-time event translation between the engine and a CLAP plugin.
//!
//! Everything here runs inside a processing block or a suspended parameter flush, so nothing
//! allocates once the queue exists: the input queue is bounded, and plugin output is read into
//! the parameter exchange as it arrives instead of being stored.

use std::sync::atomic::Ordering;

use clack_common::events::{
    EventFlags, EventHeader, Pckn, UnknownEvent,
    event_types::{
        MidiEvent as ClapMidiEvent, NoteExpressionEvent, NoteExpressionType as ClapExpression,
        NoteOffEvent, NoteOnEvent, ParamValueEvent, TransportEvent, TransportFlags,
    },
    io::{EventBuffer, InputEvents, OutputEventBuffer, TryPushError},
    spaces::CoreEventSpace,
};
use clack_common::utils::{BeatTime, ClapId, SecondsTime};
use clack_extensions::note_ports::{NoteDialect, NoteDialects};
use karbeat_host_api::{EDIT_BEGIN, EDIT_CHANGED, EDIT_END, ParameterExchange};
use karbeat_plugin_api::prelude::{MidiEvent, MidiMessage, NoteExpressionType, ProcessContext};

use crate::parameters::ClapParameter;

/// Largest number of events delivered to the plugin in one block.
pub(crate) const MAX_INPUT_EVENTS: usize = 512;
/// One slot per MIDI channel and key.
const KEY_SLOTS: usize = 16 * 128;
/// CLAP's wildcard for a note's port, channel, key, or ID.
const ANY: i16 = -1;

/// Events sent to the plugin in one block, with storage reserved up front.
pub(crate) struct InputQueue {
    buffer: EventBuffer,
    len: usize,
}

impl InputQueue {
    pub fn new() -> Self {
        Self {
            buffer: EventBuffer::with_capacity(MAX_INPUT_EVENTS),
            len: 0,
        }
    }

    pub fn clear(&mut self) {
        self.buffer.clear();
        self.len = 0;
    }

    /// Queues `event`, or returns `false` when the block's reserved capacity is used up.
    pub fn push<E: AsRef<UnknownEvent>>(&mut self, event: &E) -> bool {
        if self.len >= MAX_INPUT_EVENTS {
            return false;
        }
        self.buffer.push(event);
        self.len = self.len.saturating_add(1);
        true
    }

    /// Orders events by time; events at the same time keep the order they were queued in.
    pub fn sort(&mut self) {
        self.buffer.sort();
    }

    pub fn as_input(&self) -> InputEvents<'_> {
        self.buffer.as_input()
    }
}

/// How notes reach the plugin's first note input.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum NoteInput {
    /// CLAP note events, which carry note IDs for per-note expressions.
    Clap,
    /// MIDI 1.0 messages.
    Midi,
}

impl NoteInput {
    /// Picks the dialect the plugin prefers, then CLAP notes, then MIDI.
    pub fn choose(supported: NoteDialects, preferred: Option<NoteDialect>) -> Option<Self> {
        let clap = supported.supports(NoteDialect::Clap);
        let midi =
            supported.supports(NoteDialect::Midi) || supported.supports(NoteDialect::MidiMpe);
        match preferred {
            Some(NoteDialect::Clap) if clap => Some(Self::Clap),
            Some(NoteDialect::Midi | NoteDialect::MidiMpe) if midi => Some(Self::Midi),
            _ if clap => Some(Self::Clap),
            _ if midi => Some(Self::Midi),
            _ => None,
        }
    }
}

/// Converts engine notes and controllers to plugin events, remembering held notes so they can be
/// released after events were lost.
pub(crate) struct NoteSender {
    input: Option<NoteInput>,
    note_ids: [Option<u64>; KEY_SLOTS],
    active: [bool; KEY_SLOTS],
    /// Releases every held note at the start of the next block.
    pub recover: bool,
}

impl NoteSender {
    pub const fn new(input: Option<NoteInput>) -> Self {
        Self {
            input,
            note_ids: [None; KEY_SLOTS],
            active: [false; KEY_SLOTS],
            recover: false,
        }
    }

    /// Queues the block's notes and controllers, and reports whether all of them fit.
    pub fn queue(&mut self, queue: &mut InputQueue, events: &[MidiEvent], frames: usize) -> bool {
        let Some(input) = self.input else {
            self.recover = false;
            return true;
        };
        let mut delivered = true;
        if std::mem::take(&mut self.recover) {
            for slot in 0..KEY_SLOTS {
                if let Some(active) = self.active.get_mut(slot)
                    && std::mem::take(active)
                {
                    let (channel, key) = slot_key(slot);
                    delivered &= self.release(queue, input, 0, channel, key, None);
                }
            }
            self.note_ids.fill(None);
        }
        for event in events {
            if event.sample_offset >= frames {
                continue;
            }
            let time = u32::try_from(event.sample_offset).unwrap_or(0);
            delivered &= match &event.data {
                MidiMessage::NoteOn {
                    note_id,
                    channel,
                    key,
                    velocity,
                } if *channel < 16 && *key < 128 => {
                    let slot = key_slot(*channel, *key);
                    if let Some(active) = self.active.get_mut(slot) {
                        *active = true;
                    }
                    if let Some(id) = self.note_ids.get_mut(slot) {
                        *id = *note_id;
                    }
                    let velocity = (*velocity).min(127);
                    match input {
                        NoteInput::Clap => queue.push(&NoteOnEvent::new(
                            time,
                            note_pckn(*channel, *key, *note_id),
                            f64::from(velocity) / 127.0,
                        )),
                        NoteInput::Midi => {
                            queue.push(&midi(time, [0x90 | channel, *key, velocity]))
                        }
                    }
                }
                MidiMessage::NoteOff {
                    note_id,
                    channel,
                    key,
                } if *channel < 16 && *key < 128 => {
                    let slot = key_slot(*channel, *key);
                    if let Some(active) = self.active.get_mut(slot) {
                        *active = false;
                    }
                    let held = self.note_ids.get_mut(slot).and_then(Option::take);
                    self.release(queue, input, time, *channel, *key, note_id.or(held))
                }
                MidiMessage::ControlChange {
                    channel,
                    controller,
                    value,
                } if *channel < 16 && *controller < 128 => queue.push(&midi(
                    time,
                    [0xB0 | channel, *controller, (*value).min(127)],
                )),
                MidiMessage::PitchBend { channel, value } if *channel < 16 => {
                    let centered = i32::from(*value).saturating_add(8192).clamp(0, 16_383);
                    let low = u8::try_from(centered & 0x7F).unwrap_or(0);
                    let high = u8::try_from(centered >> 7).unwrap_or(0);
                    queue.push(&midi(time, [0xE0 | channel, low, high]))
                }
                MidiMessage::NoteExpression {
                    note_id,
                    expression,
                    value,
                } => self.expression(queue, input, time, *note_id, *expression, *value),
                _ => true,
            };
        }
        delivered
    }

    fn release(
        &self,
        queue: &mut InputQueue,
        input: NoteInput,
        time: u32,
        channel: u8,
        key: u8,
        note_id: Option<u64>,
    ) -> bool {
        match input {
            NoteInput::Clap => queue.push(&NoteOffEvent::new(
                time,
                note_pckn(channel, key, note_id),
                0.0,
            )),
            NoteInput::Midi => queue.push(&midi(time, [0x80 | channel, key, 0])),
        }
    }

    /// Sends a per-note expression to the held note it belongs to. MIDI 1.0 carries only
    /// pressure, as polyphonic key pressure.
    fn expression(
        &self,
        queue: &mut InputQueue,
        input: NoteInput,
        time: u32,
        note_id: u64,
        expression: NoteExpressionType,
        value: f32,
    ) -> bool {
        let Some(slot) = self.note_ids.iter().position(|id| *id == Some(note_id)) else {
            return true;
        };
        let (channel, key) = slot_key(slot);
        let normalized = if value.is_finite() {
            f64::from(value).clamp(0.0, 1.0)
        } else {
            return true;
        };
        match input {
            NoteInput::Clap => {
                let (kind, plain) = expression_value(expression, normalized);
                queue.push(&NoteExpressionEvent::new(
                    time,
                    note_pckn(channel, key, Some(note_id)),
                    kind,
                    plain,
                ))
            }
            NoteInput::Midi if expression == NoteExpressionType::Pressure => {
                let pressure = (normalized * 127.0).round().clamp(0.0, 127.0);
                queue.push(&midi(time, [0xA0 | channel, key, seven_bit(pressure)]))
            }
            NoteInput::Midi => true,
        }
    }
}

/// Maps an engine expression's normalized value to the CLAP expression and its plain range.
fn expression_value(expression: NoteExpressionType, normalized: f64) -> (ClapExpression, f64) {
    match expression {
        // CLAP volume is a linear gain up to four; a quarter of the range is unity, as in VST3.
        NoteExpressionType::Volume => (ClapExpression::Volume, normalized * 4.0),
        NoteExpressionType::Pan => (ClapExpression::Pan, normalized),
        // Semitones, centred on no change, over CLAP's ±120 semitone range.
        NoteExpressionType::Tuning => (ClapExpression::Tuning, (normalized - 0.5) * 240.0),
        NoteExpressionType::Vibrato => (ClapExpression::Vibrato, normalized),
        NoteExpressionType::Brightness => (ClapExpression::Brightness, normalized),
        NoteExpressionType::Pressure => (ClapExpression::Pressure, normalized),
    }
}

fn note_pckn(channel: u8, key: u8, note_id: Option<u64>) -> Pckn {
    let note_id = note_id.map_or(i32::from(ANY), |id| {
        i32::try_from(id & 0x7FFF_FFFF).unwrap_or(i32::from(ANY))
    });
    Pckn::from_raw(0, i16::from(channel), i16::from(key), note_id)
}

fn midi(time: u32, data: [u8; 3]) -> ClapMidiEvent {
    ClapMidiEvent::new(time, 0, data)
}

fn key_slot(channel: u8, key: u8) -> usize {
    usize::from(channel)
        .saturating_mul(128)
        .saturating_add(usize::from(key))
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
    reason = "the value is rounded and clamped to the seven-bit MIDI range first"
)]
fn seven_bit(value: f64) -> u8 {
    value as u8
}

/// Queues a parameter value at `time`, or returns `false` when the queue is full.
pub(crate) fn queue_value(queue: &mut InputQueue, time: u32, id: u32, plain: f64) -> bool {
    ClapId::from_raw(id)
        .is_none_or(|id| queue.push(&ParamValueEvent::new(time, id, Pckn::match_all(), plain)))
}

/// Queues edits the control side made since the last block, at the start of the block.
///
/// An edit that does not fit stays pending for the next block or flush.
pub(crate) fn queue_pending(
    queue: &mut InputQueue,
    exchange: &ParameterExchange,
    parameters: &[ClapParameter],
) -> bool {
    let mut delivered = true;
    for (parameter, shared) in parameters.iter().zip(&exchange.parameters) {
        if !shared.pending.load(Ordering::Acquire) {
            continue;
        }
        if parameter.read_only {
            shared.pending.store(false, Ordering::Release);
            continue;
        }
        if queue_value(queue, 0, parameter.id, parameter.to_plain(shared.get())) {
            shared.pending.store(false, Ordering::Release);
        } else {
            delivered = false;
        }
    }
    delivered
}

/// Queues the engine's sample-accurate automation and mirrors it into the exchange.
pub(crate) fn queue_automation(
    queue: &mut InputQueue,
    context: &ProcessContext,
    exchange: &ParameterExchange,
    parameters: &[ClapParameter],
    frames: usize,
) -> bool {
    let mut delivered = true;
    for change in context.param_changes {
        if change.sample_offset >= frames || !change.normalized_value.is_finite() {
            continue;
        }
        let Ok(position) = parameters.binary_search_by_key(&change.param_id, |p| p.id) else {
            continue;
        };
        let Some(parameter) = parameters.get(position).filter(|p| !p.read_only) else {
            continue;
        };
        let normalized = f64::from(change.normalized_value).clamp(0.0, 1.0);
        let time = u32::try_from(change.sample_offset).unwrap_or(0);
        delivered &= queue_value(queue, time, parameter.id, parameter.to_plain(normalized));
        if let Some(shared) = exchange.parameters.get(position) {
            shared.value.store(normalized.to_bits(), Ordering::Release);
        }
    }
    delivered
}

/// Describes the engine transport for one block.
pub(crate) fn transport(context: &ProcessContext) -> TransportEvent {
    let tempo = if context.bpm.is_finite() && context.bpm > 0.0 {
        context.bpm
    } else {
        120.0
    };
    let finite = |value: f64| if value.is_finite() { value } else { 0.0 };
    let beats_per_bar = f64::from(context.time_sig_numerator.max(1));
    let bar = finite(context.bar_position).floor();
    let beat = finite(context.beat_position);
    let mut flags = TransportFlags::HAS_TEMPO
        | TransportFlags::HAS_BEATS_TIMELINE
        | TransportFlags::HAS_SECONDS_TIMELINE
        | TransportFlags::HAS_TIME_SIGNATURE;
    if context.is_playing {
        flags |= TransportFlags::IS_PLAYING;
    }
    if context.is_recording {
        flags |= TransportFlags::IS_RECORDING;
    }
    let (loop_start, loop_end) = match (context.loop_start_beat, context.loop_end_beat) {
        (Some(start), Some(end)) if start.is_finite() && end.is_finite() && end > start => {
            flags |= TransportFlags::IS_LOOP_ACTIVE;
            (start, end)
        }
        _ => (0.0, 0.0),
    };
    let seconds = |beats: f64| SecondsTime::from_float(beats * 60.0 / tempo);
    TransportEvent {
        header: EventHeader::new_core(0, EventFlags::empty()),
        flags,
        song_pos_beats: BeatTime::from_float(beat),
        song_pos_seconds: SecondsTime::from_float(finite(context.project_time_seconds)),
        tempo,
        tempo_inc: 0.0,
        loop_start_beats: BeatTime::from_float(loop_start),
        loop_end_beats: BeatTime::from_float(loop_end),
        loop_start_seconds: seconds(loop_start),
        loop_end_seconds: seconds(loop_end),
        bar_start: BeatTime::from_float(
            beat - (finite(context.bar_position) - bar) * beats_per_bar,
        ),
        bar_number: whole(bar),
        time_signature_numerator: u16::from(context.time_sig_numerator.max(1)),
        time_signature_denominator: u16::from(context.time_sig_denominator.max(1)),
    }
}

#[allow(
    clippy::as_conversions,
    clippy::cast_possible_truncation,
    reason = "a floored bar number is clamped to the 32-bit range first"
)]
fn whole(value: f64) -> i32 {
    value.clamp(f64::from(i32::MIN), f64::from(i32::MAX)) as i32
}

/// Receives the plugin's output events and records parameter changes and gestures in the
/// exchange for the control owner. Other output is dropped.
pub(crate) struct ParameterOutput<'a> {
    pub exchange: &'a ParameterExchange,
    pub parameters: &'a [ClapParameter],
}

impl ParameterOutput<'_> {
    fn record(&self, id: Option<ClapId>, edit: u8, plain: Option<f64>) {
        let Some(id) = id else {
            return;
        };
        let Ok(position) = self.parameters.binary_search_by_key(&id.get(), |p| p.id) else {
            return;
        };
        let (Some(parameter), Some(shared)) = (
            self.parameters.get(position),
            self.exchange.parameters.get(position),
        ) else {
            return;
        };
        if let Some(plain) = plain {
            // The plugin already holds this value, so it is not sent back as pending.
            shared
                .value
                .store(parameter.to_normalized(plain).to_bits(), Ordering::Release);
        }
        if edit & (EDIT_BEGIN | EDIT_CHANGED) != 0 {
            shared.mark_user_edited();
        }
        shared.edits.fetch_or(edit, Ordering::Relaxed);
    }
}

impl OutputEventBuffer for ParameterOutput<'_> {
    fn try_push(&mut self, event: &UnknownEvent) -> Result<(), TryPushError> {
        match event.as_core_event() {
            Some(CoreEventSpace::ParamValue(event)) => {
                self.record(event.param_id(), EDIT_CHANGED, Some(event.value()));
            }
            Some(CoreEventSpace::ParamGestureBegin(event)) => {
                self.record(event.param_id(), EDIT_BEGIN, None);
            }
            Some(CoreEventSpace::ParamGestureEnd(event)) => {
                self.record(event.param_id(), EDIT_END, None);
            }
            _ => {}
        }
        Ok(())
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used, reason = "test fixtures inspect known events")]
mod tests {
    use super::*;
    use clack_common::events::{Event, io::OutputEvents};
    use karbeat_plugin_api::prelude::ProcessingMode;

    fn context<'a>(events: &'a [MidiEvent]) -> ProcessContext<'a> {
        ProcessContext {
            bpm: 120.0,
            time_sig_numerator: 3,
            time_sig_denominator: 4,
            is_playing: true,
            is_recording: false,
            mode: ProcessingMode::Realtime,
            project_time_seconds: 2.0,
            project_time_samples: 96_000,
            beat_position: 7.5,
            bar_position: 2.5,
            loop_start_beat: Some(4.0),
            loop_end_beat: Some(8.0),
            midi_events: events,
            param_changes: &[],
        }
    }

    fn core_events(queue: &InputQueue) -> Vec<String> {
        queue
            .as_input()
            .iter()
            .map(|event| match event.as_core_event() {
                Some(CoreEventSpace::NoteOn(note)) => {
                    let pckn = note.pckn();
                    format!(
                        "on {} {} {}",
                        note.time(),
                        pckn.raw_key(),
                        pckn.raw_note_id()
                    )
                }
                Some(CoreEventSpace::NoteOff(note)) => {
                    let pckn = note.pckn();
                    format!(
                        "off {} {} {}",
                        note.time(),
                        pckn.raw_key(),
                        pckn.raw_note_id()
                    )
                }
                Some(CoreEventSpace::Midi(midi)) => format!("midi {:?}", midi.data()),
                Some(CoreEventSpace::NoteExpression(expression)) => {
                    format!("expression {}", expression.value())
                }
                _ => "other".into(),
            })
            .collect()
    }

    fn note_on(offset: usize, key: u8, note_id: Option<u64>) -> MidiEvent {
        MidiEvent {
            sample_offset: offset,
            data: MidiMessage::NoteOn {
                note_id,
                channel: 0,
                key,
                velocity: 127,
            },
        }
    }

    #[test]
    fn note_inputs_prefer_the_plugins_dialect_then_clap_notes() {
        let both = NoteDialects::CLAP | NoteDialects::MIDI;
        assert_eq!(NoteInput::choose(both, None), Some(NoteInput::Clap));
        assert_eq!(
            NoteInput::choose(both, Some(NoteDialect::Midi)),
            Some(NoteInput::Midi)
        );
        assert_eq!(
            NoteInput::choose(NoteDialects::MIDI_MPE, Some(NoteDialect::Clap)),
            Some(NoteInput::Midi)
        );
        assert_eq!(NoteInput::choose(NoteDialects::MIDI2, None), None);
    }

    #[test]
    fn notes_keep_their_ids_and_late_events_are_dropped() {
        let mut queue = InputQueue::new();
        let mut sender = NoteSender::new(Some(NoteInput::Clap));
        let events = [
            note_on(9, 60, Some(5)),
            MidiEvent {
                sample_offset: 3,
                data: MidiMessage::NoteExpression {
                    note_id: 5,
                    expression: NoteExpressionType::Tuning,
                    value: 0.75,
                },
            },
            MidiEvent {
                sample_offset: 12,
                data: MidiMessage::NoteOff {
                    note_id: None,
                    channel: 0,
                    key: 60,
                },
            },
            note_on(64, 61, None),
        ];
        assert!(sender.queue(&mut queue, &events, 32));
        queue.sort();
        assert_eq!(
            core_events(&queue),
            ["expression 60", "on 9 60 5", "off 12 60 5"]
        );
    }

    #[test]
    fn midi_inputs_receive_notes_controllers_and_pressure_only() {
        let mut queue = InputQueue::new();
        let mut sender = NoteSender::new(Some(NoteInput::Midi));
        let events = [
            note_on(0, 60, Some(1)),
            MidiEvent {
                sample_offset: 1,
                data: MidiMessage::PitchBend {
                    channel: 2,
                    value: 8191,
                },
            },
            MidiEvent {
                sample_offset: 2,
                data: MidiMessage::NoteExpression {
                    note_id: 1,
                    expression: NoteExpressionType::Pressure,
                    value: 1.0,
                },
            },
            MidiEvent {
                sample_offset: 3,
                data: MidiMessage::NoteExpression {
                    note_id: 1,
                    expression: NoteExpressionType::Pan,
                    value: 1.0,
                },
            },
        ];
        assert!(sender.queue(&mut queue, &events, 8));
        assert_eq!(
            core_events(&queue),
            [
                "midi [144, 60, 127]",
                "midi [226, 127, 127]",
                "midi [160, 60, 127]"
            ]
        );
    }

    #[test]
    fn a_full_queue_reports_loss_and_held_notes_are_released_afterwards() {
        let mut queue = InputQueue::new();
        let mut sender = NoteSender::new(Some(NoteInput::Clap));
        let events = (0..=MAX_INPUT_EVENTS)
            .map(|index| note_on(0, u8::try_from(index % 128).unwrap(), None))
            .collect::<Vec<_>>();
        assert!(!sender.queue(&mut queue, &events, 1));
        sender.recover = true;
        queue.clear();
        assert!(sender.queue(&mut queue, &[], 1));
        assert_eq!(queue.as_input().len(), 128);
        assert!(
            core_events(&queue)
                .iter()
                .all(|event| event.starts_with("off 0"))
        );
    }

    #[test]
    fn transport_reports_tempo_position_and_loop() {
        let transport = transport(&context(&[]));
        assert!(
            transport
                .flags
                .contains(TransportFlags::IS_PLAYING | TransportFlags::IS_LOOP_ACTIVE)
        );
        assert!(!transport.flags.contains(TransportFlags::IS_RECORDING));
        assert!((transport.tempo - 120.0).abs() < f64::EPSILON);
        assert!((transport.song_pos_beats.to_float() - 7.5).abs() < 1.0e-6);
        assert!((transport.bar_start.to_float() - 6.0).abs() < 1.0e-6);
        assert_eq!(transport.bar_number, 2);
        assert!((transport.loop_end_seconds.to_float() - 4.0).abs() < 1.0e-6);
        assert_eq!(transport.time_signature_numerator, 3);
    }

    #[test]
    fn plugin_output_updates_values_and_gestures_without_marking_them_pending() {
        let parameter = ClapParameter {
            id: 4,
            name: "Gain".into(),
            module: String::new(),
            minimum: 0.0,
            maximum: 10.0,
            default: 0.0,
            stepped: false,
            automatable: true,
            read_only: false,
        };
        let exchange = ParameterExchange::new(&[(4, 0.0)]);
        let parameters = [parameter];
        let mut sink = ParameterOutput {
            exchange: &exchange,
            parameters: &parameters,
        };
        let mut output = OutputEvents::from_buffer(&mut sink);
        let id = ClapId::new(4);
        output
            .try_push(clack_common::events::event_types::ParamGestureBeginEvent::new(0, id))
            .unwrap();
        output
            .try_push(ParamValueEvent::new(0, id, Pckn::match_all(), 2.5))
            .unwrap();
        let shared = exchange.parameter(4).unwrap();
        assert!((shared.get() - 0.25).abs() < 1.0e-9);
        assert!(!shared.pending.load(Ordering::Acquire));
        assert_eq!(
            shared.edits.load(Ordering::Acquire),
            EDIT_BEGIN | EDIT_CHANGED
        );
        assert!(
            shared.is_user_edited(),
            "plugin-editor gestures must suspend modulation"
        );

        let mut queue = InputQueue::new();
        shared.set(0.5, 0);
        assert!(queue_pending(&mut queue, &exchange, &parameters));
        assert!(!shared.pending.load(Ordering::Acquire));
        assert_eq!(queue.as_input().len(), 1);
    }
}
