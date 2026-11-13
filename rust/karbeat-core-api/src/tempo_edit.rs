//! When a tempo edit renders the sources that stretch to the tempo again.
//!
//! Dragging the tempo changes it many times a second. Rendering a stretched source for each
//! value would start a burst of offline stretches that the next value makes stale, so while
//! the tempo is edited nothing renders and playback stretches in real time. Releasing the
//! edit renders once for the final tempo; editing again before those renders finish cancels
//! them.

use std::collections::HashMap;

use karbeat_core::shared::id::AudioSourceId;

use crate::jobs::JobId;

/// Where a tempo edit is.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum TempoEditPhase {
    /// No edit is running. A tempo change renders after a short debounce.
    #[default]
    Idle,
    /// The tempo is being edited. Nothing renders.
    Editing,
    /// The edit was released and renders for its final tempo run. Back to
    /// [`TempoEditPhase::Idle`] once every one has ended.
    Releasing,
}

/// The phase of a tempo edit and the renders its release started.
#[derive(Debug, Default)]
pub struct TempoEdit {
    phase: TempoEditPhase,
    renders: HashMap<AudioSourceId, JobId>,
}

impl TempoEdit {
    pub fn phase(&self) -> TempoEditPhase {
        self.phase
    }

    /// Whether the tempo is being edited, so tempo changes must not render.
    pub fn is_editing(&self) -> bool {
        self.phase == TempoEditPhase::Editing
    }

    /// Starts editing, or resumes it during a release. Returns the release's renders, which
    /// the caller cancels.
    pub fn begin(&mut self) -> Vec<JobId> {
        self.phase = TempoEditPhase::Editing;
        self.renders.drain().map(|(_, job)| job).collect()
    }

    /// Ends editing. Returns whether the caller should render the sources now and record
    /// each render with [`Self::render_started`], then call [`Self::settle`].
    pub fn release(&mut self) -> bool {
        if self.phase != TempoEditPhase::Editing {
            return false;
        }
        self.phase = TempoEditPhase::Releasing;
        true
    }

    /// Records a render the release started for `source`.
    pub fn render_started(&mut self, source: AudioSourceId, job: JobId) {
        if self.phase == TempoEditPhase::Releasing {
            self.renders.insert(source, job);
        }
    }

    /// Records that a render of `source` ended, whichever job ran it.
    pub fn render_ended(&mut self, source: AudioSourceId) {
        self.renders.remove(&source);
        self.settle();
    }

    /// Returns to idle once a release has no render left.
    pub fn settle(&mut self) {
        if self.phase == TempoEditPhase::Releasing && self.renders.is_empty() {
            self.phase = TempoEditPhase::Idle;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn source(id: u64) -> AudioSourceId {
        AudioSourceId::from_u64(id)
    }

    #[test]
    fn a_release_waits_for_every_render() {
        let mut edit = TempoEdit::default();
        assert!(edit.begin().is_empty());
        assert!(edit.is_editing());

        assert!(edit.release());
        edit.render_started(source(1), 10);
        edit.render_started(source(2), 11);
        edit.settle();
        assert_eq!(edit.phase(), TempoEditPhase::Releasing);

        edit.render_ended(source(1));
        assert_eq!(edit.phase(), TempoEditPhase::Releasing);
        edit.render_ended(source(2));
        assert_eq!(edit.phase(), TempoEditPhase::Idle);
    }

    #[test]
    fn a_release_without_renders_is_idle_at_once() {
        let mut edit = TempoEdit::default();
        edit.begin();
        assert!(edit.release());
        edit.settle();
        assert_eq!(edit.phase(), TempoEditPhase::Idle);
    }

    #[test]
    fn editing_during_a_release_cancels_its_renders() {
        let mut edit = TempoEdit::default();
        edit.begin();
        edit.release();
        edit.render_started(source(1), 10);
        edit.render_started(source(2), 11);

        let mut cancelled = edit.begin();
        cancelled.sort_unstable();
        assert_eq!(cancelled, vec![10, 11]);
        assert!(edit.is_editing());

        // A cancelled render ending late does not end the new edit.
        edit.render_ended(source(1));
        assert!(edit.is_editing());
        assert!(edit.release());
    }

    #[test]
    fn release_without_an_edit_does_nothing() {
        let mut edit = TempoEdit::default();
        assert!(!edit.release());
        edit.render_started(source(1), 10);
        edit.render_ended(source(1));
        assert_eq!(edit.phase(), TempoEditPhase::Idle);
    }
}
