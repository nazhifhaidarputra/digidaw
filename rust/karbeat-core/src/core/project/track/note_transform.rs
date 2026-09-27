//! Piano-roll note transforms.
//!
//! Each transform reads the notes it applies to and returns a [`NoteEdit`]: edited copies of
//! existing notes (same IDs) plus any new notes to insert. Nothing here touches project state,
//! so the note API can validate and commit every transform as a single undo step.

use crate::core::project::{Note, NoteId};

/// Lowest and highest fine pitch offset, in semitones.
pub const PITCH_RANGE: f32 = 2.0;

/// The result of a note transform, committed atomically by the note API.
#[derive(Debug, Default, Clone, PartialEq)]
pub struct NoteEdit {
    /// Edited copies of existing notes, matched to them by ID.
    pub updates: Vec<Note>,
    /// New notes to insert; their IDs are assigned on insertion.
    pub additions: Vec<Note>,
}

impl NoteEdit {
    fn updates(updates: Vec<Note>) -> Self {
        Self {
            updates,
            additions: Vec::new(),
        }
    }
}

fn snap(tick: u64, step: u64) -> u64 {
    if step == 0 {
        return tick;
    }
    (tick + step / 2) / step * step
}

/// Snaps start and end of each note to the nearest `step`; notes never shrink below one step.
pub fn quantize(notes: &[Note], step: u64) -> NoteEdit {
    NoteEdit::updates(
        notes
            .iter()
            .map(|note| {
                let start = snap(note.start_tick, step);
                let end = snap(note.start_tick + note.duration, step).max(start + step.max(1));
                Note {
                    start_tick: start,
                    duration: end - start,
                    ..note.clone()
                }
            })
            .collect(),
    )
}

/// Snaps only the start of each note to the nearest `step`, keeping its length.
pub fn quantize_start(notes: &[Note], step: u64) -> NoteEdit {
    NoteEdit::updates(
        notes
            .iter()
            .map(|note| Note {
                start_tick: snap(note.start_tick, step),
                ..note.clone()
            })
            .collect(),
    )
}

/// Stretches each note to end where the next later note among `notes` starts, so the line
/// plays without gaps or overlaps. Notes at the last start keep their length.
pub fn legato(notes: &[Note]) -> NoteEdit {
    let mut starts: Vec<u64> = notes.iter().map(|note| note.start_tick).collect();
    starts.sort_unstable();
    starts.dedup();
    NoteEdit::updates(
        notes
            .iter()
            .map(|note| {
                let next = starts
                    .iter()
                    .copied()
                    .find(|&start| start > note.start_tick);
                Note {
                    duration: next.map_or(note.duration, |next| next - note.start_tick),
                    ..note.clone()
                }
            })
            .collect(),
    )
}

/// Deterministic `SplitMix64` generator, so humanize results are reproducible from a seed.
struct SplitMix64(u64);

impl SplitMix64 {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    /// Uniform integer in `-range..=range`.
    fn spread(&mut self, range: u64) -> i64 {
        if range == 0 {
            return 0;
        }
        let width = range.saturating_mul(2).saturating_add(1);
        i64::try_from(self.next() % width).unwrap_or(0) - i64::try_from(range).unwrap_or(0)
    }
}

/// Randomly nudges each note's start by up to `timing_ticks` and its velocity by up to
/// `velocity_amount`, reproducibly for a given `seed`.
pub fn humanize(notes: &[Note], timing_ticks: u64, velocity_amount: u8, seed: u64) -> NoteEdit {
    let mut rng = SplitMix64(seed);
    NoteEdit::updates(
        notes
            .iter()
            .map(|note| {
                let start = i64::try_from(note.start_tick)
                    .unwrap_or(i64::MAX)
                    .saturating_add(rng.spread(timing_ticks))
                    .max(0);
                let velocity = (i64::from(note.velocity) + rng.spread(u64::from(velocity_amount)))
                    .clamp(1, 127);
                Note {
                    start_tick: u64::try_from(start).unwrap_or(0),
                    velocity: u8::try_from(velocity).unwrap_or(note.velocity),
                    ..note.clone()
                }
            })
            .collect(),
    )
}

/// Splits each note at every multiple of `step` inside it. The original note keeps its ID as
/// the first piece; the remaining pieces are added with its other properties.
pub fn chop(notes: &[Note], step: u64) -> NoteEdit {
    let mut edit = NoteEdit::default();
    if step == 0 {
        return edit;
    }
    for note in notes {
        let end = note.start_tick + note.duration;
        let mut cut = (note.start_tick / step + 1) * step;
        if cut >= end {
            continue;
        }
        edit.updates.push(Note {
            duration: cut - note.start_tick,
            ..note.clone()
        });
        while cut < end {
            let next = (cut + step).min(end);
            edit.additions.push(Note {
                id: NoteId::default(),
                start_tick: cut,
                duration: next - cut,
                ..note.clone()
            });
            cut = next;
        }
    }
    edit
}

/// Cuts one note in two at `at_tick`. Returns an empty edit when the tick is not inside it.
pub fn slice(note: &Note, at_tick: u64) -> NoteEdit {
    let end = note.start_tick + note.duration;
    if at_tick <= note.start_tick || at_tick >= end {
        return NoteEdit::default();
    }
    NoteEdit {
        updates: vec![Note {
            duration: at_tick - note.start_tick,
            ..note.clone()
        }],
        additions: vec![Note {
            id: NoteId::default(),
            start_tick: at_tick,
            duration: end - at_tick,
            ..note.clone()
        }],
    }
}

/// Moves every note by `semitones`. Fails if any note would leave the MIDI range, so chords
/// keep their shape at the edges.
pub fn transpose(notes: &[Note], semitones: i32) -> anyhow::Result<NoteEdit> {
    let updates = notes
        .iter()
        .map(|note| {
            let key = i32::from(note.key) + semitones;
            let key = u8::try_from(key)
                .ok()
                .filter(|key| *key <= 127)
                .ok_or_else(|| anyhow::anyhow!("Transposing would move a note outside 0-127"))?;
            Ok(Note {
                key,
                ..note.clone()
            })
        })
        .collect::<anyhow::Result<_>>()?;
    Ok(NoteEdit::updates(updates))
}

/// Moves every note by `delta_ticks`. The group stops at tick 0 rather than compressing.
pub fn shift(notes: &[Note], delta_ticks: i64) -> NoteEdit {
    let earliest = notes.iter().map(|note| note.start_tick).min().unwrap_or(0);
    let delta = delta_ticks.max(-i64::try_from(earliest).unwrap_or(i64::MAX));
    NoteEdit::updates(
        notes
            .iter()
            .map(|note| Note {
                start_tick: note.start_tick.saturating_add_signed(delta),
                ..note.clone()
            })
            .collect(),
    )
}

/// Per-note parameter change; `None` leaves a parameter unchanged.
#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct NoteParams {
    /// MIDI velocity, 1-127.
    pub velocity: Option<u8>,
    /// Stereo placement, -1 to 1.
    pub pan: Option<f32>,
    /// Fine pitch, in semitones within [`PITCH_RANGE`].
    pub pitch: Option<f32>,
}

/// Applies `params` to `note`, clamping each value into its valid range.
pub fn with_params(note: &Note, params: NoteParams) -> Note {
    Note {
        velocity: params.velocity.map_or(note.velocity, |v| v.clamp(1, 127)),
        pan: params
            .pan
            .filter(|pan| pan.is_finite())
            .map_or(note.pan, |pan| pan.clamp(-1.0, 1.0)),
        pitch: params
            .pitch
            .filter(|pitch| pitch.is_finite())
            .map_or(note.pitch, |pitch| pitch.clamp(-PITCH_RANGE, PITCH_RANGE)),
        ..note.clone()
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used, reason = "test fixtures are valid")]
mod tests {
    use super::*;

    fn note(id: u32, start: u64, duration: u64, key: u8) -> Note {
        Note {
            id: NoteId::from(id),
            start_tick: start,
            duration,
            key,
            velocity: 100,
            probability: 1.0,
            micro_offset: 0,
            mute: false,
            pan: 0.0,
            pitch: 0.0,
        }
    }

    fn spans(edit: &NoteEdit) -> Vec<(u64, u64)> {
        edit.updates
            .iter()
            .chain(&edit.additions)
            .map(|n| (n.start_tick, n.duration))
            .collect()
    }

    #[test]
    fn quantize_snaps_both_ends_and_keeps_one_step_minimum() {
        let edit = quantize(&[note(1, 230, 500, 60), note(2, 470, 10, 60)], 240);
        assert_eq!(spans(&edit), [(240, 480), (480, 240)]);
    }

    #[test]
    fn quantize_start_keeps_length() {
        let edit = quantize_start(&[note(1, 250, 333, 60)], 240);
        assert_eq!(spans(&edit), [(240, 333)]);
    }

    #[test]
    fn legato_fills_gaps_up_to_the_next_start() {
        let chord = [
            note(1, 0, 100, 60),
            note(2, 0, 100, 64),
            note(3, 960, 100, 62),
        ];
        let edit = legato(&chord);
        assert_eq!(spans(&edit), [(0, 960), (0, 960), (960, 100)]);
    }

    #[test]
    fn humanize_is_bounded_and_reproducible() {
        let notes: Vec<_> = (0..32)
            .map(|i| note(i, 960 * u64::from(i), 240, 60))
            .collect();
        let first = humanize(&notes, 20, 10, 7);
        assert_eq!(first, humanize(&notes, 20, 10, 7));
        for (before, after) in notes.iter().zip(&first.updates) {
            assert!(before.start_tick.abs_diff(after.start_tick) <= 20);
            assert!(before.velocity.abs_diff(after.velocity) <= 10);
        }
        assert_ne!(first, humanize(&notes, 20, 10, 8));
    }

    #[test]
    fn chop_splits_on_the_absolute_grid() {
        let edit = chop(&[note(1, 120, 600, 60)], 240);
        assert_eq!(edit.updates[0].id, NoteId::from(1));
        assert_eq!(spans(&edit), [(120, 120), (240, 240), (480, 240)]);
    }

    #[test]
    fn slice_ignores_ticks_outside_the_note() {
        let original = note(1, 0, 960, 60);
        assert_eq!(slice(&original, 0), NoteEdit::default());
        assert_eq!(spans(&slice(&original, 240)), [(0, 240), (240, 720)]);
    }

    #[test]
    fn transpose_rejects_leaving_the_midi_range() {
        let notes = [note(1, 0, 10, 120), note(2, 0, 10, 60)];
        assert!(transpose(&notes, 12).is_err());
        let edit = transpose(&notes, -12).unwrap();
        assert_eq!(
            edit.updates.iter().map(|n| n.key).collect::<Vec<_>>(),
            [108, 48]
        );
    }

    #[test]
    fn shift_stops_the_group_at_zero() {
        let edit = shift(&[note(1, 100, 10, 60), note(2, 400, 10, 60)], -240);
        assert_eq!(spans(&edit), [(0, 10), (300, 10)]);
    }

    #[test]
    fn params_are_clamped() {
        let edited = with_params(
            &note(1, 0, 10, 60),
            NoteParams {
                velocity: Some(0),
                pan: Some(3.0),
                pitch: Some(-9.0),
            },
        );
        assert_eq!((edited.velocity, edited.pan, edited.pitch), (1, 1.0, -2.0));
    }
}
