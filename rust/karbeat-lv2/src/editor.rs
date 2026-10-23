//! LV2 X11 editors embedded in windows owned by DigiDAW's native window service.
//!
//! An X11 UI is a shared library that creates its window inside the parent the host passes at
//! instantiation. Everything here runs on the native UI owner. The editor talks to the audio
//! side only through the parameter exchange and the bounded atom rings, and to the plugin
//! instance directly only if the UI itself uses `instance-access`.

use std::{
    cell::{Cell, RefCell},
    ffi::{CStr, CString, c_char, c_int, c_void},
    path::PathBuf,
    sync::{Arc, atomic::Ordering},
    time::{Duration, Instant},
};

use karbeat_host_api::{
    EDIT_BEGIN, EDIT_CHANGED, EDIT_END, HostError, NativeParentHandle, NativeSurfaceKind,
    ParameterExchange, native_host::EditorResizeHandler,
};
use libloading::Library;
use lilv::{World, plugin::Plugin};
use raw_window_handle::RawWindowHandle;

use crate::{
    atoms::{AtomReceiver, AtomSender},
    parameters::ControlPort,
    ports::PluginModel,
    urid::{self, c_string},
    uris::{INSTANCE_ACCESS, OPTIONS, PARAMETERS_SAMPLE_RATE, UI, URID_MAP, URID_UNMAP, Uris},
    wrapper::ProcessorSlot,
};

/// Interval between editor idle calls and port notifications.
const IDLE_INTERVAL: Duration = Duration::from_millis(33);
/// Refresh rate advertised to editors through `ui:updateRate`.
const UPDATE_RATE: f32 = 30.0;
/// Client size used until an editor reports its own.
pub(crate) const DEFAULT_SIZE: (u32, u32) = (640, 480);
/// Largest client dimension accepted from an editor.
const MAX_DIMENSION: u32 = 16_384;
/// `LV2UI_INVALID_PORT_INDEX`.
const INVALID_PORT: u32 = u32::MAX;

fn ui_uri(name: &str) -> String {
    format!("{UI}{name}")
}

/// Features the host passes to an editor; a UI requiring any other one is not opened.
fn supported_features() -> Vec<String> {
    vec![
        URID_MAP.to_owned(),
        URID_UNMAP.to_owned(),
        OPTIONS.to_owned(),
        INSTANCE_ACCESS.to_owned(),
        ui_uri("parent"),
        ui_uri("resize"),
        ui_uri("idleInterface"),
        ui_uri("touch"),
        ui_uri("portMap"),
        ui_uri("noUserResize"),
        ui_uri("fixedSize"),
    ]
}

/// UI-side ends of one instance's editor message rings.
pub(crate) struct EditorLink {
    pub to_dsp: AtomSender,
    pub from_dsp: AtomReceiver,
}

/// An embeddable editor found in a plugin's description.
pub(crate) struct EditorPlan {
    ui_uri: CString,
    plugin_uri: CString,
    binary: PathBuf,
    bundle_path: CString,
    /// Whether the user may resize the editor window.
    pub resizable: bool,
}

impl EditorPlan {
    /// Picks the plugin's first X11 UI whose required features the host provides.
    pub fn discover(plugin: &Plugin, world: &World, uris: &Uris) -> Option<Self> {
        let supported = supported_features();
        let plugin_uri = CString::new(plugin.uri().as_uri()?).ok()?;
        plugin.uis()?.iter().find_map(|ui| {
            if !ui.is_a(&uris.x11_ui) {
                return None;
            }
            let node = ui.uri();
            // A UI described in its own file is not loaded with the plugin's data.
            if world.load_resource(&node).is_none() {
                log::debug!("LV2 editor description could not be loaded");
            }
            let requires_unsupported = world
                .find_nodes(Some(&node), &uris.required_feature, None)
                .iter()
                .any(|feature| {
                    feature
                        .as_uri()
                        .is_none_or(|uri| !supported.iter().any(|known| known == uri))
                });
            if requires_unsupported {
                return None;
            }
            let declares = |feature| {
                [&uris.required_feature, &uris.optional_feature]
                    .into_iter()
                    .any(|predicate| world.ask(Some(&node), Some(predicate), Some(feature)))
            };
            let resizable = !declares(&uris.no_user_resize) && !declares(&uris.fixed_size);
            let (_, binary) = ui.binary_uri()?.path()?;
            let (_, bundle) = ui.bundle_uri()?.path()?;
            let bundle = if bundle.ends_with('/') {
                bundle
            } else {
                format!("{bundle}/")
            };
            Some(Self {
                ui_uri: CString::new(node.as_uri()?).ok()?,
                plugin_uri: plugin_uri.clone(),
                binary: PathBuf::from(binary),
                bundle_path: CString::new(bundle).ok()?,
                resizable,
            })
        })
    }
}

/// Everything an editor needs from its instance to open.
pub(crate) struct EditorSetup<'a> {
    /// The plugin instance's `LV2_Handle`, shared through `instance-access`.
    pub instance: *mut c_void,
    pub sample_rate: f64,
    pub exchange: Arc<ParameterExchange>,
    pub model: &'a PluginModel,
    pub resize: Option<EditorResizeHandler>,
}

/// Host state the editor's callbacks reach through their opaque handles.
///
/// A UI may call back from a thread of its own. Parameter values and gestures only touch
/// atomics, so they are accepted from any thread; everything else is limited to the owner.
struct EditorController {
    owner: std::thread::ThreadId,
    exchange: Arc<ParameterExchange>,
    controls: Arc<[ControlPort]>,
    symbols: Vec<CString>,
    link: RefCell<Option<EditorLink>>,
    event_transfer: u32,
    resize: RefCell<Option<EditorResizeHandler>>,
    size: Cell<Option<(u32, u32)>>,
}

impl EditorController {
    fn on_owner(&self) -> bool {
        self.owner == std::thread::current().id()
    }

    fn control(&self, port: u32) -> Option<(&ControlPort, &karbeat_host_api::ParameterValue)> {
        let position = self
            .controls
            .binary_search_by_key(&port, |control| control.index)
            .ok()?;
        Some((
            self.controls.get(position)?,
            self.exchange.parameters.get(position)?,
        ))
    }
}

/// Feature records handed to the editor. They are boxed with the editor because a UI may keep
/// the pointers for its whole lifetime.
struct FeatureStorage {
    resize: lv2_sys::LV2UI_Resize,
    touch: lv2_sys::LV2UI_Touch,
    port_map: lv2_sys::LV2UI_Port_Map,
    options: [lv2_sys::LV2_Options_Option; 3],
    sample_rate: f32,
    update_rate: f32,
    uris: Vec<CString>,
    features: Vec<lv2_sys::LV2_Feature>,
    pointers: Vec<*const lv2_sys::LV2_Feature>,
}

const fn empty_option() -> lv2_sys::LV2_Options_Option {
    lv2_sys::LV2_Options_Option {
        context: lv2_sys::LV2_Options_Context_LV2_OPTIONS_INSTANCE,
        subject: 0,
        key: 0,
        size: 0,
        type_: 0,
        value: std::ptr::null(),
    }
}

impl FeatureStorage {
    fn new(
        setup: &EditorSetup<'_>,
        controller: *mut c_void,
        parent: *mut c_void,
        sample_rate: f32,
    ) -> Box<Self> {
        let mut storage = Box::new(Self {
            resize: lv2_sys::LV2UI_Resize {
                handle: controller,
                ui_resize: Some(resize_requested),
            },
            touch: lv2_sys::LV2UI_Touch {
                handle: controller,
                touch: Some(port_touched),
            },
            port_map: lv2_sys::LV2UI_Port_Map {
                handle: controller,
                port_index: Some(port_index),
            },
            options: [empty_option(); 3],
            sample_rate,
            update_rate: UPDATE_RATE,
            uris: Vec::new(),
            features: Vec::new(),
            pointers: Vec::new(),
        });
        let float = urid::map(c"http://lv2plug.in/ns/ext/atom#Float");
        let float_option = |key: &CStr, value: &f32| lv2_sys::LV2_Options_Option {
            key: urid::map(key),
            size: 4,
            type_: float,
            value: std::ptr::from_ref(value).cast(),
            ..empty_option()
        };
        let sample_rate_key = c_string(PARAMETERS_SAMPLE_RATE);
        let update_rate_key = c_string(&ui_uri("updateRate"));
        storage.options = [
            float_option(&sample_rate_key, &storage.sample_rate),
            float_option(&update_rate_key, &storage.update_rate),
            empty_option(),
        ];
        let records: [(String, *mut c_void); 8] = [
            (URID_MAP.to_owned(), urid::map_ptr().cast()),
            (URID_UNMAP.to_owned(), urid::unmap_ptr().cast()),
            (
                OPTIONS.to_owned(),
                std::ptr::from_mut(&mut storage.options).cast(),
            ),
            (INSTANCE_ACCESS.to_owned(), setup.instance),
            (ui_uri("parent"), parent),
            (
                ui_uri("resize"),
                std::ptr::from_mut(&mut storage.resize).cast(),
            ),
            (
                ui_uri("touch"),
                std::ptr::from_mut(&mut storage.touch).cast(),
            ),
            (
                ui_uri("portMap"),
                std::ptr::from_mut(&mut storage.port_map).cast(),
            ),
        ];
        storage.uris = records
            .iter()
            .map(|(uri, _)| c_string(uri))
            .chain([c_string(&ui_uri("idleInterface"))])
            .collect();
        storage.features = storage
            .uris
            .iter()
            .zip(
                records
                    .iter()
                    .map(|(_, data)| *data)
                    .chain([std::ptr::null_mut()]),
            )
            .map(|(uri, data)| lv2_sys::LV2_Feature {
                URI: uri.as_ptr(),
                data,
            })
            .collect();
        storage.pointers = storage
            .features
            .iter()
            .map(std::ptr::from_ref)
            .chain([std::ptr::null()])
            .collect();
        storage
    }
}

unsafe extern "C" fn write_port(
    controller: *mut c_void,
    port: u32,
    size: u32,
    protocol: u32,
    buffer: *const c_void,
) {
    if controller.is_null() || buffer.is_null() {
        return;
    }
    // SAFETY: The controller is the boxed `EditorController` that outlives the UI instance.
    let controller = unsafe { &*controller.cast::<EditorController>() };
    if protocol == 0 {
        if size != 4 {
            return;
        }
        // SAFETY: The float protocol carries one `f32` in `buffer`.
        let value = unsafe { buffer.cast::<f32>().read_unaligned() };
        if let Some((control, parameter)) = controller.control(port)
            && value.is_finite()
        {
            parameter.set(control.to_normalized(value), EDIT_CHANGED);
            parameter.mark_user_edited();
        }
        return;
    }
    let Ok(size) = usize::try_from(size) else {
        return;
    };
    if protocol != controller.event_transfer || size < 8 || !controller.on_owner() {
        return;
    }
    // SAFETY: Event transfer carries an atom: its header's size word comes first.
    let body_size = unsafe { buffer.cast::<u32>().read_unaligned() };
    // SAFETY: The atom header's type word follows its size, inside the `size` bytes passed.
    let atom_type = unsafe { buffer.cast::<u32>().wrapping_add(1).read_unaligned() };
    let Ok(body_size) = usize::try_from(body_size) else {
        return;
    };
    if body_size > size - 8 {
        return;
    }
    // SAFETY: The body follows the eight-byte header and lies inside the `size` bytes passed.
    let body =
        unsafe { std::slice::from_raw_parts(buffer.cast::<u8>().wrapping_add(8), body_size) };
    if let Ok(mut link) = controller.link.try_borrow_mut()
        && let Some(ends) = link.as_mut()
        && !ends.to_dsp.send(port, atom_type, body)
    {
        controller.exchange.overflow.store(true, Ordering::Relaxed);
    }
}

unsafe extern "C" fn resize_requested(handle: *mut c_void, width: c_int, height: c_int) -> c_int {
    if handle.is_null() {
        return 1;
    }
    // SAFETY: The handle is the boxed `EditorController` that outlives the UI instance.
    let controller = unsafe { &*handle.cast::<EditorController>() };
    let (Ok(width), Ok(height)) = (u32::try_from(width), u32::try_from(height)) else {
        return 1;
    };
    if !(1..=MAX_DIMENSION).contains(&width)
        || !(1..=MAX_DIMENSION).contains(&height)
        || !controller.on_owner()
    {
        return 1;
    }
    controller.size.set(Some((width, height)));
    let handler = controller
        .resize
        .try_borrow()
        .ok()
        .and_then(|handler| handler.clone());
    c_int::from(handler.is_some_and(|handler| !handler(width, height)))
}

unsafe extern "C" fn port_touched(handle: *mut c_void, port: u32, grabbed: bool) {
    if handle.is_null() {
        return;
    }
    // SAFETY: The handle is the boxed `EditorController` that outlives the UI instance.
    let controller = unsafe { &*handle.cast::<EditorController>() };
    if let Some((_, parameter)) = controller.control(port) {
        let edit = if grabbed { EDIT_BEGIN } else { EDIT_END };
        if grabbed {
            parameter.mark_user_edited();
        }
        parameter.edits.fetch_or(edit, Ordering::Relaxed);
    }
}

unsafe extern "C" fn port_index(handle: *mut c_void, symbol: *const c_char) -> u32 {
    if handle.is_null() || symbol.is_null() {
        return INVALID_PORT;
    }
    // SAFETY: The handle is the boxed `EditorController` that outlives the UI instance.
    let controller = unsafe { &*handle.cast::<EditorController>() };
    // SAFETY: The UI passes a NUL-terminated port symbol valid for this call.
    let symbol = unsafe { CStr::from_ptr(symbol) };
    controller
        .symbols
        .iter()
        .position(|candidate| candidate.as_c_str() == symbol)
        .and_then(|index| u32::try_from(index).ok())
        .unwrap_or(INVALID_PORT)
}

/// One open editor: the loaded UI library, its instance, and the host records it points at.
pub(crate) struct Lv2Editor {
    descriptor: &'static lv2_sys::LV2UI_Descriptor,
    handle: lv2_sys::LV2UI_Handle,
    window: Option<u32>,
    idle: Option<unsafe extern "C" fn(lv2_sys::LV2UI_Handle) -> c_int>,
    resize: Option<unsafe extern "C" fn(*mut c_void, c_int, c_int) -> c_int>,
    controller: Box<EditorController>,
    sent_inputs: Vec<Option<f32>>,
    sent_outputs: Vec<Option<f32>>,
    scratch: Vec<u64>,
    next_idle: Instant,
    closed_by_plugin: bool,
    _features: Box<FeatureStorage>,
    _library: Library,
}

fn editor_error(message: &'static str) -> HostError {
    HostError::Unsupported(message)
}

impl Lv2Editor {
    /// Loads the UI library and instantiates the editor inside `parent`.
    ///
    /// The message rings in `link` move into the editor on success and stay with the caller
    /// when the UI cannot be created.
    pub fn open(
        plan: &EditorPlan,
        parent: &NativeParentHandle,
        setup: &EditorSetup<'_>,
        link: &mut Option<EditorLink>,
    ) -> Result<Self, HostError> {
        let (NativeSurfaceKind::X11, RawWindowHandle::Xcb(handle)) = (parent.kind, parent.window)
        else {
            return Err(editor_error(
                "LV2 editor does not support the supplied native parent surface",
            ));
        };
        let parent_window = std::ptr::without_provenance_mut::<c_void>(
            usize::try_from(handle.window.get()).map_err(|_| HostError::InvalidConfiguration)?,
        );
        let library = load_library(plan)?;
        let descriptor = find_descriptor(&library, plan)?;
        let instantiate = descriptor
            .instantiate
            .ok_or(editor_error("LV2 editor has no instantiate function"))?;
        let mut controller = Box::new(EditorController {
            owner: std::thread::current().id(),
            exchange: setup.exchange.clone(),
            controls: setup.model.controls.clone(),
            symbols: setup
                .model
                .symbols
                .iter()
                .map(|symbol| c_string(symbol))
                .collect(),
            link: RefCell::new(link.take()),
            event_transfer: urid::map(c"http://lv2plug.in/ns/ext/atom#eventTransfer"),
            resize: RefCell::new(setup.resize.clone()),
            size: Cell::new(None),
        });
        let controller_handle = std::ptr::from_mut::<EditorController>(controller.as_mut()).cast();
        let features = FeatureStorage::new(
            setup,
            controller_handle,
            parent_window,
            single(setup.sample_rate),
        );
        let mut widget: lv2_sys::LV2UI_Widget = std::ptr::null_mut();
        // SAFETY: Runs on the UI owner. The descriptor comes from the loaded UI library, the
        // strings and feature records outlive the UI instance, and the parent window stays
        // alive until this editor is closed.
        let handle = unsafe {
            instantiate(
                descriptor,
                plan.plugin_uri.as_ptr(),
                plan.bundle_path.as_ptr(),
                Some(write_port),
                controller_handle,
                &raw mut widget,
                features.pointers.as_ptr(),
            )
        };
        if handle.is_null() {
            *link = controller.link.take();
            return Err(editor_error("LV2 editor could not be created"));
        }
        let extension = |uri: &[u8]| {
            descriptor.extension_data.map_or(std::ptr::null(), |data| {
                // SAFETY: The UI's own lookup receives a NUL-terminated extension URI.
                unsafe { data(uri.as_ptr().cast()) }
            })
        };
        let idle =
            extension(lv2_sys::LV2_UI__idleInterface).cast::<lv2_sys::LV2UI_Idle_Interface>();
        let resize = extension(lv2_sys::LV2_UI__resize).cast::<lv2_sys::LV2UI_Resize>();
        Ok(Self {
            descriptor,
            handle,
            window: u32::try_from(widget.addr()).ok().filter(|id| *id != 0),
            // SAFETY: A non-null idle interface is a static record in the loaded UI library.
            idle: unsafe { idle.as_ref() }.and_then(|interface| interface.idle),
            // SAFETY: A non-null resize interface is a static record in the loaded UI library.
            resize: unsafe { resize.as_ref() }.and_then(|interface| interface.ui_resize),
            sent_inputs: vec![None; setup.model.controls.len()],
            sent_outputs: vec![None; setup.model.control_outputs.len()],
            controller,
            scratch: Vec::new(),
            next_idle: Instant::now(),
            closed_by_plugin: false,
            _features: features,
            _library: library,
        })
    }

    /// Replaces the callback the editor uses to resize its host window.
    pub fn set_resize_handler(&self, handler: EditorResizeHandler) {
        if let Ok(mut resize) = self.controller.resize.try_borrow_mut() {
            *resize = Some(handler);
        }
    }

    /// Client size the editor last asked for, or its window's current geometry.
    pub fn size(&self) -> Option<(u32, u32)> {
        self.controller
            .size
            .get()
            .or_else(|| self.window.and_then(window_size))
    }

    /// Resizes the editor's content to a host-chosen client size.
    pub fn resize(&self, width: u32, height: u32) -> Result<(), HostError> {
        let (Ok(native_width), Ok(native_height)) =
            (c_int::try_from(width), c_int::try_from(height))
        else {
            return Err(HostError::InvalidConfiguration);
        };
        if let Some(resize) = self.resize {
            // SAFETY: The UI's own resize interface is called with its live handle on the UI
            // owner.
            let code = unsafe { resize(self.handle, native_width, native_height) };
            if code != 0 {
                return Err(HostError::PluginCall {
                    operation: "lv2ui.resize",
                    code,
                });
            }
        } else if let Some(window) = self.window {
            resize_window(window, width, height)?;
        }
        self.controller.size.set(Some((width, height)));
        Ok(())
    }

    /// Whether the plugin asked to close its own editor.
    pub const fn closed_by_plugin(&self) -> bool {
        self.closed_by_plugin
    }

    /// Reports changed port values and atom output to the editor, then lets it idle.
    pub fn pump(&mut self, model: &PluginModel, slot: &ProcessorSlot) {
        let now = Instant::now();
        if now < self.next_idle || self.closed_by_plugin {
            return;
        }
        self.next_idle = now + IDLE_INTERVAL;
        if let Some(port_event) = self.descriptor.port_event {
            for ((control, parameter), sent) in self
                .controller
                .controls
                .iter()
                .zip(&self.controller.exchange.parameters)
                .zip(&mut self.sent_inputs)
            {
                let plain = control.to_plain(parameter.get());
                if sent.replace(plain) != Some(plain) {
                    // SAFETY: The float protocol passes one `f32` to the live UI instance.
                    unsafe {
                        port_event(
                            self.handle,
                            control.index,
                            4,
                            0,
                            std::ptr::from_ref(&plain).cast(),
                        );
                    };
                }
            }
            for ((port, shared), sent) in model
                .control_outputs
                .iter()
                .zip(&slot.control_outputs)
                .zip(&mut self.sent_outputs)
            {
                let value = f32::from_bits(shared.load(Ordering::Relaxed));
                if sent.replace(value) != Some(value) {
                    // SAFETY: As above.
                    unsafe {
                        port_event(self.handle, *port, 4, 0, std::ptr::from_ref(&value).cast());
                    };
                }
            }
            let (handle, event_transfer) = (self.handle, self.controller.event_transfer);
            let scratch = &mut self.scratch;
            if let Ok(mut link) = self.controller.link.try_borrow_mut()
                && let Some(ends) = link.as_mut()
            {
                ends.from_dsp.drain(|port, atom_type, parts| {
                    let body = parts[0].len() + parts[1].len();
                    let Ok(size) = u32::try_from(body) else {
                        return;
                    };
                    // Atoms are read as 64-bit aligned records.
                    scratch.clear();
                    scratch.resize((8 + body).div_ceil(8), 0);
                    let bytes = scratch.as_mut_ptr().cast::<u8>();
                    // SAFETY: `scratch` holds at least `8 + body` writable bytes.
                    unsafe { bytes.cast::<u32>().write(size) };
                    // SAFETY: As above; the type word follows the size word.
                    unsafe { bytes.cast::<u32>().wrapping_add(1).write(atom_type) };
                    let mut offset = 8;
                    for part in parts {
                        // SAFETY: Both parts together are `body` bytes after the header.
                        unsafe {
                            std::ptr::copy_nonoverlapping(
                                part.as_ptr(),
                                bytes.wrapping_add(offset),
                                part.len(),
                            );
                        };
                        offset += part.len();
                    }
                    // SAFETY: Event transfer passes one whole atom to the live UI instance.
                    unsafe {
                        port_event(
                            handle,
                            port,
                            size.saturating_add(8),
                            event_transfer,
                            bytes.cast(),
                        );
                    };
                });
            }
        }
        if let Some(idle) = self.idle {
            // SAFETY: The idle interface is called with the live UI handle on the UI owner.
            self.closed_by_plugin = unsafe { idle(self.handle) } != 0;
        }
    }

    /// Destroys the UI instance and returns the message rings for the next editor.
    pub fn close(mut self) -> Option<EditorLink> {
        self.cleanup();
        self.controller.link.take()
    }

    fn cleanup(&mut self) {
        let handle = std::mem::replace(&mut self.handle, std::ptr::null_mut());
        if !handle.is_null()
            && let Some(cleanup) = self.descriptor.cleanup
        {
            // SAFETY: The handle is the UI instance created in `open`, destroyed exactly once.
            unsafe { cleanup(handle) };
        }
    }
}

impl Drop for Lv2Editor {
    fn drop(&mut self) {
        self.cleanup();
    }
}

fn load_library(plan: &EditorPlan) -> Result<Library, HostError> {
    use libloading::os::unix::{Library as UnixLibrary, RTLD_LOCAL, RTLD_NOW};
    // UI toolkits start threads and register static destructors, so their code stays resident
    // until process shutdown, as the VST3 backend does for plugin modules.
    const RTLD_NODELETE: i32 = 0x1000;
    // SAFETY: Loading runs on the UI owner, for a UI the plugin's description names.
    unsafe { UnixLibrary::open(Some(&plan.binary), RTLD_NOW | RTLD_LOCAL | RTLD_NODELETE) }
        .map(Into::into)
        .map_err(|error| HostError::Module {
            path: plan.binary.clone(),
            message: error.to_string(),
        })
}

fn find_descriptor(
    library: &Library,
    plan: &EditorPlan,
) -> Result<&'static lv2_sys::LV2UI_Descriptor, HostError> {
    type Entry = unsafe extern "C" fn(u32) -> *const lv2_sys::LV2UI_Descriptor;
    // SAFETY: `lv2ui_descriptor` is the LV2 UI entry point with this signature.
    let entry = unsafe { library.get::<Entry>(b"lv2ui_descriptor\0") }.map_err(|error| {
        HostError::Module {
            path: plan.binary.clone(),
            message: error.to_string(),
        }
    })?;
    for index in 0..1024 {
        // SAFETY: The entry point returns null once `index` is past its last descriptor.
        let descriptor = unsafe { entry(index) };
        // SAFETY: A non-null descriptor is a static record in the library, which is loaded
        // with `RTLD_NODELETE` and so never unloaded.
        let Some(descriptor) = (unsafe { descriptor.as_ref() }) else {
            break;
        };
        if descriptor.URI.is_null() {
            continue;
        }
        // SAFETY: A descriptor's URI is a NUL-terminated static string.
        if unsafe { CStr::from_ptr(descriptor.URI) } == plan.ui_uri.as_c_str() {
            return Ok(descriptor);
        }
    }
    Err(HostError::Module {
        path: plan.binary.clone(),
        message: "UI library does not provide the described editor".into(),
    })
}

/// Reads the size of an editor window that never asked the host for one.
fn window_size(window: u32) -> Option<(u32, u32)> {
    use x11rb::{connection::Connection as _, protocol::xproto::ConnectionExt as _};
    let (connection, _) = x11rb::connect(None).ok()?;
    let geometry = connection.get_geometry(window).ok()?.reply().ok()?;
    drop(connection.flush());
    let size = (u32::from(geometry.width), u32::from(geometry.height));
    (size.0 > 1 && size.1 > 1).then_some(size)
}

/// Resizes the window of an editor that has no resize interface of its own.
fn resize_window(window: u32, width: u32, height: u32) -> Result<(), HostError> {
    use x11rb::{
        connection::Connection as _,
        protocol::xproto::{ConfigureWindowAux, ConnectionExt as _},
    };
    let failed = |error: &dyn std::fmt::Display| HostError::NativeDispatch(error.to_string());
    let (connection, _) = x11rb::connect(None).map_err(|error| failed(&error))?;
    connection
        .configure_window(
            window,
            &ConfigureWindowAux::new().width(width).height(height),
        )
        .map_err(|error| failed(&error))?;
    connection.flush().map_err(|error| failed(&error))
}

#[allow(
    clippy::as_conversions,
    clippy::cast_possible_truncation,
    reason = "LV2 options carry the sample rate in single precision"
)]
fn single(value: f64) -> f32 {
    if value.is_finite() { value as f32 } else { 0.0 }
}
