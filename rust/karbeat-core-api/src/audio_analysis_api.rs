//! Fitting audio sources to the project tempo, and offline renders of their edit recipes.
//!
//! Every operation is split into `begin_*` (short project read), `execute_*` (long work with
//! no project lock) and `commit_*` (short project write that rejects stale results), so the
//! work can run as a background job.

use std::{
    path::PathBuf,
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicU64, Ordering},
    },
    time::Duration,
};

use anyhow::Context;
use karbeat_analysis::{AnalysisError, AudioInput, ModelPaths, analyze_tempo};
use karbeat_core::{
    context::DawContext,
    core::{
        file_manager::audio_loader::CachedSamplesWriter,
        history::{
            HistoryAction,
            actions::{Batch, ClipEditRecorder, ClipsMadeUnique, SourceTempo, SourceTempoChanged},
        },
        project::{
            ApplicationState, AudioSourceId, DawSource,
            clip::{Clip, ClipTimeUnit, ResizeEdge},
            track::audio_waveform::{
                AudioSampleMode, AudioWaveform, BeatGrid, EditedWaveform, WaveformEdits,
            },
        },
    },
    shared::id::{ClipId, TrackId},
};
use karbeat_dsp::stretcher::{
    DefaultOfflineStretcher, OfflineStretch, OfflineTimeStretcher, stretch_offline_parallel,
};
use memmap2::Mmap;
use parking_lot::Mutex;

use crate::jobs;

/// Tempo range a source may be fitted from or to.
const BPM_RANGE: std::ops::RangeInclusive<f32> = 20.0..=400.0;

/// Tempo state of a source, compared at commit to detect edits made while a job ran.
#[derive(Clone, Debug, PartialEq)]
struct TempoSnapshot {
    original_bpm: Option<f32>,
    sample_mode: AudioSampleMode,
    edits: Option<WaveformEdits>,
    beat_grid: Option<BeatGrid>,
}

impl TempoSnapshot {
    fn of(waveform: &AudioWaveform) -> Self {
        Self {
            original_bpm: waveform.original_bpm,
            sample_mode: waveform.sample_mode,
            edits: waveform.edited.as_ref().map(|edited| edited.edits.clone()),
            beat_grid: waveform.beat_grid.clone(),
        }
    }
}

/// What a render was made from, to tell whether it still matches the project.
#[derive(Clone, Debug, PartialEq)]
struct RenderBasis {
    /// [`DawContext::instance_id`] of the project the render belongs to.
    context: u64,
    source_id: AudioSourceId,
    before: TempoSnapshot,
    purpose: RenderPurpose,
    target_bpm: f32,
}

impl RenderBasis {
    /// Whether the project tempo shapes the render: a fit, or a refresh of a source that
    /// stretches to the project tempo.
    fn follows_tempo(&self) -> bool {
        matches!(self.purpose, RenderPurpose::Fit { .. })
            || self.before.sample_mode == AudioSampleMode::Stretch
    }

    /// Whether the render still matches its source and the project tempo.
    fn is_current(&self, ctx: &DawContext) -> bool {
        let app = &ctx.app_state;
        ctx.instance_id == self.context
            && app
                .asset_library
                .source_map
                .get(self.source_id)
                .is_some_and(|waveform| TempoSnapshot::of(waveform) == self.before)
            && (!self.follows_tempo() || app.transport.bpm == self.target_bpm)
    }
}

/// A render in progress, cancelled once it no longer matches the project.
struct ActiveRender {
    id: u64,
    basis: RenderBasis,
    stale: Arc<AtomicBool>,
}

static ACTIVE_RENDERS: Mutex<Vec<ActiveRender>> = Mutex::new(Vec::new());
static NEXT_RENDER: AtomicU64 = AtomicU64::new(1);

/// Registration of a running render; unregisters on drop.
pub(crate) struct ActiveRenderGuard {
    id: u64,
    stale: Arc<AtomicBool>,
}

impl ActiveRenderGuard {
    fn track(basis: RenderBasis, stale: Arc<AtomicBool>) -> Self {
        let id = NEXT_RENDER.fetch_add(1, Ordering::Relaxed);
        ACTIVE_RENDERS.lock().push(ActiveRender {
            id,
            basis,
            stale: Arc::clone(&stale),
        });
        Self { id, stale }
    }

    /// Whether [`cancel_stale_renders`] found the render stale.
    pub(crate) fn is_stale(&self) -> bool {
        self.stale.load(Ordering::Acquire)
    }
}

impl Drop for ActiveRenderGuard {
    fn drop(&mut self) {
        ACTIVE_RENDERS.lock().retain(|render| render.id != self.id);
    }
}

/// Cancels every running render of `ctx`'s project that no longer matches it: its source's
/// tempo state changed, or, for a render stretched to the project tempo, the tempo changed.
/// Call after any edit that can change them, such as a tempo change, undo or redo.
///
/// Returns how many renders were cancelled.
pub fn cancel_stale_renders(ctx: &DawContext) -> usize {
    let mut cancelled: usize = 0;
    for render in ACTIVE_RENDERS.lock().iter() {
        if render.basis.context == ctx.instance_id
            && !render.stale.load(Ordering::Acquire)
            && !render.basis.is_current(ctx)
        {
            render.stale.store(true, Ordering::Release);
            cancelled = cancelled.saturating_add(1);
            log::info!(
                "Cancelled a stale render of audio source {}",
                render.basis.source_id.to_u64()
            );
        }
    }
    cancelled
}

/// What a commit changes besides the rendered buffer.
#[derive(Clone, Copy, Debug, PartialEq)]
enum RenderPurpose {
    /// Fit the source to the project tempo: sets its tempo and sample mode, and is undoable.
    Fit { source_bpm: f32 },
    /// Render the existing recipe again, for example after loading or a tempo change.
    Refresh,
}

/// An offline render captured from the project; run it with [`execute_render`].
pub struct PendingRender {
    context: u64,
    source_id: AudioSourceId,
    before: TempoSnapshot,
    purpose: RenderPurpose,
    edits: WaveformEdits,
    original: Option<Arc<Mmap>>,
    channels: usize,
    sample_rate: u32,
    beat_grid: Option<BeatGrid>,
    target_bpm: f32,
    /// Raised when the render turns stale; see [`Self::with_cancel_flag`].
    cancel: Arc<AtomicBool>,
}

impl PendingRender {
    pub fn source_id(&self) -> AudioSourceId {
        self.source_id
    }

    fn basis(&self) -> RenderBasis {
        RenderBasis {
            context: self.context,
            source_id: self.source_id,
            before: self.before.clone(),
            purpose: self.purpose,
            target_bpm: self.target_bpm,
        }
    }

    /// Uses `flag` as the flag [`cancel_stale_renders`] raises when the render turns stale,
    /// such as the flag of the job running it, so a stale render ends as cancelled.
    #[must_use]
    pub fn with_cancel_flag(mut self, flag: Arc<AtomicBool>) -> Self {
        self.cancel = flag;
        self
    }

    /// Registers this render as running, so [`cancel_stale_renders`] can stop it.
    pub(crate) fn track(&self) -> ActiveRenderGuard {
        ActiveRenderGuard::track(self.basis(), Arc::clone(&self.cancel))
    }
}

/// A finished render; apply it with [`commit_render`].
pub struct CompletedRender {
    basis: RenderBasis,
    edits: WaveformEdits,
    buffer: Option<Arc<Mmap>>,
    gain: f32,
}

fn waveform(ctx: &DawContext, source_id: AudioSourceId) -> anyhow::Result<&Arc<AudioWaveform>> {
    ctx.app_state
        .asset_library
        .source_map
        .get(source_id)
        .context("Cannot find audio source")
}

fn project_bpm(ctx: &DawContext) -> f32 {
    ctx.app_state.transport.bpm
}

fn pending(
    ctx: &DawContext,
    waveform: &AudioWaveform,
    source_id: AudioSourceId,
    purpose: RenderPurpose,
    edits: WaveformEdits,
) -> PendingRender {
    PendingRender {
        context: ctx.instance_id,
        source_id,
        before: TempoSnapshot::of(waveform),
        purpose,
        edits,
        original: waveform.buffer.clone(),
        channels: usize::from(waveform.channels),
        sample_rate: waveform.sample_rate,
        beat_grid: waveform.beat_grid.clone(),
        target_bpm: project_bpm(ctx),
        cancel: Arc::new(AtomicBool::new(false)),
    }
}

/// Prepares fitting a source to the project tempo.
///
/// The source tempo is the detected tempo when tempo detection ran, else the source's stored
/// tempo. `warp` stretches beat by beat and requires detected beats.
pub fn begin_fit_to_tempo(
    ctx: &DawContext,
    source_id: AudioSourceId,
    warp: bool,
) -> anyhow::Result<PendingRender> {
    let waveform = waveform(ctx, source_id)?;
    let source_bpm = waveform
        .beat_grid
        .as_ref()
        .map(|grid| grid.bpm)
        .or(waveform.original_bpm)
        .context("The source tempo is unknown: detect the tempo first")?;
    let target_bpm = project_bpm(ctx);
    anyhow::ensure!(
        BPM_RANGE.contains(&source_bpm) && BPM_RANGE.contains(&target_bpm),
        "Tempo must be between {} and {} BPM",
        BPM_RANGE.start(),
        BPM_RANGE.end()
    );
    anyhow::ensure!(
        !warp
            || waveform
                .beat_grid
                .as_ref()
                .is_some_and(|grid| grid.beats.len() >= 2),
        "Detect the tempo before fitting beat by beat"
    );
    let mut edits = waveform
        .edited
        .as_ref()
        .map(|edited| edited.edits.clone())
        .unwrap_or_default();
    edits.time_ratio = source_bpm / target_bpm;
    edits.warp = warp;
    Ok(pending(
        ctx,
        waveform,
        source_id,
        RenderPurpose::Fit { source_bpm },
        edits,
    ))
}

/// Frames copied per block when a render needs no stretching.
const COPY_BLOCK_FRAMES: usize = 8192;

/// The recipe a source should be rendered with now: in [`AudioSampleMode::Stretch`], its
/// time ratio fits the source to the project tempo.
fn current_recipe(waveform: &AudioWaveform, target_bpm: f32) -> WaveformEdits {
    let edits = waveform
        .edited
        .as_ref()
        .map(|edited| edited.edits.clone())
        .unwrap_or_default();
    match waveform.original_bpm {
        Some(source_bpm)
            if waveform.sample_mode == AudioSampleMode::Stretch
                && BPM_RANGE.contains(&source_bpm)
                && BPM_RANGE.contains(&target_bpm) =>
        {
            WaveformEdits {
                time_ratio: source_bpm / target_bpm,
                ..edits
            }
        }
        _ => edits,
    }
}

/// The recipe to render, or `None` when the loaded render already matches it or nothing
/// needs rendering.
fn refresh_recipe(waveform: &AudioWaveform, target_bpm: f32) -> Option<WaveformEdits> {
    let edits = current_recipe(waveform, target_bpm);
    let stored = waveform.edited.as_ref();
    let rendered = stored.is_some_and(|edited| edited.buffer.is_some());
    let up_to_date = if rendered {
        stored.is_some_and(|edited| edited.edits == edits)
    } else {
        !edits.needs_render() && stored.is_none_or(|edited| edited.edits == edits)
    };
    (!up_to_date).then_some(edits)
}

/// Prepares rendering a source's recipe again, or returns `None` when it has nothing to
/// render.
///
/// Sources in [`AudioSampleMode::Stretch`] are re-fitted to the current project tempo.
pub fn begin_refresh_render(
    ctx: &DawContext,
    source_id: AudioSourceId,
) -> anyhow::Result<Option<PendingRender>> {
    let waveform = waveform(ctx, source_id)?;
    Ok(refresh_recipe(waveform, project_bpm(ctx))
        .map(|edits| pending(ctx, waveform, source_id, RenderPurpose::Refresh, edits)))
}

/// Sources whose render does not match their recipe, such as every edited source after
/// loading, or stretched sources after a tempo change.
pub fn sources_needing_render(ctx: &DawContext) -> Vec<AudioSourceId> {
    let target_bpm = project_bpm(ctx);
    ctx.app_state
        .asset_library
        .source_map
        .iter()
        .filter(|(_, waveform)| refresh_recipe(waveform, target_bpm).is_some())
        .map(|(id, _)| id)
        .collect()
}

fn tempo_state(waveform: &AudioWaveform) -> SourceTempo {
    SourceTempo {
        original_bpm: waveform.original_bpm,
        sample_mode: waveform.sample_mode,
        beat_grid: waveform.beat_grid.clone(),
        edited: waveform.edited.clone(),
    }
}

/// Changes how a source follows the project tempo, as one undoable step. Returns whether it
/// needs a render.
///
/// Entering a tempo-following mode with no known source tempo anchors it to the current
/// project tempo, so the audio keeps playing as placed and later tempo changes stretch it
/// relative to that. Returning to [`AudioSampleMode::Default`] forgets such an anchor; a
/// detected tempo is kept.
///
/// Entering [`AudioSampleMode::Stretch`] keeps any render: realtime stretching follows the
/// tempo until a render fits it. Leaving it drops the tempo fit, and a render stretched by it.
pub fn set_sample_mode(
    ctx: &mut DawContext,
    source_id: AudioSourceId,
    mode: AudioSampleMode,
) -> anyhow::Result<bool> {
    let entry = ctx
        .app_state
        .asset_library
        .source_map
        .get_mut(source_id)
        .context("Cannot find audio source")?;
    if entry.sample_mode == mode {
        return Ok(false);
    }
    let project_bpm = ctx.app_state.transport.bpm;
    let waveform = Arc::make_mut(entry);
    let previous = tempo_state(waveform);
    waveform.sample_mode = mode;
    let detected = waveform.beat_grid.as_ref().map(|grid| grid.bpm);
    // An anchor only carries over between the two tempo-following modes: coming from
    // Default, a stored tempo may be a stale value from an older project.
    let anchor = match previous.sample_mode {
        AudioSampleMode::Default => None,
        AudioSampleMode::Stretch | AudioSampleMode::Resampled => waveform.original_bpm,
    };
    waveform.original_bpm = match mode {
        AudioSampleMode::Default => detected,
        AudioSampleMode::Stretch | AudioSampleMode::Resampled => detected
            .or(anchor)
            .or(Some(project_bpm).filter(|bpm| BPM_RANGE.contains(bpm))),
    };
    if mode != AudioSampleMode::Stretch
        && let Some(edited) = &mut waveform.edited
        && edited.edits.stretches()
    {
        edited.edits.time_ratio = 1.0;
        edited.edits.warp = false;
        edited.buffer = None;
        edited.gain = 1.0;
    }
    if waveform
        .edited
        .as_ref()
        .is_some_and(|edited| edited.edits == WaveformEdits::default())
    {
        waveform.edited = None;
    }
    ctx.push_history(SourceTempoChanged::new(
        source_id,
        previous,
        "Change Sample Mode",
    ));
    ctx.broadcast_audio_source(source_id);
    Ok(begin_refresh_render(ctx, source_id)?.is_some())
}

/// Sets a source's normalize, invert and reverse edits as one undoable step. Returns whether
/// it needs a render.
///
/// The current render no longer matches, so playback uses the original audio until the new
/// render arrives.
pub fn set_waveform_edits(
    ctx: &mut DawContext,
    source_id: AudioSourceId,
    normalize: bool,
    invert: bool,
    reverse: bool,
) -> anyhow::Result<bool> {
    change_edits(ctx, source_id, "Edit Waveform", |current| WaveformEdits {
        normalize,
        invert,
        reverse,
        ..current
    })
}

/// Highest pitch shift, in semitones either way, that a source edit accepts.
pub const MAX_PITCH_SEMITONES: f32 = 24.0;

/// Sets a source's pitch shift, clamped to [`MAX_PITCH_SEMITONES`] either way, and whether
/// to preserve formants, as one undoable step. Returns whether it needs a render.
///
/// The duration is kept. As with the other edits, playback uses the original audio until the
/// new render arrives.
pub fn set_waveform_pitch(
    ctx: &mut DawContext,
    source_id: AudioSourceId,
    pitch_semitones: f32,
    preserve_formants: bool,
) -> anyhow::Result<bool> {
    anyhow::ensure!(pitch_semitones.is_finite(), "Pitch shift must be a number");
    let pitch_semitones = pitch_semitones.clamp(-MAX_PITCH_SEMITONES, MAX_PITCH_SEMITONES);
    change_edits(ctx, source_id, "Pitch Shift", |current| WaveformEdits {
        pitch_semitones,
        preserve_formants,
        ..current
    })
}

/// Replaces a source's edit recipe with `change(current)` as one undoable step named `label`.
/// Returns whether it needs a render.
fn change_edits(
    ctx: &mut DawContext,
    source_id: AudioSourceId,
    label: &'static str,
    change: impl FnOnce(WaveformEdits) -> WaveformEdits,
) -> anyhow::Result<bool> {
    let entry = ctx
        .app_state
        .asset_library
        .source_map
        .get_mut(source_id)
        .context("Cannot find audio source")?;
    let current = entry
        .edited
        .as_ref()
        .map(|edited| edited.edits.clone())
        .unwrap_or_default();
    let edits = change(current.clone());
    if edits == current {
        return Ok(false);
    }
    let waveform = Arc::make_mut(entry);
    let previous = tempo_state(waveform);
    waveform.normalized = edits.normalize;
    waveform.edited = (edits != WaveformEdits::default()).then(|| EditedWaveform {
        edits,
        ..EditedWaveform::default()
    });
    ctx.push_history(SourceTempoChanged::new(source_id, previous, label));
    ctx.broadcast_audio_source(source_id);
    Ok(begin_refresh_render(ctx, source_id)?.is_some())
}

/// Whether `clip_id` plays an audio source, so a stretching resize can stretch it.
pub fn is_audio_clip(app: &ApplicationState, clip_id: ClipId) -> bool {
    app.clips_pool
        .get(clip_id)
        .is_some_and(|clip| matches!(clip.source, Some(DawSource::Audio(_))))
}

/// New length divided by old length of an audio clip resized by `delta_ticks` at `edge`,
/// with the same limits as a plain resize. `None` for clips that are not audio.
fn stretch_factor(
    time: &ClipTimeUnit,
    edge: ResizeEdge,
    delta_ticks: i64,
    bpm: f32,
    sample_rate: u32,
) -> Option<f64> {
    let (start, length) = match *time {
        ClipTimeUnit::Audio {
            start_tick,
            loop_length,
            ..
        } => (
            start_tick as i64,
            ClipTimeUnit::samples_to_ticks(loop_length, bpm, sample_rate) as i64,
        ),
        ClipTimeUnit::Samples {
            start_time,
            loop_length,
            ..
        } => (start_time as i64, loop_length as i64),
        ClipTimeUnit::Ticks { .. } => return None,
    };
    if length <= 0 {
        return None;
    }
    let end = start + length;
    let new_length = match edge {
        ResizeEdge::Right => (end + delta_ticks).max(start + 10) - start,
        ResizeEdge::Left => end - (start + delta_ticks).clamp(0, end - 10),
    };
    Some(new_length as f64 / length as f64)
}

/// `time` with its audio stretched by `factor`: length and content offset scale, and the
/// edge that was not dragged stays put.
fn stretched_time(
    time: &ClipTimeUnit,
    edge: ResizeEdge,
    factor: f64,
    bpm: f32,
    sample_rate: u32,
) -> ClipTimeUnit {
    let scale = |value: u64| (value as f64 * factor).round().max(1.0) as u64;
    match *time {
        ClipTimeUnit::Audio {
            start_tick,
            loop_length,
            offset_start,
        } => {
            let new_length = scale(loop_length);
            let start_tick = match edge {
                ResizeEdge::Right => start_tick,
                ResizeEdge::Left => {
                    let end =
                        start_tick + ClipTimeUnit::samples_to_ticks(loop_length, bpm, sample_rate);
                    end.saturating_sub(ClipTimeUnit::samples_to_ticks(new_length, bpm, sample_rate))
                }
            };
            ClipTimeUnit::Audio {
                start_tick,
                loop_length: new_length,
                offset_start: (offset_start as f64 * factor).round() as u64,
            }
        }
        ClipTimeUnit::Samples {
            start_time,
            loop_length,
            offset_start,
        } => {
            let new_length = scale(loop_length);
            let start_time = match edge {
                ResizeEdge::Right => start_time,
                ResizeEdge::Left => (start_time + loop_length).saturating_sub(new_length),
            };
            ClipTimeUnit::Samples {
                start_time,
                loop_length: new_length,
                offset_start: (offset_start as f64 * factor).round() as u64,
            }
        }
        ClipTimeUnit::Ticks { .. } => time.clone(),
    }
}

/// Resizes audio clips by `delta_ticks` at `edge`, stretching their audio to the new length
/// with its pitch kept, as one undoable step. Returns the resized clips.
///
/// Stretching re-anchors the source tempo, so a clip sharing its source with other clips is
/// made unique first and the others keep their length. The source switches to
/// [`AudioSampleMode::Stretch`] and plays through the realtime stretcher until a render fits
/// it.
pub fn stretch_resize_clips(
    ctx: &mut DawContext,
    track_id: TrackId,
    clip_ids: &[ClipId],
    edge: ResizeEdge,
    delta_ticks: i64,
) -> anyhow::Result<Vec<Clip>> {
    let bpm = ctx.app_state.transport.bpm;
    let sample_rate = ctx.app_state.audio_config.sample_rate;
    let factors: Vec<(ClipId, f64)> = clip_ids
        .iter()
        .filter_map(|id| {
            let clip = ctx.app_state.clips_pool.get(*id)?;
            stretch_factor(&clip.time, edge, delta_ticks, bpm, sample_rate)
                .filter(|factor| (factor - 1.0).abs() > 1e-9)
                .map(|factor| (*id, factor))
        })
        .collect();
    if factors.is_empty() {
        return Ok(Vec::new());
    }
    let ids: Vec<ClipId> = factors.iter().map(|(id, _)| *id).collect();
    let mut actions: Vec<Box<dyn HistoryAction>> = Vec::new();

    let unique = ClipEditRecorder::begin(&ctx.app_state, "Make Clips Unique", &[], &ids);
    let made = ctx.app_state.make_clips_unique(track_id, &ids)?;
    let made_unique = !made.clips.is_empty();
    if made_unique {
        actions.push(Box::new(ClipsMadeUnique::new(
            unique.finish(&mut ctx.app_state),
            &made,
        )));
    }

    let clip_edit = ClipEditRecorder::begin(&ctx.app_state, "Stretch Clips", &[track_id], &ids);
    let mut sources = Vec::with_capacity(factors.len());
    for (clip_id, factor) in factors {
        let Some(DawSource::Audio(source)) = ctx
            .app_state
            .clips_pool
            .get(clip_id)
            .and_then(|clip| clip.source.clone())
        else {
            continue;
        };
        let Some(entry) = ctx.app_state.asset_library.source_map.get_mut(source) else {
            continue;
        };
        let waveform = Arc::make_mut(entry);
        let previous = tempo_state(waveform);
        let anchor = match waveform.sample_mode {
            AudioSampleMode::Stretch | AudioSampleMode::Resampled => waveform.original_bpm,
            AudioSampleMode::Default => None,
        }
        .or(waveform.beat_grid.as_ref().map(|grid| grid.bpm))
        .unwrap_or(bpm);
        // Longer audio means a slower source tempo: the anchor scales with the length.
        let new_anchor = (anchor * factor as f32).clamp(*BPM_RANGE.start(), *BPM_RANGE.end());
        let factor = f64::from(new_anchor / anchor);
        waveform.sample_mode = AudioSampleMode::Stretch;
        waveform.original_bpm = Some(new_anchor);
        actions.push(Box::new(SourceTempoChanged::new(
            source,
            previous,
            "Stretch Clip",
        )));

        let app = &mut ctx.app_state;
        let track = app.tracks.get_mut(track_id).context("Track not found")?;
        track.remove_clip(&clip_id)?;
        if let Some(clip) = app.clips_pool.get_mut(clip_id) {
            clip.time = stretched_time(&clip.time, edge, factor, bpm, sample_rate);
        }
        track.add_clip(clip_id, &app.clips_pool)?;
        sources.push(source);
    }
    actions.push(Box::new(clip_edit.finish(&mut ctx.app_state)));
    ctx.push_history(Batch::new("Stretch Clips", actions));

    if made_unique {
        ctx.broadcast_full_graph();
    } else {
        ctx.broadcast_track_graph();
        for source in sources {
            ctx.broadcast_audio_source(source);
        }
    }
    Ok(ids
        .iter()
        .filter_map(|id| ctx.app_state.clips_pool.get(*id).cloned())
        .collect())
}

/// Maps each detected beat to its place on the target tempo grid, keeping the first beat
/// where a constant stretch would put it. With `reverse`, beats are mirrored to match the
/// reversed audio.
fn warp_key_frames(pending: &PendingRender, input_frames: usize) -> Vec<(usize, usize)> {
    let Some(grid) = &pending.beat_grid else {
        return Vec::new();
    };
    let rate = f64::from(pending.sample_rate);
    let duration = input_frames as f64 / rate;
    let mut beats: Vec<f64> = grid.beats.iter().map(|beat| f64::from(*beat)).collect();
    if pending.edits.reverse {
        beats = beats.iter().rev().map(|beat| duration - beat).collect();
    }
    let ratio = f64::from(pending.edits.time_ratio);
    let output_frames = input_frames as f64 * ratio;
    let frames_per_beat = 60.0 / f64::from(pending.target_bpm) * rate;
    let Some(first) = beats.first() else {
        return Vec::new();
    };
    let first_output = first * rate * ratio;

    let mut key_frames: Vec<(usize, usize)> = Vec::with_capacity(beats.len());
    for (index, beat) in beats.iter().enumerate() {
        let input = (beat * rate).round();
        let output = (first_output + index as f64 * frames_per_beat).round();
        if input <= 0.0 || input >= input_frames as f64 || output >= output_frames {
            continue;
        }
        let pair = (input as usize, output as usize);
        if key_frames
            .last()
            .is_none_or(|last| pair.0 > last.0 && pair.1 > last.1)
        {
            key_frames.push(pair);
        }
    }
    key_frames
}

/// Writes `input`'s frames last to first into a disk-backed buffer.
fn reversed(
    input: &[f32],
    channels: usize,
    cancelled: &dyn Fn() -> bool,
) -> anyhow::Result<Arc<Mmap>> {
    let mut writer = CachedSamplesWriter::new()?;
    let mut block = Vec::with_capacity(COPY_BLOCK_FRAMES * channels);
    for chunk in input.rchunks(COPY_BLOCK_FRAMES * channels) {
        anyhow::ensure!(!cancelled(), "render cancelled");
        block.clear();
        for frame in chunk.chunks_exact(channels).rev() {
            block.extend_from_slice(frame);
        }
        writer.write(&block)?;
    }
    writer.finish()
}

/// Stream of rendered blocks: inverts them when asked, tracks their peak, and writes them to
/// disk, keeping the first write error and raising `failed` so the render stops.
struct RenderSink<'a> {
    writer: CachedSamplesWriter,
    invert: bool,
    peak: f32,
    scratch: Vec<f32>,
    error: Option<anyhow::Error>,
    failed: &'a AtomicBool,
}

impl RenderSink<'_> {
    fn write(&mut self, block: &[f32]) {
        if self.error.is_some() {
            return;
        }
        let sign = if self.invert { -1.0 } else { 1.0 };
        self.scratch.clear();
        self.scratch
            .extend(block.iter().map(|sample| sample * sign));
        self.peak = self
            .scratch
            .iter()
            .fold(self.peak, |peak, sample| peak.max(sample.abs()));
        if let Err(error) = self.writer.write(&self.scratch) {
            self.error = Some(error);
            self.failed.store(true, Ordering::Release);
        }
    }
}

/// Renders the recipe: reverse, then time stretch and pitch shift with Rubber Band, then
/// invert; normalizing sets a playback gain from the rendered peak. Holds no project lock.
///
/// Long audio is stretched in chunks on the shared compute pool. `cancelled` is polled
/// between blocks, and the render also stops once [`cancel_stale_renders`] finds it stale.
/// `progress` receives `0.0..=1.0`.
pub fn execute_render(
    pending: PendingRender,
    cancelled: &(dyn Fn() -> bool + Sync),
    progress: &mut dyn FnMut(f32),
) -> anyhow::Result<CompletedRender> {
    let active = pending.track();
    let stopped = || cancelled() || active.is_stale();
    let (buffer, gain) = if pending.edits.needs_render() {
        let original = pending
            .original
            .as_ref()
            .context("Audio source has no decoded audio")?;
        let source: &[f32] = bytemuck::try_cast_slice(&original[..])
            .map_err(|error| anyhow::anyhow!("Audio source buffer is not f32 audio: {error}"))?;
        let channels = pending.channels.max(1);
        let reversed_source = if pending.edits.reverse {
            Some(reversed(source, channels, &stopped)?)
        } else {
            None
        };
        let input: &[f32] = match &reversed_source {
            Some(map) => bytemuck::try_cast_slice(&map[..])
                .map_err(|error| anyhow::anyhow!("Reversed buffer is not f32 audio: {error}"))?,
            None => source,
        };
        let write_failed = AtomicBool::new(false);
        let mut sink = RenderSink {
            writer: CachedSamplesWriter::new()?,
            invert: pending.edits.invert,
            peak: 0.0,
            scratch: Vec::new(),
            error: None,
            failed: &write_failed,
        };
        let pitch_scale = 2_f64.powf(f64::from(pending.edits.pitch_semitones) / 12.0);
        if pending.edits.stretches() || (pitch_scale - 1.0).abs() > f64::EPSILON {
            let key_frames = if pending.edits.warp {
                warp_key_frames(&pending, input.len() / channels)
            } else {
                Vec::new()
            };
            let request = OfflineStretch {
                sample_rate: pending.sample_rate,
                channels,
                input,
                time_ratio: f64::from(pending.edits.time_ratio),
                pitch_scale,
                preserve_formants: pending.edits.preserve_formants,
                key_frames: &key_frames,
            };
            let stop = || stopped() || write_failed.load(Ordering::Acquire);
            let mut write = |block: &[f32]| sink.write(block);
            let stretcher = DefaultOfflineStretcher::default();
            let stretched = match jobs::compute_pool() {
                Some(pool) => stretch_offline_parallel(
                    &stretcher, &request, pool, &stop, progress, &mut write,
                ),
                None => stretcher.stretch(&request, &stop, progress, &mut write),
            };
            // A failed write stops the stretch as cancelled; report the write failure instead.
            if let Some(error) = sink.error.take() {
                return Err(error);
            }
            stretched?;
        } else {
            let blocks = input.chunks(COPY_BLOCK_FRAMES * channels);
            let count = blocks.len().max(1) as f32;
            for (index, block) in blocks.enumerate() {
                anyhow::ensure!(!stopped(), "render cancelled");
                sink.write(block);
                progress((index + 1) as f32 / count);
            }
        }
        if let Some(error) = sink.error {
            return Err(error);
        }
        let gain = if pending.edits.normalize && sink.peak > 1e-6 {
            1.0 / sink.peak
        } else {
            1.0
        };
        (Some(sink.writer.finish()?), gain)
    } else {
        (None, 1.0)
    };
    Ok(CompletedRender {
        basis: pending.basis(),
        edits: pending.edits,
        buffer,
        gain,
    })
}

/// Applies a render unless it no longer matches the project: the source changed while it
/// ran, or it was stretched to a project tempo that has since changed. Returns whether it
/// was applied.
///
/// A fit records an undoable history step; a refresh only swaps the rendered audio.
pub fn commit_render(ctx: &mut DawContext, completed: CompletedRender) -> bool {
    let source_id = completed.basis.source_id;
    if !completed.basis.is_current(ctx) {
        log::info!(
            "Discarded a render of audio source {}: it changed while rendering",
            source_id.to_u64()
        );
        return false;
    }
    let Some(entry) = ctx.app_state.asset_library.source_map.get_mut(source_id) else {
        return false;
    };

    let waveform = Arc::make_mut(entry);
    let previous = tempo_state(waveform);
    let recipe_changed = completed.basis.before.edits.as_ref() != Some(&completed.edits);
    waveform.normalized = completed.edits.normalize;
    waveform.edited = (completed.edits != WaveformEdits::default()).then(|| EditedWaveform {
        edits: completed.edits,
        buffer: completed.buffer,
        gain: completed.gain,
    });
    match completed.basis.purpose {
        RenderPurpose::Fit { source_bpm } => {
            waveform.original_bpm = Some(source_bpm);
            waveform.sample_mode = AudioSampleMode::Stretch;
            ctx.push_history(SourceTempoChanged::new(source_id, previous, "Fit to Tempo"));
        }
        RenderPurpose::Refresh if recipe_changed => ctx.mark_project_modified(),
        RenderPurpose::Refresh => {}
    }
    ctx.broadcast_audio_source(source_id);
    true
}

/// Stores detected beats and tempo on a source as one undoable step. Returns whether the
/// source still exists.
pub fn commit_beat_grid(ctx: &mut DawContext, source_id: AudioSourceId, grid: BeatGrid) -> bool {
    let Some(entry) = ctx.app_state.asset_library.source_map.get_mut(source_id) else {
        return false;
    };
    let waveform = Arc::make_mut(entry);
    let previous = tempo_state(waveform);
    waveform.original_bpm = Some(grid.bpm);
    waveform.beat_grid = Some(grid);
    ctx.push_history(SourceTempoChanged::new(source_id, previous, "Detect Tempo"));
    ctx.broadcast_audio_source(source_id);
    true
}

/// Sets the Beat This! model files used for tempo detection: the mel front end and the
/// small beat model.
pub fn configure_tempo_models(mel: PathBuf, beat: PathBuf) -> Result<(), AnalysisError> {
    karbeat_analysis::configure_models(ModelPaths { mel, beat })
}

/// Unloads the tempo detection models if unused for `idle`, freeing their memory.
pub fn release_idle_tempo_models(idle: Duration) -> bool {
    karbeat_analysis::release_models_if_idle(idle)
}

/// Tempo detection captured from the project; run it with [`execute_detect_tempo`].
pub struct PendingTempoDetection {
    source_id: AudioSourceId,
    before: TempoSnapshot,
    buffer: Arc<Mmap>,
    channels: usize,
    sample_rate: u32,
}

/// Detected beats for a source; store them with [`commit_detect_tempo`].
pub struct CompletedTempoDetection {
    source_id: AudioSourceId,
    before: TempoSnapshot,
    grid: BeatGrid,
}

impl CompletedTempoDetection {
    pub fn grid(&self) -> &BeatGrid {
        &self.grid
    }
}

/// Snapshots the source's original audio for tempo detection.
pub fn begin_detect_tempo(
    ctx: &DawContext,
    source_id: AudioSourceId,
) -> anyhow::Result<PendingTempoDetection> {
    let waveform = waveform(ctx, source_id)?;
    Ok(PendingTempoDetection {
        source_id,
        before: TempoSnapshot::of(waveform),
        buffer: waveform
            .buffer
            .clone()
            .context("Audio source has no decoded audio")?,
        channels: usize::from(waveform.channels),
        sample_rate: waveform.sample_rate,
    })
}

/// Detects beats, downbeats and tempo. Holds no project lock.
///
/// Long audio is analyzed in segments on the shared compute pool, as many at once as free
/// memory allows; the analysis stops with [`AnalysisError::InsufficientMemory`] rather than
/// exhausting it.
pub fn execute_detect_tempo(
    pending: PendingTempoDetection,
    cancel: Arc<AtomicBool>,
    progress: &mut dyn FnMut(f32),
) -> Result<CompletedTempoDetection, AnalysisError> {
    let samples: &[f32] = bytemuck::try_cast_slice(&pending.buffer[..])
        .map_err(|_| AnalysisError::InvalidInput("audio source buffer is not f32 audio"))?;
    let analysis = analyze_tempo(
        AudioInput {
            samples,
            channels: pending.channels,
            sample_rate: pending.sample_rate,
        },
        jobs::compute_pool(),
        cancel,
        progress,
    )?;
    Ok(CompletedTempoDetection {
        source_id: pending.source_id,
        before: pending.before,
        grid: BeatGrid {
            bpm: analysis.bpm,
            confidence: analysis.confidence,
            beats: analysis.beats,
            downbeats: analysis.downbeats,
        },
    })
}

/// Stores detected beats and tempo unless the source's tempo changed meanwhile. Returns
/// whether they were stored.
pub fn commit_detect_tempo(ctx: &mut DawContext, completed: CompletedTempoDetection) -> bool {
    let Some(waveform) = ctx
        .app_state
        .asset_library
        .source_map
        .get(completed.source_id)
    else {
        return false;
    };
    if TempoSnapshot::of(waveform) != completed.before {
        return false;
    }
    commit_beat_grid(ctx, completed.source_id, completed.grid)
}
