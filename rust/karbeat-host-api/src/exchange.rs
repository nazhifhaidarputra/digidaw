//! Lock-free parameter exchange between a backend's control owner and its audio endpoint.

use std::sync::{
    Arc,
    atomic::{AtomicBool, AtomicI32, AtomicU8, AtomicU32, AtomicU64, Ordering},
};

/// Edit flag: the plugin or its editor began an automation gesture.
pub const EDIT_BEGIN: u8 = 1;
/// Edit flag: the value changed and should be reported to the host.
pub const EDIT_CHANGED: u8 = 2;
/// Edit flag: the plugin or its editor ended an automation gesture.
pub const EDIT_END: u8 = 4;

/// One normalized parameter shared by the control owner and the audio endpoint.
pub struct ParameterValue {
    /// Format-native parameter identifier.
    pub id: u32,
    /// Bits of the current normalized `f64` value.
    pub value: AtomicU64,
    /// Set while the value still has to reach the processor.
    pub pending: AtomicBool,
    /// Accumulated `EDIT_*` flags since the control owner last drained them.
    pub edits: AtomicU8,
    /// Set when the user moved this parameter outside the engine (for example in the plugin's
    /// native editor). Automation and modulation are ignored until the transport resets.
    manual_override: AtomicBool,
}

impl ParameterValue {
    /// Returns the current normalized value.
    pub fn get(&self) -> f64 {
        f64::from_bits(self.value.load(Ordering::Acquire))
    }

    /// Stores a normalized value for the processor and records `edit` flags for the host.
    pub fn set(&self, value: f64, edit: u8) {
        self.value.store(value.to_bits(), Ordering::Release);
        self.pending.store(true, Ordering::Release);
        self.edits.fetch_or(edit, Ordering::Relaxed);
    }

    /// Marks the parameter as changed by hand outside the engine's modulation path.
    pub fn mark_user_edited(&self) {
        self.manual_override.store(true, Ordering::Release);
    }

    /// Returns whether automation and modulation must leave this parameter alone.
    pub fn is_user_edited(&self) -> bool {
        self.manual_override.load(Ordering::Acquire)
    }

    /// Lets automation and modulation drive the parameter again.
    pub fn clear_user_edited(&self) {
        self.manual_override.store(false, Ordering::Release);
    }
}

/// Parameters, restart requests, and sticky status shared by one hosted instance.
pub struct ParameterExchange {
    /// Parameters sorted by identifier.
    pub parameters: Vec<ParameterValue>,
    /// Format-native restart flags requested by the plugin since the last drain.
    pub restart: AtomicI32,
    /// Set when a bounded per-block queue rejected an event or parameter point.
    pub overflow: AtomicBool,
    /// Last non-success result of the native process call, or zero.
    pub process_error: Arc<AtomicI32>,
    /// Work the plugin has that only its processor completes; see [`PendingWork`].
    pub work: Arc<PendingWork>,
}

/// Work a hosted plugin has outside its audio that only a processing call completes, shared by
/// every plugin format and reported to the engine through `AudioPlugin::has_pending_work`.
///
/// Formats record it in the two shapes plugins ask for it:
/// * counted units, each begun when it is queued and finished once the processor has taken it:
///   an editor message for the processor, or a background job and each of its responses;
/// * a single request for processing, such as CLAP's `request_process`, answered by the next
///   processed block.
///
/// A plugin often acts on what it just received only in a later block (LSP's sampler reads a
/// file path in one block and schedules the load in the next), so the work stays pending for
/// [`Self::FOLLOW_UP_BLOCKS`] processed blocks after its last unit finishes.
///
/// Every operation is lock-free and real-time safe.
#[derive(Debug, Default)]
pub struct PendingWork {
    outstanding: AtomicU32,
    requested: AtomicBool,
    follow_up: AtomicU32,
}

impl PendingWork {
    /// Processed blocks the work stays pending after its last unit finished.
    pub const FOLLOW_UP_BLOCKS: u32 = 16;

    /// Records one unit of work. Call it before the work becomes visible to the processor, so
    /// the processor can never finish a unit that was not yet counted.
    pub fn begin(&self) {
        self.outstanding.fetch_add(1, Ordering::AcqRel);
    }

    /// Records that one unit recorded with [`Self::begin`] is done, or was dropped.
    pub fn finish(&self) {
        // Before the unit is released, so the work never looks done in between.
        self.follow_up
            .store(Self::FOLLOW_UP_BLOCKS, Ordering::Release);
        // A unit is never finished twice. Stopping at zero keeps a stray call from wrapping
        // around, and the update fails only there, which needs no handling.
        drop(
            self.outstanding
                .try_update(Ordering::AcqRel, Ordering::Acquire, |count| {
                    count.checked_sub(1)
                }),
        );
    }

    /// Asks for one processing call.
    pub fn request(&self) {
        self.requested.store(true, Ordering::Release);
    }

    /// Called by the processor for every block it processes: the block answers a request and
    /// counts toward the follow-up after finished work.
    pub fn processed(&self) {
        self.requested.store(false, Ordering::Release);
        // Zero is already the floor, so a failed update needs no handling.
        drop(
            self.follow_up
                .try_update(Ordering::AcqRel, Ordering::Acquire, |blocks| {
                    blocks.checked_sub(1)
                }),
        );
    }

    /// Forgets every unit and request, for when the processor and the queues holding the units
    /// were replaced.
    pub fn reset(&self) {
        self.outstanding.store(0, Ordering::Release);
        self.requested.store(false, Ordering::Release);
        self.follow_up.store(0, Ordering::Release);
    }

    /// Whether a unit is outstanding or was finished only blocks ago, or a processing call was
    /// requested.
    pub fn is_pending(&self) -> bool {
        self.requested.load(Ordering::Acquire)
            || self.outstanding.load(Ordering::Acquire) > 0
            || self.follow_up.load(Ordering::Acquire) > 0
    }
}

impl ParameterExchange {
    /// Creates an exchange from `(identifier, normalized value)` pairs sorted by identifier.
    pub fn new(values: &[(u32, f64)]) -> Arc<Self> {
        Self::with_work(values, Arc::default())
    }

    /// Like [`Self::new`], sharing `work` with format callbacks created before the exchange.
    pub fn with_work(values: &[(u32, f64)], work: Arc<PendingWork>) -> Arc<Self> {
        Arc::new(Self {
            parameters: values
                .iter()
                .map(|&(id, value)| ParameterValue {
                    id,
                    value: AtomicU64::new(value.to_bits()),
                    pending: AtomicBool::new(false),
                    edits: AtomicU8::new(0),
                    manual_override: AtomicBool::new(false),
                })
                .collect(),
            restart: AtomicI32::new(0),
            overflow: AtomicBool::new(false),
            process_error: Arc::new(AtomicI32::new(0)),
            work,
        })
    }

    /// Looks up a parameter by its format-native identifier.
    pub fn parameter(&self, id: u32) -> Option<&ParameterValue> {
        self.parameters
            .binary_search_by_key(&id, |p| p.id)
            .ok()
            .and_then(|index| self.parameters.get(index))
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "test fixtures hold the looked-up parameter"
)]
mod tests {
    use super::*;

    #[test]
    fn values_are_found_by_identifier_and_edits_accumulate_until_drained() {
        let exchange = ParameterExchange::new(&[(3, 0.25), (9, 0.5)]);
        assert!(exchange.parameter(4).is_none());
        let parameter = exchange.parameter(9).unwrap();
        assert!(!parameter.pending.load(Ordering::Acquire));
        parameter.set(0.75, EDIT_BEGIN);
        parameter.set(1.0, EDIT_CHANGED);
        assert!((parameter.get() - 1.0).abs() < f64::EPSILON);
        assert!(parameter.pending.swap(false, Ordering::AcqRel));
        assert_eq!(
            parameter.edits.swap(0, Ordering::AcqRel),
            EDIT_BEGIN | EDIT_CHANGED
        );
        assert!((exchange.parameter(3).unwrap().get() - 0.25).abs() < f64::EPSILON);
    }

    #[test]
    fn pending_work_holds_while_units_are_outstanding_or_processing_was_requested() {
        let work = PendingWork::default();
        assert!(!work.is_pending());

        let settle = |work: &PendingWork| {
            for _ in 0..PendingWork::FOLLOW_UP_BLOCKS {
                assert!(work.is_pending());
                work.processed();
            }
            assert!(!work.is_pending());
        };

        work.begin();
        work.begin();
        work.finish();
        work.processed();
        assert!(work.is_pending());
        work.finish();
        // The plugin gets blocks to act on the finished work before it may park.
        settle(&work);
        // A stray finish does not wrap around into permanent pending work.
        work.finish();
        settle(&work);

        work.request();
        assert!(work.is_pending());
        work.processed();
        assert!(!work.is_pending());

        work.begin();
        work.request();
        work.reset();
        assert!(!work.is_pending());
    }

    #[test]
    fn user_edits_are_tracked_per_parameter_and_can_be_released() {
        let exchange = ParameterExchange::new(&[(3, 0.25), (9, 0.5)]);
        let parameter = exchange.parameter(9).unwrap();

        assert!(!parameter.is_user_edited());
        parameter.mark_user_edited();
        assert!(parameter.is_user_edited());
        assert!(!exchange.parameter(3).unwrap().is_user_edited());

        parameter.clear_user_edited();
        assert!(!parameter.is_user_edited());
    }
}
