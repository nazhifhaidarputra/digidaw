use crate::{DOWNBEAT_BYTES, OFFBEAT_BYTES, engine::helper::load_internal_wav};
use karbeat_core::{core::project::TickScale, shared::constants::f64::PPQ};
use karbeat_host::retire::Retiree;

/// A user-supplied click that replaces both built-in metronome sounds.
///
/// Both buffers are rendered ahead of time, so playback only converts their sample rate to the
/// engine's.
#[derive(Debug, Clone, PartialEq)]
pub struct MetronomeClick {
    /// Mono samples played on the first beat of each bar.
    pub downbeat: Vec<f32>,
    /// Mono samples played on every other beat.
    pub offbeat: Vec<f32>,
    /// Sample rate both buffers were rendered at.
    pub sample_rate: u32,
}

/// Most clicks waiting for delay compensation at once. A click waits at most the system
/// latency, so this covers 32 beats inside that window, far more than any real tempo and
/// latency produce.
const PENDING_CLICKS: usize = 32;

/// A click due to start at an output frame.
#[derive(Clone, Copy, Default)]
struct ScheduledClick {
    /// Output frame (`Transport::render_frame` clock) on which the click starts.
    frame: u64,
    /// Whether the click marks the first beat of a bar.
    downbeat: bool,
}

/// Where one stretch of output sits on the timeline, for placing clicks on it.
#[derive(Clone, Copy)]
pub(super) struct ClickTiming {
    /// Timeline sample of the stretch's first frame, before delay compensation.
    pub start_playhead: u32,
    /// Output frame of the stretch's first frame.
    pub render_frame: u64,
    /// Frames by which delay compensation holds back everything else in the output.
    pub latency: u32,
    /// Tempo in beats per minute.
    pub bpm: f32,
    /// Engine sample rate.
    pub sample_rate: u32,
    /// Beats in one bar; the first one gets the downbeat sound.
    pub beats_per_bar: u8,
}

pub struct MetronomeState {
    is_active: bool,
    downbeat_buffer: Vec<f32>,
    offbeat_buffer: Vec<f32>,
    /// Retires off the audio thread when replaced.
    custom_click: Option<Retiree<MetronomeClick>>,
    play_index: usize,
    /// Read position in the custom click, in its own samples.
    custom_position: f64,
    is_playing: bool,
    is_downbeat: bool,
    /// Clicks placed on the timeline but not yet audible, in frame order. A fixed ring, so
    /// scheduling never allocates on the audio thread.
    pending: [ScheduledClick; PENDING_CLICKS],
    /// Index of the oldest pending click.
    pending_head: usize,
    /// Number of pending clicks.
    pending_len: usize,
}

impl MetronomeState {
    pub(super) fn set_active(&mut self, active: bool) {
        self.is_active = active;
        if !active {
            self.is_playing = false;
            self.pending_len = 0;
        }
    }

    /// Replaces the custom click, or restores the built-in sounds with `None`. The replaced
    /// click retires off the audio thread.
    pub(super) fn set_custom_click(&mut self, click: Option<Retiree<MetronomeClick>>) {
        self.is_playing = false;
        self.custom_click = click;
    }

    /// Places the beats that fall in this stretch of the timeline and mixes the clicks due in
    /// it into `output`.
    ///
    /// Beats sit where the sequencer puts notes on them (`TickScale::to_samples` of whole
    /// quarter notes), and each click is held back by `timing.latency` like every other path
    /// through delay compensation. Holding back the click itself, rather than reading the
    /// timeline `latency` frames earlier, keeps it right across loop wraps and seeks: the tracks
    /// still play out the audio from before the jump for `latency` frames, and so do the
    /// clicks.
    pub(super) fn render(&mut self, output: &mut [f32], channels: usize, timing: ClickTiming) {
        if !self.is_active || channels == 0 {
            return;
        }
        self.schedule(output.len() / channels, timing);
        self.play(output, channels, timing.render_frame, timing.sample_rate);
    }

    /// Mixes clicks already placed on the timeline into `output` without placing new ones, for
    /// blocks rendered while the transport is stopped. Clicks still waiting for delay
    /// compensation play out like the tracks' delayed audio does.
    pub(super) fn render_tail(
        &mut self,
        output: &mut [f32],
        channels: usize,
        render_frame: u64,
        sample_rate: u32,
    ) {
        if !self.is_active || channels == 0 {
            return;
        }
        self.play(output, channels, render_frame, sample_rate);
    }

    fn schedule(&mut self, frames: usize, timing: ClickTiming) {
        let scale = TickScale::new(timing.bpm, timing.sample_rate);
        let samples_per_beat = scale.samples_per_tick() * PPQ;
        // Below one sample per beat, several beats would share a frame.
        if !samples_per_beat.is_finite() || samples_per_beat < 1.0 {
            return;
        }
        let beat_sample = |beat: u64| scale.to_samples(beat * PPQ as u64);
        let start = u64::from(timing.start_playhead);
        let end = start + frames as u64;
        let beats_per_bar = u64::from(timing.beats_per_bar.max(1));

        // `floor(start / samples_per_beat)` rounds to a beat at or before `start`.
        let mut beat = (start as f64 / samples_per_beat) as u64;
        if beat_sample(beat) < start {
            beat += 1;
        }
        loop {
            let sample = beat_sample(beat);
            if sample >= end {
                break;
            }
            self.push_pending(ScheduledClick {
                frame: timing.render_frame + (sample - start) + u64::from(timing.latency),
                downbeat: beat.is_multiple_of(beats_per_bar),
            });
            beat += 1;
        }
    }

    fn push_pending(&mut self, click: ScheduledClick) {
        // A drop in latency can place a click before ones placed under the old latency. Those
        // came from earlier beats, and this click restarts the sound anyway, so drop them to
        // keep the queue in frame order.
        while self.pending_len > 0 {
            let last = (self.pending_head + self.pending_len - 1) % PENDING_CLICKS;
            if self.pending[last].frame < click.frame {
                break;
            }
            self.pending_len -= 1;
        }
        if self.pending_len == PENDING_CLICKS {
            // Unreachable with real tempos and latencies; losing the oldest click beats
            // allocating on the audio thread.
            self.pending_head = (self.pending_head + 1) % PENDING_CLICKS;
            self.pending_len -= 1;
        }
        let slot = (self.pending_head + self.pending_len) % PENDING_CLICKS;
        self.pending[slot] = click;
        self.pending_len += 1;
    }

    /// Pops the click due at or before `frame`, if any. Clicks are in frame order, so a late
    /// one (placed after its frame passed) starts now rather than never.
    fn pop_due(&mut self, frame: u64) -> Option<ScheduledClick> {
        let mut due = None;
        while self.pending_len > 0 && self.pending[self.pending_head].frame <= frame {
            due = Some(self.pending[self.pending_head]);
            self.pending_head = (self.pending_head + 1) % PENDING_CLICKS;
            self.pending_len -= 1;
        }
        due
    }

    fn play(&mut self, output: &mut [f32], channels: usize, render_frame: u64, sample_rate: u32) {
        for (frame_index, output_frame) in output.chunks_mut(channels).enumerate() {
            if let Some(click) = self.pop_due(render_frame + frame_index as u64) {
                // Restarting here cuts off whatever is left of the previous click.
                self.is_playing = true;
                self.play_index = 0;
                self.custom_position = 0.0;
                self.is_downbeat = click.downbeat;
            }

            if !self.is_playing {
                continue;
            }

            if let Some(click) = &self.custom_click {
                let samples = if self.is_downbeat {
                    &click.downbeat
                } else {
                    &click.offbeat
                };
                let index = self.custom_position as usize;
                let Some(&current) = samples.get(index) else {
                    self.is_playing = false;
                    continue;
                };
                let next = samples.get(index + 1).copied().unwrap_or(0.0);
                let fraction = (self.custom_position - index as f64) as f32;
                let sample = current + (next - current) * fraction;
                for output_sample in output_frame {
                    *output_sample += sample;
                }
                self.custom_position += f64::from(click.sample_rate) / f64::from(sample_rate);
                continue;
            }

            let source = if self.is_downbeat {
                &self.downbeat_buffer
            } else {
                &self.offbeat_buffer
            };

            if let Some(sample) = source.get(self.play_index) {
                for output_sample in output_frame {
                    *output_sample += sample;
                }
                self.play_index += 1;
            } else {
                self.is_playing = false;
            }
        }
    }
}

impl Default for MetronomeState {
    fn default() -> Self {
        Self {
            is_active: false,
            downbeat_buffer: load_internal_wav(DOWNBEAT_BYTES),
            offbeat_buffer: load_internal_wav(OFFBEAT_BYTES),
            custom_click: None,
            play_index: 0,
            custom_position: 0.0,
            is_playing: false,
            is_downbeat: true,
            pending: [ScheduledClick::default(); PENDING_CLICKS],
            pending_head: 0,
            pending_len: 0,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{ClickTiming, MetronomeClick, MetronomeState, PENDING_CLICKS, ScheduledClick};
    use crate::commands::retiring;

    fn metronome(custom_click: Option<MetronomeClick>) -> MetronomeState {
        MetronomeState {
            is_active: true,
            downbeat_buffer: vec![0.5],
            offbeat_buffer: vec![0.25],
            custom_click: custom_click.map(retiring),
            play_index: 0,
            custom_position: 0.0,
            is_playing: false,
            is_downbeat: false,
            pending: [ScheduledClick::default(); PENDING_CLICKS],
            pending_head: 0,
            pending_len: 0,
        }
    }

    fn at(start_playhead: u32, bpm: f32, sample_rate: u32) -> ClickTiming {
        ClickTiming {
            start_playhead,
            render_frame: 0,
            latency: 0,
            bpm,
            sample_rate,
            beats_per_bar: 4,
        }
    }

    fn ramp(sample_rate: u32) -> MetronomeClick {
        MetronomeClick {
            downbeat: vec![-1.0, -2.0, -3.0, -4.0, -5.0, -6.0],
            offbeat: vec![1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
            sample_rate,
        }
    }

    #[test]
    fn renders_downbeat_into_each_channel() {
        let mut metronome = metronome(None);
        let mut output = [0.0; 4];

        metronome.render(&mut output, 2, at(0, 120.0, 48_000));

        assert_eq!(output, [0.5, 0.5, 0.0, 0.0]);
    }

    #[test]
    fn custom_click_plays_its_downbeat_buffer_on_the_downbeat() {
        let mut metronome = metronome(Some(ramp(48_000)));
        let mut output = [0.0; 4];

        // Sample 0 starts bar one
        metronome.render(&mut output, 1, at(0, 120.0, 48_000));

        assert_eq!(output, [-1.0, -2.0, -3.0, -4.0]);
    }

    #[test]
    fn custom_click_plays_its_offbeat_buffer_on_an_offbeat() {
        let mut metronome = metronome(Some(ramp(48_000)));
        let mut output = [0.0; 4];

        // One beat at 120 BPM and 48 kHz is 24000 samples: the second beat of the bar
        metronome.render(&mut output, 1, at(24_000, 120.0, 48_000));

        assert_eq!(output, [1.0, 2.0, 3.0, 4.0]);
    }

    #[test]
    fn custom_click_keeps_its_pitch_at_another_engine_rate() {
        let mut metronome = metronome(Some(ramp(24_000)));
        let mut output = [0.0; 4];

        // The click was decoded at half the engine rate, so offbeats read half a sample a frame
        metronome.render(&mut output, 1, at(24_000, 120.0, 48_000));

        assert_eq!(output, [1.0, 1.5, 2.0, 2.5]);
    }

    #[test]
    fn next_beat_cuts_off_the_tail_of_a_custom_click() {
        let mut metronome = metronome(Some(ramp(4)));
        let mut output = [0.0; 4];

        // At 4 Hz a beat is two samples long, shorter than the six-sample click
        metronome.render(&mut output, 1, at(2, 120.0, 4));

        assert_eq!(output, [1.0, 2.0, 1.0, 2.0]);
    }

    #[test]
    fn clearing_the_custom_click_restores_the_built_in_sound() {
        let mut metronome = metronome(Some(ramp(48_000)));

        metronome.set_custom_click(None);
        let mut output = [0.0; 2];
        metronome.render(&mut output, 1, at(0, 120.0, 48_000));

        assert_eq!(output, [0.5, 0.0]);
    }

    #[test]
    fn delay_compensation_holds_the_click_back_with_the_tracks() {
        let mut metronome = metronome(None);
        let mut output = [0.0; 4];
        let timing = ClickTiming {
            latency: 6,
            ..at(0, 120.0, 48_000)
        };

        // Beat one is due at output frame 6: the block after this one, frame 2.
        metronome.render(&mut output, 1, timing);
        assert_eq!(output, [0.0; 4]);
        let next = ClickTiming {
            start_playhead: 4,
            render_frame: 4,
            ..timing
        };
        metronome.render(&mut output, 1, next);

        assert_eq!(output, [0.0, 0.0, 0.5, 0.0]);
    }

    #[test]
    fn a_click_waiting_for_compensation_plays_after_a_loop_wrap() {
        let mut metronome = metronome(None);
        let mut output = [0.0; 4];
        // At 4 Hz a beat is two samples: beat three (sample 4) is placed at output frame 6.
        let before_wrap = ClickTiming {
            start_playhead: 4,
            render_frame: 0,
            latency: 2,
            ..at(0, 120.0, 4)
        };
        metronome.render(&mut output[..1], 1, before_wrap);

        // The loop jumps back to sample 1, between beats; the earlier click still sounds.
        let after_wrap = ClickTiming {
            start_playhead: 1,
            render_frame: 1,
            ..before_wrap
        };
        metronome.render(&mut output[1..], 1, after_wrap);

        assert_eq!(output, [0.0, 0.0, 0.25, 0.0]);
    }

    #[test]
    fn beats_stay_on_the_sample_grid_late_in_a_song() {
        let mut metronome = metronome(None);
        let mut output = [0.0; 4];
        // 44.1 kHz at 123 BPM: a beat is 21512.195... samples. Beat 10_000 lands on
        // 215_121_951, which f32 cannot represent.
        let beat = 215_121_951;

        metronome.render(&mut output, 1, at(beat - 1, 123.0, 44_100));

        assert_eq!(output, [0.0, 0.5, 0.0, 0.0]);
    }

    #[test]
    fn the_bar_length_decides_the_downbeat() {
        let mut metronome = metronome(None);
        let mut output = [0.0; 2];
        let three_four = ClickTiming {
            beats_per_bar: 3,
            ..at(72_000, 120.0, 48_000)
        };

        // Beat four starts bar two in 3/4.
        metronome.render(&mut output, 1, three_four);

        assert_eq!(output, [0.5, 0.0]);
    }

    #[test]
    fn a_stopped_transport_plays_out_waiting_clicks_only() {
        let mut metronome = metronome(None);
        let mut output = [0.0; 4];
        let timing = ClickTiming {
            latency: 4,
            ..at(0, 120.0, 48_000)
        };
        metronome.render(&mut output, 1, timing);

        metronome.render_tail(&mut output, 1, 4, 48_000);

        assert_eq!(output, [0.5, 0.0, 0.0, 0.0]);
    }

    #[test]
    fn deactivating_drops_waiting_clicks() {
        let mut metronome = metronome(None);
        let mut output = [0.0; 4];
        let timing = ClickTiming {
            latency: 4,
            ..at(0, 120.0, 48_000)
        };
        metronome.render(&mut output, 1, timing);

        metronome.set_active(false);
        metronome.set_active(true);
        metronome.render_tail(&mut output, 1, 4, 48_000);

        assert_eq!(output, [0.0; 4]);
    }
}
