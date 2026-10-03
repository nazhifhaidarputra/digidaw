//! Realtime pitch-preserving stretch for Stretch-mode audio clips.
//!
//! Each playing clip that needs stretching borrows one realtime stretcher from a
//! fixed pool, keyed by track and clip. Voices are rebuilt every block, so a slot remembers
//! the clip content position it expects next: a matching voice continues seamlessly, anything
//! else (a new clip, a seek, a loop jump) resets and primes the stretcher so its output lines
//! up with the timeline. Stretchers run at the engine's DSP sample rate; a source recorded at
//! another rate is converted while feeding them, so their time ratio is the tempo ratio alone.

use karbeat_dsp::stretcher::{DefaultRealtimeStretcher, REALTIME_CHANNELS, RealtimeTimeStretcher};

use crate::{
    audio::engine::helper::LoopBounds,
    shared::{ClipId, TrackId},
};

/// Stretched clips that can play at once; more play resampled instead.
pub const STRETCH_SLOTS: usize = 8;
/// Frames fed to or taken from a stretcher per call.
const CHUNK: usize = 1024;

/// The source a stretched clip reads.
#[derive(Clone, Copy)]
pub struct StretchSource<'a> {
    pub buffer: &'a [f32],
    pub channels: usize,
    pub bounds: LoopBounds,
    /// Source frames; reads past the end are silent unless looping.
    pub frames: f64,
    pub is_looping: bool,
}

impl StretchSource<'_> {
    /// Frame at unwrapped source position `position`: silence before the start, and after the
    /// end unless looping.
    fn frame(&self, position: f64) -> [f32; 2] {
        if position < 0.0 || (!self.is_looping && position >= self.frames) {
            return [0.0, 0.0];
        }
        self.bounds.sample(
            self.buffer,
            self.bounds.read_pos(0.0, position),
            self.channels,
        )
    }
}

/// How a stretched clip is read, per output frame.
#[derive(Clone, Copy, Debug)]
pub struct StretchRate {
    /// Source frames per output frame, including the tempo change.
    pub step: f64,
    /// Source frames per engine frame: the sample-rate conversion alone.
    pub pitch_step: f64,
}

struct StretchSlot {
    stretcher: DefaultRealtimeStretcher,
    owner: Option<(TrackId, ClipId)>,
    used: bool,
    /// Clip content frame of the next output frame.
    next_content: u64,
    /// Next unwrapped source frame to feed.
    source_position: f64,
    /// Output frames still to drop after priming.
    discard: usize,
    input: [Vec<f32>; 2],
    output: [Vec<f32>; 2],
}

impl StretchSlot {
    /// Feeds `frames` source frames read at `pitch_step`, at most [`CHUNK`].
    fn feed(&mut self, frames: usize, pitch_step: f64, source: &StretchSource<'_>) {
        let frames = frames.clamp(1, CHUNK);
        let [left, right] = &mut self.input;
        for index in 0..frames {
            let [l, r] = source.frame(self.source_position + index as f64 * pitch_step);
            if let (Some(left), Some(right)) = (left.get_mut(index), right.get_mut(index)) {
                *left = l;
                *right = r;
            }
        }
        self.source_position += frames as f64 * pitch_step;
        self.stretcher.process(&[
            left.get(..frames).unwrap_or_default(),
            right.get(..frames).unwrap_or_default(),
        ]);
    }

    /// Restarts the stretcher so its next output frame is clip content frame `content`.
    fn prime(&mut self, content: u64, rate: StretchRate, source: &StretchSource<'_>) {
        self.stretcher.reset();
        let pad = self.stretcher.start_pad();
        // The lead-in is the audio just before the start, so the first frames are not faded.
        self.source_position = content as f64 * rate.step - pad as f64 * rate.pitch_step;
        let mut remaining = pad;
        while remaining > 0 {
            let frames = remaining.min(CHUNK);
            self.feed(frames, rate.pitch_step, source);
            remaining -= frames;
        }
        self.discard = self.stretcher.start_delay();
        self.next_content = content;
    }
}

/// Fixed set of realtime stretchers shared by the Stretch-mode clips playing at once.
pub struct StretchPool {
    slots: Vec<StretchSlot>,
    sample_rate: u32,
}

impl StretchPool {
    /// A pool without stretchers, used until [`Self::prepare`] runs.
    pub fn empty() -> Self {
        Self {
            slots: Vec::new(),
            sample_rate: 0,
        }
    }

    /// Builds the stretchers for `sample_rate`, unless they already run at it. Allocates, so
    /// call it at setup or on a sample-rate change, never from `process`.
    pub fn prepare(&mut self, sample_rate: u32) {
        if sample_rate == self.sample_rate && !self.slots.is_empty() {
            return;
        }
        self.sample_rate = sample_rate;
        self.slots = (0..STRETCH_SLOTS)
            .filter_map(|_| {
                DefaultRealtimeStretcher::new(sample_rate, REALTIME_CHANNELS, CHUNK).ok()
            })
            .map(|stretcher| StretchSlot {
                stretcher,
                owner: None,
                used: false,
                next_content: 0,
                source_position: 0.0,
                discard: 0,
                input: [vec![0.0; CHUNK], vec![0.0; CHUNK]],
                output: [vec![0.0; CHUNK], vec![0.0; CHUNK]],
            })
            .collect();
        if self.slots.len() < STRETCH_SLOTS {
            log::warn!(
                "Only {} of {STRETCH_SLOTS} realtime stretchers could be created",
                self.slots.len()
            );
        }
    }

    /// Renders `frames` stretched output frames of clip `key` starting at clip content frame
    /// `content`, handing each to `write(index, frame)`.
    ///
    /// Returns `false`, rendering nothing, when every stretcher is busy with another clip.
    pub fn render(
        &mut self,
        key: (TrackId, ClipId),
        content: u64,
        rate: StretchRate,
        source: &StretchSource<'_>,
        frames: usize,
        mut write: impl FnMut(usize, [f32; 2]),
    ) -> bool {
        let index = self
            .slots
            .iter()
            .position(|slot| slot.owner == Some(key))
            .or_else(|| self.slots.iter().position(|slot| slot.owner.is_none()));
        let Some(slot) = index.and_then(|index| self.slots.get_mut(index)) else {
            return false;
        };
        slot.used = true;
        // Output duration per input duration: input is fed at `pitch_step` source frames per
        // frame and output consumes `step`.
        slot.stretcher.set_time_ratio(rate.pitch_step / rate.step);
        if slot.owner != Some(key) || slot.next_content != content {
            slot.owner = Some(key);
            slot.prime(content, rate, source);
        }

        let mut written = 0;
        // Bounds the loop should the stretcher stop producing output.
        let mut feeds_left = 64 + frames / 64;
        while written < frames {
            let available = slot.stretcher.available();
            if available == 0 {
                if feeds_left == 0 {
                    break;
                }
                feeds_left -= 1;
                let required = slot.stretcher.samples_required();
                slot.feed(required, rate.pitch_step, source);
                continue;
            }
            let wanted = if slot.discard > 0 {
                slot.discard
            } else {
                frames - written
            };
            let take = available.min(wanted).min(CHUNK);
            let [left, right] = &mut slot.output;
            let got = slot.stretcher.retrieve(&mut [
                left.get_mut(..take).unwrap_or_default(),
                right.get_mut(..take).unwrap_or_default(),
            ]);
            if got == 0 {
                break;
            }
            if slot.discard > 0 {
                slot.discard -= got.min(slot.discard);
                continue;
            }
            for (offset, (l, r)) in left.iter().zip(right.iter()).take(got).enumerate() {
                write(written + offset, [*l, *r]);
            }
            written += got;
        }
        slot.next_content = content + frames as u64;
        true
    }

    /// Frees the stretchers of clips that did not play this block. Call once per block.
    pub fn end_block(&mut self) {
        for slot in &mut self.slots {
            if !slot.used {
                slot.owner = None;
            }
            slot.used = false;
        }
    }
}
