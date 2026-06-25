use std::{cell::Cell, sync::Arc};

pub struct MidiEvent {
    pub sample_offset: usize,
    pub data: MidiMessage,
}

pub enum MidiMessage {
    NoteOn { channel: u8, key: u8, velocity: u8 },
    NoteOff { channel: u8, key: u8 },
    ControlChange { channel: u8, controller: u8, value: u8 },
    PitchBend { channel: u8, value: i16 },
    
    /// Allows per-note modulation (e.g., individual pitch bend or pressure per key).
    NoteExpression {
        note_id: u32, // Unique ID to track overlapping notes
        expression: NoteExpressionType,
        value: f32,   // Normalized 0.0 to 1.0
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NoteExpressionType {
    Volume,
    Pan,
    Tuning,    // Per-note pitch bend
    Vibrato,
    Brightness,
    Pressure,
}

/// Represents a sample-accurate parameter change.
/// Instead of changing a parameter once per block, the engine passes an array 
/// of these so the plugin can apply the change at the exact `sample_offset`.
#[derive(Debug, Clone, Copy)]
pub struct ParamChange {
    pub param_id: u32,
    pub sample_offset: usize,
    /// The new normalized value of the parameter (0.0 to 1.0).
    pub normalized_value: f32,
}

/// Defines whether the plugin is running in real-time or offline.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProcessingMode {
    /// Real-time processing (e.g., live playback, recording).
    Realtime,
    /// Offline processing (e.g., bouncing, exporting, freeze).
    /// Plugins can use this to enable higher quality algorithms or disable lookahead.
    Offline,
}

/// Represents a single audio bus (e.g., Main Input, Sidechain, Multi-Out).
/// Audio is non-interleaved: `channel_data` contains a separate slice for each channel.
pub struct AudioBusBuffer<'a> {
    /// Slices of audio data, one for each channel. 
    /// e.g., for stereo: `&mut [&mut [f32], &mut [f32]]` (Left, Right)
    pub channel_data: &'a mut [&'a mut [f32]],
    /// True if the host/engine has determined this bus is completely silent.
    /// Plugins can skip processing to save CPU.
    pub is_silent: bool,
}

/// Aggregates all audio buses for a single process call.
/// This replaces the old interleaved `&mut [f32]` and `aux_buffer`.
pub struct AudioBuffers<'a> {
    pub main_inputs: &'a mut [AudioBusBuffer<'a>],
    pub main_outputs: &'a mut [AudioBusBuffer<'a>],
    pub aux_inputs: &'a mut [AudioBusBuffer<'a>],  // Sidechains
    pub aux_outputs: &'a mut [AudioBusBuffer<'a>], // Multi-outs
}

/// Configuration for a single audio bus (e.g., Main Input, Sidechain, Multi-Out).
/// Used by the host/engine to negotiate IO layouts with the plugin before processing.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BusConfig {
    /// The name of the bus (e.g., "Main", "Sidechain", "Out 2").
    pub name: String,
    /// The number of audio channels in this bus (e.g., 1 for Mono, 2 for Stereo).
    pub channel_count: usize,
    /// Whether this bus is optional. 
    /// For example, sidechain inputs are usually optional, while main outputs are not.
    pub is_optional: bool,
}


/// Tells the DAW how to route audio/MIDI to this plugin.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PluginCategory {
    /// Primarily generates audio from MIDI (Synths, Samplers)
    Instrument,
    /// Primarily processes incoming audio (Reverb, EQ, Compressors)
    Effect,
    /// Processes audio but also relies heavily on MIDI (Vocoders, Auto-Tune)
    MidiEffect,
}

#[derive(Clone)]
pub struct ProcessContext<'a> {
    pub bpm: f64,
    pub time_sig_numerator: u8,
    pub time_sig_denominator: u8,
    pub is_playing: bool,
    pub is_recording: bool,

    pub mode: ProcessingMode,

    /// Absolute time in seconds since the start of the project.
    pub project_time_seconds: f64,
    /// Absolute time in samples since the start of the project.
    pub project_time_samples: u64,
    /// Continuous beat position (e.g., 5.5 is exactly halfway through beat 5).
    pub beat_position: f64,
    /// Continuous bar position (e.g., 2.25 is exactly a quarter into bar 2).
    pub bar_position: f64,

        /// Loop points in beats (if looping is active).
    pub loop_start_beat: Option<f64>,
    pub loop_end_beat: Option<f64>,

    // --- Events & Automation ---
    pub midi_events: &'a [MidiEvent],
    
    /// Sample-accurate parameter changes that occur *within* this audio block.
    pub param_changes: &'a [ParamChange],
    
    // pub aux_buffer: Cell<Option<&'a [f32]>>,
}

/// Zero copy buffer used for FFI interoperability
#[derive(Clone, Debug)]
pub enum ZeroCopyBuffer {
    Float32(Arc<Box<[f32]>>),
    Uint8(Arc<Box<[u8]>>),
    Int32(Arc<Box<[i32]>>),
    Int8(Arc<Box<[i8]>>),
}

/// Avalable Shared Buffer Data Type
pub enum BufferDataType {
    Float32,
    Uint8,
    Int32,
    Int8,
}
