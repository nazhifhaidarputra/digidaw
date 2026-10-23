//! Per-track clip spans, so a block looks only at the clips that can overlap it.

use hashbrown::HashMap;

use crate::{
    core::project::{AudioTrack, Clip, ClipTimeUnit},
    shared::ClipId,
};

/// Clip spans of every track in project samples at one tempo.
///
/// Song playback asks which clips overlap each block. Walking a track's clip list from its
/// first clip costs a lookup per clip already played, so the cost grows with the song. The
/// spans are computed once per graph and tempo instead, as running maxima that a binary
/// search can cut at both ends.
#[derive(Default)]
pub(super) struct ClipSchedule {
    /// Tempo scale the spans were computed for; `None` forces a rebuild.
    samples_per_tick: Option<u64>,
    /// One entry per graph track, in graph order.
    tracks: Vec<TrackSpans>,
}

#[derive(Default)]
struct TrackSpans {
    /// For each clip, the latest start among it and the clips before it.
    start_ceiling: Vec<u32>,
    /// For each clip, the latest end among it and the clips before it.
    end_ceiling: Vec<u32>,
}

impl ClipSchedule {
    /// Marks the spans stale after the track list or the clips changed.
    pub fn invalidate(&mut self) {
        self.samples_per_tick = None;
    }

    /// Recomputes the spans when the graph or the tempo scale changed since the last call.
    pub fn ensure(
        &mut self,
        tracks: &[AudioTrack],
        clips: &HashMap<ClipId, Clip>,
        samples_per_tick: f64,
    ) {
        let scale = samples_per_tick.to_bits();
        if self.samples_per_tick == Some(scale) && self.tracks.len() == tracks.len() {
            return;
        }
        self.samples_per_tick = Some(scale);
        self.tracks.resize_with(tracks.len(), TrackSpans::default);
        for (spans, track) in self.tracks.iter_mut().zip(tracks) {
            spans.start_ceiling.clear();
            spans.end_ceiling.clear();
            let (mut latest_start, mut latest_end) = (0, 0);
            for clip_id in track.clips() {
                // A stale clip ID plays nothing and must not hide the clips after it.
                if let Some(clip) = clips.get(clip_id) {
                    let (start, length, _) = clip_span_samples(&clip.time, samples_per_tick);
                    latest_start = latest_start.max(start);
                    latest_end = latest_end.max(start.wrapping_add(length));
                }
                spans.start_ceiling.push(latest_start);
                spans.end_ceiling.push(latest_end);
            }
        }
    }

    /// Indices into the clip list of track `track_index` that can overlap the samples
    /// `start_time..=end_time`. Clips before the range all end before `start_time`; the range
    /// stops at the first clip that starts after `end_time`.
    pub fn candidates(
        &self,
        track_index: usize,
        start_time: u32,
        end_time: u32,
    ) -> std::ops::Range<usize> {
        let Some(spans) = self.tracks.get(track_index) else {
            return 0..0;
        };
        let last = spans
            .start_ceiling
            .partition_point(|start| *start <= end_time);
        let first = spans
            .end_ceiling
            .partition_point(|end| *end < start_time)
            .min(last);
        first..last
    }
}

/// Timeline start, length, and source offset of a clip in project samples.
pub(super) fn clip_span_samples(time: &ClipTimeUnit, samples_per_tick: f64) -> (u32, u32, u32) {
    match time {
        ClipTimeUnit::Samples {
            start_time,
            loop_length,
            offset_start,
        } => (
            *start_time as u32,
            *loop_length as u32,
            *offset_start as u32,
        ),
        ClipTimeUnit::Ticks {
            start_time,
            loop_length,
            offset_start,
        } => {
            let st = ((*start_time as f64) * samples_per_tick) as u32;
            let ll = ((*loop_length as f64) * samples_per_tick) as u32;
            let os = ((*offset_start as f64) * samples_per_tick) as u32;
            (st, ll, os)
        }
        ClipTimeUnit::Audio {
            start_tick,
            loop_length,
            offset_start,
        } => (
            ((*start_tick as f64) * samples_per_tick).round() as u32,
            *loop_length as u32,
            *offset_start as u32,
        ),
    }
}

#[cfg(test)]
#[allow(clippy::expect_used, reason = "fixtures hold the clips they index")]
mod tests {
    use super::*;
    use crate::core::project::{ApplicationState, TrackType};
    use karbeat_utils::color::Color;

    /// A track whose clips have the given `(start, length)` spans in samples, plus the IDs
    /// of the clips in track order.
    fn track(spans: &[(u64, u64)]) -> (Vec<AudioTrack>, HashMap<ClipId, Clip>) {
        let mut app = ApplicationState::default();
        let track_id = app.tracks.insert_with_key(|id| {
            AudioTrack::new(id, "Clips", Color::new_from_rgb(0, 0, 0), TrackType::Audio)
        });
        let ids: Vec<ClipId> = spans
            .iter()
            .map(|(start_time, loop_length)| {
                app.clips_pool.insert_with_key(|id| Clip {
                    name: String::new(),
                    id,
                    source: None,
                    time: ClipTimeUnit::Samples {
                        start_time: *start_time,
                        loop_length: *loop_length,
                        offset_start: 0,
                    },
                    envelope: None,
                })
            })
            .collect();
        app.tracks[track_id].add_clips_bulk(&ids, &app.clips_pool);
        let clips = app
            .clips_pool
            .iter()
            .map(|(id, clip)| (id, clip.clone()))
            .collect();
        (vec![app.tracks[track_id].clone()], clips)
    }

    /// The clips the old full walk visited for a block: every clip not ending before the
    /// block, up to the first one starting after it.
    fn walked(spans: &[(u64, u64)], start_time: u32, end_time: u32) -> Vec<usize> {
        let mut visited = Vec::new();
        for (index, (start, length)) in spans.iter().enumerate() {
            if *start as u32 > end_time {
                break;
            }
            if (*start + *length) as u32 >= start_time {
                visited.push(index);
            }
        }
        visited
    }

    #[test]
    fn candidates_cover_every_clip_the_full_walk_visits() {
        // Back-to-back clips, a long one overlapping its successors, and a gap.
        let spans = [
            (0, 100),
            (100, 100),
            (150, 1_000),
            (200, 50),
            (300, 20),
            (2_000, 100),
            (2_100, 100),
        ];
        let (tracks, clips) = track(&spans);
        let mut schedule = ClipSchedule::default();
        schedule.ensure(&tracks, &clips, 25.0);
        for start_time in (0..2_400).step_by(37) {
            for length in [1, 64, 512] {
                let end_time = start_time + length;
                let candidates = schedule.candidates(0, start_time, end_time);
                for index in walked(&spans, start_time, end_time) {
                    assert!(
                        candidates.contains(&index),
                        "clip {index} missing for {start_time}..{end_time}: {candidates:?}"
                    );
                }
                assert!(
                    candidates.end == spans.len() || spans[candidates.end].0 as u32 > end_time,
                    "range for {start_time}..{end_time} stops early: {candidates:?}"
                );
            }
        }
        // Late in the song only the clips near the playhead are visited.
        assert_eq!(schedule.candidates(0, 2_050, 2_060), 5..6);
        assert_eq!(schedule.candidates(1, 0, 100), 0..0);
    }

    #[test]
    fn spans_follow_the_tempo_and_the_graph() {
        let (mut tracks, mut clips) = track(&[(0, 100)]);
        let tick_clip = *tracks[0].clips().first().expect("clip");
        clips.get_mut(&tick_clip).expect("clip").time = ClipTimeUnit::Ticks {
            start_time: 10,
            loop_length: 4,
            offset_start: 0,
        };
        let mut schedule = ClipSchedule::default();
        schedule.ensure(&tracks, &clips, 25.0);
        assert_eq!(schedule.candidates(0, 250, 260), 0..1);
        assert!(schedule.candidates(0, 500, 510).is_empty());
        // Twice the samples per tick moves the clip to 500..600.
        schedule.ensure(&tracks, &clips, 50.0);
        assert_eq!(schedule.candidates(0, 500, 510), 0..1);

        // A graph edit is picked up after invalidation.
        tracks.clear();
        schedule.invalidate();
        schedule.ensure(&tracks, &clips, 50.0);
        assert!(schedule.candidates(0, 500, 510).is_empty());
    }
}
