use std::{collections::HashMap, sync::Arc};

use flutter_rust_bridge::frb;
use jiff::Timestamp;
use karbeat_core::audio::exporter::{ExportRange, RenderOptions, RenderPurpose, TailHandling};
use karbeat_core::audio::writer::{
    AudioExportConfig, BitDepth, flac::FlacAudioWriterConfig, ogg::OggOpusAudioWriterConfig,
    wav::WavAudioWriterConfig,
};
use karbeat_core::context::DawContext as CoreDawContext;
use karbeat_core::core::file_manager::audio_loader::AudioLoader;
use karbeat_core::core::project::{
    ApplicationState, CoverArt, CoverImage, EnvelopeCursor, EnvelopePoint, Fade, GainEnvelope,
    PluginInstance, audio_waveform::AudioSampleMode,
};
use karbeat_core::core::project::{
    AudioHardwareConfig, DawSource, ProjectMetadata,
    clip::Clip,
    generator::{GeneratorInstance, GeneratorInstanceType},
    track::{AudioTrack, TrackType, audio_waveform::AudioWaveform},
    transport::TransportState,
};
use karbeat_core_api::{
    audio_waveform_api, bounce_api,
    jobs::{JobClass, JobContext, JobKind, JobSpec, JobTarget},
    project_api, track_api,
};
use karbeat_utils::types::BipolarF64;
use serde::Serialize;

use crate::api::automation::AutomationCurveTypeDto;
use crate::api::context::DawSessionInner;
use crate::api::jobs::run_job;
use crate::api::waveform::WaveformHandle;
use crate::frb_generated::StreamSink;

/// Shared bridge handle whose inner guards control access to the core DAW state.
#[frb(opaque)]
#[derive(Clone)]
pub struct DawContext {
    pub(crate) inner: Arc<DawSessionInner>,
}

pub enum UiTrackType {
    Audio,
    Midi,
    Automation,
}

pub struct UiApplicationState {
    pub metadata: UiProjectMetadata,
    pub transport: UiTransportState,
    pub hardware_config: UiAudioHardwareConfig,
    pub tracks: HashMap<u64, UiTrack>,
    pub generators: HashMap<u64, UiGeneratorInstance>,
    pub patterns: HashMap<u64, crate::api::pattern::UiPattern>,
    pub mixer: crate::api::mixer::UiMixerState,
    pub audio_sources: HashMap<u64, AudioWaveformUiForSourceList>,
    pub timeline: crate::api::timeline::UiTimelineState,
}

impl From<ApplicationState> for UiApplicationState {
    fn from(value: ApplicationState) -> Self {
        let tracks: HashMap<u64, UiTrack> = value
            .tracks
            .iter()
            .map(|(id, track)| (id.to_u64(), UiTrack::from_track(track, &value)))
            .collect();

        let generators: HashMap<u64, UiGeneratorInstance> = value
            .generator_pool
            .iter()
            .map(|(id, generator)| (id.to_u64(), UiGeneratorInstance::from(generator)))
            .collect();

        let patterns: HashMap<u64, crate::api::pattern::UiPattern> = value
            .pattern_pool
            .iter()
            .map(|(id, pat)| (id.to_u64(), crate::api::pattern::UiPattern::from(pat)))
            .collect();

        let audio_sources: HashMap<u64, AudioWaveformUiForSourceList> = value
            .asset_library
            .source_map
            .iter()
            .map(|(id, source)| {
                (
                    id.to_u64(),
                    AudioWaveformUiForSourceList::from(source.as_ref()),
                )
            })
            .collect();

        Self {
            metadata: UiProjectMetadata::from(value.metadata),
            transport: UiTransportState::from(value.transport),
            hardware_config: UiAudioHardwareConfig::from(&value.audio_config),
            tracks,
            generators,
            patterns,
            mixer: crate::api::mixer::UiMixerState::from(&value.mixer),
            audio_sources,
            timeline: crate::api::timeline::UiTimelineState::from(&value.timeline),
        }
    }
}

impl From<&UiTrackType> for TrackType {
    fn from(value: &UiTrackType) -> Self {
        match value {
            UiTrackType::Audio => TrackType::Audio,
            UiTrackType::Midi => TrackType::Midi,
            UiTrackType::Automation => TrackType::Automation,
        }
    }
}

impl From<TrackType> for UiTrackType {
    fn from(value: TrackType) -> Self {
        match value {
            TrackType::Audio => UiTrackType::Audio,
            TrackType::Midi => UiTrackType::Midi,
            TrackType::Automation => UiTrackType::Automation,
        }
    }
}

#[frb(dart_metadata=("freezed"))]
pub struct UiTrack {
    pub id: u64,
    pub name: String,
    pub color: String,
    pub track_type: UiTrackType,
    pub clips: Vec<UiClip>,
    pub generator_id: Option<u64>,
    pub order_idx: usize,
}

#[derive(Clone, Default)]
#[frb(dart_metadata=("freezed"))]
pub struct UiProjectMetadata {
    pub name: String,
    pub author: String,
    pub description: String,
    pub genre: String,
    pub version: String,
    pub created_at: String,
    /// Absolute path of the square cover image file, when the project has one
    pub cover_path: Option<String>,
}

impl From<ProjectMetadata> for UiProjectMetadata {
    fn from(m: ProjectMetadata) -> Self {
        Self {
            name: m.name,
            author: m.author,
            description: m.description,
            genre: m.genre,
            version: m.version,
            created_at: m.created_at.to_string(),
            cover_path: m
                .cover
                .map(|cover| cover.path.to_string_lossy().into_owned()),
        }
    }
}

impl From<UiProjectMetadata> for ProjectMetadata {
    fn from(m: UiProjectMetadata) -> Self {
        Self {
            name: m.name,
            author: m.author,
            description: m.description,
            genre: m.genre,
            version: m.version,
            created_at: m
                .created_at
                .parse::<Timestamp>()
                .unwrap_or_else(|_| Timestamp::now()),
            cover: m.cover_path.map(CoverImage::new),
        }
    }
}

#[frb(dart_metadata=("freezed"))]
pub struct UiAudioHardwareConfig {
    pub selected_input_device: String,
    pub selected_output_device: String,
    pub sample_rate: u32,
    pub buffer_size: u32,
    pub cpu_load: f32,
}

impl From<&AudioHardwareConfig> for UiAudioHardwareConfig {
    fn from(c: &AudioHardwareConfig) -> Self {
        Self {
            selected_input_device: c.selected_input_device.clone(),
            selected_output_device: c.selected_output_device.clone(),
            sample_rate: c.sample_rate,
            buffer_size: c.buffer_size,
            cpu_load: c.cpu_load,
        }
    }
}

impl From<UiAudioHardwareConfig> for AudioHardwareConfig {
    fn from(c: UiAudioHardwareConfig) -> Self {
        Self {
            selected_input_device: c.selected_input_device,
            selected_output_device: c.selected_output_device,
            sample_rate: c.sample_rate,
            buffer_size: c.buffer_size,
            cpu_load: c.cpu_load,
        }
    }
}

#[derive(Default, Clone)]
#[frb(dart_metadata=("freezed"))]
pub struct UiTransportState {
    pub bpm: f32,
    pub time_signature: (u8, u8),
}

impl From<TransportState> for UiTransportState {
    fn from(s: TransportState) -> Self {
        Self {
            bpm: s.bpm,
            time_signature: s.time_signature,
        }
    }
}

impl From<UiTransportState> for TransportState {
    fn from(s: UiTransportState) -> Self {
        Self {
            bpm: s.bpm,
            time_signature: s.time_signature,
        }
    }
}

impl UiTrack {
    #[frb(ignore)]
    pub fn from_track(value: &AudioTrack, state: &ApplicationState) -> Self {
        let generator_id = value
            .generator
            .as_ref()
            .map(|gen_instance| gen_instance.id.to_u64());
        Self {
            id: value.id.to_u64(),
            name: value.name.clone(),
            color: value.color.to_string(),
            track_type: value.track_type.clone().into(),
            clips: value
                .clips_to_vec(&state.clips_pool)
                .iter()
                .map(|c| UiClip::from(c))
                .collect(),
            generator_id,
            order_idx: value.order_idx,
        }
    }
}

#[frb(sync)]
pub fn project_metadata_new() -> UiProjectMetadata {
    UiProjectMetadata::default()
}

#[frb(sync)]
pub fn audio_hardware_config_new() -> UiAudioHardwareConfig {
    UiAudioHardwareConfig::from(&AudioHardwareConfig::default())
}

#[frb(sync)]
pub fn audio_hardware_config_new_with_param(
    selected_input_device: String,
    selected_output_device: String,
    sample_rate: u32,
    buffer_size: u32,
    cpu_load: f32,
) -> UiAudioHardwareConfig {
    UiAudioHardwareConfig {
        selected_input_device,
        selected_output_device,
        sample_rate,
        buffer_size,
        cpu_load,
    }
}

#[frb(sync)]
pub fn transport_state_new() -> UiTransportState {
    UiTransportState::default()
}

#[frb(sync)]
pub fn transport_state_new_with_param(bpm: f32, time_signature: (u8, u8)) -> UiTransportState {
    UiTransportState {
        bpm,
        time_signature,
    }
}

#[derive(Clone)]
#[frb(dart_metadata=("freezed"))]
pub struct UiClip {
    pub name: String,
    pub id: u64,
    /// Timeline placement in ticks.
    pub start_time: u64,
    pub source: UiClipSource,
    /// Offset from source content in samples for audio, ticks otherwise.
    pub offset_start: u64,
    /// Loop length in samples for audio, ticks otherwise.
    pub loop_length: u64,
    /// True when loop length and source offset are raw samples.
    pub is_sample_based: bool,
    /// Audio clip gain envelope stacked on the waveform envelope; `None` leaves audio untouched.
    pub envelope: Option<UiGainEnvelope>,
}

/// A fade at one edge of a waveform or clip.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiFade {
    /// Length in samples; zero disables the fade.
    pub length: u32,
    pub curve_type: AutomationCurveTypeDto,
    /// Bipolar tension, -1.0 to 1.0.
    pub tension: f64,
}

/// One gain breakpoint of a gain envelope.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiEnvelopePoint {
    /// Source frames from the trim start (waveform envelope) or clip content samples in the unit
    /// of `offset_start` (clip envelope).
    pub position: u64,
    /// Linear gain, 0.0 to 2.0.
    pub gain: f32,
    /// Curve toward the next point.
    pub curve_type: AutomationCurveTypeDto,
    /// Bipolar tension of the curve toward the next point.
    pub tension: f64,
}

/// Fades, crossfade, and gain points of a waveform or audio clip.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiGainEnvelope {
    pub fade_in: UiFade,
    pub fade_out: UiFade,
    /// Equal-power crossfade length in samples: the loop crossfade on a waveform, the crossfade
    /// with overlapping neighbours on a clip.
    pub crossfade: u32,
    /// Gain points sorted by position.
    pub points: Vec<UiEnvelopePoint>,
}

/// Samples the gain of an envelope at `positions`, with the code the audio engine plays.
///
/// `positions` are in the envelope's own unit (see [`UiEnvelopePoint::position`]);
/// `content_start` and `content_length` locate the content the fades are measured against.
/// The crossfade is not part of the gain and is drawn separately.
#[frb(sync)]
pub fn sample_gain_envelope(
    envelope: UiGainEnvelope,
    content_start: u64,
    content_length: u64,
    positions: Vec<f64>,
) -> Vec<f32> {
    let envelope = GainEnvelope::from(envelope);
    let mut cursor = EnvelopeCursor::default();
    positions
        .into_iter()
        .map(|position| {
            let position = envelope_position(position);
            let elapsed = position.saturating_sub(content_start);
            envelope.fade_gain(elapsed, content_length) * envelope.point_gain(position, &mut cursor)
        })
        .collect()
}

/// Gain of a fade at normalized position `t`, rising from silence (0.0) to unity (1.0).
#[frb(sync)]
pub fn fade_gain_at(fade: UiFade, t: f64) -> f32 {
    Fade::from(fade).gain_at(t)
}

/// Rounds a drawing position to the envelope's whole-sample unit.
#[allow(
    clippy::as_conversions,
    reason = "float-to-int `as` saturates, so off-content positions clamp to the edges"
)]
fn envelope_position(position: f64) -> u64 {
    position.round() as u64
}

/// How a waveform's playback responds to tempo.
#[derive(Clone, Copy, Debug, Serialize)]
pub enum UiAudioSampleMode {
    Default,
    Stretch,
    Resampled,
}

impl From<UiAudioSampleMode> for AudioSampleMode {
    fn from(value: UiAudioSampleMode) -> Self {
        match value {
            UiAudioSampleMode::Default => Self::Default,
            UiAudioSampleMode::Stretch => Self::Stretch,
            UiAudioSampleMode::Resampled => Self::Resampled,
        }
    }
}

impl From<AudioSampleMode> for UiAudioSampleMode {
    fn from(value: AudioSampleMode) -> Self {
        match value {
            AudioSampleMode::Default => Self::Default,
            AudioSampleMode::Stretch => Self::Stretch,
            AudioSampleMode::Resampled => Self::Resampled,
        }
    }
}

impl From<&Fade> for UiFade {
    fn from(value: &Fade) -> Self {
        Self {
            length: value.length,
            curve_type: value.curve_type.into(),
            tension: value.tension.get(),
        }
    }
}

impl From<UiFade> for Fade {
    fn from(value: UiFade) -> Self {
        Self {
            length: value.length,
            curve_type: value.curve_type.into(),
            tension: BipolarF64::new(value.tension),
        }
    }
}

impl From<&GainEnvelope> for UiGainEnvelope {
    fn from(value: &GainEnvelope) -> Self {
        Self {
            fade_in: UiFade::from(&value.fade_in),
            fade_out: UiFade::from(&value.fade_out),
            crossfade: value.crossfade,
            points: value
                .points
                .iter()
                .map(|point| UiEnvelopePoint {
                    position: point.position,
                    gain: point.gain,
                    curve_type: point.curve_type.into(),
                    tension: point.tension.get(),
                })
                .collect(),
        }
    }
}

impl From<UiGainEnvelope> for GainEnvelope {
    fn from(value: UiGainEnvelope) -> Self {
        Self {
            fade_in: value.fade_in.into(),
            fade_out: value.fade_out.into(),
            crossfade: value.crossfade,
            points: value
                .points
                .into_iter()
                .map(|point| EnvelopePoint {
                    position: point.position,
                    gain: point.gain,
                    curve_type: point.curve_type.into(),
                    tension: BipolarF64::new(point.tension),
                })
                .collect(),
        }
    }
}

#[derive(Clone)]
pub enum UiClipSource {
    Audio { source_id: u64 },
    Midi { pattern_id: u64 },
    None, // represent clip with empty source, this is placeholder, as this will be removed when I already implement MIDI Pattern and automation
}

impl From<&Clip> for UiClip {
    fn from(value: &Clip) -> Self {
        // Map source to either AudioWaveform, midi
        let source = match value.source.as_ref() {
            Some(DawSource::Audio(source_id)) => UiClipSource::Audio {
                source_id: source_id.to_u64(),
            },
            Some(DawSource::Midi(pattern_id)) => UiClipSource::Midi {
                pattern_id: pattern_id.to_u64(),
            },
            _ => UiClipSource::None,
        };
        Self {
            name: value.name.clone(),
            id: value.id.to_u64(),
            start_time: value.time.start_time_raw(),
            source,
            offset_start: value.time.offset_start_raw(),
            loop_length: value.time.loop_length_raw(),
            is_sample_based: value.time.is_samples(),
            envelope: value.envelope.as_deref().map(UiGainEnvelope::from),
        }
    }
}

#[derive(Clone, Debug, Serialize)]
#[frb(dart_metadata=("freezed"))]
pub struct AudioWaveformUiForSourceList {
    pub name: String,
    pub muted: bool,
    pub sample_rate: u32,
}

#[derive(Clone, Debug, Serialize)]
#[frb(dart_metadata=("freezed"))]
pub struct AudioWaveformUiForAudioProperties {
    pub id: Option<u64>,
    pub buffer_handle: WaveformHandle,
    pub file_path: String,
    pub name: String,
    pub sample_rate: u32,
    pub channels: u16,
    pub duration: f64,
    pub root_note: u8,
    pub fine_tune: i16,
    pub trim_start: u32,
    pub trim_end: u32,
    pub is_looping: bool,
    pub normalized: bool,
    pub muted: bool, // this only affects when play stream, not when doing preview sound
    pub sample_mode: UiAudioSampleMode,
    /// Tempo of the original audio: detected, or anchored to the project tempo when a
    /// tempo-following mode was entered. `None` when unknown.
    pub original_bpm: Option<f32>,
    /// Beats found by tempo detection, if it ran.
    pub beat_grid: Option<crate::api::audio_analysis::UiBeatGrid>,
    /// Whether the source is stretched to the project tempo.
    pub fitted: bool,
    /// Whether the stretch follows each detected beat.
    pub warp: bool,
    /// Whether the audio plays with inverted polarity.
    pub invert: bool,
    /// Whether the audio plays backwards.
    pub reverse: bool,
    /// Whether the stretched audio is rendered; playback uses the original until it is.
    pub render_ready: bool,
}

impl From<&AudioWaveform> for AudioWaveformUiForSourceList {
    fn from(value: &AudioWaveform) -> Self {
        Self {
            name: value.name.clone(),
            muted: value.muted,
            sample_rate: value.sample_rate,
        }
    }
}

impl AudioWaveformUiForAudioProperties {
    #[frb(ignore)]
    pub fn try_from_with_context(
        ctx: &CoreDawContext,
        value: &AudioWaveform,
    ) -> Result<Self, String> {
        let Some(id) = value.id else {
            return Err(String::from("This audio waveform does not have an ID"));
        };
        let waveform = ctx
            .app_state
            .get_audio_source(&id)
            .ok_or("Cannot get this waveform handle")?;
        let waveform_handle = WaveformHandle::from_waveform(waveform.clone());
        Ok(Self {
            id: Some(id.to_u64()),
            buffer_handle: waveform_handle,
            file_path: value.file_path.display().to_string(),
            name: value.name.clone(),
            sample_rate: value.sample_rate,
            channels: value.channels,
            duration: value.duration,
            root_note: value.root_note,
            fine_tune: value.fine_tune,
            trim_start: value.trim_start,
            trim_end: value.trim_end,
            is_looping: value.is_looping,
            normalized: value
                .edited
                .as_ref()
                .is_some_and(|edited| edited.edits.normalize),
            muted: value.muted,
            sample_mode: value.sample_mode.into(),
            original_bpm: value.original_bpm,
            beat_grid: value.beat_grid.as_ref().map(Into::into),
            fitted: value
                .edited
                .as_ref()
                .is_some_and(|edited| edited.edits.stretches()),
            warp: value
                .edited
                .as_ref()
                .is_some_and(|edited| edited.edits.warp),
            invert: value
                .edited
                .as_ref()
                .is_some_and(|edited| edited.edits.invert),
            reverse: value
                .edited
                .as_ref()
                .is_some_and(|edited| edited.edits.reverse),
            render_ready: value
                .edited
                .as_ref()
                .is_some_and(|edited| edited.buffer.is_some()),
        })
    }
}

// ============================================================
// =================== GENERATOR INSTANCE =====================
// ============================================================

#[frb(dart_metadata=("freezed"))]
pub struct UiGeneratorInstance {
    pub id: u64,
    pub instance_type: UiGeneratorInstanceType,
}

#[frb(dart_metadata=("freezed"))]
pub struct UiPluginInstance {
    /// Registry ID for plugin lookup (stable identifier)
    pub registry_id: u32,
    /// Name of the plugin (for display purposes)
    pub name: String,
    /// Whether this plugin is bypassed
    pub bypass: bool,
}

impl From<PluginInstance> for UiPluginInstance {
    fn from(value: PluginInstance) -> Self {
        Self {
            registry_id: value.registry_id,
            name: value.name,
            bypass: value.bypass,
        }
    }
}

pub enum UiGeneratorInstanceType {
    Plugin(UiPluginInstance),
    Sampler { asset_id: u32, root_note: u8 },
}

impl From<GeneratorInstanceType> for UiGeneratorInstanceType {
    fn from(value: GeneratorInstanceType) -> Self {
        match value {
            GeneratorInstanceType::Plugin(plugin_instance) => {
                Self::Plugin(UiPluginInstance::from(plugin_instance))
            }
            GeneratorInstanceType::Sampler {
                asset_id,
                root_note,
            } => Self::Sampler {
                asset_id,
                root_note,
            },
        }
    }
}

impl From<&GeneratorInstance> for UiGeneratorInstance {
    fn from(generator_instance: &GeneratorInstance) -> Self {
        match &generator_instance.instance_type {
            GeneratorInstanceType::Plugin(plugin_instance) => Self {
                id: generator_instance.id.to_u64(),
                instance_type: UiGeneratorInstanceType::Plugin(UiPluginInstance::from(
                    plugin_instance.to_owned(),
                )),
            },
            GeneratorInstanceType::Sampler {
                asset_id,
                root_note,
            } => Self {
                id: generator_instance.id.to_u64(),
                instance_type: UiGeneratorInstanceType::Sampler {
                    asset_id: *asset_id,
                    root_note: *root_note,
                },
            },
        }
    }
}

// ========================= Tail Handling DTO ========================
pub enum TailHandlingDTO {
    CutRemaining,
    LeaveRemaining,
    WrapRemaining,
}

/// Part of the song to export.
pub enum ExportRangeDTO {
    /// From the song start to the end of the last clip.
    Song,
    /// From `start_tick` up to `end_tick`, such as the loop region.
    Ticks { start_tick: u64, end_tick: u64 },
}

impl From<ExportRangeDTO> for ExportRange {
    fn from(value: ExportRangeDTO) -> Self {
        match value {
            ExportRangeDTO::Song => ExportRange::Song,
            ExportRangeDTO::Ticks {
                start_tick,
                end_tick,
            } => ExportRange::Ticks {
                start_tick,
                end_tick,
            },
        }
    }
}

impl From<TailHandlingDTO> for TailHandling {
    fn from(value: TailHandlingDTO) -> Self {
        match value {
            TailHandlingDTO::CutRemaining => TailHandling::CutRemainder,
            TailHandlingDTO::LeaveRemaining => TailHandling::LeaveRemainder,
            TailHandlingDTO::WrapRemaining => TailHandling::WrapRemainder,
        }
    }
}

#[derive(Clone)]
pub enum BitDepthDTO {
    BitPerSample(u16),
    BitPerSecond(u16),
}

impl TryFrom<BitDepthDTO> for BitDepth {
    type Error = String;

    fn try_from(value: BitDepthDTO) -> Result<Self, Self::Error> {
        let bit_depth = match value {
            BitDepthDTO::BitPerSample(bps) => {
                BitDepth::try_new_bits_per_sample(bps).map_err(|e| e.to_string())
            }
            BitDepthDTO::BitPerSecond(bps) => {
                BitDepth::try_new_bits_per_sec(bps).map_err(|e| e.to_string())
            }
        };

        bit_depth
    }
}

#[derive(Clone)]
pub struct WavExportConfigDTO {
    pub sample_rate: u32,
    pub channels: u8,
    pub bit_depth: BitDepthDTO,
}

#[derive(Clone)]
pub struct Mp3ExportConfigDTO {
    pub sample_rate: u32,
    pub channels: u8,
    pub bit_rate: BitDepthDTO,
}

#[derive(Clone)]
pub struct FlacExportConfigDTO {
    pub sample_rate: u32,
    pub channels: u8,
    pub bit_depth: BitDepthDTO,
}

impl TryFrom<FlacExportConfigDTO> for FlacAudioWriterConfig {
    type Error = String;

    fn try_from(value: FlacExportConfigDTO) -> Result<Self, Self::Error> {
        let BitDepth::BitPerSample(bits_per_sample) = value.bit_depth.try_into()? else {
            return Err("FLAC export requires a bit depth in bits per sample".to_string());
        };
        Ok(Self {
            sample_rate: value.sample_rate,
            channels: u16::from(value.channels),
            bits_per_sample,
        })
    }
}

/// OGG Opus always renders at 48 kHz, so no sample rate is configurable
#[derive(Clone)]
pub struct OggExportConfigDTO {
    pub channels: u8,
    pub bit_rate: BitDepthDTO,
}

impl TryFrom<OggExportConfigDTO> for OggOpusAudioWriterConfig {
    type Error = String;

    fn try_from(value: OggExportConfigDTO) -> Result<Self, Self::Error> {
        let BitDepth::BitPerSecond(bitrate) = value.bit_rate.try_into()? else {
            return Err("OGG Opus export requires a bitrate in kbps".to_string());
        };
        Ok(Self {
            channels: value.channels,
            bitrate,
        })
    }
}

#[derive(Clone)]
pub enum AudioExportConfigDTO {
    Wav(WavExportConfigDTO),
    Mp3(Mp3ExportConfigDTO),
    Flac(FlacExportConfigDTO),
    Ogg(OggExportConfigDTO),
}

// ============================ APIs ==================================

/// Get the current project metadata state from the backend
pub fn get_project_metadata(ctx: &DawContext) -> Result<UiProjectMetadata, String> {
    project_api::get_project_metadata(&ctx.read(), |m| UiProjectMetadata::from(m.clone()))
        .map_err(|e| e.to_string())
}

pub fn update_project_metadata(
    ctx: &DawContext,
    metadata: UiProjectMetadata,
) -> Result<UiProjectMetadata, String> {
    let mut ctx = ctx.project_write();
    let created_at = ctx.app_state.metadata.created_at;
    let mut metadata = ProjectMetadata::from(metadata);
    metadata.created_at = created_at;
    // An unchanged cover keeps the link recorded when the project was loaded
    if let (Some(cover), Some(current)) = (&mut metadata.cover, &ctx.app_state.metadata.cover)
        && cover.path == current.path
    {
        *cover = current.clone();
    }
    project_api::update_project_metadata(&mut ctx, metadata)
        .map(UiProjectMetadata::from)
        .map_err(|error| error.to_string())
}

/// Encodes a square RGBA crop from the cover editor as a JPEG in the app cache
/// and returns its path, ready to be set as the project's `cover_path`.
pub fn encode_cover_art(size: u32, rgba: Vec<u8>) -> Result<String, String> {
    CoverArt::encode_rgba(size, &rgba)
        .and_then(|cover| cover.store_in_cache())
        .map(|path| path.to_string_lossy().into_owned())
        .map_err(|error| error.to_string())
}

/// Get the transport state from the backend
pub fn get_transport_state(ctx: &DawContext) -> Result<UiTransportState, String> {
    project_api::get_transport_state(&ctx.read(), |t| UiTransportState::from(t.clone()))
        .map_err(|e| e.to_string())
}

/// Get all audio waveform source list from the backend
pub fn get_audio_source_list(
    ctx: &DawContext,
) -> Option<HashMap<u64, AudioWaveformUiForSourceList>> {
    audio_waveform_api::get_audio_source_list(&ctx.read(), |id, wf| {
        (id, AudioWaveformUiForSourceList::from(wf))
    })
    .ok()
}

/// Get generator list used in the project
pub fn get_generator_list(ctx: &DawContext) -> Result<HashMap<u64, UiGeneratorInstance>, String> {
    project_api::get_generator_list(&ctx.read(), |id, generator| {
        (id, UiGeneratorInstance::from(generator))
    })
    .map_err(|e| e.to_string())
}

/// Bounces the loop region, every track and bus without the master bus, to a new audio
/// source and returns its ID. Rendering runs without holding the project lock.
pub async fn bounce_loop_region(ctx: &DawContext) -> Result<u64, String> {
    let ctx = ctx.clone();
    run_job(
        JobSpec::new(JobKind::Bounce, JobClass::Heavy).with_target(JobTarget::Project),
        move |job| -> Result<u64, String> {
            // Like an export, the render keeps plugin and project operations out until it
            // ends; the guard must be gone before `project_write` takes the same lock
            let completed = {
                let operation = ctx.begin_project_operation();
                let pending =
                    bounce_api::begin_bounce(&operation.read_core()).map_err(|e| e.to_string())?;
                bounce_api::execute_bounce(pending, |progress| {
                    job.progress("render", progress);
                    !job.is_cancelled()
                })
                .map_err(|e| e.to_string())?
            };
            let source_id = bounce_api::commit_bounce(&mut ctx.project_write(), completed);
            Ok(source_id.to_u64())
        },
    )
    .await
}

/// Add a new audio source to the project
///
/// ## Parameters:
/// - file_path: Path to the audio file to be added
/// Decoding runs without holding the project lock; only the final insert takes it.
pub async fn add_audio_source(ctx: &DawContext, file_path: &str) -> Result<u64, String> {
    let ctx = ctx.clone();
    let file_path = file_path.to_owned();
    run_job(
        JobSpec::new(JobKind::AudioImport, JobClass::Heavy),
        move |_| -> Result<u64, String> {
            let pending = audio_waveform_api::begin_audio_import(&ctx.read(), &file_path)
                .map_err(|e| e.to_string())?;
            let completed =
                audio_waveform_api::execute_audio_import(pending).map_err(|e| e.to_string())?;
            let source_id =
                audio_waveform_api::commit_audio_import(&mut ctx.project_write(), completed);
            Ok(source_id.to_u64())
        },
    )
    .await
}

/// Add new track to the track list. Throws an error, so it must handled gracefully
pub fn add_new_audio_track(ctx: &DawContext) -> UiTrack {
    let mut ctx = ctx.project_write();
    let track = track_api::add_new_audio_track(&mut ctx);
    log::info!("[add_new_track] successfully added new track");
    UiTrack::from_track(&track, &ctx.app_state)
}

/// Get all tracks on the session/project.
///
/// Returns Map<u32, UiTrack> upon success, and Error when it fails
pub fn get_tracks(ctx: &DawContext) -> Result<HashMap<u64, UiTrack>, String> {
    let ctx = ctx.read();
    track_api::get_tracks_ordered(&ctx, |id, track| {
        (id, UiTrack::from_track(track, &ctx.app_state))
    })
    .map_err(|e| e.to_string())
}

/// Export project to flutter. also report progress via StreamSink
#[frb]
pub async fn export_project_flutter(
    ctx: &DawContext,
    output_path: String,
    config: AudioExportConfigDTO,
    tail_handling: TailHandlingDTO,
    range: ExportRangeDTO,
    progress_sink: StreamSink<f32>,
) -> Result<(), String> {
    let ctx = ctx.clone();
    run_job(
        JobSpec::new(JobKind::ProjectExport, JobClass::Heavy).with_target(JobTarget::Project),
        move |job| {
            export_project_blocking(
                &ctx,
                output_path,
                config,
                RenderOptions {
                    tail_handling: tail_handling.into(),
                    range: range.into(),
                    purpose: RenderPurpose::Export,
                },
                &progress_sink,
                job,
            )
        },
    )
    .await
}

fn export_project_blocking(
    ctx: &DawContext,
    output_path: String,
    config: AudioExportConfigDTO,
    options: RenderOptions,
    progress_sink: &StreamSink<f32>,
    job: &JobContext,
) -> Result<(), String> {
    // Map the FFI DTO to the Core Configuration Enum
    let core_config = match config {
        AudioExportConfigDTO::Wav(wav_dto) => {
            let bit_depth = wav_dto.bit_depth.try_into()?;
            AudioExportConfig::Wav(WavAudioWriterConfig {
                sample_rate: wav_dto.sample_rate,
                channels: wav_dto.channels as u16,
                bit_depth,
            })
        }
        AudioExportConfigDTO::Mp3(mp3_dto) => {
            // First, map the DTO to the core BitDepth enum
            let bit_depth: BitDepth = mp3_dto.bit_rate.try_into()?;
            let sample_rate = mp3_dto.sample_rate;
            let channels = mp3_dto.channels;

            AudioExportConfig::Mp3 {
                sample_rate,
                channels,
                bit_depth,
            }
        }
        AudioExportConfigDTO::Flac(flac_dto) => AudioExportConfig::Flac(flac_dto.try_into()?),
        AudioExportConfigDTO::Ogg(ogg_dto) => AudioExportConfig::Ogg(ogg_dto.try_into()?),
    };

    let operation = ctx.begin_project_operation();
    let pending = project_api::begin_project_export(&operation.read_core());
    project_api::execute_project_export(pending, &output_path, core_config, options, |progress| {
        job.progress("render", progress);
        // If the sink successfully adds the value, return true to keep rendering.
        // If it fails (meaning the Dart UI unmounted/cancelled), return false to abort!
        !job.is_cancelled() && progress_sink.add(progress).is_ok()
    })
    .map_err(|e| e.to_string())
}
