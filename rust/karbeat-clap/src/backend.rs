//! The CLAP implementation of DigiDAW's universal native host contracts.

use std::{
    collections::HashMap,
    path::PathBuf,
    rc::Rc,
    sync::{Arc, atomic::Ordering},
    thread::ThreadId,
};

use karbeat_host_api::{
    DigidawPluginHost, EDIT_BEGIN, EDIT_CHANGED, EDIT_END, HostCapabilities, HostError, HostEvent,
    HostInstanceId, HostedProcessor, MAX_HOSTED_INSTANCES, NativeParentHandle,
    NativeSurfacePreference, NativeWindowConstraints, NativeWindowSize, PluginController,
    PluginDescriptor, PluginEditorManager, PluginFormat, PluginInstanceManager, PluginScanner,
    PluginState, ProcessingConfig, bypass::BypassDelay, native_host::EditorResizeHandler,
};
use karbeat_plugin_api::prelude::ParameterSpec;

use crate::{
    editor::SURFACE,
    module::{self, ClapModule},
    plugin::ClapInstance,
    wrapper::ClapProcessor,
};

/// UI-thread owner of CLAP plugin instances, their parameters, and their editors.
///
/// The host records its construction thread and rejects instance operations from any other
/// thread. Only the exclusive [`HostedProcessor`] endpoint produced for an instance crosses to
/// audio processing; instantiation, state, and editor work remain with this owner, which CLAP
/// calls the main thread.
pub struct ClapPluginHost {
    owner: ThreadId,
    instances: HashMap<HostInstanceId, ClapInstance>,
    /// Loaded modules by canonical path, kept for the host's lifetime.
    modules: HashMap<PathBuf, Rc<ClapModule>>,
    closed_editors: Vec<HostInstanceId>,
}

impl Default for ClapPluginHost {
    fn default() -> Self {
        Self::new()
    }
}

impl ClapPluginHost {
    /// Must be constructed on the native UI thread, which owns the host for its entire lifetime.
    pub fn new() -> Self {
        Self {
            owner: std::thread::current().id(),
            instances: HashMap::new(),
            modules: HashMap::new(),
            closed_editors: Vec::new(),
        }
    }

    fn check_thread(&self) -> Result<(), HostError> {
        if self.owner == std::thread::current().id() {
            Ok(())
        } else {
            Err(HostError::WrongThread)
        }
    }

    fn instance(&self, id: HostInstanceId) -> Result<&ClapInstance, HostError> {
        self.check_thread()?;
        self.instances
            .get(&id)
            .ok_or(HostError::UnknownInstance(id))
    }

    fn instance_mut(&mut self, id: HostInstanceId) -> Result<&mut ClapInstance, HostError> {
        self.check_thread()?;
        self.instances
            .get_mut(&id)
            .ok_or(HostError::UnknownInstance(id))
    }

    fn module(&mut self, path: &std::path::Path) -> Result<Rc<ClapModule>, HostError> {
        let path = std::fs::canonicalize(path)?;
        if let Some(module) = self.modules.get(&path) {
            return Ok(module.clone());
        }
        let module = ClapModule::load(&path)?;
        self.modules.insert(path, module.clone());
        Ok(module)
    }

    /// Whether control-side parameter edits still wait to reach the plugin.
    pub fn has_pending_parameters(&self, id: HostInstanceId) -> Result<bool, HostError> {
        Ok(self
            .instance(id)?
            .exchange
            .parameters
            .iter()
            .any(|parameter| parameter.pending.load(Ordering::Acquire)))
    }

    /// Services main-thread requests, timers, and descriptors of every instance, and activates
    /// plugins again that asked for a restart.
    ///
    /// # Errors
    ///
    /// Returns [`HostError::WrongThread`] unless called from the host's owner thread.
    pub fn pump(&mut self) -> Result<(), HostError> {
        self.check_thread()?;
        for (&id, instance) in &mut self.instances {
            if instance.pump() {
                self.closed_editors.push(id);
            }
            match instance.restart_if_requested() {
                Ok(()) | Err(HostError::Busy) => {}
                Err(error) => log::error!("{}: CLAP restart: {error}", instance.descriptor.name),
            }
        }
        Ok(())
    }

    /// Installs the callback used when the plugin asks its host window to resize.
    pub fn set_editor_resize_handler(
        &mut self,
        id: HostInstanceId,
        handler: EditorResizeHandler,
    ) -> Result<(), HostError> {
        self.instance_mut(id)?.set_editor_resize_handler(handler);
        Ok(())
    }

    /// Returns the discovery descriptor retained for `id`.
    ///
    /// # Errors
    ///
    /// Returns a wrong-thread or unknown-instance error when the instance cannot be accessed.
    pub fn descriptor(&self, id: HostInstanceId) -> Result<&PluginDescriptor, HostError> {
        Ok(&self.instance(id)?.descriptor)
    }

    /// Returns the processing configuration used to prepare `id`.
    ///
    /// # Errors
    ///
    /// Returns [`HostError::InvalidTransition`] before preparation has stored a configuration,
    /// in addition to wrong-thread and unknown-instance errors.
    pub fn processing_config(&self, id: HostInstanceId) -> Result<&ProcessingConfig, HostError> {
        self.instance(id)?
            .config()
            .ok_or(HostError::InvalidTransition)
    }
}

impl DigidawPluginHost for ClapPluginHost {}

impl PluginScanner for ClapPluginHost {
    fn format(&self) -> PluginFormat {
        PluginFormat::Clap
    }
    fn default_scan_paths(&self) -> Vec<PathBuf> {
        module::default_scan_paths()
    }
}

impl PluginInstanceManager for ClapPluginHost {
    fn is_processing(&self, id: HostInstanceId) -> Result<bool, HostError> {
        Ok(self.instance(id)?.is_running())
    }

    fn create(&mut self, descriptor: &PluginDescriptor) -> Result<HostInstanceId, HostError> {
        self.check_thread()?;
        if self.instances.len() >= MAX_HOSTED_INSTANCES {
            return Err(HostError::Busy);
        }
        if descriptor.identity.format != PluginFormat::Clap {
            return Err(HostError::Unsupported("plugin format"));
        }
        let module = self.module(&descriptor.path)?;
        let instance = ClapInstance::create(module, descriptor.clone())?;
        let id = HostInstanceId::allocate()?;
        self.instances.insert(id, instance);
        Ok(id)
    }

    fn capabilities(&mut self, id: HostInstanceId) -> Result<HostCapabilities, HostError> {
        let instance = self.instance(id)?;
        Ok(HostCapabilities {
            controller: true,
            editor: instance.has_editor(),
            sidechain: instance.has_sidechain(),
            offline: true,
        })
    }

    fn prepare(&mut self, id: HostInstanceId, config: &ProcessingConfig) -> Result<(), HostError> {
        self.instance_mut(id)?.prepare(config)
    }

    fn take_processor(&mut self, id: HostInstanceId) -> Result<Box<HostedProcessor>, HostError> {
        let instance = self.instance_mut(id)?;
        let slot = instance.slot.as_ref().ok_or(HostError::InvalidTransition)?;
        if instance.endpoint_taken || instance.config().is_none() {
            return Err(HostError::InvalidTransition);
        }
        let latency = slot.latency.load(Ordering::Acquire);
        let bypass_delay = BypassDelay::new(
            2,
            usize::try_from(latency).map_err(|_| HostError::InvalidConfiguration)?,
        )?;
        slot.endpoint_alive.store(true, Ordering::Release);
        let slot = slot.clone();
        instance.endpoint_taken = true;
        let fallback_tail = instance.config().map_or(0, |config| {
            karbeat_host_api::fallback_tail_samples(config.sample_rate)
        });
        let mut endpoint = HostedProcessor::new(
            Box::new(ClapProcessor {
                slot,
                exchange: instance.exchange.clone(),
                descriptor: instance.descriptor.clone(),
                specs: instance.parameters(),
                bypass: false,
                reset_pending: false,
                latency_seen: latency,
                bypass_delay,
            }),
            id,
        );
        endpoint.set_fallback_tail_samples(fallback_tail);
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
            .is_some_and(|slot| Arc::strong_count(slot) != 1)
        {
            return Err(HostError::Busy);
        }
        instance.suspend()?;
        self.instances.remove(&id);
        self.closed_editors.retain(|closed| *closed != id);
        Ok(())
    }
}

impl PluginController for ClapPluginHost {
    fn parameters(&self, id: HostInstanceId) -> Result<Vec<ParameterSpec>, HostError> {
        Ok(self.instance(id)?.parameters())
    }

    fn set_parameter(
        &mut self,
        id: HostInstanceId,
        parameter: u32,
        value: f64,
    ) -> Result<(), HostError> {
        validate_normalized(parameter, value)?;
        let instance = self.instance(id)?;
        if instance.parameter(parameter)?.read_only {
            return Err(HostError::InvalidParameter(parameter));
        }
        let shared = instance
            .exchange
            .parameter(parameter)
            .ok_or(HostError::InvalidParameter(parameter))?;
        shared.set(value, EDIT_CHANGED);
        shared.mark_user_edited();
        Ok(())
    }

    fn normalized_to_plain(
        &self,
        id: HostInstanceId,
        parameter: u32,
        value: f64,
    ) -> Result<f64, HostError> {
        validate_normalized(parameter, value)?;
        Ok(self.instance(id)?.parameter(parameter)?.to_plain(value))
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
        Ok(self
            .instance(id)?
            .parameter(parameter)?
            .to_normalized(value))
    }

    fn parameter_text(
        &self,
        id: HostInstanceId,
        parameter: u32,
        value: f64,
    ) -> Result<String, HostError> {
        validate_normalized(parameter, value)?;
        self.instance(id)?.parameter_text(parameter, value)
    }

    fn parse_parameter(
        &self,
        id: HostInstanceId,
        parameter: u32,
        text: &str,
    ) -> Result<f64, HostError> {
        self.instance(id)?.parse_parameter(parameter, text)
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
            for parameter in &instance.exchange.parameters {
                let edits = parameter.edits.swap(0, Ordering::AcqRel);
                if edits & EDIT_BEGIN != 0 {
                    events.push(HostEvent::BeginEdit {
                        instance: id,
                        parameter: parameter.id,
                    });
                }
                if edits & EDIT_CHANGED != 0 {
                    events.push(HostEvent::ParameterChanged {
                        instance: id,
                        parameter: parameter.id,
                        value: parameter.get(),
                    });
                }
                if edits & EDIT_END != 0 {
                    events.push(HostEvent::EndEdit {
                        instance: id,
                        parameter: parameter.id,
                    });
                }
            }
            if instance.exchange.overflow.swap(false, Ordering::AcqRel) {
                events.push(HostEvent::QueueOverflow { instance: id });
            }
        }
        events.extend(
            self.closed_editors
                .drain(..)
                .map(|instance| HostEvent::EditorClosed { instance }),
        );
        events
    }
}

impl PluginEditorManager for ClapPluginHost {
    fn editor_constraints(
        &mut self,
        id: HostInstanceId,
    ) -> Result<NativeWindowConstraints, HostError> {
        let instance = self.instance_mut(id)?;
        if instance.editor_resizable()? {
            Ok(NativeWindowConstraints::resizable())
        } else {
            let (width, height) = instance.editor_size()?;
            Ok(NativeWindowConstraints::fixed(NativeWindowSize::new(
                width, height,
            )?))
        }
    }

    fn editor_size(&mut self, id: HostInstanceId) -> Result<NativeWindowSize, HostError> {
        let (width, height) = self.instance_mut(id)?.editor_size()?;
        Ok(NativeWindowSize::new(width, height)?)
    }

    fn editor_surface_preference(
        &self,
        id: HostInstanceId,
    ) -> Result<NativeSurfacePreference, HostError> {
        self.instance(id)?;
        Ok(NativeSurfacePreference::Require(SURFACE))
    }

    fn open_editor(
        &mut self,
        id: HostInstanceId,
        parent: &NativeParentHandle,
    ) -> Result<(), HostError> {
        self.instance_mut(id)?.open_editor(parent)
    }

    fn resize_editor(
        &mut self,
        id: HostInstanceId,
        width: u32,
        height: u32,
    ) -> Result<(), HostError> {
        self.instance_mut(id)?.resize_editor(width, height)
    }

    fn close_editor(&mut self, id: HostInstanceId) -> Result<(), HostError> {
        self.instance_mut(id)?.close_editor();
        Ok(())
    }
}

impl Drop for ClapPluginHost {
    fn drop(&mut self) {
        for (_, instance) in self.instances.drain() {
            if instance
                .slot
                .as_ref()
                .is_some_and(|slot| Arc::strong_count(slot) != 1)
            {
                // Losing the UI owner before endpoint retirement cannot safely destroy the plugin.
                log::error!(
                    "CLAP host dropped before audio endpoint retirement; retaining instance for process lifetime"
                );
                std::mem::forget(instance);
            }
        }
    }
}

fn validate_normalized(parameter: u32, value: f64) -> Result<(), HostError> {
    if value.is_finite() && (0.0..=1.0).contains(&value) {
        Ok(())
    } else {
        Err(HostError::InvalidParameter(parameter))
    }
}
