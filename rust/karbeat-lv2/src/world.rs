//! LV2 bundle discovery and loading through lilv.
//!
//! Reading a bundle only parses its Turtle description; no plugin code is loaded until an
//! instance is created. Loading a bundle reads its manifest, which only lists the plugins. lilv
//! reads a plugin's own description the first time that plugin is used, so hosting one plugin
//! from a bundle of hundreds costs one description, not all of them. Discovery does read every
//! description, on the scan thread, and its result is cached by the shared scanner.

use std::{
    ffi::OsStr,
    path::{Path, PathBuf},
    rc::Rc,
};

use karbeat_host_api::{HostError, PluginDescriptor, PluginFormat, PluginIdentity, PluginKind};
use lilv::{node::Node, plugin::Plugin};
use lilv_sys as sys;

use crate::{
    plugin::SUPPORTED_FEATURES,
    ports::{PortKind, port_kind},
    uris::Uris,
};

/// Directory extension that marks one LV2 bundle.
pub const BUNDLE_EXTENSION: &str = "lv2";

fn module_error(path: &Path, message: impl ToString) -> HostError {
    HostError::Module {
        path: path.to_path_buf(),
        message: message.to_string(),
    }
}

/// Returns the conventional per-user and system-wide LV2 bundle directories.
///
/// `LV2_PATH` entries come first, as they do for other LV2 hosts. Paths are returned whether or
/// not they exist.
pub fn default_scan_paths() -> Vec<PathBuf> {
    scan_paths(
        std::env::var_os("LV2_PATH").as_deref(),
        std::env::var_os("HOME").as_deref(),
    )
}

fn scan_paths(lv2_path: Option<&OsStr>, home: Option<&OsStr>) -> Vec<PathBuf> {
    let mut paths: Vec<PathBuf> = lv2_path
        .map(|configured| {
            std::env::split_paths(configured)
                .filter(|path| !path.as_os_str().is_empty())
                .collect()
        })
        .unwrap_or_default();
    if let Some(home) = home {
        paths.push(PathBuf::from(home).join(".lv2"));
    }
    paths.extend(
        [
            "/usr/local/lib/lv2",
            "/usr/local/lib64/lv2",
            "/usr/lib/lv2",
            "/usr/lib64/lv2",
        ]
        .map(PathBuf::from),
    );
    // Debian-style multiarch installations.
    paths.push(PathBuf::from(format!(
        "/usr/lib/{}-linux-gnu/lv2",
        std::env::consts::ARCH
    )));
    let mut seen = std::collections::HashSet::new();
    paths.retain(|path| seen.insert(path.clone()));
    paths
}

/// Reads the plugins of one bundle that this host can run.
///
/// A plugin is listed when the host can run every one of its ports, provides its required
/// features, and it has an audio output. Replaced and incomplete plugins are skipped.
pub fn probe_bundle(path: &Path) -> Result<Vec<PluginDescriptor>, HostError> {
    let bundle = std::fs::canonicalize(path)?;
    if !bundle.join("manifest.ttl").is_file() {
        return Ok(Vec::new());
    }
    let world = lilv::World::new();
    world.load_bundle(&bundle_node(&world, &bundle)?);
    let uris = Uris::new(&world);
    let mut descriptors = Vec::new();
    for plugin in world.plugins() {
        let Some(uri) = plugin.uri().as_uri().map(str::to_owned) else {
            continue;
        };
        if plugin.is_replaced() {
            continue;
        }
        if let Some(reason) = unhostable(&plugin, &uris) {
            tracing::debug!("{uri}: skipped, {reason}");
            continue;
        }
        let Some(name) = plugin.name().as_str().map(str::to_owned) else {
            continue;
        };
        descriptors.push(PluginDescriptor {
            identity: PluginIdentity {
                format: PluginFormat::Lv2,
                native_id: uri,
            },
            path: bundle.clone(),
            name,
            vendor: plugin
                .author_name()
                .and_then(|author| author.as_str().map(str::to_owned))
                .unwrap_or_default(),
            version: version(&plugin, &uris),
            kind: if plugin
                .value(&uris.rdf_type)
                .contains(&uris.instrument_plugin)
            {
                PluginKind::Instrument
            } else {
                PluginKind::Effect
            },
        });
    }
    descriptors.sort_by(|left, right| left.identity.native_id.cmp(&right.identity.native_id));
    Ok(descriptors)
}

/// Builds the `file://` URI node lilv identifies a canonical bundle directory by.
fn bundle_node(world: &lilv::World, bundle: &Path) -> Result<Node, HostError> {
    let text = bundle
        .to_str()
        .filter(|text| !text.contains('\0'))
        .ok_or_else(|| module_error(bundle, "bundle path is not valid UTF-8"))?;
    Ok(world.new_file_uri(None, &format!("{text}/")))
}

/// Says why the host cannot run `plugin`, or returns `None` when it can.
pub(crate) fn unhostable(plugin: &Plugin, uris: &Uris) -> Option<&'static str> {
    // Without a name or any port the description is incomplete, and reading the name of such
    // a plugin through the lilv bindings would panic.
    if !plugin.verify() {
        return Some("its description is incomplete");
    }
    let mut has_audio_output = false;
    for port in plugin.iter_ports() {
        match port_kind(&port, uris) {
            None => return Some("a port has a direction or type the host does not run"),
            Some(PortKind::AudioOutput) => has_audio_output = true,
            Some(_) => {}
        }
        if port.symbol().is_none() {
            return Some("a port has no symbol");
        }
    }
    if !has_audio_output {
        return Some("it has no audio output");
    }
    let requires_unsupported = plugin.required_features().iter().any(|feature| {
        feature
            .as_uri()
            .is_none_or(|uri| !SUPPORTED_FEATURES.contains(&uri))
    });
    requires_unsupported.then_some("it requires an LV2 feature the host does not provide")
}

fn version(plugin: &Plugin, uris: &Uris) -> String {
    let number = |predicate: &Node| {
        plugin
            .value(predicate)
            .iter()
            .next()
            .and_then(|value| value.as_int())
    };
    match (number(&uris.minor_version), number(&uris.micro_version)) {
        (Some(minor), Some(micro)) => format!("{minor}.{micro}"),
        (Some(minor), None) => minor.to_string(),
        _ => String::new(),
    }
}

/// One bundle's lilv world, owned by the host on the native UI thread.
///
/// The raw lilv calls made for instantiation and state bypass the `lilv` crate's world lock,
/// which is sound because a bundle never leaves the thread that loaded it.
pub(crate) struct Lv2Bundle {
    /// Canonical bundle directory.
    pub path: PathBuf,
    pub world: lilv::World,
    pub uris: Uris,
}

impl Lv2Bundle {
    /// Reads the bundle's manifest. Plugin descriptions are read when a plugin is first used.
    pub fn load(path: &Path) -> Result<Rc<Self>, HostError> {
        let path = std::fs::canonicalize(path)?;
        if !path.join("manifest.ttl").is_file() {
            return Err(module_error(&path, "bundle has no manifest"));
        }
        let world = lilv::World::new();
        world.load_bundle(&bundle_node(&world, &path)?);
        let uris = Uris::new(&world);
        Ok(Rc::new(Self { path, world, uris }))
    }

    fn unavailable(&self) -> HostError {
        module_error(&self.path, "plugin is no longer available")
    }

    /// Looks up a plugin of this bundle by URI.
    pub fn plugin(&self, uri: &str) -> Result<Plugin, HostError> {
        if uri.contains('\0') {
            return Err(self.unavailable());
        }
        self.world
            .plugins()
            .plugin(&self.world.new_uri(uri))
            .ok_or_else(|| self.unavailable())
    }

    /// Looks up the lilv record of a plugin, for the raw calls that instantiate it and
    /// capture its state.
    pub fn plugin_record(&self, uri: &str) -> Result<*const sys::LilvPlugin, HostError> {
        if uri.contains('\0') {
            return Err(self.unavailable());
        }
        let node = self.world.new_uri(uri);
        // SAFETY: The world is alive and used only by its owning thread.
        let plugins = unsafe { sys::lilv_world_get_all_plugins(self.world.as_ptr()) };
        // SAFETY: The collection belongs to the live world and the node is a valid URI node.
        let plugin = unsafe { sys::lilv_plugins_get_by_uri(plugins, node.as_ptr()) };
        if plugin.is_null() {
            Err(self.unavailable())
        } else {
            Ok(plugin)
        }
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used, reason = "test fixtures must be creatable")]
mod tests {
    use super::*;

    #[test]
    fn lv2_path_entries_come_first_and_duplicates_are_dropped() {
        let paths = scan_paths(
            Some(OsStr::new("/opt/lv2::/usr/lib/lv2")),
            Some(OsStr::new("/home/user")),
        );
        assert_eq!(paths[0], PathBuf::from("/opt/lv2"));
        assert_eq!(paths[1], PathBuf::from("/usr/lib/lv2"));
        assert_eq!(paths[2], PathBuf::from("/home/user/.lv2"));
        assert!(paths.contains(&PathBuf::from("/usr/lib64/lv2")));
        assert_eq!(
            paths
                .iter()
                .filter(|path| path.as_path() == Path::new("/usr/lib/lv2"))
                .count(),
            1
        );
    }

    #[test]
    fn defaults_cover_the_lib64_layout_without_environment() {
        let paths = scan_paths(None, None);
        assert!(paths.contains(&PathBuf::from("/usr/lib64/lv2")));
        assert!(paths.contains(&PathBuf::from("/usr/local/lib/lv2")));
        assert!(!paths.iter().any(|path| path.ends_with(".lv2")));
    }

    #[test]
    fn a_directory_without_a_manifest_is_an_empty_bundle() {
        let directory = tempfile::tempdir().unwrap();
        let bundle = directory.path().join("Empty.lv2");
        std::fs::create_dir(&bundle).unwrap();
        assert!(matches!(probe_bundle(&bundle), Ok(plugins) if plugins.is_empty()));
        assert!(probe_bundle(&directory.path().join("Missing.lv2")).is_err());
    }
}
