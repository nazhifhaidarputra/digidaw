use hashbrown::HashMap;
use indexmap::IndexMap;
use karbeat_plugin_api::types::MidiEvent;
use karbeat_plugin_api::types::ZeroCopyBuffer;
use karbeat_plugins::registry::PluginFactory;

use crate::{
    audio::{
        engine::{PlaybackMode, PluginTelemetrySnapshot},
        event::PluginTarget,
        render_state::{AudioAutomationLane, AudioGraphState},
    },
    core::project::{
        AutomationTarget, Clip, GeneratorId, ModulationLink, ModulationSource,
        mixer::{MixerChannelParams, RoutingConnection},
        plugin::AudioPlugin,
        track::{AudioTrack, audio_waveform::AudioWaveform, midi::Pattern},
    },
    shared::{AutomationId, ModulationId, PatternId, id::*},
};

/// Preallocated triple-buffer endpoints used to publish one plugin's telemetry without locking.
pub struct PreparedPluginTelemetry {
    /// Audio-thread writer retained beside the plugin instance.
    pub producer: triple_buffer::Input<crate::audio::engine::PluginTelemetrySnapshot>,
    /// UI-side reader transferred through [`TelemetryRegistration`].
    pub consumer: Box<triple_buffer::Output<crate::audio::engine::PluginTelemetrySnapshot>>,
}

impl PreparedPluginTelemetry {
    /// Creates a telemetry channel seeded from the plugin's current buffers and metadata.
    pub fn new(plugin: &dyn AudioPlugin) -> Self {
        let initial = crate::audio::engine::PluginTelemetrySnapshot::from_plugin(plugin);
        let (producer, consumer) = triple_buffer::triple_buffer(&initial);
        Self {
            producer,
            consumer: Box::new(consumer),
        }
    }
}

/// Commands transferred to the audio thread through the bounded command queue.
///
/// Variants carrying prepared plugins or control transfers move ownership into the engine;
/// graph and parameter variants mutate only audio-thread-owned render state.
pub enum AudioCommand {
    /// Installs all prepared hosted processors contained in a project snapshot.
    InstallHostedProject(karbeat_host::ControlTransfer<crate::audio::hosted_plugin::HostedProjectInstall>),
    /// Replaces active hosted endpoints with preconfigured instances after device changes.
    ReconfigureHostedPlugins(karbeat_host::ControlTransfer<crate::audio::hosted_plugin::HostedPluginReconfiguration>),
    /// Retires hosted processors and returns endpoint ownership to the native control owner.
    RemoveHostedPlugins(karbeat_host::ControlTransfer<crate::audio::hosted_plugin::HostedPluginRemoval>),
    /// Publishes one already prepared native endpoint; completion is acknowledged separately.
    InstallHostedPlugin(karbeat_host::ControlTransfer<crate::audio::hosted_plugin::HostedPluginInstall>),
    // =============================
    // Transport Command
    // =============================
    /// Plays an entire waveform once, independently of the project transport.
    PlayOneShot(AudioWaveform),
    /// Starts a bounded waveform preview.
    PlayPreview {
        /// Waveform retained by the preview voice.
        waveform: AudioWaveform,
        /// Maximum number of source frames the preview may render.
        max_frames: u64,
    },
    /// Stops and removes every active preview voice.
    StopAllPreviews,
    /// Set playback state (play/pause)
    SetPlaying(bool),
    /// Toggles transport playback and applies the supplied mode when starting.
    TogglePlayingWithPlaybackMode(PlaybackMode),
    /// Starts or stops isolated playback of one MIDI pattern through a generator.
    TogglePatternPlayback {
        /// Pattern rendered in isolation.
        pattern_id: PatternId,
        /// Generator receiving the pattern's MIDI events.
        generator_id: GeneratorId,
    },
    /// Set loop mode
    SetLooping(bool),
    /// Stop playback and reset playhead to 0
    StopAndReset,
    /// Moves the transport playhead to an absolute sample index.
    SetPlayhead(u32),
    /// Starts or stops a preview note outside normal pattern scheduling.
    PlayPreviewNote {
        /// MIDI note number.
        note_key: u8,
        /// Generator receiving the preview event.
        generator_id: GeneratorId,
        /// MIDI note-on velocity.
        velocity: u8,
        /// `true` sends note-on; `false` sends note-off.
        is_note_on: bool,
    },
    /// Queue a sample-accurate MIDI event for a generator.
    SendMidiEvent {
        /// Generator receiving the event.
        generator_id: GeneratorId,
        /// Event whose sample offset is interpreted by the audio block scheduler.
        event: MidiEvent,
    },
    /// Set BPM to the field0 value
    SetBPM(f32),
    /// Replaces the transport playback mode without toggling playback.
    SetPlaybackMode(PlaybackMode),

    /// Hot-swaps the active generator while pattern playback is running
    SwitchPatternGenerator(crate::shared::id::GeneratorId),

    // =========================================================================
    // Generator Plugin Commands
    // =========================================================================
    /// Add a generator plugin to the audio thread
    AddGenerator {
        /// Stable project generator identifier used by later commands.
        generator_id: GeneratorId,
        /// Track whose MIDI and mixer path owns the generator.
        track_id: TrackId,
        /// Internal plugin registry identifier.
        registry_id: u32,
        /// Factory invoked outside callback-time processing to construct the plugin.
        plugin_factory: PluginFactory,
    },
    /// Installs a plugin instance and preallocated telemetry already prepared off the audio thread.
    InstallGenerator {
        /// Stable project generator identifier.
        generator_id: GeneratorId,
        /// Owning track.
        track_id: TrackId,
        /// Internal plugin registry identifier.
        registry_id: u32,
        /// Prepared plugin endpoint transferred into audio-thread ownership.
        plugin: Box<dyn AudioPlugin>,
        /// Optional preallocated telemetry producer/consumer pair.
        telemetry: Option<PreparedPluginTelemetry>,
    },
    /// Remove a generator plugin from the audio thread
    RemoveGenerator {
        /// Generator removed from the render graph and telemetry registry.
        generator_id: GeneratorId,
    },
    /// Set a parameter on a target plugin
    SetParameter {
        /// Generator or effect receiving the parameter change.
        target: PluginTarget,
        /// Plugin parameter identifier.
        param_id: u32,
        /// Plain parameter value expected by the plugin abstraction.
        value: f32,
    },
    /// Update generator's associated track
    UpdateGeneratorTrack {
        /// Generator whose routing association changes.
        generator_id: GeneratorId,
        /// New owning track.
        track_id: TrackId,
    },
    /// Request parameter feedback for a generator (triggers ParameterSnapshot response)
    QueryGeneratorParameters {
        /// Generator whose current parameters should be copied into feedback.
        generator_id: GeneratorId,
    },

    // =========================================================================
    // Effect Plugin Commands
    // =========================================================================
    /// Add an effect to the target's effect chain
    AddEffect {
        /// Track, bus, or master effect chain receiving the plugin.
        target: EffectTarget,
        /// Stable project identifier assigned to the effect instance.
        effect_id: EffectId,
        /// Internal plugin registry identifier.
        registry_id: u32,
        /// Factory used to construct the effect away from callback-time processing.
        effect_factory: PluginFactory,
    },
    /// Installs a prepared effect and telemetry channel into the selected chain.
    InstallEffect {
        /// Track, bus, or master effect chain receiving the plugin.
        target: EffectTarget,
        /// Stable project effect identifier.
        effect_id: EffectId,
        /// Internal plugin registry identifier.
        registry_id: u32,
        /// Prepared effect endpoint transferred into audio-thread ownership.
        plugin: Box<dyn AudioPlugin>,
        /// Optional preallocated telemetry producer/consumer pair.
        telemetry: Option<PreparedPluginTelemetry>,
    },
    /// Remove an effect from the target's effect chain
    RemoveEffect {
        /// Effect chain containing the instance.
        target: EffectTarget,
        /// Effect removed from the chain.
        effect_id: EffectId,
    },
    /// Move an effect to a new index in the target's effect chain.
    MoveEffect {
        /// Effect chain whose order changes.
        target: EffectTarget,
        /// Effect moved within the chain.
        effect_id: EffectId,
        /// Destination zero-based chain index, clamped or validated by the handler.
        new_position: usize,
    },
    /// Enables or bypasses an effect slot without removing it from the chain.
    SetEffectBypass {
        /// Effect chain containing the instance.
        target: EffectTarget,
        /// Effect whose bypass state changes.
        effect_id: EffectId,
        /// `true` passes audio through the slot untouched.
        bypass: bool,
    },

    /// Request parameter feedback for a target effect (triggers EffectParameterSnapshot response)
    QueryEffectParameters {
        /// Effect chain containing the instance.
        target: EffectTarget,
        /// Effect whose current parameters should be returned.
        effect_id: EffectId,
    },

    /// Request a ZeroCopyBuffer from a specific plugin
    QueryZeroCopyBuffer {
        /// Plugin exposing the named telemetry buffer.
        target: PluginTarget,
        /// Plugin-defined buffer name.
        name: String,
        /// Correlation identifier copied into the feedback response.
        request_id: u32,
    },

    // =====================================================
    // Mixer Channel Parameter Commands
    // =====================================================
    /// Set a single DSP parameter on a mixer channel (track, bus, or master).
    /// The audio thread is the sole owner of these values; AppState is only
    /// written back during save_project.
    SetMixerChannelParameter {
        /// Track, bus, or master channel to mutate.
        target: MixerChannelTarget,
        /// Parameter mutation applied to the channel's audio-thread values.
        param: MixerChannelParams,
    },

    /// Request a full snapshot of a mixer channel's current DSP state.
    /// The audio thread responds with AudioFeedback::MixerChannelSnapshot.
    QueryMixerChannel {
        /// Track, bus, or master channel to snapshot.
        target: MixerChannelTarget,
        /// Optional correlation identifier copied into the response.
        request_id: Option<u32>,
    },

    // =====================================================
    // Bus Commands
    // =====================================================
    /// Create a new mixer bus on the audio thread
    AddBus {
        /// Stable project bus identifier.
        bus_id: BusId,
        /// Display name retained in audio-thread bus state.
        name: String,
    },
    /// Remove a mixer bus from the audio thread
    RemoveBus {
        /// Bus removed from routing, effects, and mixer state.
        bus_id: BusId,
    },

    /// Update the routing matrix directly on the audio thread.
    /// This bypasses the triple-buffer; routing is owned by the ring-buffer path.
    UpdateRouting {
        /// Complete routing connection list replacing the current matrix.
        routing: Box<[RoutingConnection]>,
    },
    /// Prepare all plugins and seed the audio thread's mixer channel state.
    /// Called on project load / new project to fully hydrate the audio thread.
    HydratePlugin {
        /// Prepared effects grouped by track and effect identifier.
        track_effects: IndexMap<TrackId, IndexMap<EffectId, (u32, Box<dyn AudioPlugin>, PreparedPluginTelemetry)>>,
        /// Prepared effects in master-chain order.
        master_effects: IndexMap<EffectId, (u32, Box<dyn AudioPlugin>, PreparedPluginTelemetry)>,
        /// Prepared effects grouped by bus and effect identifier.
        bus_effects: IndexMap<BusId, IndexMap<EffectId, (u32, Box<dyn AudioPlugin>, PreparedPluginTelemetry)>>,
        /// Prepared generator plugins keyed by project generator identifier.
        generators: IndexMap<GeneratorId, (u32, Box<dyn AudioPlugin>, PreparedPluginTelemetry)>,
        /// Initial DSP values for every track channel (volume, pan, mute, solo, inverted_phase)
        track_channels: IndexMap<TrackId, MixerChannelSeed>,
        /// Initial DSP values for every bus channel
        bus_channels: IndexMap<BusId, MixerChannelSeed>,
        /// Initial DSP values for the master channel
        master_channel: MixerChannelSeed,
    },
    /// Enables or disables metronome rendering.
    SetMetronomeActive(bool),

    /// Send command to execute command from real-time plugin state. to use this
    /// effectively, use a message passing channel for real-time data streaming
    ExecutePluginCommand {
        /// Plugin receiving the command.
        target: PluginTarget,
        /// Plugin-defined command name.
        command: String,
        /// Structured plugin-defined command payload.
        payload: serde_json::Value,
        /// Correlation identifier copied into command feedback.
        request_id: u32,
    },

    //////////////////////////////////////////
    // Load and Save related commands
    /////////////////////////////////////////
    /// Tell a specific plugin to overwrite its internal state
    SetPluginState {
        /// Plugin whose opaque state should be replaced.
        target: PluginTarget,
        /// Plugin-defined serialized state bytes.
        state: Vec<u8>,
    },

    /// Ask the engine to provide the latest state of a specific plugin
    QueryPluginState {
        /// Plugin whose opaque state should be captured.
        target: PluginTarget,
        /// Correlation identifier copied into state feedback.
        request_id: u32, // To track the response in the UI
    },

    /// Request the read-only live-engine state needed to construct an offline renderer.
    QueryAudioExportSnapshot {
        /// One-use channel receiving the snapshot directly from command handling.
        response_tx: std::sync::mpsc::Sender<crate::audio::engine::AudioExportSnapshot>,
    },

    // =========================================================================
    // Granular Graph-State Commands (replace the old triple-buffer path)
    // =========================================================================
    /// Update the track + pattern snapshot on the audio thread.
    /// Sent whenever tracks are added/removed, clips are edited, patterns
    /// are modified, or BPM changes the max_sample_index.
    UpdateTrackGraph {
        /// Ordered track snapshots used by rendering and routing lookup.
        tracks: Box<[AudioTrack]>,
        /// Clip pool referenced by track clip identifiers.
        clips: HashMap<ClipId, Clip>,
        /// MIDI pattern pool referenced by MIDI clips.
        patterns: HashMap<PatternId, Pattern>,
    },

    /// Add or replace a single automation lane on the audio thread.
    /// Sent on add/remove automation point, lane enable toggle, or lane metadata update.
    UpdateAutomationLane {
        /// Stable lane identifier used in the render graph.
        id: AutomationId,
        /// Fully rebuilt audio-thread automation lane.
        lane: AudioAutomationLane,
    },

    /// Remove an automation lane from the audio thread's local graph.
    RemoveAutomationLane {
        /// Lane removed from audio-thread automation evaluation.
        id: AutomationId,
    },

    /// Update audio engine config (sample_rate, buffer_size).
    /// Sent when the audio device is reconfigured at runtime.
    UpdateAudioConfig {
        /// New sample rate, or `None` to retain the current value.
        sample_rate: Option<u32>,
        /// New maximum callback buffer size, or `None` to retain the current value.
        buffer_size: Option<usize>,
    },

    /// Atomically replace the full audio graph state on the engine.
    /// Used exclusively for undo/redo where an arbitrary subset of sub-graphs
    /// may have changed and enumerating diffs would be impractical.
    ReplaceFullGraph {
        /// Complete immutable graph snapshot replacing all current graph sub-state.
        graph: AudioGraphState,
    },

    /// Spawn a new generator in the DSP thread (e.g., an LFO)
    AddModulationSource {
        /// Stable modulation source identifier.
        id: ModulationId,
        /// Source oscillator or generator configuration.
        source: ModulationSource,
    },
    /// Removes a modulation source and links that depend on it.
    RemoveModulationSource(ModulationId),

    /// Plug a cable from a Generator to a Target
    AddModulationLink {
        /// Stable link identifier.
        id: ModulationLinkId,
        /// Source-to-parameter connection evaluated by the modulation engine.
        link: ModulationLink,
    },
    /// Changes the signed modulation amount for one existing link.
    UpdateModulationLinkDepth {
        /// Link whose amount changes.
        id: ModulationLinkId,
        /// New signed modulation depth.
        depth: f32,
    },
    /// Removes one modulation link while retaining its source.
    RemoveModulationLink(ModulationLinkId),

    /// Automation tracker
    BeginEdit {
        /// Parameter target whose manual-edit gesture begins.
        target: AutomationTarget,
    },
    /// Ends a manual automation edit gesture.
    EndEdit {
        /// Parameter target whose manual-edit gesture ends.
        target: AutomationTarget,
    },

    // =========== TELEMETRY RELATED =====================
    /// Enables selected named telemetry buffers for one plugin.
    SetPluginTelemetrySubscription {
        /// Plugin whose telemetry selection changes.
        target: PluginTarget,
        /// Plugin-defined buffer names to publish.
        buffers: Vec<String>,
        /// Whether to subscribe to or clear the selection.
        active: bool,
    },
    /// Enables or disables periodic mixer-channel snapshots.
    SetMixerTelemetrySubscription {
        /// New mixer telemetry subscription state.
        active: bool,
    },
    /// Releases an automation target from a suspended manual edit.
    ResumeAutomation {
        /// Target returned to automatic evaluation.
        target: AutomationTarget,
    },
}

// ============================================================================
// Audio → UI Feedback Messages
// ============================================================================

// ======================================
// MixerChannelTarget
// ======================================

/// Identifies which mixer channel a command or snapshot applies to.
#[derive(Clone, Debug, PartialEq)]
pub enum MixerChannelTarget {
    /// Mixer channel owned by a project track.
    Track(TrackId),
    /// Auxiliary mixer bus channel.
    Bus(BusId),
    /// Final master output channel.
    Master,
}

/// Lightweight plain-value snapshot used to seed the audio thread's mixer
/// state on project load, and written back to AppState during save_project.
#[derive(Clone, Debug, Default)]
pub struct MixerChannelSeed {
    /// Fader gain in decibels.
    pub volume: f32,
    /// Stereo pan in the normalized `[-1, 1]` domain.
    pub pan: f32,
    /// Whether the channel starts muted.
    pub mute: bool,
    /// Whether the channel starts soloed.
    pub solo: bool,
    /// Whether the channel starts with polarity inverted.
    pub inverted_phase: bool,
}

// ======================================
// EffectTarget
// ======================================

/// Specifies the location of an effect to ensure precise UI syncing
#[derive(Clone, Debug)]
pub enum EffectTarget {
    /// Effect chain belonging to a track.
    Track(TrackId),
    /// Master output effect chain.
    Master,
    /// Effect chain belonging to an auxiliary bus.
    Bus(BusId),
}

/// Parameter value update from a generator to the UI
#[derive(Clone, Debug)]
pub struct GeneratorParameterUpdate {
    /// Generator that emitted the value.
    pub generator_id: GeneratorId,
    /// Plugin parameter identifier.
    pub param_id: u32,
    /// Current plain parameter value.
    pub value: f32,
}

/// Full parameter snapshot for a generator (response to QueryGeneratorParameters)
#[derive(Clone, Debug)]
pub struct GeneratorParameterSnapshot {
    /// Generator represented by the snapshot.
    pub generator_id: GeneratorId,
    /// `(parameter_id, current_value)` pairs captured by the engine.
    pub parameters: Vec<(u32, f32)>, // (param_id, value) pairs
}

/// Parameter value update from an effect to the UI
#[derive(Clone, Debug)]
pub struct EffectParameterUpdate {
    /// Effect chain containing the plugin.
    pub target: EffectTarget,
    /// Effect that emitted the value.
    pub effect_id: EffectId,
    /// Plugin parameter identifier.
    pub param_id: u32,
    /// Current plain parameter value.
    pub value: f32,
}

/// Full parameter snapshot for an effect (response to Query...EffectParameters)
#[derive(Clone, Debug)]
pub struct EffectParameterSnapshot {
    /// Effect chain containing the plugin.
    pub target: EffectTarget,
    /// Effect represented by the snapshot.
    pub effect_id: EffectId,
    /// `(parameter_id, current_value)` pairs captured by the engine.
    pub parameters: Vec<(u32, f32)>, // (param_id, value) pairs
}

/// Full DSP state snapshot of a single mixer channel.
/// Sent by the audio thread in response to QueryMixerChannel.
#[derive(Clone, Debug)]
pub struct MixerChannelSnapshot {
    /// Channel represented by this snapshot.
    pub target: MixerChannelTarget,
    /// Optional query correlation identifier; periodic telemetry uses `None`.
    pub request_id: Option<u32>,
    /// Post-effects, post-fader peak magnitude in linear amplitude.
    pub magnitude: f32,
    /// Fader gain in decibels.
    pub volume: f32,
    /// Stereo pan in the normalized `[-1, 1]` domain.
    pub pan: f32,
    /// Current mute state.
    pub mute: bool,
    /// Current solo state.
    pub solo: bool,
    /// Current polarity-inversion state.
    pub inverted_phase: bool,
}

/// Messages from audio thread to UI thread
#[derive(Clone, Debug)]
pub enum AudioFeedback {
    // Generator Feedback
    /// Single parameter changed (e.g., automation moved it)
    GeneratorParameterChanged(GeneratorParameterUpdate),
    /// Full parameter snapshot in response to query
    GeneratorParameterSnapshot(GeneratorParameterSnapshot),

    // Effect Feedback
    /// Single parameter changed on an effect (e.g., automation moved it)
    EffectParameterChanged(EffectParameterUpdate),
    /// Full parameter snapshot for an effect in response to query
    EffectParameterSnapshot(EffectParameterSnapshot),

    // ======================================
    // Mixer Channel Feedback
    // ======================================
    /// Full DSP state snapshot for a mixer channel (response to QueryMixerChannel)
    MixerChannelSnapshot(MixerChannelSnapshot),

    // Command Response Feedback
    PluginCommandResponse {
        /// Correlation identifier from `ExecutePluginCommand`.
        request_id: u32,
        /// Plugin-defined structured response.
        response: serde_json::Value,
    },

    /// The engine returning the requested state blob
    PluginStateSnapshot {
        /// Plugin represented by the captured state.
        target: PluginTarget,
        /// Plugin-defined serialized state bytes.
        state: Vec<u8>,
        /// Correlation identifier from `QueryPluginState`.
        request_id: u32,
        /// Native host handle when the target is an externally hosted plugin.
        host_instance: Option<karbeat_host::HostInstanceId>,
    },

    /// Response to a named zero-copy telemetry buffer query.
    ZeroCopyBufferResponse {
        /// Correlation identifier from the query.
        request_id: u32,
        /// Requested buffer, or `None` when the plugin did not expose it.
        buffer: Option<ZeroCopyBuffer>,
    },
}

// ============================================================
// Telemetry consumer registration — dedicated mpsc channel
// ============================================================

/// Messages sent from the audio thread to `DawContext` via a dedicated
/// `std::sync::mpsc` channel to register/unregister per-plugin telemetry consumers.
///
/// These travel on a **separate** channel from `AudioFeedback` so that
/// `AudioFeedback` can remain `Clone + Debug` and be processed on the
/// background feedback-stream thread without issue.
pub enum TelemetryRegistration {
    /// A plugin was added — hand the UI-side consumer over to `DawContext`.
    Registered {
        /// Plugin associated with the telemetry consumer.
        target: PluginTarget,
        /// UI-side triple-buffer output receiving published snapshots.
        consumer: Box<triple_buffer::Output<PluginTelemetrySnapshot>>,
    },
    /// A plugin was removed — `DawContext` should drop the corresponding consumer.
    Removed {
        /// Plugin whose telemetry consumer should be dropped.
        target: PluginTarget,
    },
    /// `HydratePlugin` completed — replace **all** consumers at once.
    BatchRegistered {
        /// Complete replacement map produced during project hydration.
        consumers: HashMap<PluginTarget, Box<triple_buffer::Output<PluginTelemetrySnapshot>>>,
    },
}
