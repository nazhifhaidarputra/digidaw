use serde::{Deserialize, Serialize};

use crate::core::project::envelope::GainEnvelope;
use crate::shared::id::AudioSourceId;

pub type AudioFrame = [f32; 2];

use memmap2::Mmap;
/// Audio Waveform data of an audio sample
use std::{path::PathBuf, sync::Arc};

// STATIC global variables for waveform mipmaps

/// ======================================
/// AudioSampleMode
/// Determines how source content responds to project tempo.
/// Clip placement is tick-based in every mode.
/// ======================================
#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Default)]
pub enum AudioSampleMode {
    /// Sample-based duration with no tempo stretching.
    #[default]
    Default,
    /// ticks (BPM-dependent, for time-stretched audio, preserved pitch)
    Stretch,
    /// ticks (BPM-dependent, for time-stretched audio, do not preserve pitch)
    Resampled,
}

/// Offline processing recipe for a waveform, applied by an offline render.
#[derive(Clone, Serialize, Deserialize, Debug, PartialEq)]
#[serde(default)]
pub struct WaveformEdits {
    /// Scale the peak to full scale.
    pub normalize: bool,
    /// Invert the polarity.
    pub invert: bool,
    /// Play the audio backwards.
    pub reverse: bool,
    /// Pitch shift in semitones.
    pub pitch_semitones: f32,
    /// Preserve the spectral envelope when shifting pitch, for voices and instruments.
    pub preserve_formants: bool,
    /// Time-stretch ratio; 1.0 keeps the original length.
    pub time_ratio: f32,
    /// Stretch beat by beat so every detected beat lands on the grid, instead of by one
    /// constant ratio. Needs a [`BeatGrid`] on the waveform.
    pub warp: bool,
}

impl Default for WaveformEdits {
    fn default() -> Self {
        Self {
            normalize: false,
            invert: false,
            reverse: false,
            pitch_semitones: 0.0,
            preserve_formants: false,
            time_ratio: 1.0,
            warp: false,
        }
    }
}

impl WaveformEdits {
    /// Whether the recipe stretches the audio in time.
    pub fn stretches(&self) -> bool {
        (self.time_ratio - 1.0).abs() > f32::EPSILON || self.warp
    }

    /// Whether the recipe changes the audio, so it needs an offline render.
    pub fn needs_render(&self) -> bool {
        self.stretches()
            || self.pitch_semitones.abs() > f32::EPSILON
            || self.reverse
            || self.invert
            || self.normalize
    }

    /// Whether `other` differs from this recipe only in the time ratio, which realtime
    /// stretching can make up for while a new render is prepared.
    pub fn differs_only_in_tempo(&self, other: &Self) -> bool {
        Self {
            time_ratio: other.time_ratio,
            ..self.clone()
        } == *other
    }
}

fn unity_gain() -> f32 {
    1.0
}

/// Beats detected in a waveform, in seconds from the start of the original audio.
#[derive(Clone, Serialize, Deserialize, Debug, PartialEq, Default)]
#[serde(default)]
pub struct BeatGrid {
    /// Detected tempo.
    pub bpm: f32,
    /// How regular the detected beats are, from 0.0 (erratic) to 1.0 (steady).
    pub confidence: f32,
    /// Beat times.
    pub beats: Vec<f32>,
    /// Downbeat (bar start) times; each is also in `beats`.
    pub downbeats: Vec<f32>,
}

/// An offline-processed render of a waveform.
///
/// Only the recipe is saved. The rendered buffer is a cache rebuilt from the original audio, has
/// the same channel count and sample rate as the original, and replaces it for playback.
#[derive(Clone, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct EditedWaveform {
    /// Edits applied to the original audio.
    pub edits: WaveformEdits,
    /// Rendered result; `None` until an offline render produces it.
    #[serde(skip)]
    pub buffer: Option<Arc<Mmap>>,
    /// Playback gain of the render: `1 / peak` when normalizing, else 1.0.
    #[serde(skip, default = "unity_gain")]
    pub gain: f32,
}

impl Default for EditedWaveform {
    fn default() -> Self {
        Self {
            edits: WaveformEdits::default(),
            buffer: None,
            gain: 1.0,
        }
    }
}

#[derive(Clone, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct AudioWaveform {
    pub id: Option<AudioSourceId>,
    /// Audio buffer of samples
    #[serde(skip)]
    pub buffer: Option<Arc<Mmap>>,
    /// path to the audio source file
    pub file_path: PathBuf,
    /// name of the audio waveform
    pub name: String,
    /// Original sample rate of the audio waveform
    pub original_sample_rate: u32,
    /// Current sample rate of the audio waveform
    pub sample_rate: u32,
    /// Number of channels of the audio waveform
    pub channels: u16,
    /// duration of the entire audio waveform in seconds
    pub duration: f64,
    /// Root note of the audio waveform
    pub root_note: u8,
    /// Fine tune of the audio waveform
    pub fine_tune: i16,
    /// Tempo the original audio is at, which Stretch and Resampled modes play relative to.
    ///
    /// `None` when unknown: tempo detection sets it, and entering a tempo-following mode
    /// without a detected tempo anchors it to the project tempo at that moment, so the audio
    /// plays as it was placed. Never guessed.
    pub original_bpm: Option<f32>,
    /// Start of the audio waveform in samples
    pub trim_start: u32,
    /// End of the audio waveform in samples
    pub trim_end: u32,
    /// Whether the audio waveform is looping
    pub is_looping: bool,
    /// Whether the audio waveform is normalized
    pub normalized: bool,
    /// Whether the audio waveform is muted
    pub muted: bool,
    /// How source duration and playback rate respond to tempo.
    pub sample_mode: AudioSampleMode,
    /// Fades, loop crossfade, and gain points shared by every clip referencing this waveform.
    pub envelope: GainEnvelope,
    /// Offline-processed version of the audio, when edits have been applied.
    pub edited: Option<EditedWaveform>,
    /// Beats detected by tempo analysis, if it ran.
    pub beat_grid: Option<BeatGrid>,
}

impl PartialEq for AudioWaveform {
    fn eq(&self, other: &Self) -> bool {
        self.id == other.id
            && self.file_path == other.file_path
            && self.name == other.name
            && self.sample_rate == other.sample_rate
            && self.channels == other.channels
            && self.duration == other.duration
            && self.root_note == other.root_note
            && self.fine_tune == other.fine_tune
            && self.trim_start == other.trim_start
            && self.trim_end == other.trim_end
            && self.is_looping == other.is_looping
            && self.normalized == other.normalized
            && self.muted == other.muted
            && self.sample_mode == other.sample_mode
            && self.original_bpm == other.original_bpm
            && self.envelope == other.envelope
            && self.edited.as_ref().map(|edited| &edited.edits)
                == other.edited.as_ref().map(|edited| &edited.edits)
            && self.beat_grid == other.beat_grid
    }
}

impl Default for AudioWaveform {
    fn default() -> Self {
        Self {
            id: None,
            buffer: None,
            file_path: PathBuf::new(),
            name: "Sample".to_string(),
            original_sample_rate: 44100,
            sample_rate: 44100,
            channels: 2,
            duration: 0.0,
            root_note: 60, // C4
            fine_tune: 0,
            trim_start: 0,
            trim_end: 0,
            is_looping: false,
            normalized: false,
            muted: false,
            sample_mode: AudioSampleMode::Default,
            original_bpm: None,
            envelope: GainEnvelope::default(),
            edited: None,
            beat_grid: None,
        }
    }
}

/// A context struct providing the audio engine with everything it needs
/// to render the waveform correctly based on the current sample mode.
pub struct WaveformPlaybackContext<'a> {
    /// The trimmed, ready-to-read audio buffer slice
    pub buffer: &'a [f32],
    /// Multiplier for the read-pointer speed (e.g., 2.0 = play twice as fast)
    pub playback_rate: f64,
    /// Multiplier for the pitch (e.g., 2.0 = one octave up).
    /// If playback_rate != pitch_rate, the engine must use a time-stretching algorithm.
    pub pitch_ratio: f64,
    /// The mode, passed along just in case the engine needs algorithmic context
    pub mode: AudioSampleMode,
}

impl AudioWaveform {
    pub fn try_assign_id(&mut self, id: AudioSourceId) -> anyhow::Result<()> {
        if self.id.is_some() {
            return Err(anyhow::anyhow!("Audio waveform already has an ID"));
        }
        self.id = Some(id);
        Ok(())
    }

    /// The buffer playback reads: the offline-processed render when one exists, else the
    /// original audio.
    pub fn active_buffer(&self) -> Option<&Arc<Mmap>> {
        self.edited
            .as_ref()
            .and_then(|edited| edited.buffer.as_ref())
            .or(self.buffer.as_ref())
    }

    /// The rendered buffer, when an offline render of the edits is loaded.
    fn rendered_buffer(&self) -> Option<&Arc<Mmap>> {
        self.edited
            .as_ref()
            .and_then(|edited| edited.buffer.as_ref())
    }

    /// Tempo of the audio playback reads: the render's tempo when a render is loaded, since
    /// the render stretched `original_bpm` by the recipe's time ratio. `None` when the source
    /// tempo is unknown.
    pub fn playback_bpm(&self) -> Option<f32> {
        let original = self.original_bpm.filter(|bpm| *bpm > 0.0)?;
        Some(match (&self.edited, self.rendered_buffer()) {
            (Some(edited), Some(_)) if edited.edits.time_ratio > 0.0 => {
                original / edited.edits.time_ratio
            }
            _ => original,
        })
    }

    /// Gain to play the active buffer at: the render's normalization gain, else 1.0.
    pub fn playback_gain(&self) -> f32 {
        match (&self.edited, self.rendered_buffer()) {
            (Some(edited), Some(_)) => edited.gain,
            _ => 1.0,
        }
    }

    /// Read-speed multiplier for `project_bpm` under the waveform's sample mode. An unknown
    /// source tempo plays at its own speed.
    pub fn tempo_rate(&self, project_bpm: f32) -> f64 {
        match (self.sample_mode, self.playback_bpm()) {
            (AudioSampleMode::Stretch | AudioSampleMode::Resampled, Some(bpm))
                if project_bpm > 0.0 =>
            {
                f64::from(project_bpm) / f64::from(bpm)
            }
            _ => 1.0,
        }
    }

    /// Frames in the active buffer per frame of the original audio, used to map trim points
    /// (stored in original frames) onto a render of a different length.
    fn active_frame_scale(&self) -> f64 {
        let (Some(rendered), Some(original)) = (self.rendered_buffer(), self.buffer.as_ref())
        else {
            return 1.0;
        };
        if original.is_empty() {
            return 1.0;
        }
        rendered.len() as f64 / original.len() as f64
    }

    /// Returns a strictly valid slice of the audio buffer, cropped exactly to
    /// the trim_start and trim_end boundaries.
    pub fn get_playable_buffer<'a>(&'a self) -> Option<&'a [f32]> {
        let raw_buffer: &[f32] = bytemuck::try_cast_slice(&self.active_buffer()?[..]).ok()?;
        let channels = self.channels as usize;

        if channels == 0 || raw_buffer.is_empty() {
            return None;
        }

        let total_frames = raw_buffer.len() / channels;
        let scale = self.active_frame_scale();
        let scaled = |frame: u32| (f64::from(frame) * scale).round() as usize;

        let start_frame = scaled(self.trim_start).min(total_frames);
        let end_frame = if self.trim_end > 0 {
            scaled(self.trim_end).min(total_frames).max(start_frame)
        } else {
            total_frames
        };

        let start_idx = start_frame * channels;
        let end_idx = end_frame * channels;

        if start_idx >= raw_buffer.len() || end_idx > raw_buffer.len() || start_idx >= end_idx {
            return None;
        }

        Some(&raw_buffer[start_idx..end_idx])
    }

    /// Abstracts the logic of AudioSampleModes. The audio engine passes the project's
    /// current BPM, and this returns the exact parameters needed to render the audio.
    pub fn get_playback_context<'a>(
        &'a self,
        project_bpm: f32,
    ) -> Option<WaveformPlaybackContext<'a>> {
        let buffer = self.get_playable_buffer()?;

        let (playback_rate, pitch_ratio) = match self.sample_mode {
            // Default: Ignores BPM entirely. Plays 1:1 speed, original pitch.
            AudioSampleMode::Default => (1.0, 1.0),

            // Stretch: Speeds up/slows down to match project BPM, but pitch remains 1.0
            // (Engine must use phase vocoder/granular synthesis to accommodate this)
            AudioSampleMode::Stretch => (self.tempo_rate(project_bpm), 1.0),

            // Resampled: Speeds up/slows down to match project BPM, pitch bends with it
            // (Classic turntable/tape effect. Engine just reads faster/slower)
            AudioSampleMode::Resampled => {
                let ratio = self.tempo_rate(project_bpm);
                (ratio, ratio)
            }
        };

        Some(WaveformPlaybackContext {
            buffer,
            playback_rate,
            pitch_ratio,
            mode: self.sample_mode.clone(),
        })
    }
}

#[cfg(test)]
#[allow(
    clippy::expect_used,
    clippy::unwrap_used,
    reason = "test fixtures fail immediately on unexpected results"
)]
mod tests {
    use std::sync::Arc;

    use memmap2::{Mmap, MmapOptions};

    use super::{AudioSampleMode, AudioWaveform, EditedWaveform, WaveformEdits};

    fn mono(frames: usize) -> Arc<Mmap> {
        let samples: Vec<f32> = (0..frames).map(|frame| frame as f32).collect();
        let bytes: &[u8] = bytemuck::cast_slice(&samples);
        let mut map = MmapOptions::new().len(bytes.len()).map_anon().expect("map");
        map.copy_from_slice(bytes);
        Arc::new(map.make_read_only().expect("read-only"))
    }

    fn waveform(frames: usize) -> AudioWaveform {
        AudioWaveform {
            buffer: Some(mono(frames)),
            channels: 1,
            original_bpm: Some(100.0),
            sample_mode: AudioSampleMode::Stretch,
            ..AudioWaveform::default()
        }
    }

    fn fitted(frames: usize, time_ratio: f32, rendered: Option<usize>) -> AudioWaveform {
        AudioWaveform {
            edited: Some(EditedWaveform {
                edits: WaveformEdits {
                    time_ratio,
                    ..WaveformEdits::default()
                },
                buffer: rendered.map(mono),
                gain: 1.0,
            }),
            ..waveform(frames)
        }
    }

    #[test]
    fn tempo_rate_follows_the_render_once_it_is_loaded() {
        // Fitted from 100 to 125 BPM: the render plays at 125.
        let close = |actual: f64, expected: f64| (actual - expected).abs() < 1e-6;
        let pending = fitted(1_000, 0.8, None);
        assert!(close(
            f64::from(pending.playback_bpm().expect("known tempo")),
            100.0
        ));
        assert!(close(pending.tempo_rate(125.0), 1.25));

        let rendered = fitted(1_000, 0.8, Some(800));
        assert!(close(
            f64::from(rendered.playback_bpm().expect("known tempo")),
            125.0
        ));
        assert!(close(rendered.tempo_rate(125.0), 1.0));
        assert!(close(rendered.tempo_rate(150.0), 1.2));
    }

    #[test]
    fn unknown_source_tempo_plays_at_its_own_speed() {
        for sample_mode in [AudioSampleMode::Stretch, AudioSampleMode::Resampled] {
            let waveform = AudioWaveform {
                original_bpm: None,
                sample_mode,
                ..waveform(1_000)
            };
            assert_eq!(waveform.playback_bpm(), None);
            assert_eq!(waveform.tempo_rate(157.0), 1.0);
        }
    }

    #[test]
    fn default_mode_ignores_tempo() {
        let waveform = AudioWaveform {
            sample_mode: AudioSampleMode::Default,
            ..fitted(1_000, 0.8, Some(800))
        };
        assert_eq!(waveform.tempo_rate(180.0), 1.0);
    }

    #[test]
    fn trim_points_scale_onto_a_render_of_a_different_length() {
        let mut rendered = fitted(1_000, 0.5, Some(500));
        rendered.trim_start = 200;
        rendered.trim_end = 800;

        let playable = rendered.get_playable_buffer().unwrap();
        assert_eq!(playable.len(), 300);
        assert_eq!(playable.first(), Some(&100.0));
    }

    #[test]
    fn identity_recipe_is_recognized() {
        assert!(!WaveformEdits::default().needs_render());
        // Formant preservation only matters once the pitch moves.
        assert!(
            !WaveformEdits {
                preserve_formants: true,
                ..WaveformEdits::default()
            }
            .needs_render()
        );
        for edits in [
            WaveformEdits {
                pitch_semitones: -0.5,
                ..WaveformEdits::default()
            },
            WaveformEdits {
                warp: true,
                ..WaveformEdits::default()
            },
            WaveformEdits {
                reverse: true,
                ..WaveformEdits::default()
            },
            WaveformEdits {
                normalize: true,
                ..WaveformEdits::default()
            },
        ] {
            assert!(edits.needs_render());
        }
    }

    #[test]
    fn only_a_tempo_change_can_keep_the_render() {
        let edits = WaveformEdits {
            time_ratio: 1.2,
            reverse: true,
            ..WaveformEdits::default()
        };
        let retimed = WaveformEdits {
            time_ratio: 0.9,
            ..edits.clone()
        };
        assert!(edits.differs_only_in_tempo(&retimed));
        let inverted = WaveformEdits {
            invert: true,
            ..edits.clone()
        };
        assert!(!edits.differs_only_in_tempo(&inverted));
    }
}
