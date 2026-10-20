//! CLAP modules are shared libraries (`.so` on Linux, `.dll` on Windows) named `*.clap`.
//!
//! Loading a module initialises its entry, which runs plugin code, so discovery reads modules in
//! the scanner helper. The host keeps each module it loaded for the rest of its lifetime.

use std::{
    ffi::OsStr,
    path::{Path, PathBuf},
    rc::Rc,
};

use clack_common::plugin::features;
use clack_host::entry::PluginEntry;
use karbeat_host_api::{HostError, PluginDescriptor, PluginFormat, PluginIdentity, PluginKind};

/// File extension that marks one CLAP module.
pub const MODULE_EXTENSION: &str = "clap";

fn module_error(path: &Path, message: impl ToString) -> HostError {
    HostError::Module {
        path: path.to_path_buf(),
        message: message.to_string(),
    }
}

/// Returns the per-user and system-wide CLAP directories the CLAP specification lists.
///
/// `CLAP_PATH` entries come first. Paths are returned whether or not they exist.
pub fn default_scan_paths() -> Vec<PathBuf> {
    let variable = |name: &str| std::env::var_os(name).map(PathBuf::from);
    let defaults = if cfg!(target_os = "windows") {
        vec![
            variable("LOCALAPPDATA").map(|local| local.join("Programs/Common/CLAP")),
            variable("CommonProgramFiles").map(|common| common.join("CLAP")),
        ]
    } else {
        // Fedora-style `lib64` and `/usr/local` installations sit beside the listed directory.
        let mut defaults = vec![variable("HOME").map(|home| home.join(".clap"))];
        defaults.extend(
            ["/usr/lib/clap", "/usr/lib64/clap", "/usr/local/lib/clap"]
                .map(|path| Some(PathBuf::from(path))),
        );
        defaults
    };
    scan_paths(std::env::var_os("CLAP_PATH").as_deref(), &defaults)
}

fn scan_paths(configured: Option<&OsStr>, defaults: &[Option<PathBuf>]) -> Vec<PathBuf> {
    let mut paths: Vec<PathBuf> = configured
        .map(|configured| {
            std::env::split_paths(configured)
                .filter(|path| !path.as_os_str().is_empty())
                .collect()
        })
        .unwrap_or_default();
    paths.extend(defaults.iter().flatten().cloned());
    let mut seen = std::collections::HashSet::new();
    paths.retain(|path| seen.insert(path.clone()));
    paths
}

/// One loaded and initialised CLAP module.
///
/// The entry is deinitialised, and the library released, when the last module and instance
/// referring to it are gone. The `Rc` keeps it on the UI thread that loaded it.
pub struct ClapModule {
    /// Canonical path of the module file.
    pub path: PathBuf,
    entry: PluginEntry,
    _ui_only: std::marker::PhantomData<Rc<()>>,
}

impl ClapModule {
    /// Loads the module and initialises its entry.
    ///
    /// # Errors
    ///
    /// Returns an error when the path is not a module file, the library or its `clap_entry`
    /// symbol cannot be loaded, or the entry fails to initialise.
    pub fn load(path: &Path) -> Result<Rc<Self>, HostError> {
        let path = std::fs::canonicalize(path)?;
        if !path.is_file() {
            return Err(module_error(&path, "a CLAP module must be a library file"));
        }
        let entry = load_entry(&path)?;
        Ok(Rc::new(Self {
            path,
            entry,
            _ui_only: std::marker::PhantomData,
        }))
    }

    /// The initialised entry, from which plugin instances are created.
    pub const fn entry(&self) -> &PluginEntry {
        &self.entry
    }

    /// Lists the plugins the module's factory provides.
    ///
    /// Descriptors without a usable ID or name are skipped.
    ///
    /// # Errors
    ///
    /// Returns a module error when the entry provides no plugin factory.
    pub fn descriptors(&self) -> Result<Vec<PluginDescriptor>, HostError> {
        let factory = self
            .entry
            .get_plugin_factory()
            .ok_or_else(|| module_error(&self.path, "module provides no plugin factory"))?;
        let text = |value: Option<&std::ffi::CStr>| {
            value.map_or_else(String::new, |value| value.to_string_lossy().into_owned())
        };
        let mut descriptors = factory
            .plugin_descriptors()
            .filter_map(|plugin| {
                let id = plugin.id()?.to_str().ok()?.to_owned();
                let name = text(plugin.name());
                if id.is_empty() || name.is_empty() {
                    return None;
                }
                Some(PluginDescriptor {
                    identity: PluginIdentity {
                        format: PluginFormat::Clap,
                        native_id: id,
                    },
                    path: self.path.clone(),
                    name,
                    vendor: text(plugin.vendor()),
                    version: text(plugin.version()),
                    kind: if plugin
                        .features()
                        .any(|feature| feature == features::INSTRUMENT)
                    {
                        PluginKind::Instrument
                    } else {
                        PluginKind::Effect
                    },
                })
            })
            .collect::<Vec<_>>();
        descriptors.sort_by(|left, right| left.identity.native_id.cmp(&right.identity.native_id));
        descriptors.dedup_by(|left, right| left.identity == right.identity);
        Ok(descriptors)
    }
}

#[cfg(target_os = "linux")]
fn load_entry(path: &Path) -> Result<PluginEntry, HostError> {
    use clack_host::entry::LibraryEntry;
    use libloading::os::unix::{Library as UnixLibrary, RTLD_LOCAL, RTLD_NOW};
    use std::os::unix::ffi::OsStrExt;
    // Plugin code stays resident until process shutdown, as it does for VST3 and LV2 modules:
    // GUI toolkits start threads and register static destructors that deadlock in `dlclose`.
    const RTLD_NODELETE: i32 = 0x1000;
    // SAFETY: Loading runs in the scanner helper or on the UI owner, for a module file the
    // user installed as a CLAP plugin.
    let library: libloading::Library =
        unsafe { UnixLibrary::open(Some(path), RTLD_NOW | RTLD_LOCAL | RTLD_NODELETE) }
            .map_err(|error| module_error(path, error))?
            .into();
    // SAFETY: `clap_entry` is the CLAP entry symbol; the provider keeps the library loaded.
    let provider = unsafe { LibraryEntry::load_from_library(library) }
        .map_err(|error| module_error(path, error))?;
    let bundle = std::ffi::CString::new(path.as_os_str().as_bytes())
        .map_err(|error| module_error(path, error))?;
    // SAFETY: The entry is initialised once with the module's own path and deinitialised when
    // its last reference is dropped.
    unsafe { PluginEntry::load_from(provider, &bundle) }.map_err(|error| module_error(path, error))
}

#[cfg(target_os = "windows")]
fn load_entry(path: &Path) -> Result<PluginEntry, HostError> {
    // SAFETY: Loading runs in the scanner helper or on the UI owner, for a module file the
    // user installed as a CLAP plugin. The entry keeps the library loaded.
    unsafe { PluginEntry::load(path) }.map_err(|error| module_error(path, error))
}

#[cfg(test)]
#[allow(clippy::unwrap_used, reason = "test fixtures must be creatable")]
mod tests {
    use super::*;

    #[test]
    fn configured_paths_come_first_and_duplicates_are_dropped() {
        let configured = std::env::join_paths(["/opt/clap", "", "/usr/lib/clap"]).unwrap();
        let paths = scan_paths(
            Some(&configured),
            &[
                Some(PathBuf::from("/home/user/.clap")),
                None,
                Some(PathBuf::from("/usr/lib/clap")),
            ],
        );
        assert_eq!(
            paths,
            ["/opt/clap", "/usr/lib/clap", "/home/user/.clap"].map(PathBuf::from)
        );
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn defaults_cover_the_system_directories() {
        let paths = default_scan_paths();
        assert!(paths.contains(&PathBuf::from("/usr/lib/clap")));
        assert!(paths.contains(&PathBuf::from("/usr/lib64/clap")));
    }

    #[test]
    fn a_directory_or_missing_file_is_not_a_module() {
        let directory = tempfile::tempdir().unwrap();
        let bundle = directory.path().join("Bundle.clap");
        std::fs::create_dir(&bundle).unwrap();
        assert!(ClapModule::load(&bundle).is_err());
        assert!(ClapModule::load(&directory.path().join("Missing.clap")).is_err());
        let invalid = directory.path().join("Invalid.clap");
        std::fs::write(&invalid, b"not a library").unwrap();
        assert!(matches!(
            ClapModule::load(&invalid),
            Err(HostError::Module { .. })
        ));
    }
}
