//! Lock-free parameter exchange between a backend's control owner and its audio endpoint.

use std::sync::{
    Arc,
    atomic::{AtomicBool, AtomicI32, AtomicU8, AtomicU64, Ordering},
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
}

impl ParameterExchange {
    /// Creates an exchange from `(identifier, normalized value)` pairs sorted by identifier.
    pub fn new(values: &[(u32, f64)]) -> Arc<Self> {
        Arc::new(Self {
            parameters: values
                .iter()
                .map(|&(id, value)| ParameterValue {
                    id,
                    value: AtomicU64::new(value.to_bits()),
                    pending: AtomicBool::new(false),
                    edits: AtomicU8::new(0),
                })
                .collect(),
            restart: AtomicI32::new(0),
            overflow: AtomicBool::new(false),
            process_error: Arc::new(AtomicI32::new(0)),
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
}
