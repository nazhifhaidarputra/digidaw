//! Non-blocking forwarding of Rust `tracing` events to the Flutter log viewer.
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
use std::fmt::{self, Write as _};
use std::sync::{Arc, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

use tracing::field::{Field, Visit};
use tracing_log::NormalizeEvent;
use tracing_subscriber::Layer;
use tracing_subscriber::layer::Context;

use crate::api::logging::{RustLogEntryDto, RustLogLevel};
use crate::sync::atomic::{AtomicU64, Ordering};
use crate::sync::mpsc::{self, Receiver, SyncSender, TrySendError};
use crate::sync::{Mutex, thread, thread_local};

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

/// Starts the process-wide bridge used by [`LogBridgeLayer`].
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

    /// Queues an entry without blocking; entries are dropped (and counted)
    /// when the queue is full. `message` only runs when the entry is forwarded.
    fn push(&self, level: RustLogLevel, target: &str, message: impl FnOnce() -> String) {
        if FORWARDING.with(Cell::get) {
            return;
        }
        let entry = RustLogEntryDto {
            timestamp_millis: now_millis(),
            level,
            target: target.to_owned(),
            message: message(),
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
    FORWARDING.with(|forwarding| forwarding.set(true));
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
    let previous = FORWARDING.with(|forwarding| forwarding.replace(true));
    let result = operation();
    FORWARDING.with(|forwarding| forwarding.set(previous));
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

/// Subscriber layer forwarding every event accepted by the process filter to
/// Flutter through the bridge.
pub(crate) struct LogBridgeLayer {
    bridge: &'static LogBridge,
}

impl LogBridgeLayer {
    pub(crate) fn new(bridge: &'static LogBridge) -> Self {
        Self { bridge }
    }
}

impl<S: tracing::Subscriber> Layer<S> for LogBridgeLayer {
    fn on_event(&self, event: &tracing::Event<'_>, _context: Context<'_, S>) {
        push_event(self.bridge, event);
    }
}

fn push_event(bridge: &LogBridge, event: &tracing::Event<'_>) {
    // Records bridged from the `log` crate carry their real target in fields.
    let normalized = event.normalized_metadata();
    let metadata = normalized.as_ref().unwrap_or_else(|| event.metadata());
    bridge.push((*metadata.level()).into(), metadata.target(), || {
        let mut visitor = MessageVisitor::default();
        event.record(&mut visitor);
        visitor.finish()
    });
}

/// Renders an event as its message followed by any structured `name=value` fields.
#[derive(Default)]
struct MessageVisitor {
    message: String,
    fields: String,
}

impl MessageVisitor {
    fn finish(mut self) -> String {
        if self.message.is_empty() {
            return self.fields;
        }
        if !self.fields.is_empty() {
            self.message.push(' ');
            self.message.push_str(&self.fields);
        }
        self.message
    }
}

impl Visit for MessageVisitor {
    fn record_debug(&mut self, field: &Field, value: &dyn fmt::Debug) {
        let written = if field.name() == "message" {
            write!(self.message, "{value:?}")
        } else if field.name().starts_with("log.") {
            Ok(())
        } else {
            let separator = if self.fields.is_empty() { "" } else { " " };
            write!(self.fields, "{separator}{}={value:?}", field.name())
        };
        debug_assert!(written.is_ok(), "writing to a String cannot fail");
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::indexing_slicing,
    reason = "log bridge tests fail immediately when the drain thread cannot start"
)]
mod tests {
    use tracing_log::log;
    use tracing_subscriber::layer::SubscriberExt as _;

    use super::*;
    use crate::sync::{atomic::AtomicBool, check_random};

    struct ChannelSink {
        batches: mpsc::Sender<Vec<RustLogEntryDto>>,
        open: Arc<AtomicBool>,
    }

    impl LogBatchSink for ChannelSink {
        fn send_batch(&self, batch: &[RustLogEntryDto]) -> bool {
            self.open.load(Ordering::SeqCst) && self.batches.send(batch.to_vec()).is_ok()
        }
    }

    fn sink() -> (
        Box<dyn LogBatchSink>,
        mpsc::Receiver<Vec<RustLogEntryDto>>,
        Arc<AtomicBool>,
    ) {
        let (sender, receiver) = mpsc::channel();
        let open = Arc::new(AtomicBool::new(true));
        let sink = ChannelSink {
            batches: sender,
            open: Arc::clone(&open),
        };
        (Box::new(sink), receiver, open)
    }

    fn log(bridge: &LogBridge, level: RustLogLevel, message: &str) {
        bridge.push(level, "karbeat::test", || message.to_owned());
    }

    /// Forwards events to an owned bridge, unlike the production layer's `'static` one.
    struct OwnedBridgeLayer(Arc<LogBridge>);

    impl<S: tracing::Subscriber> Layer<S> for OwnedBridgeLayer {
        fn on_event(&self, event: &tracing::Event<'_>, _context: Context<'_, S>) {
            push_event(&self.0, event);
        }
    }

    /// Runs `emit` under a subscriber holding only a bridge layer, then returns what it forwarded.
    fn capture(emit: impl FnOnce()) -> Vec<RustLogEntryDto> {
        let bridge = Arc::new(LogBridge::start(16, 16, 4).unwrap());
        let (sink, receiver, _open) = sink();
        bridge.attach(sink);
        let subscriber = tracing_subscriber::registry().with(OwnedBridgeLayer(Arc::clone(&bridge)));
        tracing::subscriber::with_default(subscriber, emit);
        drop(bridge);
        receiver.iter().flatten().collect()
    }

    /// Drops the bridge so the drain thread flushes its queue and releases the sink, then
    /// returns every message the sink received.
    fn close_and_collect(
        bridge: LogBridge,
        receiver: &mpsc::Receiver<Vec<RustLogEntryDto>>,
    ) -> Vec<String> {
        drop(bridge);
        receiver
            .iter()
            .flatten()
            .map(|entry| entry.message)
            .collect()
    }

    fn wait_until(bridge: &LogBridge, condition: impl Fn(&SinkState) -> bool) {
        while !condition(&bridge.shared.lock()) {
            thread::yield_now();
        }
    }

    #[test]
    fn backlog_is_flushed_in_order_when_a_sink_attaches() {
        check_random(
            || {
                let bridge = LogBridge::start(16, 16, 4).unwrap();
                log(&bridge, RustLogLevel::Info, "first");
                log(&bridge, RustLogLevel::Warn, "second");
                wait_until(&bridge, |state| state.backlog.len() >= 2);

                let (sink, receiver, _open) = sink();
                bridge.attach(sink);
                log(&bridge, RustLogLevel::Error, "third");

                assert_eq!(
                    close_and_collect(bridge, &receiver),
                    ["first", "second", "third"]
                );
            },
            200,
        );
    }

    #[test]
    fn closed_sink_is_detached_and_records_return_to_backlog() {
        check_random(
            || {
                let bridge = LogBridge::start(16, 16, 4).unwrap();
                let (first_sink, _first_receiver, first_open) = sink();
                bridge.attach(first_sink);
                first_open.store(false, Ordering::SeqCst);
                log(&bridge, RustLogLevel::Info, "kept");
                wait_until(&bridge, |state| state.backlog.len() >= 1);

                let (second_sink, second_receiver, _open) = sink();
                bridge.attach(second_sink);

                assert_eq!(close_and_collect(bridge, &second_receiver), ["kept"]);
            },
            200,
        );
    }

    #[test]
    fn backlog_overflow_evicts_oldest_and_reports_drop() {
        check_random(
            || {
                let bridge = LogBridge::start(16, 2, 1).unwrap();
                log(&bridge, RustLogLevel::Info, "a");
                log(&bridge, RustLogLevel::Info, "b");
                log(&bridge, RustLogLevel::Info, "c");
                wait_until(&bridge, |state| state.overflowed == 1);

                let (sink, receiver, _open) = sink();
                bridge.attach(sink);
                let delivered = close_and_collect(bridge, &receiver);

                assert_eq!(delivered.len(), 3);
                assert!(delivered[0].starts_with("1 Rust log entries were dropped"));
                assert_eq!(delivered[1..], ["b", "c"]);
            },
            200,
        );
    }

    #[test]
    fn records_logged_while_forwarding_are_ignored() {
        check_random(
            || {
                let bridge = LogBridge::start(16, 16, 4).unwrap();
                forwarding(|| log(&bridge, RustLogLevel::Info, "re-entrant"));
                log(&bridge, RustLogLevel::Info, "normal");
                wait_until(&bridge, |state| state.backlog.len() >= 1);

                let (sink, receiver, _open) = sink();
                bridge.attach(sink);

                assert_eq!(close_and_collect(bridge, &receiver), ["normal"]);
            },
            200,
        );
    }

    #[test]
    fn full_queue_never_blocks_the_caller() {
        check_random(
            || {
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
                    log(&bridge, RustLogLevel::Info, "lost");
                }
                assert_eq!(bridge.dropped.load(Ordering::Relaxed), 7);
            },
            1,
        );
    }
    #[test]
    fn events_keep_their_level_target_and_fields() {
        check_random(
            || {
                let entries = capture(|| {
                    tracing::warn!(target: "karbeat::test", voice = 3, "stolen {}", "note");
                });

                assert_eq!(entries.len(), 1);
                assert_eq!(entries[0].level, RustLogLevel::Warn);
                assert_eq!(entries[0].target, "karbeat::test");
                assert_eq!(entries[0].message, "stolen note voice=3");
            },
            1,
        );
    }

    #[test]
    fn log_crate_records_keep_their_real_target() {
        check_random(
            || {
                let entries = capture(|| {
                    log::Log::log(
                        &tracing_log::LogTracer::new(),
                        &log::Record::builder()
                            .level(log::Level::Error)
                            .target("cpal::host")
                            .args(format_args!("stream lost"))
                            .build(),
                    );
                });

                assert_eq!(entries.len(), 1);
                assert_eq!(entries[0].level, RustLogLevel::Error);
                assert_eq!(entries[0].target, "cpal::host");
                assert_eq!(entries[0].message, "stream lost");
            },
            1,
        );
    }
}
