//! One LV2 plugin instance, created and run through lilv.
//!
//! lilv instantiates the plugin: it loads the library, finds the descriptor, checks required
//! features, and passes the bundle path. Everything after that goes through the plugin's own
//! `LV2_Descriptor`, read with the `lv2-sys` definitions so optional entries stay optional.

use std::{
    ffi::{CStr, c_void},
    ptr::NonNull,
    sync::MutexGuard,
};

use karbeat_host_api::{HostError, ProcessingConfig};
use lilv_sys as sys;

use crate::{
    ports::PluginModel,
    urid,
    worker::{WorkerPort, WorkerResponses, WorkerThread},
};

/// Features the host passes to a plugin. A plugin that requires any other one is not hosted.
pub(crate) const SUPPORTED_FEATURES: [&str; 5] = [
    "http://lv2plug.in/ns/ext/urid#map",
    "http://lv2plug.in/ns/ext/urid#unmap",
    "http://lv2plug.in/ns/ext/options#options",
    "http://lv2plug.in/ns/ext/buf-size#boundedBlockLength",
    "http://lv2plug.in/ns/ext/worker#schedule",
];

/// Reads a NUL-terminated URI constant from the `lv2-sys` bindings.
fn uri(bytes: &'static [u8]) -> &'static CStr {
    CStr::from_bytes_until_nul(bytes).unwrap_or_default()
}

const fn end_of_options() -> lv2_sys::LV2_Options_Option {
    lv2_sys::LV2_Options_Option {
        context: lv2_sys::LV2_Options_Context_LV2_OPTIONS_INSTANCE,
        subject: 0,
        key: 0,
        size: 0,
        type_: 0,
        value: std::ptr::null(),
    }
}

/// Feature records handed to the plugin at instantiation. They are boxed with the instance
/// because a plugin may keep the pointers for its whole lifetime.
struct Features {
    block_lengths: [i32; 2],
    options: [lv2_sys::LV2_Options_Option; 3],
    worker: Option<WorkerPort>,
    records: Vec<lv2_sys::LV2_Feature>,
    pointers: Vec<*const lv2_sys::LV2_Feature>,
}

impl Features {
    fn new(max_block_size: usize, with_worker: bool) -> Result<Box<Self>, HostError> {
        let max_block =
            i32::try_from(max_block_size).map_err(|_| HostError::InvalidConfiguration)?;
        let mut features = Box::new(Self {
            block_lengths: [1, max_block],
            options: [end_of_options(); 3],
            worker: with_worker.then(WorkerPort::new),
            records: Vec::new(),
            pointers: Vec::new(),
        });
        let int = urid::map(uri(lv2_sys::LV2_ATOM__Int));
        let length = |key: &'static [u8], value: &i32| lv2_sys::LV2_Options_Option {
            key: urid::map(uri(key)),
            size: 4,
            type_: int,
            value: std::ptr::from_ref(value).cast(),
            ..end_of_options()
        };
        let [minimum, maximum] = &features.block_lengths;
        features.options = [
            length(lv2_sys::LV2_BUF_SIZE__minBlockLength, minimum),
            length(lv2_sys::LV2_BUF_SIZE__maxBlockLength, maximum),
            end_of_options(),
        ];
        let options = lv2_sys::LV2_Feature {
            URI: lv2_sys::LV2_OPTIONS__options.as_ptr().cast(),
            data: std::ptr::from_mut(&mut features.options).cast(),
        };
        let bounded = lv2_sys::LV2_Feature {
            URI: lv2_sys::LV2_BUF_SIZE__boundedBlockLength.as_ptr().cast(),
            data: std::ptr::null_mut(),
        };
        features.records = [urid::map_feature(), urid::unmap_feature(), options, bounded]
            .into_iter()
            .chain(features.worker.as_ref().map(WorkerPort::feature))
            .collect();
        features.pointers = features
            .records
            .iter()
            .map(std::ptr::from_ref)
            .chain([std::ptr::null()])
            .collect();
        Ok(features)
    }
}

/// An activated plugin instance with its control-port storage and worker.
///
/// The instance is created, destroyed, and has its state accessed on the UI owner; `run` is
/// called by whichever side holds exclusive DSP access.
pub(crate) struct PluginInstance {
    raw: NonNull<sys::LilvInstance>,
    descriptor: NonNull<lv2_sys::LV2_Descriptor>,
    handle: lv2_sys::LV2_Handle,
    /// One value per port, by port index; control ports are connected to their entry.
    controls: Box<[f32]>,
    responses: Option<WorkerResponses>,
    worker: Option<WorkerThread>,
    active: bool,
    features: Box<Features>,
}

impl PluginInstance {
    /// Instantiates and activates `plugin` for `config`, with control inputs at their defaults.
    ///
    /// Audio, CV, and atom ports are left for the caller to connect before the first `run`.
    pub fn instantiate(
        plugin: *const sys::LilvPlugin,
        model: &PluginModel,
        config: &ProcessingConfig,
    ) -> Result<Self, HostError> {
        let features = Features::new(config.max_block_size, model.schedules_work)?;
        // SAFETY: Runs plugin code on the UI owner. The plugin record belongs to a live world
        // and the feature list is null-terminated and outlives the instance.
        let raw = unsafe {
            sys::lilv_plugin_instantiate(
                plugin,
                config.sample_rate,
                features.pointers.as_ptr().cast(),
            )
        };
        let raw = NonNull::new(raw).ok_or(HostError::PluginCall {
            operation: "lv2.instantiate",
            code: -1,
        })?;
        // SAFETY: lilv returned a live instance record.
        let record = unsafe { raw.as_ref() };
        let handle: lv2_sys::LV2_Handle = record.lv2_handle.cast();
        let Some(descriptor) = NonNull::new(record.lv2_descriptor.cast_mut().cast()) else {
            // SAFETY: The instance is not used again.
            unsafe { sys::lilv_instance_free(raw.as_ptr()) };
            return Err(HostError::Unsupported("LV2 plugin descriptor"));
        };
        let mut instance = Self {
            raw,
            descriptor,
            handle,
            controls: vec![0.0; model.symbols.len()].into_boxed_slice(),
            responses: None,
            worker: None,
            active: false,
            features,
        };
        for control in model.controls.iter() {
            instance.set_control(control.index, control.range.default);
        }
        let ports = u32::try_from(instance.controls.len()).unwrap_or(0);
        for port in (0..ports).filter(|port| model.is_control(*port)) {
            let Some(value) = usize::try_from(port)
                .ok()
                .and_then(|index| instance.controls.get_mut(index))
            else {
                continue;
            };
            let location = std::ptr::from_mut(value).cast();
            // SAFETY: The boxed control storage lives as long as the instance and never moves.
            unsafe { instance.connect(port, location) };
        }
        let interface = instance
            .extension_data(uri(lv2_sys::LV2_WORKER__interface))
            .cast::<lv2_sys::LV2_Worker_Interface>();
        // SAFETY: A non-null worker interface is a static record in the plugin library.
        let interface = unsafe { interface.as_ref() };
        if let (Some(port), Some(interface)) = (instance.features.worker.as_mut(), interface) {
            let (responses, worker) = port.attach(interface, handle, config.offline)?;
            instance.responses = Some(responses);
            instance.worker = worker;
        }
        if let Some(activate) = instance.descriptor().activate {
            // SAFETY: The instance is instantiated and its control ports are connected.
            unsafe { activate(handle) };
        }
        instance.active = true;
        Ok(instance)
    }

    fn descriptor(&self) -> &lv2_sys::LV2_Descriptor {
        // SAFETY: The descriptor is a static record in the plugin library, which lilv keeps
        // loaded until the instance is freed.
        unsafe { self.descriptor.as_ref() }
    }

    /// The plugin's `LV2_Handle`, shared with editors through `instance-access`.
    pub const fn handle(&self) -> lv2_sys::LV2_Handle {
        self.handle
    }

    /// The lilv instance record, for lilv's state functions.
    pub const fn raw(&self) -> *mut sys::LilvInstance {
        self.raw.as_ptr()
    }

    /// Looks up plugin extension data such as its state or worker interface.
    pub fn extension_data(&self, extension: &CStr) -> *const c_void {
        self.descriptor()
            .extension_data
            .map_or(std::ptr::null(), |lookup| {
                // SAFETY: The plugin's lookup receives a NUL-terminated extension URI.
                unsafe { lookup(extension.as_ptr()) }
            })
    }

    /// Connects `port` to `location`.
    ///
    /// # Safety
    /// `location` must point to storage of the port's type that stays valid, without moving,
    /// until the port is connected elsewhere or the instance is dropped.
    pub unsafe fn connect(&mut self, port: u32, location: *mut c_void) {
        if let Some(connect_port) = self.descriptor().connect_port {
            // SAFETY: The caller guarantees the location; the handle is this live instance.
            unsafe { connect_port(self.handle, port, location) };
        }
    }

    /// Reads a control port's current value.
    pub fn control(&self, port: u32) -> Option<f32> {
        self.controls.get(usize::try_from(port).ok()?).copied()
    }

    /// Writes a control input, which the plugin reads during its next `run`.
    pub fn set_control(&mut self, port: u32, value: f32) {
        if let Some(control) = usize::try_from(port)
            .ok()
            .and_then(|index| self.controls.get_mut(index))
        {
            *control = value;
        }
    }

    /// Runs the plugin for `frames` and delivers finished worker responses.
    ///
    /// # Safety
    /// Every audio, CV, and atom port must be connected to storage holding at least `frames`
    /// frames, and the caller must have exclusive DSP access.
    pub unsafe fn run(&mut self, frames: u32) {
        if let Some(run) = self.descriptor().run {
            // SAFETY: The caller guarantees connected ports and exclusive access.
            unsafe { run(self.handle, frames) };
        }
        if let Some(responses) = &mut self.responses {
            responses.deliver(self.handle);
        }
    }

    /// Keeps worker jobs from running until the guard is dropped.
    pub fn exclude_worker(&self) -> Option<MutexGuard<'_, ()>> {
        self.worker.as_ref().map(WorkerThread::exclude)
    }
}

impl Drop for PluginInstance {
    fn drop(&mut self) {
        // The worker calls into the plugin, so it has to stop before the plugin goes away.
        self.worker.take();
        if self.active
            && let Some(deactivate) = self.descriptor().deactivate
        {
            // SAFETY: The instance was activated in `instantiate` and nothing runs it now.
            unsafe { deactivate(self.handle) };
        }
        // SAFETY: The instance is owned here and not used again; lilv calls `cleanup`.
        unsafe { sys::lilv_instance_free(self.raw.as_ptr()) };
    }
}
