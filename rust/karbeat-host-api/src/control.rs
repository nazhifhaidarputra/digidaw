/// A prepared control payload borrowed by DSP and returned for destruction off the audio thread.
pub struct ControlTransfer<T: Send> {
    payload: Option<Box<T>>,
    sender: rtrb::Producer<Box<T>>,
}

impl<T: Send> ControlTransfer<T> {
    /// Creates a payload transfer and its control-thread retirement receiver.
    ///
    /// The one-slot queue reserves return capacity before the payload can enter DSP ownership.
    pub fn new(payload: T) -> (Self, ControlRetirement<T>) {
        let (sender, receiver) = rtrb::RingBuffer::new(1);
        (
            Self {
                payload: Some(Box::new(payload)),
                sender,
            },
            ControlRetirement {
                receiver: Some(receiver),
                returned: false,
            },
        )
    }

    /// Borrows the in-transit payload until this transfer is dropped and returns ownership.
    pub fn get_mut(&mut self) -> Option<&mut T> {
        self.payload.as_deref_mut()
    }
}

impl<T: Send> Drop for ControlTransfer<T> {
    fn drop(&mut self) {
        if let Some(payload) = self.payload.take() {
            if let Err(rtrb::PushError::Full(payload)) = self.sender.push(payload) {
                std::mem::forget(payload);
            }
        }
    }
}

/// Must remain on its control owner until the one-use payload returns.
pub struct ControlRetirement<T: Send> {
    receiver: Option<rtrb::Consumer<Box<T>>>,
    returned: bool,
}

impl<T: Send> ControlRetirement<T> {
    /// Polls for the returned payload and destroys it on the control owner.
    ///
    /// Returns `true` only after the payload was collected and the producer was abandoned, so the
    /// retirement record can be removed safely.
    pub fn collect(&mut self) -> bool {
        if let Some(receiver) = &mut self.receiver {
            if let Ok(payload) = receiver.pop() {
                drop(payload);
                self.returned = true;
            }
            if self.returned && receiver.is_abandoned() {
                self.receiver.take();
                return true;
            }
        }
        false
    }
}

impl<T: Send> Drop for ControlRetirement<T> {
    fn drop(&mut self) {
        if let Some(receiver) = self.receiver.take() {
            if !receiver.is_abandoned() {
                log::error!("Plugin control owner shut down before command retirement");
                std::mem::forget(receiver);
            }
        }
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "retirement test must report thread failures"
)]
mod tests {
    use super::*;
    use shuttle::{
        sync::{Arc, Mutex},
        thread,
    };

    struct Payload(Arc<Mutex<Option<thread::ThreadId>>>);
    impl Drop for Payload {
        fn drop(&mut self) {
            *self.0.lock().unwrap() = Some(thread::current().id());
        }
    }

    #[test]
    fn applied_and_cancelled_payloads_drop_on_the_control_owner() {
        for apply in [false, true] {
            shuttle::check_pct(
                move || {
                    let destroyed = Arc::new(Mutex::new(None));
                    let (mut transfer, mut retirement) =
                        ControlTransfer::new(Payload(destroyed.clone()));
                    let audio = thread::spawn(move || {
                        if apply {
                            assert!(transfer.get_mut().is_some());
                        }
                        drop(transfer);
                    });
                    while !retirement.collect() {
                        assert!(destroyed.lock().unwrap().is_none());
                        thread::yield_now();
                    }
                    audio.join().unwrap();
                    assert_eq!(*destroyed.lock().unwrap(), Some(thread::current().id()));
                    assert!(!retirement.collect());
                },
                1_000,
                3,
            );
        }
    }
}
