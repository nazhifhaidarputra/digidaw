use crate::HostInstanceId;
use karbeat_plugin_api::prelude::*;

/// Maximum number of native instances accepted by one host implementation.
pub const MAX_HOSTED_INSTANCES: usize = 256;

/// Tail used for hosted formats that cannot report one, in seconds.
pub const FALLBACK_TAIL_SECONDS: u32 = 5;

/// Converts the fallback tail into samples at `sample_rate`.
#[allow(
    clippy::as_conversions,
    reason = "the fallback duration is a small bounded constant and the result is a sample count"
)]
pub fn fallback_tail_samples(sample_rate: f64) -> u32 {
    (sample_rate * f64::from(FALLBACK_TAIL_SECONDS)) as u32
}

/// Format-independent owned DSP endpoint. Core retires this concrete envelope to the UI
/// thread before destruction; its inner native processor is never cloned.
pub struct HostedProcessor {
    inner: Box<dyn AudioPlugin + Send>,
    /// Runtime handle used to correlate this endpoint with its native control owner.
    pub instance: HostInstanceId,
    bypass: bool,
    /// Opt-in for endpoints that must run even when their channel is silent.
    continuous_processing: bool,
    /// Tail used when the format cannot report one, so a parked hosted endpoint still rings
    /// out for a bounded time after its last active block.
    fallback_tail_samples: u32,
    processing_status: Option<std::sync::Arc<std::sync::atomic::AtomicI32>>,
    retirement: Option<rtrb::Producer<Box<HostedProcessor>>>,
}
impl HostedProcessor {
    /// Wraps an exclusive native processor endpoint for format-independent engine use.
    pub fn new(inner: Box<dyn AudioPlugin + Send>, instance: HostInstanceId) -> Self {
        Self {
            inner,
            instance,
            bypass: false,
            continuous_processing: false,
            fallback_tail_samples: 0,
            processing_status: None,
            retirement: None,
        }
    }

    /// Sets the tail reported while a format backend cannot provide one.
    pub fn set_fallback_tail_samples(&mut self, samples: u32) {
        self.fallback_tail_samples = samples;
    }

    /// Marks an endpoint that must keep processing while its channel is silent.
    pub fn set_continuous_processing(&mut self, continuous: bool) {
        self.continuous_processing = continuous;
    }

    /// Returns the last bypass state sent through this wrapper.
    pub fn is_bypassed(&self) -> bool {
        self.bypass
    }

    /// Attach the backend's sticky process status before publishing the endpoint.
    pub fn set_processing_status(&mut self, status: std::sync::Arc<std::sync::atomic::AtomicI32>) {
        self.processing_status = Some(status);
    }

    /// Read on a control/render worker; a nonzero native result is retained until acknowledged.
    pub fn processing_error(&self) -> Option<crate::HostError> {
        let code = self
            .processing_status
            .as_ref()?
            .load(std::sync::atomic::Ordering::Acquire);
        (code != 0).then_some(crate::HostError::PluginCall {
            operation: "processor.process",
            code,
        })
    }

    /// Install a one-use return queue before transferring this endpoint to the engine.
    pub fn enable_retirement(&mut self) -> Result<ProcessorRetirement, crate::HostError> {
        if self.retirement.is_some() {
            return Err(crate::HostError::InvalidTransition);
        }
        let (sender, receiver) = rtrb::RingBuffer::new(1);
        self.retirement = Some(sender);
        Ok(ProcessorRetirement {
            receiver: Some(receiver),
        })
    }

    /// Make publication failure and discarded commands return ownership to the native owner.
    pub fn prepare_transfer(
        mut self: Box<Self>,
    ) -> Result<(PreparedProcessor, ProcessorRetirement), crate::HostError> {
        let retirement = self.enable_retirement()?;
        Ok((
            PreparedProcessor {
                processor: Some(self),
            },
            retirement,
        ))
    }
}

/// An endpoint in transit. Dropping it before installation uses its reserved retirement queue.
pub struct PreparedProcessor {
    processor: Option<Box<HostedProcessor>>,
}
impl PreparedProcessor {
    /// Copies cached parameter values while the endpoint is still owned by a control worker.
    pub fn parameter_values(&self) -> Vec<(u32, f32)> {
        self.processor.as_ref().map_or_else(Vec::new, |processor| {
            processor
                .get_parameter_specs()
                .iter()
                .map(|spec| (spec.id, processor.get_parameter(spec.id)))
                .collect()
        })
    }

    /// Consumes the transfer and returns its endpoint for installation in the audio graph.
    ///
    /// Returns [`HostError::InvalidTransition`] if the endpoint was already taken.
    pub fn install(mut self) -> Result<Box<dyn AudioPlugin>, crate::HostError> {
        self.processor
            .take()
            .map(|processor| -> Box<dyn AudioPlugin> { processor })
            .ok_or(crate::HostError::InvalidTransition)
    }
}
impl Drop for PreparedProcessor {
    fn drop(&mut self) {
        if let Some(processor) = self.processor.take() {
            processor.retire();
        }
    }
}

/// Retained by the native control owner until the endpoint has been returned and destroyed.
pub struct ProcessorRetirement {
    receiver: Option<rtrb::Consumer<Box<HostedProcessor>>>,
}
impl ProcessorRetirement {
    /// True after the endpoint has released its producer, including control-worker unwind.
    pub fn is_abandoned(&self) -> bool {
        self.receiver
            .as_ref()
            .is_none_or(rtrb::Consumer::is_abandoned)
    }
    /// Takes the returned endpoint when the audio side has retired it.
    ///
    /// The control owner must destroy the returned value on its native owner thread.
    pub fn take(&mut self) -> Option<Box<HostedProcessor>> {
        self.receiver
            .as_mut()
            .and_then(|receiver| receiver.pop().ok())
    }
}
impl Drop for ProcessorRetirement {
    fn drop(&mut self) {
        if let Some(receiver) = self.receiver.take() {
            if !receiver.is_abandoned() {
                // A premature control-owner shutdown must not make the audio thread the final
                // owner of the return queue. Retain it until process exit rather than unload code.
                log::error!("Hosted plugin owner shut down before endpoint retirement");
                std::mem::forget(receiver);
            }
        }
    }
}
impl AudioPlugin for HostedProcessor {
    fn retire(mut self: Box<Self>) {
        if let Some(mut sender) = self.retirement.take() {
            // This private producer is used exactly once, with capacity reserved at creation.
            if let Err(rtrb::PushError::Full(endpoint)) = sender.push(self) {
                std::mem::forget(endpoint);
            }
        }
    }
    fn name(&self) -> &str {
        self.inner.name()
    }
    fn vendor(&self) -> &str {
        self.inner.vendor()
    }
    fn version(&self) -> &str {
        self.inner.version()
    }
    fn category(&self) -> PluginCategory {
        self.inner.category()
    }
    fn prepare(&mut self, rate: f32, frames: usize) {
        self.inner.prepare(rate, frames);
    }
    fn reset(&mut self) {
        self.inner.reset();
    }
    fn can_apply_io_layout(&self, inputs: &[BusConfig], outputs: &[BusConfig]) -> bool {
        self.inner.can_apply_io_layout(inputs, outputs)
    }
    fn set_io_layout(&mut self, inputs: &[BusConfig], outputs: &[BusConfig]) {
        self.inner.set_io_layout(inputs, outputs);
    }
    fn process(&mut self, buffers: &mut AudioBuffers, context: &ProcessContext) {
        self.inner.process(buffers, context);
    }
    fn set_bypass(&mut self, bypass: bool) {
        self.bypass = bypass;
        self.inner.set_bypass(bypass);
    }
    fn latency_samples(&self) -> u32 {
        self.inner.latency_samples()
    }
    fn tail_samples(&self) -> u32 {
        let reported = self.inner.tail_samples();
        if reported > 0 {
            reported
        } else {
            self.fallback_tail_samples
        }
    }
    fn has_latency_changed(&mut self) -> bool {
        self.inner.has_latency_changed()
    }
    fn needs_continuous_processing(&self) -> bool {
        // Hosted endpoints are parked like built-in processors by default. The engine keeps
        // them alive while they carry signal and for their reported (or fallback) tail; the
        // native host's existing flush transaction delivers parameter edits when one wakes.
        // Endpoints that genuinely generate or scan audio without input opt in explicitly.
        self.continuous_processing || self.inner.needs_continuous_processing()
    }
    fn set_parameter(&mut self, id: u32, value: f32) {
        self.inner.set_parameter(id, value);
    }
    fn get_parameter(&self, id: u32) -> f32 {
        self.inner.get_parameter(id)
    }
    fn get_current_parameter(&self, id: u32) -> f32 {
        self.inner.get_current_parameter(id)
    }
    fn apply_automation(&mut self, id: u32, value: f32) {
        self.inner.apply_automation(id, value);
    }
    fn clear_automation(&mut self, id: u32) {
        self.inner.clear_automation(id);
    }
    fn clear_parameter_overrides(&mut self) {
        self.inner.clear_parameter_overrides();
    }
    fn begin_parameter_edit(&mut self, id: u32) {
        self.inner.begin_parameter_edit(id);
    }
    fn end_parameter_edit(&mut self, id: u32) {
        self.inner.end_parameter_edit(id);
    }
    fn plain_to_normalized(&self, id: u32, value: f32) -> f32 {
        self.inner.plain_to_normalized(id, value)
    }
    fn normalized_to_plain(&self, id: u32, value: f32) -> f32 {
        self.inner.normalized_to_plain(id, value)
    }
    fn value_to_string(&self, id: u32, value: f32) -> String {
        self.inner.value_to_string(id, value)
    }
    fn string_to_value(&self, id: u32, value: &str) -> Option<f32> {
        self.inner.string_to_value(id, value)
    }
    fn default_parameters(&self) -> HashMap<u32, f32> {
        self.inner.default_parameters()
    }
    fn static_parameter_specs() -> Vec<ParameterSpec> {
        Vec::new()
    }
    fn get_parameter_specs(&self) -> Vec<ParameterSpec> {
        self.inner.get_parameter_specs()
    }
    fn get_state(&self) -> Vec<u8> {
        self.inner.get_state()
    }
    fn set_state(&mut self, state: &[u8]) {
        self.inner.set_state(state);
        self.inner.clear_parameter_overrides();
    }
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "test setup and thread failures should fail the test"
)]
mod tests {
    use super::*;
    use shuttle::{
        sync::{Arc, Mutex},
        thread,
    };

    struct ParkProbe;

    impl AudioPlugin for ParkProbe {
        fn name(&self) -> &str {
            "park probe"
        }
        fn category(&self) -> PluginCategory {
            PluginCategory::Effect
        }
        fn prepare(&mut self, _: f32, _: usize) {}
        fn reset(&mut self) {}
        fn set_io_layout(&mut self, _: &[BusConfig], _: &[BusConfig]) {}
        fn process(&mut self, _: &mut AudioBuffers, _: &ProcessContext) {}
        fn set_parameter(&mut self, _: u32, _: f32) {}
        fn get_parameter(&self, _: u32) -> f32 {
            0.0
        }
        fn apply_automation(&mut self, _: u32, _: f32) {}
        fn clear_automation(&mut self, _: u32) {}
        fn default_parameters(&self) -> HashMap<u32, f32> {
            HashMap::new()
        }
        fn static_parameter_specs() -> Vec<ParameterSpec> {
            Vec::new()
        }
        fn get_parameter_specs(&self) -> Vec<ParameterSpec> {
            Vec::new()
        }
        fn as_any(&self) -> &dyn std::any::Any {
            self
        }
    }

    struct Probe(Arc<Mutex<Option<thread::ThreadId>>>);
    impl Drop for Probe {
        fn drop(&mut self) {
            *self.0.lock().unwrap() = Some(thread::current().id());
        }
    }
    impl AudioPlugin for Probe {
        fn name(&self) -> &str {
            "retirement probe"
        }
        fn category(&self) -> PluginCategory {
            PluginCategory::Instrument
        }
        fn prepare(&mut self, _: f32, _: usize) {}
        fn reset(&mut self) {}
        fn set_io_layout(&mut self, _: &[BusConfig], _: &[BusConfig]) {}
        fn process(&mut self, _: &mut AudioBuffers, _: &ProcessContext) {}
        fn set_parameter(&mut self, _: u32, _: f32) {}
        fn get_parameter(&self, _: u32) -> f32 {
            0.0
        }
        fn apply_automation(&mut self, _: u32, _: f32) {}
        fn clear_automation(&mut self, _: u32) {}
        fn default_parameters(&self) -> HashMap<u32, f32> {
            HashMap::new()
        }
        fn static_parameter_specs() -> Vec<ParameterSpec> {
            Vec::new()
        }
        fn get_parameter_specs(&self) -> Vec<ParameterSpec> {
            Vec::new()
        }
        fn as_any(&self) -> &dyn std::any::Any {
            self
        }
    }

    #[test]
    fn hosted_endpoints_park_by_default_and_can_opt_into_continuous_processing() {
        let mut endpoint = HostedProcessor::new(Box::new(ParkProbe), HostInstanceId(1));
        assert!(!endpoint.needs_continuous_processing());
        endpoint.set_continuous_processing(true);
        assert!(endpoint.needs_continuous_processing());
        assert_eq!(endpoint.tail_samples(), 0);
        endpoint.set_fallback_tail_samples(1_234);
        assert_eq!(endpoint.tail_samples(), 1_234);
    }

    #[test]
    fn retiring_a_trait_object_returns_all_payload_destruction_to_the_control_owner() {
        shuttle::check_pct(
            || {
                let destroyed_on = Arc::new(Mutex::new(None));
                let mut endpoint = Box::new(HostedProcessor::new(
                    Box::new(Probe(destroyed_on.clone())),
                    HostInstanceId(1),
                ));
                let mut retirement = endpoint.enable_retirement().unwrap();
                assert!(endpoint.enable_retirement().is_err());
                assert!(retirement.take().is_none());
                let audio = thread::spawn(move || {
                    let endpoint: Box<dyn AudioPlugin> = endpoint;
                    endpoint.retire();
                });
                let endpoint = loop {
                    if let Some(endpoint) = retirement.take() {
                        break endpoint;
                    }
                    assert!(destroyed_on.lock().unwrap().is_none());
                    thread::yield_now();
                };
                audio.join().unwrap();
                assert!(destroyed_on.lock().unwrap().is_none());
                assert_eq!(endpoint.instance, HostInstanceId(1));
                drop(endpoint);
                assert_eq!(*destroyed_on.lock().unwrap(), Some(thread::current().id()));
                assert!(retirement.take().is_none());
            },
            1_000,
            3,
        );
    }
}
