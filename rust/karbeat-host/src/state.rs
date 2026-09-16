use std::sync::{
    Arc,
    atomic::{AtomicU8, Ordering},
};

use crate::{DigidawPluginHost, HostError, HostInstanceId, PluginState};

const WAITING: u8 = 0;
const EXECUTING: u8 = 1;
const CANCELLED: u8 = 2;
const COMPLETED: u8 = 3;

pub enum StateOperation {
    Capture,
    FlushParameters,
    Restore(PluginState),
}

#[derive(Debug)]
pub enum StateResult {
    Captured(PluginState),
    ParametersFlushed,
    Restored,
}

/// Thread-safe cancellation control; successful cancellation prevents the native state call.
#[derive(Clone)]
pub struct StateTransactionControl(Arc<AtomicU8>);
impl StateTransactionControl {
    pub fn is_cancelled(&self) -> bool {
        self.0.load(Ordering::Acquire) == CANCELLED
    }
    pub fn cancel(&self) -> bool {
        self.0
            .compare_exchange(WAITING, CANCELLED, Ordering::AcqRel, Ordering::Acquire)
            .is_ok()
    }
}

/// Polled by the native UI owner. Busy audio blocks yield to the next UI iteration.
/// Once polled, retain the transaction until completion, even after caller cancellation,
/// so an acknowledged suspension can restore the previous processing state.
pub struct StateTransaction {
    instance: HostInstanceId,
    operation: Option<StateOperation>,
    was_running: Option<bool>,
    status: Arc<AtomicU8>,
}

impl StateTransaction {
    pub fn new(
        instance: HostInstanceId,
        operation: StateOperation,
    ) -> (Self, StateTransactionControl) {
        let status = Arc::new(AtomicU8::new(WAITING));
        let control = StateTransactionControl(status.clone());
        (
            Self {
                instance,
                operation: Some(operation),
                was_running: None,
                status,
            },
            control,
        )
    }

    /// Returns None while waiting for suspension. A cancelled request still completes any
    /// suspension it requested and restores processing before releasing its control owner.
    pub fn poll(
        &mut self,
        host: &mut dyn DigidawPluginHost,
    ) -> Option<Result<StateResult, HostError>> {
        if self.status.load(Ordering::Acquire) == COMPLETED {
            return Some(Err(HostError::InvalidTransition));
        }
        if self.was_running.is_none() {
            if self.status.load(Ordering::Acquire) == CANCELLED {
                return self.finish(Err(HostError::Cancelled));
            }
            match host.is_processing(self.instance) {
                Ok(running) => self.was_running = Some(running),
                Err(error) => return self.finish(Err(error)),
            }
        }
        match host.suspend(self.instance) {
            Err(HostError::Busy) => return None,
            Err(error) => {
                let result = self.restore_processing(host, Err(error));
                return self.finish(result);
            }
            Ok(()) => {}
        }
        let result = if self
            .status
            .compare_exchange(WAITING, EXECUTING, Ordering::AcqRel, Ordering::Acquire)
            .is_err()
        {
            Err(HostError::Cancelled)
        } else {
            match self.operation.take() {
                Some(StateOperation::FlushParameters) => host
                    .flush_parameters(self.instance)
                    .map(|()| StateResult::ParametersFlushed),
                Some(StateOperation::Capture) => {
                    host.save_state(self.instance).map(StateResult::Captured)
                }
                Some(StateOperation::Restore(state)) => host
                    .restore_state(self.instance, &state)
                    .map(|()| StateResult::Restored),
                None => Err(HostError::InvalidTransition),
            }
        };
        let result = self.restore_processing(host, result);
        self.finish(result)
    }

    fn restore_processing(
        &self,
        host: &mut dyn DigidawPluginHost,
        result: Result<StateResult, HostError>,
    ) -> Result<StateResult, HostError> {
        if self.was_running == Some(true) {
            if let Err(resume) = host.resume(self.instance) {
                return Err(HostError::StateResume {
                    operation: result.err().map(Box::new),
                    resume: Box::new(resume),
                });
            }
        }
        result
    }

    fn finish(
        &mut self,
        result: Result<StateResult, HostError>,
    ) -> Option<Result<StateResult, HostError>> {
        self.status.store(COMPLETED, Ordering::Release);
        Some(result)
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::panic,
    reason = "test fixtures fail on unexpected host results"
)]
mod tests {
    use super::*;
    use crate::{
        HostCapabilities, HostEvent, HostedProcessor, NativeParentHandle, NativeSurfacePreference,
        NativeWindowConstraints, NativeWindowSize, PluginController, PluginDescriptor,
        PluginEditorManager, PluginFormat, PluginIdentity, PluginInstanceManager, PluginScanner,
        ProcessingConfig, ProcessingGate,
    };
    use karbeat_plugin_api::prelude::ParameterSpec;
    use std::path::PathBuf;

    struct MockHost {
        instance: Option<HostInstanceId>,
        next_id: u64,
        running: bool,
        gate: Arc<ProcessingGate>,
        calls: Vec<&'static str>,
        state_error: bool,
        resume_error: bool,
        cancel_during_capture: Option<StateTransactionControl>,
    }

    impl MockHost {
        fn new(running: bool) -> Self {
            let gate = Arc::new(ProcessingGate::default());
            if running {
                gate.resume().unwrap();
            }
            Self {
                instance: Some(HostInstanceId(1)),
                next_id: 2,
                running,
                gate,
                calls: Vec::new(),
                state_error: false,
                resume_error: false,
                cancel_during_capture: None,
            }
        }

        fn check(&self, id: HostInstanceId) -> Result<(), HostError> {
            if self.instance == Some(id) {
                Ok(())
            } else {
                Err(HostError::UnknownInstance(id))
            }
        }

        fn state() -> PluginState {
            PluginState {
                version: 1,
                identity: PluginIdentity {
                    format: PluginFormat::Clap,
                    native_id: "mock.instrument".into(),
                },
                component: vec![42],
                controller: None,
            }
        }
    }

    impl PluginScanner for MockHost {
        fn format(&self) -> PluginFormat {
            PluginFormat::Clap
        }
        fn default_scan_paths(&self) -> Vec<PathBuf> {
            Vec::new()
        }
    }
    impl PluginInstanceManager for MockHost {
        fn create(&mut self, _: &PluginDescriptor) -> Result<HostInstanceId, HostError> {
            if self.instance.is_some() {
                return Err(HostError::Busy);
            }
            let id = HostInstanceId(self.next_id);
            self.next_id += 1;
            self.instance = Some(id);
            Ok(id)
        }
        fn capabilities(&mut self, id: HostInstanceId) -> Result<HostCapabilities, HostError> {
            self.check(id)?;
            Ok(HostCapabilities::default())
        }
        fn prepare(
            &mut self,
            id: HostInstanceId,
            config: &ProcessingConfig,
        ) -> Result<(), HostError> {
            self.check(id)?;
            config.validate()?;
            self.suspend(id)
        }
        fn take_processor(
            &mut self,
            id: HostInstanceId,
        ) -> Result<Box<HostedProcessor>, HostError> {
            self.check(id)?;
            Err(HostError::Unsupported("mock has no audio endpoint"))
        }
        fn suspend(&mut self, id: HostInstanceId) -> Result<(), HostError> {
            self.check(id)?;
            self.calls.push("suspend");
            self.gate.suspend()?;
            self.running = false;
            Ok(())
        }
        fn resume(&mut self, id: HostInstanceId) -> Result<(), HostError> {
            self.check(id)?;
            self.calls.push("resume");
            if self.resume_error {
                return Err(HostError::PluginCall {
                    operation: "resume",
                    code: -1,
                });
            }
            self.gate.resume()?;
            self.running = true;
            Ok(())
        }
        fn is_processing(&self, id: HostInstanceId) -> Result<bool, HostError> {
            self.check(id)?;
            Ok(self.running)
        }
        fn destroy(&mut self, id: HostInstanceId) -> Result<(), HostError> {
            self.suspend(id)?;
            self.instance = None;
            Ok(())
        }
    }
    impl PluginController for MockHost {
        fn parameters(&self, id: HostInstanceId) -> Result<Vec<ParameterSpec>, HostError> {
            self.check(id)?;
            Ok(Vec::new())
        }
        fn set_parameter(
            &mut self,
            id: HostInstanceId,
            parameter: u32,
            _: f64,
        ) -> Result<(), HostError> {
            self.check(id)?;
            Err(HostError::InvalidParameter(parameter))
        }
        fn flush_parameters(&mut self, id: HostInstanceId) -> Result<(), HostError> {
            self.check(id)?;
            assert!(self.gate.is_suspended());
            self.calls.push("flush");
            Ok(())
        }
        fn save_state(&mut self, id: HostInstanceId) -> Result<PluginState, HostError> {
            self.check(id)?;
            assert!(self.gate.is_suspended());
            self.calls.push("capture");
            if let Some(control) = &self.cancel_during_capture {
                assert!(!control.cancel());
            }
            if self.state_error {
                return Err(HostError::InvalidState("capture failed".into()));
            }
            Ok(Self::state())
        }
        fn restore_state(
            &mut self,
            id: HostInstanceId,
            state: &PluginState,
        ) -> Result<(), HostError> {
            self.check(id)?;
            assert!(self.gate.is_suspended());
            self.calls.push("restore");
            if state.version != 1 {
                return Err(HostError::InvalidState("unsupported version".into()));
            }
            Ok(())
        }
        fn drain_events(&mut self) -> Vec<HostEvent> {
            Vec::new()
        }
    }
    impl PluginEditorManager for MockHost {
        fn editor_size(&mut self, id: HostInstanceId) -> Result<NativeWindowSize, HostError> {
            self.check(id)?;
            Err(HostError::Unsupported("native editor"))
        }
        fn editor_constraints(
            &mut self,
            id: HostInstanceId,
        ) -> Result<NativeWindowConstraints, HostError> {
            self.editor_size(id).map(NativeWindowConstraints::fixed)
        }
        fn editor_surface_preference(
            &self,
            id: HostInstanceId,
        ) -> Result<NativeSurfacePreference, HostError> {
            self.check(id)?;
            Ok(NativeSurfacePreference::AnySupported)
        }
        fn open_editor(
            &mut self,
            id: HostInstanceId,
            _: &NativeParentHandle,
        ) -> Result<(), HostError> {
            self.editor_size(id).map(|_| ())
        }
        fn resize_editor(&mut self, id: HostInstanceId, _: u32, _: u32) -> Result<(), HostError> {
            self.editor_size(id).map(|_| ())
        }
        fn close_editor(&mut self, id: HostInstanceId) -> Result<(), HostError> {
            self.check(id)
        }
    }
    impl DigidawPluginHost for MockHost {}

    #[test]
    fn parameter_flush_preserves_running_intent_without_serializing_state() {
        for running in [false, true] {
            let mut host = MockHost::new(running);
            let gate = host.gate.clone();
            let audio = running.then(|| gate.enter().unwrap());
            let (mut transaction, _) =
                StateTransaction::new(HostInstanceId(1), StateOperation::FlushParameters);
            if running {
                assert!(transaction.poll(&mut host).is_none());
            }
            drop(audio);
            assert!(matches!(
                transaction.poll(&mut host),
                Some(Ok(StateResult::ParametersFlushed))
            ));
            assert_eq!(host.running, running);
            assert!(host.calls.contains(&"flush"));
            assert!(!host.calls.contains(&"capture"));
        }
    }

    #[test]
    fn capture_waits_for_audio_acknowledgement_and_resumes() {
        let mut host = MockHost::new(true);
        let gate = host.gate.clone();
        let block = gate.enter().unwrap();
        let (mut transaction, control) =
            StateTransaction::new(HostInstanceId(1), StateOperation::Capture);
        assert!(transaction.poll(&mut host).is_none());
        assert!(host.running);
        assert_eq!(host.calls, ["suspend"]);
        drop(block);
        assert!(
            matches!(transaction.poll(&mut host), Some(Ok(StateResult::Captured(state))) if state == MockHost::state())
        );
        assert_eq!(host.calls, ["suspend", "suspend", "capture", "resume"]);
        assert!(gate.enter().is_some());
        assert!(!control.cancel());
        assert!(matches!(
            transaction.poll(&mut host),
            Some(Err(HostError::InvalidTransition))
        ));
    }

    #[test]
    fn cancellation_before_poll_does_not_touch_the_instance() {
        let mut host = MockHost::new(true);
        let (mut transaction, control) =
            StateTransaction::new(HostInstanceId(1), StateOperation::Capture);
        assert!(control.cancel());
        assert!(matches!(
            transaction.poll(&mut host),
            Some(Err(HostError::Cancelled))
        ));
        assert!(host.calls.is_empty());
        assert!(host.running);
    }

    #[test]
    fn cancellation_while_audio_is_busy_still_resumes_after_acknowledgement() {
        let mut host = MockHost::new(true);
        let gate = host.gate.clone();
        let block = gate.enter().unwrap();
        let (mut transaction, control) = StateTransaction::new(
            HostInstanceId(1),
            StateOperation::Restore(MockHost::state()),
        );
        assert!(transaction.poll(&mut host).is_none());
        assert!(std::thread::spawn(move || control.cancel()).join().unwrap());
        assert!(transaction.poll(&mut host).is_none());
        drop(block);
        assert!(matches!(
            transaction.poll(&mut host),
            Some(Err(HostError::Cancelled))
        ));
        assert_eq!(host.calls, ["suspend", "suspend", "suspend", "resume"]);
        assert!(host.running);
        assert!(gate.enter().is_some());
    }

    #[test]
    fn executing_state_call_cannot_be_cancelled() {
        let mut host = MockHost::new(true);
        let (mut transaction, control) =
            StateTransaction::new(HostInstanceId(1), StateOperation::Capture);
        host.cancel_during_capture = Some(control);
        assert!(matches!(
            transaction.poll(&mut host),
            Some(Ok(StateResult::Captured(_)))
        ));
    }

    #[test]
    fn stopped_instance_stays_stopped_after_restore() {
        let mut host = MockHost::new(false);
        let (mut transaction, _) = StateTransaction::new(
            HostInstanceId(1),
            StateOperation::Restore(MockHost::state()),
        );
        assert!(matches!(
            transaction.poll(&mut host),
            Some(Ok(StateResult::Restored))
        ));
        assert_eq!(host.calls, ["suspend", "restore"]);
        assert!(!host.running);
        assert!(host.gate.enter().is_none());
    }

    #[test]
    fn failed_capture_and_corrupt_restore_resume_processing() {
        let mut host = MockHost::new(true);
        host.state_error = true;
        let mut invalid = MockHost::state();
        invalid.version = 99;
        for operation in [StateOperation::Capture, StateOperation::Restore(invalid)] {
            host.calls.clear();
            let (mut transaction, _) = StateTransaction::new(HostInstanceId(1), operation);
            assert!(matches!(
                transaction.poll(&mut host),
                Some(Err(HostError::InvalidState(_)))
            ));
            assert_eq!(host.calls.last(), Some(&"resume"));
            assert!(host.running);
            assert!(host.gate.enter().is_some());
        }
    }

    #[test]
    fn resume_failure_preserves_both_operation_errors() {
        for state_error in [false, true] {
            let mut host = MockHost::new(true);
            host.state_error = state_error;
            host.resume_error = true;
            let (mut transaction, _) =
                StateTransaction::new(HostInstanceId(1), StateOperation::Capture);
            let Some(Err(HostError::StateResume { operation, resume })) =
                transaction.poll(&mut host)
            else {
                panic!("resume failure must be visible");
            };
            assert_eq!(operation.is_some(), state_error);
            assert!(matches!(
                *resume,
                HostError::PluginCall {
                    operation: "resume",
                    ..
                }
            ));
            assert!(!host.running);
        }
    }

    #[test]
    fn universal_host_rejects_invalid_transitions_and_stale_handles() {
        let mut host: Box<dyn DigidawPluginHost> = Box::new(MockHost::new(false));
        let id = HostInstanceId(1);
        host.resume(id).unwrap();
        assert!(matches!(host.resume(id), Err(HostError::InvalidTransition)));
        host.destroy(id).unwrap();
        let descriptor = PluginDescriptor {
            identity: MockHost::state().identity,
            path: PathBuf::from("mock.clap"),
            name: "Mock".into(),
            vendor: String::new(),
            version: "1".into(),
            kind: crate::PluginKind::Instrument,
        };
        assert_ne!(host.create(&descriptor).unwrap(), id);
        let (mut transaction, _) = StateTransaction::new(id, StateOperation::Capture);
        assert!(
            matches!(transaction.poll(host.as_mut()), Some(Err(HostError::UnknownInstance(stale))) if stale == id)
        );
    }
}
