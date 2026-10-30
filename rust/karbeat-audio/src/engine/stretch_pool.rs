//! Realtime time stretch and pitch shift for audio clips and previews.
//!
//! Each playing voice that needs it, a Stretch-mode clip off its own tempo or a source with a
//! realtime pitch shift, borrows one realtime stretcher from a fixed pool, keyed by
//! [`StretchKey`]. Voices are rebuilt every block, so a slot remembers the content position it
//! expects next: a matching voice continues seamlessly, anything else (a new clip, a seek, a
//! loop jump) primes the stretcher so its output lines up with the timeline. Stretchers run at
//! the engine's DSP sample rate; a source recorded at another rate is converted while feeding
//! them.

use karbeat_dsp::stretcher::{DefaultRealtimeStretcher, REALTIME_CHANNELS, RealtimeTimeStretcher};

use crate::engine::helper::LoopBounds;
use karbeat_core::shared::{ClipId, TrackId};

/// Voices that can stretch at once; more play resampled instead.
pub const STRETCH_SLOTS: usize = 8;
/// Output frames rendered per stretcher call.
const CHUNK: usize = 1024;
/// Input frames per output frame a full [`CHUNK`] can take; faster tempo ratios render in
/// shorter calls.
const MAX_FEED_RATIO: usize = 8;

/// The voice a stretcher belongs to.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StretchKey {
    Clip(TrackId, ClipId),
    /// A preview, by its index among the playing previews.
    Preview(usize),
}

/// The source a stretched voice reads.
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

/// How a stretched voice is read and shifted, per output frame.
#[derive(Clone, Copy, Debug)]
pub struct StretchRate {
    /// Source frames per output frame, including the tempo change.
    pub step: f64,
    /// Source frames per stretcher input frame: the sample-rate conversion, and the tempo
    /// change too when the pitch should follow it.
    pub feed_step: f64,
    /// Frequency multiplier the stretcher applies on top.
    pub pitch_scale: f64,
    pub preserve_formants: bool,
}

impl StretchRate {
    /// Stretcher input frames per output frame.
    fn feed_ratio(&self) -> f64 {
        self.step / self.feed_step
    }
}

struct StretchSlot {
    stretcher: DefaultRealtimeStretcher,
    /// Content frame of the next output frame.
    next_content: u64,
    /// Next unwrapped source frame to feed.
    source_position: f64,
    /// Fraction of an input frame owed to the stretcher, so the fed frames follow the ratio.
    feed_debt: f64,
    /// Output frames still to drop after priming.
    discard: usize,
    input: [Vec<f32>; 2],
    output: [Vec<f32>; 2],
}

impl StretchSlot {
    /// Reads up to `frames` source frames at `feed_step` into the input buffers; returns how
    /// many.
    fn load(&mut self, frames: usize, feed_step: f64, source: &StretchSource<'_>) -> usize {
        let [left, right] = &mut self.input;
        let frames = frames.min(left.len()).min(right.len());
        for (index, (left, right)) in left
            .iter_mut()
            .zip(right.iter_mut())
            .take(frames)
            .enumerate()
        {
            [*left, *right] = source.frame(self.source_position + index as f64 * feed_step);
        }
        self.source_position += frames as f64 * feed_step;
        frames
    }

    /// Restarts the stretcher so its next output frame is content frame `content`.
    fn prime(&mut self, content: u64, rate: StretchRate, source: &StretchSource<'_>) {
        self.stretcher.reset();
        let history = self.stretcher.seek_frames();
        // The seek ends one input latency past the start, which puts the processing point on
        // it; the audio just before the start is history, so the first frames are not faded.
        let lead = history.saturating_sub(self.stretcher.input_latency());
        self.source_position = content as f64 * rate.step - lead as f64 * rate.feed_step;
        let frames = self.load(history, rate.feed_step, source);
        let [left, right] = &self.input;
        self.stretcher.seek(
            &[
                left.get(..frames).unwrap_or_default(),
                right.get(..frames).unwrap_or_default(),
            ],
            rate.feed_ratio(),
        );
        self.feed_debt = 0.0;
        // Output trails the processing point; drop it so the start lines up.
        self.discard = self.stretcher.output_latency();
        self.next_content = content;
    }

    /// Runs `frames` output frames, at most [`CHUNK`], through the stretcher into the output
    /// buffers.
    fn process(&mut self, frames: usize, rate: StretchRate, source: &StretchSource<'_>) {
        self.feed_debt += frames as f64 * rate.feed_ratio();
        let wanted = self.feed_debt.floor().max(0.0) as usize;
        let fed = self.load(wanted, rate.feed_step, source);
        self.feed_debt -= fed as f64;
        let [in_left, in_right] = &self.input;
        let [out_left, out_right] = &mut self.output;
        self.stretcher.process(
            &[
                in_left.get(..fed).unwrap_or_default(),
                in_right.get(..fed).unwrap_or_default(),
            ],
            &mut [
                out_left.get_mut(..frames).unwrap_or_default(),
                out_right.get_mut(..frames).unwrap_or_default(),
            ],
        );
    }
}

/// A stretcher taken out of the pool for one voice and one block, so voices rendered on
/// different workers never share pool state. Hand it back with [`StretchPool::give_back`].
pub struct StretchLease {
    index: usize,
    /// Voice the slot played before this lease.
    previous: Option<StretchKey>,
    /// Whether the slot last played another voice and must be primed.
    fresh: bool,
    slot: StretchSlot,
}

impl StretchLease {
    /// Renders `frames` stretched output frames starting at content frame `content`, handing
    /// each to `write(index, frame)`.
    pub fn render(
        &mut self,
        content: u64,
        rate: StretchRate,
        source: &StretchSource<'_>,
        frames: usize,
        mut write: impl FnMut(usize, [f32; 2]),
    ) {
        let slot = &mut self.slot;
        slot.stretcher.set_pitch_scale(rate.pitch_scale);
        slot.stretcher.set_preserve_formants(rate.preserve_formants);
        if self.fresh || slot.next_content != content {
            self.fresh = false;
            slot.prime(content, rate, source);
        }

        // Keep each call's input within the buffers.
        let input_frames = slot.input[0].len();
        let per_call = ((input_frames as f64 / rate.feed_ratio()).floor() as usize).clamp(1, CHUNK);
        let mut written = 0;
        while written < frames {
            let wanted = if slot.discard > 0 {
                slot.discard
            } else {
                frames - written
            };
            let take = wanted.min(per_call);
            slot.process(take, rate, source);
            if slot.discard > 0 {
                slot.discard -= take;
                continue;
            }
            let [left, right] = &slot.output;
            for (offset, (l, r)) in left.iter().zip(right.iter()).take(take).enumerate() {
                write(written + offset, [*l, *r]);
            }
            written += take;
        }
        slot.next_content = content + frames as u64;
    }
}

/// Fixed set of realtime stretchers shared by the voices stretching at once.
pub struct StretchPool {
    /// `None` while the slot is leased to a voice.
    slots: Vec<Option<StretchSlot>>,
    /// Owner of each slot, kept here so leased slots stay claimed.
    owners: Vec<Option<StretchKey>>,
    used: Vec<bool>,
    sample_rate: u32,
}

impl StretchPool {
    /// A pool without stretchers, used until [`Self::prepare`] runs.
    pub fn empty() -> Self {
        Self {
            slots: Vec::new(),
            owners: Vec::new(),
            used: Vec::new(),
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
            .filter_map(|_| DefaultRealtimeStretcher::new(sample_rate, REALTIME_CHANNELS).ok())
            .map(|stretcher| {
                let input = stretcher.seek_frames().max(CHUNK * MAX_FEED_RATIO);
                Some(StretchSlot {
                    stretcher,
                    next_content: 0,
                    source_position: 0.0,
                    feed_debt: 0.0,
                    discard: 0,
                    input: [vec![0.0; input], vec![0.0; input]],
                    output: [vec![0.0; CHUNK], vec![0.0; CHUNK]],
                })
            })
            .collect();
        self.owners = vec![None; self.slots.len()];
        self.used = vec![false; self.slots.len()];
        if self.slots.len() < STRETCH_SLOTS {
            tracing::warn!(
                "Only {} of {STRETCH_SLOTS} realtime stretchers could be created",
                self.slots.len()
            );
        }
    }

    /// Takes the stretcher of voice `key` for this block: the one it already plays through,
    /// else a free one. Returns `None` when every stretcher is busy with another voice.
    pub fn lease(&mut self, key: StretchKey) -> Option<StretchLease> {
        let index = self
            .owners
            .iter()
            .position(|owner| *owner == Some(key))
            .or_else(|| self.owners.iter().position(Option::is_none))?;
        let slot = self.slots.get_mut(index)?.take()?;
        let previous = self.owners[index];
        let fresh = previous != Some(key);
        self.owners[index] = Some(key);
        self.used[index] = true;
        Some(StretchLease {
            index,
            previous,
            fresh,
            slot,
        })
    }

    /// Returns a leased stretcher to the pool.
    pub fn give_back(&mut self, lease: StretchLease) {
        if let Some(place) = self.slots.get_mut(lease.index) {
            if lease.fresh {
                // Never rendered: the slot still holds the previous voice's stream.
                self.owners[lease.index] = lease.previous;
            }
            *place = Some(lease.slot);
        }
    }

    /// Renders `frames` stretched output frames of voice `key` starting at content frame
    /// `content`, handing each to `write(index, frame)`.
    ///
    /// Returns `false`, rendering nothing, when every stretcher is busy with another voice.
    pub fn render(
        &mut self,
        key: StretchKey,
        content: u64,
        rate: StretchRate,
        source: &StretchSource<'_>,
        frames: usize,
        write: impl FnMut(usize, [f32; 2]),
    ) -> bool {
        let Some(mut lease) = self.lease(key) else {
            return false;
        };
        lease.render(content, rate, source, frames, write);
        self.give_back(lease);
        true
    }

    /// Frees the stretchers of voices that did not play this block. Call once per block.
    pub fn end_block(&mut self) {
        for (owner, used) in self.owners.iter_mut().zip(&mut self.used) {
            if !*used {
                *owner = None;
            }
            *used = false;
        }
    }
}
