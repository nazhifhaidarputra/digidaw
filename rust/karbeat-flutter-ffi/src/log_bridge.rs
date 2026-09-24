//! Non-blocking forwarding of Rust `log` records to the Flutter log viewer.
//!
//! Logging call sites only perform a bounded `try_send`: they never wait on
//! Flutter, on the drain thread, or on any lock owned by this module. A
//! dedicated drain thread batches queued records and forwards them to the
//! attached Dart stream, keeping a bounded backlog while no stream is attached.
//!
//! The drain thread and [`attach`] are the only users of the shared sink lock,
//! and neither acquires another lock while holding it. Records emitted while a
//! thread is forwarding (for example by the bridge runtime itself) are ignored
//! by the forwarder so delivery can never feed back into its own queue.

use std::cell::Cell;
use std::collections::VecDeque;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc::{self, Receiver, SyncSender, TrySendError};
use std::sync::{Arc, OnceLock};
use std::thread;
use std::time::{SystemTime, UNIX_EPOCH};

use parking_lot::Mutex;

use crate::api::logging::{RustLogEntryDto, RustLogLevel};

const QUEUE_CAPACITY: usize = 4096;
const BACKLOG_CAPACITY: usize = 2048;
const MAX_BATCH_LEN: usize = 256;
const BRIDGE_TARGET: &str = "karbeat::log_bridge";

static LOG_BRIDGE: OnceLock<LogBridge> = OnceLock::new();

thread_local! {
    static FORWARDING: Cell<bool> = const { Cell::new(false) };
}

#[derive(Debug, thiserror::Error)]
#[error("Rust log forwarding is not available")]
pub(crate) struct LogBridgeUnavailable;

/// Destination for forwarded log batches.
pub(crate) trait LogBatchSink: Send {
    /// Returns `false` when the destination is closed and must be detached.
    fn send_batch(&self, batch: &[RustLogEntryDto]) -> bool;
}

/// Starts the process-wide bridge used by [`KarbeatLogger`].
pub(crate) fn install() -> std::io::Result<&'static LogBridge> {
    if let Some(bridge) = LOG_BRIDGE.get() {
        return Ok(bridge);
    }
    let bridge = LogBridge::start(QUEUE_CAPACITY, BACKLOG_CAPACITY, MAX_BATCH_LEN)?;
    Ok(LOG_BRIDGE.get_or_init(|| bridge))
}

/// Attaches `sink` to the process-wide bridge, replacing any previous sink.
pub(crate) fn attach(sink: Box<dyn LogBatchSink>) -> Result<(), LogBridgeUnavailable> {
    let bridge = LOG_BRIDGE.get().ok_or(LogBridgeUnavailable)?;
    bridge.attach(sink);
    Ok(())
}

pub(crate) struct LogBridge {
    sender: SyncSender<RustLogEntryDto>,
    dropped: Arc<AtomicU64>,
    shared: Arc<Mutex<SinkState>>,
}

impl LogBridge {
    fn start(
        queue_capacity: usize,
        backlog_capacity: usize,
        max_batch_len: usize,
    ) -> std::io::Result<Self> {
        let (sender, receiver) = mpsc::sync_channel(queue_capacity);
        let dropped = Arc::new(AtomicU64::new(0));
        let shared = Arc::new(Mutex::new(SinkState {
            sink: None,
            backlog: VecDeque::with_capacity(backlog_capacity),
            backlog_capacity,
            overflowed: 0,
        }));

        let drain_dropped = Arc::clone(&dropped);
        let drain_shared = Arc::clone(&shared);
        thread::Builder::new()
            .name("karbeat-log-bridge".to_owned())
            .spawn(move || drain(&receiver, &drain_dropped, &drain_shared, max_batch_len))?;

        Ok(Self {
            sender,
            dropped,
            shared,
        })
    }

    /// Queues `record` without blocking; records are dropped (and counted)
    /// when the queue is full.
    pub(crate) fn push(&self, record: &log::Record<'_>) {
        if FORWARDING.get() {
            return;
        }
        let entry = RustLogEntryDto {
            timestamp_millis: now_millis(),
            level: record.level().into(),
            target: record.target().to_owned(),
            message: record.args().to_string(),
        };
        match self.sender.try_send(entry) {
            Ok(()) => {}
            Err(TrySendError::Full(_) | TrySendError::Disconnected(_)) => {
                self.dropped.fetch_add(1, Ordering::Relaxed);
            }
        }
    }

    fn attach(&self, sink: Box<dyn LogBatchSink>) {
        forwarding(|| self.shared.lock().attach(sink));
    }
}

struct SinkState {
    sink: Option<Box<dyn LogBatchSink>>,
    backlog: VecDeque<RustLogEntryDto>,
    backlog_capacity: usize,
    overflowed: u64,
}

impl SinkState {
    fn attach(&mut self, sink: Box<dyn LogBatchSink>) {
        self.take_overflow_notice();
        if !self.backlog.is_empty() {
            let pending: Vec<_> = self.backlog.drain(..).collect();
            if !sink.send_batch(&pending) {
                self.retain(pending);
                return;
            }
        }
        self.sink = Some(sink);
    }

    fn deliver(&mut self, batch: Vec<RustLogEntryDto>) {
        if let Some(sink) = &self.sink {
            if sink.send_batch(&batch) {
                return;
            }
            self.sink = None;
        }
        self.retain(batch);
    }

    fn retain(&mut self, entries: Vec<RustLogEntryDto>) {
        for entry in entries {
            if self.backlog.len() >= self.backlog_capacity {
                self.backlog.pop_front();
                self.overflowed = self.overflowed.saturating_add(1);
            }
            self.backlog.push_back(entry);
        }
    }

    /// Prepends a warning entry describing backlog eviction before it flushes.
    fn take_overflow_notice(&mut self) {
        let overflowed = std::mem::take(&mut self.overflowed);
        if overflowed > 0 {
            self.backlog
                .push_front(dropped_notice(overflowed, "backlog"));
        }
    }
}

fn drain(
    receiver: &Receiver<RustLogEntryDto>,
    dropped: &AtomicU64,
    shared: &Mutex<SinkState>,
    max_batch_len: usize,
) {
    FORWARDING.set(true);
    while let Ok(first) = receiver.recv() {
        let mut batch = Vec::with_capacity(max_batch_len);
        batch.push(first);
        while batch.len() < max_batch_len {
            match receiver.try_recv() {
                Ok(entry) => batch.push(entry),
                Err(_) => break,
            }
        }
        let lost = dropped.swap(0, Ordering::Relaxed);
        if lost > 0 {
            batch.push(dropped_notice(lost, "queue"));
        }
        shared.lock().deliver(batch);
    }
}

fn forwarding<T>(operation: impl FnOnce() -> T) -> T {
    let previous = FORWARDING.replace(true);
    let result = operation();
    FORWARDING.set(previous);
    result
}

fn dropped_notice(count: u64, stage: &str) -> RustLogEntryDto {
    RustLogEntryDto {
        timestamp_millis: now_millis(),
        level: RustLogLevel::Warn,
        target: BRIDGE_TARGET.to_owned(),
        message: format!("{count} Rust log entries were dropped because the log {stage} was full"),
    }
}

fn now_millis() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .ok()
        .and_then(|elapsed| i64::try_from(elapsed.as_millis()).ok())
        .unwrap_or_default()
}

/// Process logger writing to stdout through `env_logger` and forwarding every
/// accepted record to Flutter through the bridge.
pub(crate) struct KarbeatLogger {
    stdout: env_logger::Logger,
    bridge: Option<&'static LogBridge>,
}

impl KarbeatLogger {
    pub(crate) fn new(stdout: env_logger::Logger, bridge: Option<&'static LogBridge>) -> Self {
        Self { stdout, bridge }
    }

    pub(crate) fn filter(&self) -> log::LevelFilter {
        self.stdout.filter()
    }
}

impl log::Log for KarbeatLogger {
    fn enabled(&self, metadata: &log::Metadata<'_>) -> bool {
        self.stdout.enabled(metadata)
    }

    fn log(&self, record: &log::Record<'_>) {
        if !self.stdout.matches(record) {
            return;
        }
        self.stdout.log(record);
        if let Some(bridge) = self.bridge {
            bridge.push(record);
        }
    }

    fn flush(&self) {
        self.stdout.flush();
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::indexing_slicing,
    reason = "log bridge tests fail immediately when the drain thread cannot start"
)]
mod tests {
    use std::sync::mpsc::RecvTimeoutError;
    use std::time::Duration;

    use super::*;

    struct ChannelSink {
        batches: mpsc::Sender<Vec<RustLogEntryDto>>,
        open: Arc<std::sync::atomic::AtomicBool>,
    }

    impl LogBatchSink for ChannelSink {
        fn send_batch(&self, batch: &[RustLogEntryDto]) -> bool {
            self.open.load(Ordering::SeqCst) && self.batches.send(batch.to_vec()).is_ok()
        }
    }

    fn sink() -> (
        Box<dyn LogBatchSink>,
        mpsc::Receiver<Vec<RustLogEntryDto>>,
        Arc<std::sync::atomic::AtomicBool>,
    ) {
        let (sender, receiver) = mpsc::channel();
        let open = Arc::new(std::sync::atomic::AtomicBool::new(true));
        let sink = ChannelSink {
            batches: sender,
            open: Arc::clone(&open),
        };
        (Box::new(sink), receiver, open)
    }

    fn log(bridge: &LogBridge, level: log::Level, message: &str) {
        bridge.push(
            &log::Record::builder()
                .level(level)
                .target("karbeat::test")
                .args(format_args!("{message}"))
                .build(),
        );
    }

    fn messages(receiver: &mpsc::Receiver<Vec<RustLogEntryDto>>) -> Vec<String> {
        let mut messages = Vec::new();
        loop {
            match receiver.recv_timeout(Duration::from_millis(200)) {
                Ok(batch) => messages.extend(batch.into_iter().map(|entry| entry.message)),
                Err(RecvTimeoutError::Timeout | RecvTimeoutError::Disconnected) => {
                    return messages;
                }
            }
        }
    }

    fn wait_for_backlog(bridge: &LogBridge, len: usize) {
        for _ in 0..200 {
            if bridge.shared.lock().backlog.len() >= len {
                return;
            }
            thread::sleep(Duration::from_millis(5));
        }
    }

    #[test]
    fn backlog_is_flushed_in_order_when_a_sink_attaches() {
        let bridge = LogBridge::start(16, 16, 4).unwrap();
        log(&bridge, log::Level::Info, "first");
        log(&bridge, log::Level::Warn, "second");
        wait_for_backlog(&bridge, 2);

        let (sink, receiver, _open) = sink();
        bridge.attach(sink);
        log(&bridge, log::Level::Error, "third");

        assert_eq!(messages(&receiver), ["first", "second", "third"]);
    }

    #[test]
    fn closed_sink_is_detached_and_records_return_to_backlog() {
        let bridge = LogBridge::start(16, 16, 4).unwrap();
        let (first_sink, _first_receiver, first_open) = sink();
        bridge.attach(first_sink);
        first_open.store(false, Ordering::SeqCst);
        log(&bridge, log::Level::Info, "kept");
        wait_for_backlog(&bridge, 1);

        let (second_sink, second_receiver, _open) = sink();
        bridge.attach(second_sink);

        assert_eq!(messages(&second_receiver), ["kept"]);
    }

    #[test]
    fn backlog_overflow_evicts_oldest_and_reports_drop() {
        let bridge = LogBridge::start(16, 2, 1).unwrap();
        log(&bridge, log::Level::Info, "a");
        log(&bridge, log::Level::Info, "b");
        log(&bridge, log::Level::Info, "c");
        for _ in 0..200 {
            if bridge.shared.lock().overflowed == 1 {
                break;
            }
            thread::sleep(Duration::from_millis(5));
        }

        let (sink, receiver, _open) = sink();
        bridge.attach(sink);
        let delivered = messages(&receiver);

        assert_eq!(delivered.len(), 3);
        assert!(delivered[0].starts_with("1 Rust log entries were dropped"));
        assert_eq!(delivered[1..], ["b", "c"]);
    }

    #[test]
    fn records_logged_while_forwarding_are_ignored() {
        let bridge = LogBridge::start(16, 16, 4).unwrap();
        forwarding(|| log(&bridge, log::Level::Info, "re-entrant"));
        log(&bridge, log::Level::Info, "normal");
        wait_for_backlog(&bridge, 1);

        let (sink, receiver, _open) = sink();
        bridge.attach(sink);

        assert_eq!(messages(&receiver), ["normal"]);
    }

    #[test]
    fn full_queue_never_blocks_the_caller() {
        // The receiver is never drained, so only the first record fits.
        let (sender, _receiver) = mpsc::sync_channel(1);
        let bridge = LogBridge {
            sender,
            dropped: Arc::new(AtomicU64::new(0)),
            shared: Arc::new(Mutex::new(SinkState {
                sink: None,
                backlog: VecDeque::new(),
                backlog_capacity: 1,
                overflowed: 0,
            })),
        };
        for _ in 0..8 {
            log(&bridge, log::Level::Info, "lost");
        }
        assert_eq!(bridge.dropped.load(Ordering::Relaxed), 7);
    }
}
