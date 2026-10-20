//! CLAP editors embedded in windows owned by DigiDAW's native window service.
//!
//! The plugin creates its GUI for the platform's window API and parents it to the host window.
//! Everything here runs on the UI owner, which CLAP calls the main thread.

use clack_extensions::gui::{GuiApiType, GuiConfiguration, GuiSize, PluginGui, Window};
use clack_host::plugin::PluginMainThreadHandle;
use karbeat_host_api::{
    HostError, NativeParentHandle, NativeSurfaceKind, native_host::EditorResizeHandler,
};
use raw_window_handle::RawWindowHandle;

/// Largest client dimension accepted from a plugin.
const MAX_DIMENSION: u32 = 16_384;

/// Window API of the native surface the host parents editors to.
#[cfg(target_os = "linux")]
pub(crate) const API: GuiApiType<'static> = GuiApiType::X11;
#[cfg(target_os = "windows")]
pub(crate) const API: GuiApiType<'static> = GuiApiType::WIN32;

/// Native surface the host creates for editors.
#[cfg(target_os = "linux")]
pub(crate) const SURFACE: NativeSurfaceKind = NativeSurfaceKind::X11;
#[cfg(target_os = "windows")]
pub(crate) const SURFACE: NativeSurfaceKind = NativeSurfaceKind::Win32;

const EMBEDDED: GuiConfiguration<'static> = GuiConfiguration {
    api_type: API,
    is_floating: false,
};

fn gui_error(operation: &'static str) -> HostError {
    HostError::PluginCall {
        operation,
        code: -1,
    }
}

fn valid(size: GuiSize) -> Option<(u32, u32)> {
    let range = 1..=MAX_DIMENSION;
    (range.contains(&size.width) && range.contains(&size.height))
        .then_some((size.width, size.height))
}

/// Whether the plugin can embed an editor in the host's window.
pub(crate) fn supported(gui: PluginGui, plugin: &PluginMainThreadHandle<'_>) -> bool {
    gui.is_api_supported(plugin, EMBEDDED)
}

/// One created editor. It is destroyed with [`ClapEditor::destroy`] before its plugin.
pub(crate) struct ClapEditor {
    gui: PluginGui,
    attached: bool,
    resizable: bool,
}

impl ClapEditor {
    /// Creates the plugin's embedded GUI, which stays hidden until it is attached.
    pub fn create(gui: PluginGui, plugin: &PluginMainThreadHandle<'_>) -> Result<Self, HostError> {
        gui.create(plugin, EMBEDDED)
            .map_err(|_| gui_error("clap.gui.create"))?;
        Ok(Self {
            gui,
            attached: false,
            resizable: gui.can_resize(plugin),
        })
    }

    pub const fn resizable(&self) -> bool {
        self.resizable
    }

    /// The editor's current client size, when the plugin reports a usable one.
    pub fn size(&self, plugin: &PluginMainThreadHandle<'_>) -> Option<(u32, u32)> {
        self.gui.get_size(plugin).and_then(valid)
    }

    /// Parents the editor to the host window and shows it.
    pub fn attach(
        &mut self,
        plugin: &PluginMainThreadHandle<'_>,
        parent: &NativeParentHandle,
    ) -> Result<(), HostError> {
        if self.attached {
            return Ok(());
        }
        let window = match (parent.kind, parent.window) {
            #[cfg(target_os = "linux")]
            (NativeSurfaceKind::X11, RawWindowHandle::Xcb(handle)) => {
                Window::from_x11_handle(handle.window.get().into())
            }
            #[cfg(target_os = "linux")]
            (NativeSurfaceKind::X11, RawWindowHandle::Xlib(handle)) => {
                Window::from_x11_handle(handle.window)
            }
            #[cfg(target_os = "windows")]
            (NativeSurfaceKind::Win32, RawWindowHandle::Win32(handle)) => {
                let hwnd = usize::try_from(handle.hwnd.get())
                    .map_err(|_| HostError::InvalidConfiguration)?;
                // SAFETY: The handle names the live host window the editor is parented to.
                unsafe { Window::from_win32_hwnd(std::ptr::with_exposed_provenance_mut(hwnd)) }
            }
            _ => {
                return Err(HostError::Unsupported(
                    "CLAP editor does not support the supplied native parent surface",
                ));
            }
        };
        // SAFETY: The native window service keeps the parent alive until the editor is
        // destroyed, which happens before the window is.
        unsafe { self.gui.set_parent(plugin, window) }
            .map_err(|_| gui_error("clap.gui.set_parent"))?;
        self.attached = true;
        // Embedded editors show with their parent; plugins that do not implement `show` still
        // appear, so a refusal is only logged.
        if self.gui.show(plugin).is_err() {
            log::debug!("CLAP editor did not acknowledge show");
        }
        Ok(())
    }

    /// Resizes the editor's content to a host-chosen client size, adjusted to what the plugin
    /// accepts. The host window follows the adjusted size through `resize_window`.
    pub fn resize(
        &self,
        plugin: &PluginMainThreadHandle<'_>,
        width: u32,
        height: u32,
        resize_window: Option<&EditorResizeHandler>,
    ) -> Result<(), HostError> {
        if !self.resizable {
            return Err(HostError::Unsupported("editor has a fixed size"));
        }
        let requested = GuiSize { width, height };
        let adjusted = self.gui.adjust_size(plugin, requested).unwrap_or(requested);
        let (adjusted_width, adjusted_height) =
            valid(adjusted).ok_or(HostError::InvalidConfiguration)?;
        if adjusted != requested
            && resize_window.is_some_and(|resize| !resize(adjusted_width, adjusted_height))
        {
            return Err(HostError::NativeDispatch(
                "could not apply editor size constraints".into(),
            ));
        }
        self.gui
            .set_size(plugin, adjusted)
            .map_err(|_| gui_error("clap.gui.set_size"))
    }

    /// Hides and destroys the editor. The host window is destroyed afterwards by its owner.
    pub fn destroy(self, plugin: &PluginMainThreadHandle<'_>) {
        if self.attached && self.gui.hide(plugin).is_err() {
            log::debug!("CLAP editor did not acknowledge hide");
        }
        self.gui.destroy(plugin);
    }
}
