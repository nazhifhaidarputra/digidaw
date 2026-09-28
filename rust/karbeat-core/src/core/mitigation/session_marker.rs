use std::{
    path::Path,
    sync::atomic::{AtomicBool, Ordering},
};

use jiff::Timestamp;

use super::{MitigationError, auto_save::remove_if_exists};

/// Set once this process has started a session, so a host-side hot restart that configures
/// mitigation again does not mistake this process's own marker for a crashed run.
static SESSION_STARTED: AtomicBool = AtomicBool::new(false);

/// Marker contents written when a termination signal, such as Ctrl+C, ends the session.
const FORCED_SHUTDOWN: &str = "forced";

/// How the previous session ended, as read from its marker.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PreviousSession {
    /// No marker was left behind: the session ended cleanly, or this is the first run.
    Clean,
    /// The session was terminated on request by a signal such as Ctrl+C. Not a crash.
    Forced,
    /// A marker was left behind without explanation: a crash, a kill, or a power loss.
    Unclean,
}

/// Starts a session by writing the marker at `marker`, and reports how the previous one ended.
pub fn begin_session(marker: &Path) -> Result<PreviousSession, MitigationError> {
    let first_in_process = !SESSION_STARTED.swap(true, Ordering::AcqRel);
    begin_session_with(marker, first_in_process)
}

fn begin_session_with(
    marker: &Path,
    first_in_process: bool,
) -> Result<PreviousSession, MitigationError> {
    let previous = if first_in_process {
        match std::fs::read_to_string(marker) {
            Ok(contents) if contents.trim() == FORCED_SHUTDOWN => PreviousSession::Forced,
            Ok(_) => PreviousSession::Unclean,
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => PreviousSession::Clean,
            Err(error) => return Err(error.into()),
        }
    } else {
        PreviousSession::Clean
    };
    if let Some(parent) = marker.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::write(marker, Timestamp::now().to_string())?;
    Ok(previous)
}

/// Records that the running session is being terminated on request rather than crashing.
///
/// Does nothing when no session is running, such as after a clean shutdown or while suspended.
pub fn mark_forced_shutdown(marker: &Path) -> Result<(), MitigationError> {
    if marker.exists() {
        std::fs::write(marker, FORCED_SHUTDOWN)?;
    }
    Ok(())
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

        assert_eq!(
            begin_session_with(&marker, true).expect("first session"),
            PreviousSession::Clean
        );
        assert_eq!(
            begin_session_with(&marker, true).expect("crashed session"),
            PreviousSession::Unclean
        );

        end_session(&marker).expect("end session");
        assert_eq!(
            begin_session_with(&marker, true).expect("clean session"),
            PreviousSession::Clean
        );
    }

    #[test]
    fn restarting_inside_the_same_process_is_not_a_crash() {
        let dir = tempfile::tempdir().expect("temporary directory");
        let marker = dir.path().join("session.lock");

        begin_session_with(&marker, true).expect("first session");
        assert_eq!(
            begin_session_with(&marker, false).expect("hot restart"),
            PreviousSession::Clean
        );
    }

    #[test]
    fn forced_shutdown_is_reported_separately_from_a_crash() {
        let dir = tempfile::tempdir().expect("temporary directory");
        let marker = dir.path().join("session.lock");

        begin_session_with(&marker, true).expect("first session");
        mark_forced_shutdown(&marker).expect("forced shutdown");
        assert_eq!(
            begin_session_with(&marker, true).expect("next session"),
            PreviousSession::Forced
        );
    }

    #[test]
    fn forced_shutdown_after_the_session_ended_leaves_no_marker() {
        let dir = tempfile::tempdir().expect("temporary directory");
        let marker = dir.path().join("session.lock");

        begin_session_with(&marker, true).expect("first session");
        end_session(&marker).expect("end session");
        mark_forced_shutdown(&marker).expect("forced shutdown");
        assert!(!marker.exists());
    }
}
