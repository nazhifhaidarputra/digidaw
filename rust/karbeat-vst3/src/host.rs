//! The VST3 implementation of DigiDAW's universal native host contracts.

use crate::{
    context::Vst3HostContext,
    editor::Vst3Editor,
    instance::{Vst3Instance, check},
    module::{self, Vst3Module},
    wrapper::Vst3Processor,
};
use karbeat_host::*;
use karbeat_plugin_api::prelude::ParameterSpec;
use std::{collections::HashMap, path::PathBuf, rc::Rc, sync::atomic::Ordering, thread::ThreadId};
use vst3::{
    ComWrapper,
    Steinberg::{FUnknown, IPluginFactory3, IPluginFactory3Trait, Vst::IEditControllerTrait},
};

pub struct Vst3PluginHost {
    owner: ThreadId,
    context: ComWrapper<Vst3HostContext>,
    instances: HashMap<HostInstanceId, Vst3Instance>,
    modules: HashMap<PathBuf, Rc<Vst3Module>>,
    next_id: u64,
}
impl Default for Vst3PluginHost {
    fn default() -> Self {
        Self::new()
    }
}
impl Vst3PluginHost {
    /// Must be constructed on the native UI thread, which owns the host for its entire lifetime.
    pub fn new() -> Self {
        Self {
            owner: std::thread::current().id(),
            context: ComWrapper::new(Vst3HostContext::default()),
            instances: HashMap::new(),
            modules: HashMap::new(),
            next_id: 1,
        }
    }
    fn check_thread(&self) -> Result<(), HostError> {
        if self.owner == std::thread::current().id() {
            Ok(())
        } else {
            Err(HostError::WrongThread)
        }
    }
    fn instance(&self, id: HostInstanceId) -> Result<&Vst3Instance, HostError> {
        self.check_thread()?;
        self.instances
            .get(&id)
            .ok_or(HostError::UnknownInstance(id))
    }
    fn parameter_controller(
        &self,
        id: HostInstanceId,
        parameter: u32,
    ) -> Result<&vst3::ComPtr<vst3::Steinberg::Vst::IEditController>, HostError> {
        let instance = self.instance(id)?;
        instance
            .exchange
            .parameter(parameter)
            .ok_or(HostError::InvalidParameter(parameter))?;
        instance
            .controller
            .as_ref()
            .ok_or(HostError::Unsupported("edit controller"))
    }
    fn instance_mut(&mut self, id: HostInstanceId) -> Result<&mut Vst3Instance, HostError> {
        self.check_thread()?;
        self.instances
            .get_mut(&id)
            .ok_or(HostError::UnknownInstance(id))
    }
    pub(crate) fn has_pending_parameters(&self, id: HostInstanceId) -> Result<bool, HostError> {
        Ok(self
            .instance(id)?
            .exchange
            .parameters
            .iter()
            .any(|parameter| parameter.pending.load(Ordering::Acquire)))
    }
    pub fn pump(&self) -> Result<(), HostError> {
        self.check_thread()?;
        self.context.run_loop.pump();
        Ok(())
    }
    pub fn set_editor_resize_handler(
        &mut self,
        id: HostInstanceId,
        handler: Rc<dyn Fn(u32, u32) -> bool>,
    ) -> Result<(), HostError> {
        self.ensure_editor(id)?;
        self.instance(id)?
            .editor
            .as_ref()
            .ok_or(HostError::InvalidTransition)?
            .set_resize_handler(handler);
        Ok(())
    }
    pub fn descriptor(&self, id: HostInstanceId) -> Result<&PluginDescriptor, HostError> {
        Ok(&self.instance(id)?.descriptor)
    }
    pub fn processing_config(&self, id: HostInstanceId) -> Result<&ProcessingConfig, HostError> {
        self.instance(id)?
            .config
            .as_ref()
            .ok_or(HostError::InvalidTransition)
    }
    fn ensure_editor(&mut self, id: HostInstanceId) -> Result<(), HostError> {
        let run_loop = self.context.run_loop.clone();
        let instance = self.instance_mut(id)?;
        if instance.editor.is_none() {
            let controller = instance
                .controller
                .as_ref()
                .ok_or(HostError::Unsupported("edit controller"))?;
            instance.editor = Some(Vst3Editor::create(controller, run_loop)?);
        }
        Ok(())
    }
}
impl DigidawPluginHost for Vst3PluginHost {}
impl PluginScanner for Vst3PluginHost {
    fn format(&self) -> PluginFormat {
        PluginFormat::Vst3
    }
    fn default_scan_paths(&self) -> Vec<PathBuf> {
        module::default_scan_paths()
    }
}
impl PluginInstanceManager for Vst3PluginHost {
    fn is_processing(&self, id: HostInstanceId) -> Result<bool, HostError> {
        Ok(self.instance(id)?.running)
    }
    fn create(&mut self, descriptor: &PluginDescriptor) -> Result<HostInstanceId, HostError> {
        self.check_thread()?;
        if self.instances.len() >= MAX_HOSTED_INSTANCES {
            return Err(HostError::Busy);
        }
        if descriptor.identity.format != PluginFormat::Vst3 {
            return Err(HostError::Unsupported("plugin format"));
        }
        let path = std::fs::canonicalize(&descriptor.path)?;
        let module = if let Some(module) = self.modules.get(&path) {
            module.clone()
        } else {
            let module = Vst3Module::load(&path)?;
            if let Some(factory) = module.factory()?.cast::<IPluginFactory3>() {
                let context = self
                    .context
                    .as_com_ref::<FUnknown>()
                    .ok_or(HostError::Unsupported("host context"))?;
                // SAFETY: Host context including IRunLoop outlives all module instances.
                check("factory.setHostContext", unsafe {
                    factory.setHostContext(context.as_ptr())
                })?;
            }
            self.modules.insert(path, module.clone());
            module
        };
        let descriptors = module.descriptors()?;
        let descriptor = descriptors
            .into_iter()
            .find(|d| d.identity == descriptor.identity)
            .ok_or_else(|| HostError::Module {
                path: module.path.clone(),
                message: "component class is no longer available".into(),
            })?;
        let context = self
            .context
            .to_com_ptr::<FUnknown>()
            .ok_or(HostError::Unsupported("host context"))?;
        let instance = Vst3Instance::create(module, descriptor, context)?;
        let id = HostInstanceId(self.next_id);
        self.next_id = self
            .next_id
            .checked_add(1)
            .ok_or(HostError::InvalidTransition)?;
        self.instances.insert(id, instance);
        Ok(id)
    }
    fn capabilities(&mut self, id: HostInstanceId) -> Result<HostCapabilities, HostError> {
        let editor = match self.ensure_editor(id) {
            Ok(()) => true,
            Err(HostError::Unsupported(_)) => false,
            Err(error) => return Err(error),
        };
        let instance = self.instance(id)?;
        let mut sidechain = false;
        if let Some(component) = &instance.component {
            use vst3::Steinberg::Vst::{BusInfo, IComponentTrait};
            // SAFETY: Bus metadata is queried on the component's owning UI thread.
            let count = unsafe { component.getBusCount(0, 0) }.clamp(0, 64);
            for index in 0..count {
                // SAFETY: BusInfo is a plain ABI record with valid zero values.
                let mut info: BusInfo = unsafe { std::mem::zeroed() };
                // SAFETY: index is within the component's reported bus count.
                if unsafe { component.getBusInfo(0, 0, index, &raw mut info) } == 0
                    && info.busType == 1
                {
                    sidechain = true;
                }
            }
        }
        Ok(HostCapabilities {
            controller: instance.controller.is_some(),
            editor,
            sidechain,
            offline: true,
        })
    }
    fn prepare(&mut self, id: HostInstanceId, config: &ProcessingConfig) -> Result<(), HostError> {
        self.instance_mut(id)?.prepare(config)
    }
    fn take_processor(&mut self, id: HostInstanceId) -> Result<Box<HostedProcessor>, HostError> {
        let instance = self.instance_mut(id)?;
        let slot = instance.slot.as_ref().ok_or(HostError::InvalidTransition)?;
        if instance.endpoint_taken {
            return Err(HostError::InvalidTransition);
        }
        let bypass_delay = karbeat_host::bypass::BypassDelay::new(
            2,
            usize::try_from(slot.latency.load(Ordering::Acquire))
                .map_err(|_| HostError::InvalidConfiguration)?,
        )?;
        slot.endpoint_alive.store(true, Ordering::Release);
        instance.endpoint_taken = true;
        let mut endpoint = HostedProcessor::new(
            Box::new(Vst3Processor {
                slot: slot.clone(),
                exchange: instance.exchange.clone(),
                descriptor: instance.descriptor.clone(),
                specs: instance.specs.clone(),
                bypass: false,
                reset_pending: false,
                latency_seen: slot.latency.load(Ordering::Acquire),
                bypass_delay,
            }),
            id,
        );
        endpoint.set_processing_status(instance.exchange.process_error.clone());
        Ok(Box::new(endpoint))
    }
    fn suspend(&mut self, id: HostInstanceId) -> Result<(), HostError> {
        self.instance_mut(id)?.suspend()
    }
    fn resume(&mut self, id: HostInstanceId) -> Result<(), HostError> {
        self.instance_mut(id)?.resume()
    }
    fn destroy(&mut self, id: HostInstanceId) -> Result<(), HostError> {
        let instance = self.instance_mut(id)?;
        if instance
            .slot
            .as_ref()
            .is_some_and(|s| std::sync::Arc::strong_count(s) != 1)
        {
            return Err(HostError::Busy);
        }
        instance.suspend()?;
        self.instances.remove(&id);
        Ok(())
    }
}
impl PluginController for Vst3PluginHost {
    fn parameters(&self, id: HostInstanceId) -> Result<Vec<ParameterSpec>, HostError> {
        Ok(self.instance(id)?.specs.clone())
    }
    fn set_parameter(
        &mut self,
        id: HostInstanceId,
        parameter: u32,
        value: f64,
    ) -> Result<(), HostError> {
        if !value.is_finite() || !(0.0..=1.0).contains(&value) {
            return Err(HostError::InvalidParameter(parameter));
        }
        let instance = self.instance_mut(id)?;
        let param = instance
            .exchange
            .parameter(parameter)
            .ok_or(HostError::InvalidParameter(parameter))?;
        if let Some(controller) = &instance.controller {
            // SAFETY: Host API executes on the controller's UI thread with a known parameter ID.
            check("controller.setParamNormalized", unsafe {
                controller.setParamNormalized(parameter, value)
            })?;
        }
        param.set(value, 2);
        Ok(())
    }
    fn normalized_to_plain(
        &self,
        id: HostInstanceId,
        parameter: u32,
        value: f64,
    ) -> Result<f64, HostError> {
        validate_normalized(parameter, value)?;
        let controller = self.parameter_controller(id, parameter)?;
        // SAFETY: The controller and parameter are validated on their native UI owner.
        let plain = unsafe { controller.normalizedParamToPlain(parameter, value) };
        if plain.is_finite() {
            Ok(plain)
        } else {
            Err(HostError::InvalidParameter(parameter))
        }
    }
    fn plain_to_normalized(
        &self,
        id: HostInstanceId,
        parameter: u32,
        value: f64,
    ) -> Result<f64, HostError> {
        if !value.is_finite() {
            return Err(HostError::InvalidParameter(parameter));
        }
        let controller = self.parameter_controller(id, parameter)?;
        // SAFETY: The controller and parameter are validated on their native UI owner.
        let normalized = unsafe { controller.plainParamToNormalized(parameter, value) };
        validate_normalized(parameter, normalized)?;
        Ok(normalized)
    }
    fn parameter_text(
        &self,
        id: HostInstanceId,
        parameter: u32,
        value: f64,
    ) -> Result<String, HostError> {
        validate_normalized(parameter, value)?;
        let controller = self.parameter_controller(id, parameter)?;
        let mut text = [0_u16; 128];
        // SAFETY: The controller receives writable String128 storage on its UI owner.
        check("controller.getParamStringByValue", unsafe {
            controller.getParamStringByValue(parameter, value, &raw mut text)
        })?;
        Ok(crate::api::string128_to_string(&text))
    }
    fn parse_parameter(
        &self,
        id: HostInstanceId,
        parameter: u32,
        text: &str,
    ) -> Result<f64, HostError> {
        let controller = self.parameter_controller(id, parameter)?;
        let mut encoded = [0_u16; 128];
        let mut length = 0;
        for unit in text.encode_utf16() {
            if unit == 0 || length >= 127 {
                return Err(HostError::InvalidParameter(parameter));
            }
            encoded[length] = unit;
            length += 1;
        }
        let mut value = 0.0;
        // SAFETY: The terminated UTF-16 text and output value remain live for this UI call.
        check("controller.getParamValueByString", unsafe {
            controller.getParamValueByString(parameter, encoded.as_mut_ptr(), &raw mut value)
        })?;
        validate_normalized(parameter, value)?;
        Ok(value)
    }
    fn flush_parameters(&mut self, id: HostInstanceId) -> Result<(), HostError> {
        self.instance_mut(id)?.flush_parameters()
    }
    fn save_state(&mut self, id: HostInstanceId) -> Result<PluginState, HostError> {
        self.instance_mut(id)?.save_state()
    }
    fn restore_state(&mut self, id: HostInstanceId, state: &PluginState) -> Result<(), HostError> {
        self.instance_mut(id)?.restore_state(state)
    }
    fn drain_events(&mut self) -> Vec<HostEvent> {
        if self.check_thread().is_err() {
            return Vec::new();
        }
        let mut events = Vec::new();
        for (&id, instance) in &self.instances {
            for param in &instance.exchange.parameters {
                let edits = param.edits.swap(0, Ordering::AcqRel);
                if edits & 1 != 0 {
                    events.push(HostEvent::BeginEdit {
                        instance: id,
                        parameter: param.id,
                    });
                }
                if edits & 2 != 0 {
                    events.push(HostEvent::ParameterChanged {
                        instance: id,
                        parameter: param.id,
                        value: param.get(),
                    });
                }
                if edits & 4 != 0 {
                    events.push(HostEvent::EndEdit {
                        instance: id,
                        parameter: param.id,
                    });
                }
            }
            let flags = instance.exchange.restart.swap(0, Ordering::AcqRel);
            if flags != 0 {
                events.push(HostEvent::RestartRequested {
                    instance: id,
                    flags: u32::from_ne_bytes(flags.to_ne_bytes()),
                });
            }
            if instance.exchange.overflow.swap(false, Ordering::AcqRel) {
                events.push(HostEvent::QueueOverflow { instance: id });
            }
        }
        events
    }
}
impl PluginEditorManager for Vst3PluginHost {
    fn editor_constraints(
        &mut self,
        id: HostInstanceId,
    ) -> Result<NativeWindowConstraints, HostError> {
        self.ensure_editor(id)?;
        let editor = self
            .instance(id)?
            .editor
            .as_ref()
            .ok_or(HostError::InvalidTransition)?;
        if editor.resizable()? {
            Ok(NativeWindowConstraints::resizable())
        } else {
            let (width, height) = editor.size()?;
            Ok(NativeWindowConstraints::fixed(NativeWindowSize::new(
                width, height,
            )?))
        }
    }
    fn editor_size(&mut self, id: HostInstanceId) -> Result<NativeWindowSize, HostError> {
        self.ensure_editor(id)?;
        let (width, height) = self
            .instance(id)?
            .editor
            .as_ref()
            .ok_or(HostError::InvalidTransition)?
            .size()?;
        Ok(NativeWindowSize::new(width, height)?)
    }
    fn editor_surface_preference(
        &self,
        id: HostInstanceId,
    ) -> Result<NativeSurfacePreference, HostError> {
        self.instance(id)?;
        #[cfg(target_os = "linux")]
        let surface = NativeSurfaceKind::X11;
        #[cfg(target_os = "windows")]
        let surface = NativeSurfaceKind::Win32;
        #[cfg(target_os = "macos")]
        let surface = NativeSurfaceKind::AppKit;
        Ok(NativeSurfacePreference::Require(surface))
    }
    fn open_editor(
        &mut self,
        id: HostInstanceId,
        parent: &NativeParentHandle,
    ) -> Result<(), HostError> {
        self.ensure_editor(id)?;
        self.instance_mut(id)?
            .editor
            .as_mut()
            .ok_or(HostError::InvalidTransition)?
            .open(parent)
    }
    fn resize_editor(
        &mut self,
        id: HostInstanceId,
        width: u32,
        height: u32,
    ) -> Result<(), HostError> {
        self.instance(id)?
            .editor
            .as_ref()
            .ok_or(HostError::InvalidTransition)?
            .resize(width, height)
    }
    fn close_editor(&mut self, id: HostInstanceId) -> Result<(), HostError> {
        let instance = self.instance_mut(id)?;
        if let Some(mut editor) = instance.editor.take() {
            editor.close()?;
        }
        Ok(())
    }
}
impl Drop for Vst3PluginHost {
    fn drop(&mut self) {
        for (_, instance) in self.instances.drain() {
            if instance
                .slot
                .as_ref()
                .is_some_and(|s| std::sync::Arc::strong_count(s) != 1)
            {
                // Losing the UI owner before endpoint retirement cannot safely unload native code.
                log::error!(
                    "VST3 host dropped before audio endpoint retirement; retaining module for process lifetime"
                );
                std::mem::forget(instance);
            }
        }
        self.context.run_loop.clear();
        self.modules.clear();
    }
}

fn validate_normalized(parameter: u32, value: f64) -> Result<(), HostError> {
    if value.is_finite() && (0.0..=1.0).contains(&value) {
        Ok(())
    } else {
        Err(HostError::InvalidParameter(parameter))
    }
}
