use std::{
    path::{Path, PathBuf},
    rc::Rc,
};

#[cfg(any(target_os = "linux", target_os = "macos"))]
use std::ffi::c_void;

use karbeat_host_api::{HostError, PluginDescriptor, PluginFormat, PluginIdentity, PluginKind};
use libloading::Library;
use vst3::{
    ComPtr,
    Steinberg::{
        IPluginFactory, IPluginFactory2, IPluginFactory2Trait, IPluginFactoryTrait, PClassInfo,
        PClassInfo2, PFactoryInfo, TUID, kResultOk,
    },
};

fn module_error(path: &Path, message: impl ToString) -> HostError {
    HostError::Module {
        path: path.to_path_buf(),
        message: message.to_string(),
    }
}

/// Returns the conventional per-user and system-wide VST3 locations for the current platform.
///
/// Paths are returned whether or not they currently exist. Environment-dependent user paths
/// are omitted when the corresponding home or common-files variable is unavailable.
pub fn default_scan_paths() -> Vec<PathBuf> {
    let mut paths = Vec::new();
    if cfg!(target_os = "linux") {
        if let Some(home) = std::env::var_os("HOME") {
            paths.push(PathBuf::from(home).join(".vst3"));
        }
        paths.extend(["/usr/lib/vst3", "/usr/local/lib/vst3"].map(PathBuf::from));
    } else if cfg!(target_os = "macos") {
        if let Some(home) = std::env::var_os("HOME") {
            paths.push(PathBuf::from(home).join("Library/Audio/Plug-Ins/VST3"));
        }
        paths.push(PathBuf::from("/Library/Audio/Plug-Ins/VST3"));
    } else if cfg!(target_os = "windows") {
        if let Some(local) = std::env::var_os("LOCALAPPDATA") {
            paths.push(PathBuf::from(local).join("Programs/Common/VST3"));
        }
        if let Some(common) = std::env::var_os("CommonProgramFiles") {
            paths.push(PathBuf::from(common).join("VST3"));
        }
    }
    paths
}

fn binary_path(bundle: &Path) -> Result<PathBuf, HostError> {
    if cfg!(target_os = "windows") && bundle.is_file() {
        return Ok(bundle.to_path_buf());
    }
    let arch = std::env::consts::ARCH;
    let directory = if cfg!(target_os = "linux") {
        bundle.join("Contents").join(format!("{arch}-linux"))
    } else if cfg!(target_os = "windows") {
        let arch = if arch == "aarch64" { "arm64" } else { arch };
        bundle.join("Contents").join(format!("{arch}-win"))
    } else if cfg!(target_os = "macos") {
        bundle.join("Contents/MacOS")
    } else {
        return Err(HostError::Unsupported("VST3 on this platform"));
    };
    if !directory.is_dir() {
        return Err(module_error(
            bundle,
            format!("no native {arch} binary in {}", directory.display()),
        ));
    }
    let extension = if cfg!(target_os = "linux") {
        Some("so")
    } else if cfg!(target_os = "windows") {
        Some("vst3")
    } else {
        None
    };
    let mut binaries = std::fs::read_dir(&directory)?
        .filter_map(Result::ok)
        .map(|e| e.path())
        .filter(|p| {
            p.is_file()
                && extension
                    .is_none_or(|ext| p.extension().is_some_and(|e| e.eq_ignore_ascii_case(ext)))
        })
        .collect::<Vec<_>>();
    binaries.sort();
    if let Some(stem) = bundle.file_stem() {
        if let Some(path) = binaries.iter().find(|p| p.file_stem() == Some(stem)) {
            return Ok(path.clone());
        }
    }
    if binaries.len() == 1 {
        return Ok(binaries.remove(0));
    }
    Err(module_error(
        bundle,
        "bundle does not identify a unique executable",
    ))
}

/// The factory and every live component retain this owner on the native UI thread.
/// Explicit field teardown releases COM objects before calling the module exit function.
pub struct Vst3Module {
    /// Canonical path to the loaded VST3 bundle or Windows module file.
    pub path: PathBuf,
    factory: Option<ComPtr<IPluginFactory>>,
    exit: Option<unsafe extern "system" fn() -> bool>,
    _library: Library,
    #[cfg(target_os = "macos")]
    _bundle: MacBundle,
    _ui_only: std::marker::PhantomData<Rc<()>>,
}

impl Vst3Module {
    /// Loads and initializes a VST3 module and adopts its plugin factory.
    ///
    /// The platform entry point and `GetPluginFactory` are called before this returns. The
    /// returned `Rc` is intentionally UI-thread-only and keeps the native library loaded until
    /// all instances and factory references have been released.
    ///
    /// # Errors
    ///
    /// Returns an error when the path cannot be canonicalized, the architecture-specific
    /// executable is ambiguous or missing, a required symbol is absent, module initialization
    /// fails, or the factory export returns null.
    pub fn load(path: &Path) -> Result<Rc<Self>, HostError> {
        let path = std::fs::canonicalize(path)?;
        let binary = binary_path(&path)?;
        #[cfg(target_os = "linux")]
        let library: Library = {
            use libloading::os::unix::{Library as UnixLibrary, RTLD_LOCAL, RTLD_NOW};
            // Linux RTLD_NODELETE keeps plugin code resident until process shutdown. Vital's
            // static OpenGL threads call dlclose during teardown, which deadlocks when dlclose
            // invokes their destructors while holding the loader lock. Objects and ModuleExit
            // still follow normal ownership; only code unloading is deferred.
            const RTLD_NODELETE: i32 = 0x1000;
            // SAFETY: Loading is confined to the scanner or a UI-thread instance request.
            unsafe { UnixLibrary::open(Some(&binary), RTLD_NOW | RTLD_LOCAL | RTLD_NODELETE) }
                .map_err(|error| module_error(&path, error))?
                .into()
        };
        #[cfg(not(target_os = "linux"))]
        // SAFETY: Loading is isolated to the scanner or an explicit UI-thread instance request.
        let library = unsafe { Library::new(&binary) }.map_err(|e| module_error(&path, e))?;
        #[cfg(target_os = "linux")]
        let (library, entry_ok, exit) = {
            let native: libloading::os::unix::Library = library.into();
            let handle = native.into_raw();
            // SAFETY: Reconstitute the same owned dlopen handle; it is not closed in between.
            let library: Library =
                unsafe { libloading::os::unix::Library::from_raw(handle) }.into();
            // SAFETY: These are the VST3 Linux module ABI entry/exit signatures.
            let entry = unsafe {
                library.get::<unsafe extern "system" fn(*mut c_void) -> bool>(b"ModuleEntry\0")
            }
            .map_err(|e| module_error(&path, e))?;
            // SAFETY: Symbol is retained by library, and the matching module handle is live.
            let ok = unsafe { entry(handle) };
            // SAFETY: VST3 ModuleExit takes no arguments and library outlives the function pointer.
            let exit =
                unsafe { library.get::<unsafe extern "system" fn() -> bool>(b"ModuleExit\0") }
                    .ok()
                    .map(|s| *s);
            (library, ok, exit)
        };
        #[cfg(target_os = "windows")]
        let (entry_ok, exit) = {
            // SAFETY: VST3 Windows initialization and termination use these exported signatures.
            let entry = unsafe { library.get::<unsafe extern "system" fn() -> bool>(b"InitDll\0") }
                .map_err(|e| module_error(&path, e))?;
            // SAFETY: Entry belongs to the loaded module and is called on the UI thread.
            let ok = unsafe { entry() };
            // SAFETY: Library remains owned until after termination.
            let exit = unsafe { library.get::<unsafe extern "system" fn() -> bool>(b"ExitDll\0") }
                .ok()
                .map(|s| *s);
            (ok, exit)
        };
        #[cfg(target_os = "macos")]
        let bundle = MacBundle::new(&path)?;
        #[cfg(target_os = "macos")]
        let (entry_ok, exit) = {
            // SAFETY: bundleEntry receives a live CFBundleRef for this module.
            let entry = unsafe {
                library.get::<unsafe extern "system" fn(*mut c_void) -> bool>(b"bundleEntry\0")
            }
            .map_err(|e| module_error(&path, e))?;
            // SAFETY: Bundle and library stay alive through bundleExit.
            let ok = unsafe { entry(bundle.0) };
            // SAFETY: VST3 bundleExit has no arguments.
            let exit =
                unsafe { library.get::<unsafe extern "system" fn() -> bool>(b"bundleExit\0") }
                    .ok()
                    .map(|s| *s);
            (ok, exit)
        };
        #[cfg(not(any(target_os = "linux", target_os = "windows", target_os = "macos")))]
        let (entry_ok, exit): (bool, Option<unsafe extern "system" fn() -> bool>) = (false, None);
        if !entry_ok {
            return Err(module_error(&path, "module initialization failed"));
        }
        let mut module = Self {
            path,
            factory: None,
            exit,
            _library: library,
            #[cfg(target_os = "macos")]
            _bundle: bundle,
            _ui_only: std::marker::PhantomData,
        };
        // SAFETY: The VST3 factory export returns an owned IPluginFactory reference.
        let get_factory = unsafe {
            module
                ._library
                .get::<unsafe extern "system" fn() -> *mut IPluginFactory>(b"GetPluginFactory\0")
        }
        .map_err(|e| module_error(&module.path, e))?;
        // SAFETY: Module entry succeeded and its code remains loaded.
        let raw = unsafe { get_factory() };
        // SAFETY: Adopt the reference returned by GetPluginFactory, rejecting a null result.
        module.factory = unsafe { ComPtr::from_raw(raw) };
        if module.factory.is_none() {
            return Err(module_error(&module.path, "factory is null"));
        }
        Ok(Rc::new(module))
    }

    /// Borrows the initialized factory retained by this module.
    ///
    /// # Errors
    ///
    /// Returns a module error if teardown has already removed the factory.
    pub fn factory(&self) -> Result<&ComPtr<IPluginFactory>, HostError> {
        self.factory
            .as_ref()
            .ok_or_else(|| module_error(&self.path, "factory is unavailable"))
    }

    /// Enumerates audio-module classes exported by the factory as host descriptors.
    ///
    /// Non-audio classes and individual class-info queries that fail are skipped. Extended
    /// factory metadata is used when available, with basic factory metadata as the vendor
    /// fallback. The class count is rejected when it is negative or unreasonably large.
    ///
    /// # Errors
    ///
    /// Returns an error if the factory is unavailable or reports an invalid class count.
    pub fn descriptors(&self) -> Result<Vec<PluginDescriptor>, HostError> {
        let factory = self.factory()?;
        // SAFETY: PFactoryInfo contains integer and fixed-array fields with valid zero representations.
        let mut vendor: PFactoryInfo = unsafe { std::mem::zeroed() };
        // SAFETY: Factory is live and vendor is writable for the duration of the call.
        let vendor_ok = unsafe { factory.getFactoryInfo(&raw mut vendor) } == kResultOk;
        let factory2 = factory.cast::<IPluginFactory2>();
        // SAFETY: Factory is initialized on this thread.
        let count = unsafe { factory.countClasses() };
        if !(0..=65_536).contains(&count) {
            return Err(module_error(&self.path, "invalid class count"));
        }
        let mut descriptors = Vec::new();
        for index in 0..count {
            // SAFETY: Both structs are plain integer/fixed-array ABI records.
            let mut info: PClassInfo = unsafe { std::mem::zeroed() };
            // SAFETY: index is in the factory's reported range; output is writable.
            if unsafe { factory.getClassInfo(index, &raw mut info) } != kResultOk {
                continue;
            }
            if c_string(&info.category) != "Audio Module Class" {
                continue;
            }
            // SAFETY: PClassInfo2 has no nonzero or pointer validity constraints.
            let mut extended: PClassInfo2 = unsafe { std::mem::zeroed() };
            let extended_ok = factory2.as_ref().is_some_and(|f| {
                // SAFETY: Factory2 implements this method and output is writable.
                (unsafe { f.getClassInfo2(index, &raw mut extended) }) == kResultOk
            });
            let categories = if extended_ok {
                c_string(&extended.subCategories)
            } else {
                String::new()
            };
            descriptors.push(PluginDescriptor {
                identity: PluginIdentity {
                    format: PluginFormat::Vst3,
                    native_id: class_id_string(&info.cid),
                },
                path: self.path.clone(),
                name: c_string(&info.name),
                vendor: if extended_ok && extended.vendor[0] != 0 {
                    c_string(&extended.vendor)
                } else if vendor_ok {
                    c_string(&vendor.vendor)
                } else {
                    String::new()
                },
                version: if extended_ok {
                    c_string(&extended.version)
                } else {
                    String::new()
                },
                kind: if categories.split('|').any(|c| c == "Instrument") {
                    PluginKind::Instrument
                } else {
                    PluginKind::Effect
                },
            });
        }
        Ok(descriptors)
    }
}

impl Drop for Vst3Module {
    fn drop(&mut self) {
        self.factory.take();
        if let Some(exit) = self.exit.take() {
            // SAFETY: The factory is released, instances retain the module until destroyed,
            // and the library remains loaded until this destructor returns.
            unsafe { exit() };
        }
    }
}

fn c_string(chars: &[std::ffi::c_char]) -> String {
    let bytes = chars
        .iter()
        .take_while(|&&c| c != 0)
        .map(|c| c.to_ne_bytes()[0])
        .collect::<Vec<_>>();
    String::from_utf8_lossy(&bytes).into_owned()
}

/// Encodes a VST3 class ID as 32 uppercase hexadecimal digits.
///
/// Windows GUID byte groups are reordered to match the textual VST3 class-ID convention.
pub fn class_id_string(id: &TUID) -> String {
    let mut bytes = id.map(|b| b.to_ne_bytes()[0]);
    if cfg!(target_os = "windows") {
        bytes[..4].reverse();
        bytes[4..6].reverse();
        bytes[6..8].reverse();
    }
    bytes.iter().map(|b| format!("{b:02X}")).collect()
}

/// Decodes a 32-digit hexadecimal VST3 class ID into its native byte representation.
///
/// Windows GUID byte groups are converted back to the byte order expected by the VST3 ABI.
///
/// # Errors
///
/// Returns [`HostError::InvalidState`] when `text` is not exactly 32 ASCII hexadecimal digits.
pub fn parse_class_id(text: &str) -> Result<TUID, HostError> {
    if text.len() != 32 || !text.is_ascii() {
        return Err(HostError::InvalidState(
            "class ID must contain 32 hex digits".into(),
        ));
    }
    let mut bytes = [0_u8; 16];
    for (index, byte) in bytes.iter_mut().enumerate() {
        *byte = u8::from_str_radix(&text[index * 2..index * 2 + 2], 16)
            .map_err(|e| HostError::InvalidState(e.to_string()))?;
    }
    if cfg!(target_os = "windows") {
        bytes[..4].reverse();
        bytes[4..6].reverse();
        bytes[6..8].reverse();
    }
    Ok(bytes.map(|b| i8::from_ne_bytes([b])))
}

#[cfg(target_os = "macos")]
struct MacBundle(*mut c_void);

#[cfg(target_os = "macos")]
#[link(name = "CoreFoundation", kind = "framework")]
unsafe extern "C" {
    fn CFURLCreateFromFileSystemRepresentation(
        allocator: *const c_void,
        bytes: *const u8,
        length: isize,
        directory: bool,
    ) -> *mut c_void;
    fn CFBundleCreate(allocator: *const c_void, url: *const c_void) -> *mut c_void;
    fn CFRelease(value: *const c_void);
}

#[cfg(target_os = "macos")]
impl MacBundle {
    fn new(path: &Path) -> Result<Self, HostError> {
        use std::os::unix::ffi::OsStrExt;
        let bytes = path.as_os_str().as_bytes();
        let length = isize::try_from(bytes.len()).map_err(|e| module_error(path, e))?;
        // SAFETY: Bytes are valid for length; null allocator selects the system allocator.
        let url = unsafe {
            CFURLCreateFromFileSystemRepresentation(std::ptr::null(), bytes.as_ptr(), length, true)
        };
        if url.is_null() {
            return Err(module_error(path, "could not create bundle URL"));
        }
        // SAFETY: url is a retained CFURLRef.
        let bundle = unsafe { CFBundleCreate(std::ptr::null(), url) };
        // SAFETY: Release exactly the owned URL reference.
        unsafe { CFRelease(url) };
        if bundle.is_null() {
            return Err(module_error(path, "could not create bundle"));
        }
        Ok(Self(bundle))
    }
}

#[cfg(target_os = "macos")]
impl Drop for MacBundle {
    fn drop(&mut self) {
        // SAFETY: This owner releases its non-null CFBundleRef exactly once.
        unsafe { CFRelease(self.0) };
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
    fn class_ids_are_canonical_and_round_trip() {
        let text = "00112233445566778899AABBCCDDEEFF";
        assert_eq!(class_id_string(&parse_class_id(text).unwrap()), text);
        assert!(parse_class_id("bad").is_err());
        assert!(parse_class_id("GG112233445566778899AABBCCDDEEFF").is_err());
    }

    #[cfg(target_os = "windows")]
    #[test]
    fn windows_bundle_and_direct_module_paths_resolve_without_guessing_other_architectures() {
        let temporary = tempfile::tempdir().unwrap();
        let direct = temporary.path().join("Direct.vst3");
        std::fs::write(&direct, []).unwrap();
        assert_eq!(binary_path(&direct).unwrap(), direct);

        let bundle = temporary.path().join("Bundle.vst3");
        let architecture = if std::env::consts::ARCH == "aarch64" {
            "arm64"
        } else {
            std::env::consts::ARCH
        };
        let binary_directory = bundle.join("Contents").join(format!("{architecture}-win"));
        std::fs::create_dir_all(&binary_directory).unwrap();
        let binary = binary_directory.join("Bundle.vst3");
        std::fs::write(&binary, []).unwrap();
        assert_eq!(binary_path(&bundle).unwrap(), binary);

        let wrong_architecture = temporary.path().join("WrongArchitecture.vst3");
        std::fs::create_dir_all(wrong_architecture.join("Contents/x86-win")).unwrap();
        assert!(binary_path(&wrong_architecture).is_err());
    }
}
