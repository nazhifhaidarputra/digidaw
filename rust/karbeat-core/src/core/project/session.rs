use std::path::{Path, PathBuf};

/// Runtime-only save tracking for the loaded project.
///
/// Every persisted modification bumps a revision counter. Saving records the revision captured
/// when the save *began*, so an edit that lands while a save is still running keeps the project
/// unsaved. Undo and redo are modifications too: undoing back to the saved point still reports
/// unsaved changes.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct SessionState {
    revision: u64,
    saved_revision: u64,
    autosaved_revision: u64,
    file_path: Option<PathBuf>,
}

impl SessionState {
    /// Project file this session was loaded from or last saved to; `None` while untitled.
    pub fn file_path(&self) -> Option<&Path> {
        self.file_path.as_deref()
    }

    /// Records the project file after a successful save, load, or recovery.
    pub fn set_file_path(&mut self, path: Option<PathBuf>) {
        self.file_path = path;
    }

    /// Records one persisted modification.
    pub fn mark_modified(&mut self) {
        self.revision = self.revision.wrapping_add(1);
    }

    /// Whether the project file reflects every modification made so far.
    pub fn is_saved(&self) -> bool {
        self.revision == self.saved_revision
    }

    /// Current modification revision, captured when a save or auto save begins.
    pub fn revision(&self) -> u64 {
        self.revision
    }

    /// Marks the project saved as of `revision`, the value captured when the save began.
    pub fn mark_saved_at(&mut self, revision: u64) {
        self.saved_revision = revision;
        self.autosaved_revision = revision;
    }

    /// Whether modifications exist that neither a save nor an auto save has written.
    pub fn needs_autosave(&self) -> bool {
        self.revision != self.saved_revision && self.revision != self.autosaved_revision
    }

    /// Records that the recovery copy reflects every modification up to `revision`.
    pub fn mark_autosaved_at(&mut self, revision: u64) {
        self.autosaved_revision = revision;
    }
}

#[cfg(test)]
mod tests {
    use super::SessionState;

    #[test]
    fn fresh_session_is_saved_and_needs_no_autosave() {
        let session = SessionState::default();
        assert!(session.is_saved());
        assert!(!session.needs_autosave());
    }

    #[test]
    fn edit_after_save_began_keeps_project_unsaved() {
        let mut session = SessionState::default();
        session.mark_modified();
        let captured = session.revision();
        session.mark_modified();
        session.mark_saved_at(captured);

        assert!(!session.is_saved());
        assert!(session.needs_autosave());
    }

    #[test]
    fn autosave_does_not_mark_project_saved() {
        let mut session = SessionState::default();
        session.mark_modified();
        session.mark_autosaved_at(session.revision());

        assert!(!session.is_saved());
        assert!(!session.needs_autosave());

        session.mark_modified();
        assert!(session.needs_autosave());
    }
}
