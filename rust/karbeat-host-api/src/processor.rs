use crate::HostInstanceId;
use karbeat_plugin_api::prelude::*;

/// Maximum number of native instances accepted by one host implementation.
pub const MAX_HOSTED_INSTANCES: usize = 256;

/// Format-independent owned DSP endpoint. Core retires this concrete envelope to the UI
/// thread before destruction; its inner native processor is never cloned.
pub struct HostedProcessor {
    inner: Box<dyn AudioPlugin + Send>,
    /// Runtime handle used to correlate this endpoint with its native control owner.
    pub instance: HostInstanceId,
    bypass: bool,
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
            processing_status: None,
            retirement: None,
        }
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
        self.inner.tail_samples()
    }
    fn has_latency_changed(&mut self) -> bool {
        self.inner.has_latency_changed()
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
    use std::sync::{Arc, Mutex};

    struct Probe(Arc<Mutex<Option<std::thread::ThreadId>>>);
    impl Drop for Probe {
        fn drop(&mut self) {
            *self.0.lock().unwrap() = Some(std::thread::current().id());
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
    fn retiring_a_trait_object_returns_all_payload_destruction_to_the_control_owner() {
        let destroyed_on = Arc::new(Mutex::new(None));
        let mut endpoint = Box::new(HostedProcessor::new(
            Box::new(Probe(destroyed_on.clone())),
            HostInstanceId(1),
        ));
        let mut retirement = endpoint.enable_retirement().unwrap();
        assert!(endpoint.enable_retirement().is_err());
        assert!(retirement.take().is_none());
        std::thread::spawn(move || {
            let endpoint: Box<dyn AudioPlugin> = endpoint;
            endpoint.retire();
        })
        .join()
        .unwrap();
        assert!(destroyed_on.lock().unwrap().is_none());
        let endpoint = retirement.take().unwrap();
        assert_eq!(endpoint.instance, HostInstanceId(1));
        drop(endpoint);
        assert_eq!(
            *destroyed_on.lock().unwrap(),
            Some(std::thread::current().id())
        );
        assert!(retirement.take().is_none());
    }
}
