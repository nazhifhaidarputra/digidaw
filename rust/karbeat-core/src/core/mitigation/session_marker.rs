use std::{
    path::Path,
    sync::atomic::{AtomicBool, Ordering},
};

use jiff::Timestamp;

use super::{MitigationError, auto_save::remove_if_exists};

/// Set once this process has started a session, so a host-side hot restart that configures
/// mitigation again does not mistake this process's own marker for a crashed run.
static SESSION_STARTED: AtomicBool = AtomicBool::new(false);

/// Starts a session by writing the marker at `marker`.
///
/// Returns `true` when a marker from an earlier process was still present, meaning that process
/// ended without [`end_session`]: a crash, a kill, or a power loss.
pub fn begin_session(marker: &Path) -> Result<bool, MitigationError> {
    let first_in_process = !SESSION_STARTED.swap(true, Ordering::AcqRel);
    begin_session_with(marker, first_in_process)
}

fn begin_session_with(marker: &Path, first_in_process: bool) -> Result<bool, MitigationError> {
    let previous_unclean = first_in_process && marker.exists();
    if let Some(parent) = marker.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::write(marker, Timestamp::now().to_string())?;
    Ok(previous_unclean)
}

/// Ends the session cleanly by removing the marker.
pub fn end_session(marker: &Path) -> Result<(), MitigationError> {
    remove_if_exists(marker)
}

#[cfg(test)]
#[allow(
    clippy::expect_used,
    reason = "session marker tests fail immediately when temporary files cannot be used"
)]
mod tests {
    use super::*;

    #[test]
    fn stale_marker_from_another_process_reports_unclean_shutdown() {
        let dir = tempfile::tempdir().expect("temporary directory");
        let marker = dir.path().join("session.lock");

        assert!(!begin_session_with(&marker, true).expect("first session"));
        assert!(begin_session_with(&marker, true).expect("crashed session"));

        end_session(&marker).expect("end session");
        assert!(!begin_session_with(&marker, true).expect("clean session"));
    }

    #[test]
    fn restarting_inside_the_same_process_is_not_a_crash() {
        let dir = tempfile::tempdir().expect("temporary directory");
        let marker = dir.path().join("session.lock");

        begin_session_with(&marker, true).expect("first session");
        assert!(!begin_session_with(&marker, false).expect("hot restart"));
    }
}
