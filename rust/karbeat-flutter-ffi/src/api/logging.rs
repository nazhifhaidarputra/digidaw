use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;
use crate::log_bridge::{self, LogBatchSink};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RustLogLevel {
    Trace,
    Debug,
    Info,
    Warn,
    Error,
}

impl From<log::Level> for RustLogLevel {
    fn from(value: log::Level) -> Self {
        match value {
            log::Level::Trace => Self::Trace,
            log::Level::Debug => Self::Debug,
            log::Level::Info => Self::Info,
            log::Level::Warn => Self::Warn,
            log::Level::Error => Self::Error,
        }
    }
}

/// One Rust `log` record forwarded to the Flutter log viewer.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct RustLogEntryDto {
    /// Milliseconds since the Unix epoch at the time the record was logged.
    pub timestamp_millis: i64,
    pub level: RustLogLevel,
    /// The `log` target, usually the emitting module path.
    pub target: String,
    pub message: String,
}

impl LogBatchSink for StreamSink<Vec<RustLogEntryDto>> {
    fn send_batch(&self, batch: &[RustLogEntryDto]) -> bool {
        self.add(batch.to_vec()).is_ok()
    }
}

/// Streams batches of Rust log records to Flutter.
///
/// Records logged before the first subscription (or while no Dart listener is
/// attached, e.g. across a hot restart) are retained in a bounded backlog and
/// delivered first. Subscribing again replaces the previous stream.
pub fn subscribe_rust_logs(sink: StreamSink<Vec<RustLogEntryDto>>) -> Result<(), String> {
    log_bridge::attach(Box::new(sink)).map_err(|error| error.to_string())
}
