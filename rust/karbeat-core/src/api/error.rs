use thiserror::Error;

/// Stable UI-facing category attached to a [`DawError`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DawErrorCode {
    /// Requested track identifier does not exist.
    TrackNotFound,
    /// Track name failed API validation.
    InvalidTrackName,
    /// Color value could not be parsed or validated.
    InvalidColorFormat,
    /// Filesystem or stream operation failed.
    IoError,
    /// Error did not map to a more specific UI category.
    InternalError,
}

/// The uniform error struct sent to Flutter
#[derive(Debug, Error)]
#[error("[{code:?}] {reason}")]
pub struct DawError {
    /// Stable error category used by the UI for presentation or branching.
    pub code: DawErrorCode,
    /// User-facing summary that does not expose implementation details.
    pub reason: String,

    /// Underlying diagnostic retained for logging and debugging.
    pub cause: Option<String>,
}

impl From<anyhow::Error> for DawError {
    fn from(err: anyhow::Error) -> Self {
        DawError {
            code: DawErrorCode::InternalError,
            reason: "An internal engine error occurred".to_string(),
            cause: Some(err.to_string()),
        }
    }
}
