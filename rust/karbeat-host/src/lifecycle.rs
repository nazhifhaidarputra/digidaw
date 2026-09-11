use std::sync::atomic::{AtomicU8, Ordering};

use crate::HostError;

const SUSPENDED: u8 = 0;
const READY: u8 = 1;
const PROCESSING: u8 = 2;
const SUSPENDING: u8 = 3;

/// Coordinates exclusive DSP access with nonblocking control-thread suspension.
/// The control owner may access processor internals only after `suspend` succeeds.
pub struct ProcessingGate(AtomicU8);

impl Default for ProcessingGate {
    fn default() -> Self {
        Self(AtomicU8::new(SUSPENDED))
    }
}

impl ProcessingGate {
    pub fn resume(&self) -> Result<(), HostError> {
        self.0
            .compare_exchange(SUSPENDED, READY, Ordering::Release, Ordering::Relaxed)
            .map(|_| ())
            .map_err(|_| HostError::InvalidTransition)
    }

    pub fn suspend(&self) -> Result<(), HostError> {
        loop {
            match self.0.load(Ordering::Acquire) {
                SUSPENDED => return Ok(()),
                READY => {
                    if self
                        .0
                        .compare_exchange(READY, SUSPENDED, Ordering::AcqRel, Ordering::Acquire)
                        .is_ok()
                    {
                        return Ok(());
                    }
                }
                PROCESSING => {
                    if self
                        .0
                        .compare_exchange(
                            PROCESSING,
                            SUSPENDING,
                            Ordering::AcqRel,
                            Ordering::Acquire,
                        )
                        .is_ok()
                    {
                        return Err(HostError::Busy);
                    }
                }
                _ => return Err(HostError::Busy),
            }
        }
    }

    /// The returned guard releases DSP ownership even if a caller exits early.
    pub fn enter(&self) -> Option<ProcessingGuard<'_>> {
        self.0
            .compare_exchange(READY, PROCESSING, Ordering::Acquire, Ordering::Relaxed)
            .ok()
            .map(|_| ProcessingGuard(self))
    }

    pub fn is_suspended(&self) -> bool {
        self.0.load(Ordering::Acquire) == SUSPENDED
    }
}

pub struct ProcessingGuard<'a>(&'a ProcessingGate);

impl Drop for ProcessingGuard<'_> {
    fn drop(&mut self) {
        if self
            .0
            .0
            .compare_exchange(PROCESSING, READY, Ordering::Release, Ordering::Relaxed)
            .is_err()
        {
            self.0.0.store(SUSPENDED, Ordering::Release);
        }
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "test fixtures use assertions for failure reporting"
)]
mod tests {
    use super::*;

    #[test]
    fn suspension_acknowledges_the_last_processing_block() {
        let gate = ProcessingGate::default();
        assert!(gate.enter().is_none());
        gate.resume().unwrap();
        let block = gate.enter().unwrap();
        assert!(gate.enter().is_none());
        assert!(matches!(gate.suspend(), Err(HostError::Busy)));
        assert!(gate.resume().is_err());
        drop(block);
        assert!(gate.is_suspended());
        assert!(gate.enter().is_none());
        gate.suspend().unwrap();
        gate.resume().unwrap();
        assert!(gate.resume().is_err());
    }
}
