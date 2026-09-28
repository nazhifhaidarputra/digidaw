use serde::{Deserialize, Serialize};

/// External identity and opaque native state survive missing installations and catalog ID changes.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct ExternalPluginInstance {
    pub descriptor: karbeat_host::PluginDescriptor,
    pub state: Option<karbeat_host::PluginState>,
}

/// Define a plugin instance descriptor.
///
/// This is a lightweight struct for serialization and UI purposes.
/// The actual plugin processing instance is owned by the audio thread's `AudioPluginState`.
///
/// # Example:
/// ```rust,ignore
/// let instance = PluginInstance {
///     registry_id: 0,
///     name: "Basic Reverb".to_string(),
///     bypass: false,
///     parameters: indexmap::IndexMap::new(),
/// };
/// ```
#[derive(Serialize, Deserialize, Clone, Debug, Default)]
pub struct PluginInstance {
    /// Registry ID for plugin lookup (stable identifier)
    pub registry_id: u32,
    /// Name of the plugin (for display purposes)
    pub name: String,
    /// Whether this plugin is bypassed
    pub bypass: bool,
    /// Plugin parameter specifications for persistence
    #[serde(default)]
    pub parameter_specs: Vec<karbeat_plugin_types::ParameterSpec>,

    #[serde(default)]
    pub plugin_state: Vec<u8>,

    /// Native state is captured by the control owner, independently of the audio snapshot.
    #[serde(default)]
    pub external: Option<ExternalPluginInstance>,
}

impl PartialEq for PluginInstance {
    fn eq(&self, other: &Self) -> bool {
        self.registry_id == other.registry_id
            && self.name == other.name
            && self.bypass == other.bypass
            && self.plugin_state == other.plugin_state
            && self.external == other.external
        // Note: We ignore parameter_specs for equality checks because they are just metadata
    }
}

impl PluginInstance {
    /// Create a new plugin instance with name only (backwards compatible)
    pub fn new(name: &str) -> Self {
        Self {
            registry_id: 0,
            name: name.to_string(),
            bypass: false,
            parameter_specs: Vec::new(),
            plugin_state: Vec::new(),
            external: None,
        }
    }

    /// Create a new plugin instance with registry ID and name
    pub fn new_with_id(registry_id: u32, name: &str) -> Self {
        Self {
            registry_id,
            name: name.to_string(),
            bypass: false,
            parameter_specs: Vec::new(),
            plugin_state: Vec::new(),
            external: None,
        }
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "serialization failures should fail these tests"
)]
mod tests {
    use super::*;
    use karbeat_host::{PluginDescriptor, PluginFormat, PluginIdentity, PluginKind, PluginState};

    #[test]
    fn legacy_named_and_sequence_projects_default_to_builtin_instances() {
        let json = r#"{"registry_id":42,"name":"Legacy","bypass":false,"plugin_state":[1,2]}"#;
        let restored: PluginInstance = serde_json::from_str(json).unwrap();
        assert!(restored.external.is_none());
        assert_eq!(restored.plugin_state, [1, 2]);
        let sequence = (
            42_u32,
            "Legacy",
            false,
            Vec::<karbeat_plugin_types::ParameterSpec>::new(),
            vec![1_u8, 2],
        );
        let restored: PluginInstance =
            rmp_serde::from_slice(&rmp_serde::to_vec(&sequence).unwrap()).unwrap();
        assert!(restored.external.is_none());
        assert_eq!(restored.registry_id, 42);
    }

    #[test]
    fn missing_external_plugin_round_trip_preserves_both_native_states() {
        let identity = PluginIdentity {
            format: PluginFormat::Vst3,
            native_id: "56535456697461766974616C00000000".into(),
        };
        let mut plugin = PluginInstance::new_with_id(123, "Vital");
        plugin.external = Some(ExternalPluginInstance {
            descriptor: PluginDescriptor {
                identity: identity.clone(),
                path: "/missing/Vital.vst3".into(),
                name: "Vital".into(),
                vendor: "Vital Audio".into(),
                version: "1.6.4".into(),
                kind: PluginKind::Instrument,
            },
            state: Some(PluginState {
                version: 1,
                identity,
                component: vec![0, 255, 3],
                controller: Some(vec![42, 0]),
            }),
        });
        let restored: PluginInstance =
            rmp_serde::from_slice(&rmp_serde::to_vec_named(&plugin).unwrap()).unwrap();
        assert_eq!(restored, plugin);
        let restored: PluginInstance =
            serde_json::from_slice(&serde_json::to_vec(&plugin).unwrap()).unwrap();
        assert_eq!(restored, plugin);
    }
}
