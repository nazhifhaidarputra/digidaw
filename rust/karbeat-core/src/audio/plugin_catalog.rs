use std::collections::{HashMap, HashSet};

use karbeat_host::{PluginDescriptor, PluginIdentity, PluginKind};
use karbeat_plugins::registry::{PluginInfo, PluginRegistry};

/// External discovery entry. The numeric ID is local to this catalog; projects persist identity.
#[derive(Clone, Debug)]
pub struct ExternalPluginEntry {
    /// Process-local numeric ID used by API calls and project plugin instances.
    pub id: u32,
    /// Scanner-provided identity, path, metadata, and plugin kind.
    pub descriptor: PluginDescriptor,
    /// Whether the descriptor currently resolves to a usable installation.
    pub available: bool,
}

/// Combines discovery with reserved first-party IDs without creating native plugin instances.
pub struct PluginCatalog {
    built_in: Vec<PluginInfo>,
    reserved: HashSet<u32>,
    external: HashMap<u32, ExternalPluginEntry>,
    identities: HashMap<PluginIdentity, u32>,
}

impl PluginCatalog {
    /// Builds a catalog containing the registry's built-in plugins and reserves their IDs.
    pub fn new(registry: &PluginRegistry) -> Self {
        let built_in = registry.list_plugins_with_ids();
        Self {
            reserved: built_in.iter().map(|plugin| plugin.id).collect(),
            built_in,
            external: HashMap::new(),
            identities: HashMap::new(),
        }
    }

    /// Merge confirmed discovery results. Omitted entries retain their previous availability;
    /// a cancelled or failed scan must not remove a previously usable plugin.
    pub fn merge(&mut self, descriptors: impl IntoIterator<Item = PluginDescriptor>) {
        for descriptor in descriptors {
            if let Some(id) = self.identities.get(&descriptor.identity) {
                if let Some(entry) = self.external.get_mut(id) {
                    entry.descriptor = descriptor;
                    entry.available = true;
                }
                continue;
            }
            let id = self.allocate_id(&descriptor.identity);
            self.identities.insert(descriptor.identity.clone(), id);
            self.external.insert(
                id,
                ExternalPluginEntry {
                    id,
                    descriptor,
                    available: true,
                },
            );
        }
    }

    /// Looks up an external catalog entry by its process-local numeric ID.
    pub fn external(&self, id: u32) -> Option<&ExternalPluginEntry> {
        self.external.get(&id)
    }

    /// Returns all external entries sorted by display name and then numeric ID.
    pub fn external_entries(&self) -> Vec<ExternalPluginEntry> {
        let mut entries: Vec<_> = self.external.values().cloned().collect();
        entries.sort_by(|a, b| {
            a.descriptor
                .name
                .cmp(&b.descriptor.name)
                .then(a.id.cmp(&b.id))
        });
        entries
    }

    /// Resolves a persisted format/native-ID identity to its current catalog entry.
    pub fn resolve(&self, identity: &PluginIdentity) -> Option<&ExternalPluginEntry> {
        self.identities
            .get(identity)
            .and_then(|id| self.external.get(id))
    }

    /// Only explicit removal or a confirmed unavailable location marks a plugin missing.
    pub fn mark_missing(&mut self, identity: &PluginIdentity) {
        if let Some(id) = self.identities.get(identity) {
            if let Some(entry) = self.external.get_mut(id) {
                entry.available = false;
            }
        }
    }

    /// Returns built-in and currently available external plugins sorted for display.
    pub fn list(&self) -> Vec<PluginInfo> {
        let mut plugins = self.built_in.clone();
        plugins.extend(
            self.external
                .values()
                .filter(|entry| entry.available)
                .map(|entry| PluginInfo {
                    id: entry.id,
                    name: entry.descriptor.name.clone(),
                    is_synth: entry.descriptor.kind == PluginKind::Instrument,
                }),
        );
        plugins.sort_by(|a, b| a.name.cmp(&b.name).then(a.id.cmp(&b.id)));
        plugins
    }

    fn allocate_id(&self, identity: &PluginIdentity) -> u32 {
        let mut id = karbeat_utils::hash::hash_str(&format!(
            "external:{:?}:{}",
            identity.format, identity.native_id
        ));
        while self.reserved.contains(&id) || self.external.contains_key(&id) {
            id = id.wrapping_add(1);
        }
        id
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use karbeat_host::PluginFormat;

    fn descriptor() -> PluginDescriptor {
        PluginDescriptor {
            identity: PluginIdentity {
                format: PluginFormat::Vst3,
                native_id: "56535456697461766974616C00000000".into(),
            },
            path: "/old/Vital.vst3".into(),
            name: "Vital".into(),
            vendor: "Vital Audio".into(),
            version: "1".into(),
            kind: PluginKind::Instrument,
        }
    }

    #[test]
    fn reserves_builtin_ids_and_keeps_identity_across_relocation_and_failed_scans() {
        let registry = PluginRegistry::new_with_defaults();
        let mut catalog = PluginCatalog::new(&registry);
        let mut plugin = descriptor();
        let collision = catalog.allocate_id(&plugin.identity);
        catalog.reserved.insert(collision);
        catalog.merge([plugin.clone()]);
        let id = catalog.resolve(&plugin.identity).map(|entry| entry.id);
        assert_ne!(id, Some(collision));
        assert!(registry.list_plugins_with_ids().iter().all(|builtin| {
            catalog
                .list()
                .iter()
                .any(|p| p.id == builtin.id && p.name == builtin.name)
        }));
        plugin.path = "/new/Vital.vst3".into();
        catalog.merge([plugin.clone()]);
        catalog.merge([]);
        assert_eq!(
            catalog
                .resolve(&plugin.identity)
                .map(|entry| (entry.id, &entry.descriptor.path)),
            id.map(|id| (id, &plugin.path))
        );
        assert_eq!(catalog.external.len(), 1);
        catalog.mark_missing(&plugin.identity);
        assert!(!catalog.list().iter().any(|p| Some(p.id) == id));
        catalog.merge([plugin.clone()]);
        assert!(
            catalog
                .resolve(&plugin.identity)
                .is_some_and(|entry| entry.available && Some(entry.id) == id)
        );
    }
}
