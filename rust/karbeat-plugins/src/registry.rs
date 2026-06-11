// src/core/plugin/registry.rs
use hashbrown::HashMap;
use karbeat_plugin_types::ParameterSpec;
use karbeat_plugin_api::{traits::{AudioPlugin, AudioPluginBuilder}, types::PluginCategory};
use karbeat_utils::hash::hash_str;
use crate::{
    effect::parametric_eq::DigiParametricEQ,
    generator::{karbeatzer_v2::KarbeatzerV2, my_retro::MyRetro},
};

type PluginFactory = Box<dyn Fn() -> Box<dyn AudioPlugin + Send + Sync> + Send + Sync>;

struct RegisteredPlugin {
    name: String,
    factory: PluginFactory,
    parameter_specs: Vec<ParameterSpec>,
    is_synth: bool,
}

/// Information about a registered plugin (for UI display)
#[derive(Clone, Debug)]
pub struct PluginInfo {
    pub id: u32,
    pub name: String,
}

pub struct PluginRegistry {
    plugins: HashMap<u32, RegisteredPlugin>,
}

impl PluginRegistry {
    pub fn new() -> Self {
        Self {
            plugins: HashMap::new(),
        }
    }

    pub fn new_with_defaults() -> Self {
        let mut registry = Self::new();
        registry.register_plugin("synth_karbeatzer_v2", "Karbeatzer V2", || {
            Box::new(KarbeatzerV2::build())
        });
        registry.register_plugin("synth_my_retro", "My Retro", || {
            Box::new(MyRetro::build())
        });
        registry.register_plugin("effect_param_eq", "Parametric EQ", || {
            Box::new(DigiParametricEQ::build())
        });
        registry
    }

    pub fn register_plugin<F>(&mut self, id_str: &str, name: &str, factory: F) -> u32
    where
        F: Fn() -> Box<dyn AudioPlugin + Send + Sync> + Send + Sync + 'static,
    {
        let id = hash_str(id_str);
        let temp_plugin = factory();
        let parameter_specs = temp_plugin.get_parameter_specs();
        let is_synth = matches!(temp_plugin.category(), PluginCategory::Instrument);
        self.plugins.insert(
            id,
            RegisteredPlugin {
                name: name.to_string(),
                factory: Box::new(factory),
                parameter_specs,
                is_synth,
            },
        );
        id
    }

    /// Deprecated: use `register_plugin` instead.
    #[deprecated(note = "use register_plugin instead")]
    pub fn register_generator<F>(&mut self, id_str: &str, name: &str, factory: F) -> u32
    where
        F: Fn() -> Box<dyn AudioPlugin + Send + Sync> + Send + Sync + 'static,
    {
        self.register_plugin(id_str, name, factory)
    }

    /// Deprecated: use `register_plugin` instead.
    #[deprecated(note = "use register_plugin instead")]
    pub fn register_effect<F>(&mut self, id_str: &str, name: &str, factory: F) -> u32
    where
        F: Fn() -> Box<dyn AudioPlugin + Send + Sync> + Send + Sync + 'static,
    {
        self.register_plugin(id_str, name, factory)
    }

    // =========================================================================
    // ID-based creation
    // =========================================================================

    pub fn create_plugin_by_id(
        &self,
        id: u32,
    ) -> Option<(Box<dyn AudioPlugin + Send + Sync>, String)> {
        self.plugins.get(&id).map(|reg| {
            let plugin = (reg.factory)();
            (plugin, reg.name.clone())
        })
    }

    /// Deprecated: use `create_plugin_by_id` instead.
    #[deprecated(note = "use create_plugin_by_id instead")]
    pub fn create_generator_by_id(
        &self,
        id: u32,
    ) -> Option<(Box<dyn AudioPlugin + Send + Sync>, String)> {
        self.create_plugin_by_id(id)
    }

    /// Deprecated: use `create_plugin_by_id` instead.
    #[deprecated(note = "use create_plugin_by_id instead")]
    pub fn create_effect_by_id(
        &self,
        id: u32,
    ) -> Option<(Box<dyn AudioPlugin + Send + Sync>, String)> {
        self.create_plugin_by_id(id)
    }

    // =========================================================================
    // Cached Parameter Specs
    // =========================================================================

    pub fn get_plugin_parameter_specs_by_id(&self, id: u32) -> Option<Vec<ParameterSpec>> {
        self.plugins.get(&id).map(|reg| reg.parameter_specs.clone())
    }

    pub fn get_plugin_parameter_specs_by_id_str(&self, id_str: &str) -> Option<Vec<ParameterSpec>> {
        self.get_plugin_parameter_specs_by_id(hash_str(id_str))
    }

    /// Deprecated: use `get_plugin_parameter_specs_by_id` instead.
    #[deprecated(note = "use get_plugin_parameter_specs_by_id instead")]
    pub fn get_generator_parameter_specs_by_id(&self, id: u32) -> Option<Vec<ParameterSpec>> {
        self.get_plugin_parameter_specs_by_id(id)
    }

    /// Deprecated: use `get_plugin_parameter_specs_by_id_str` instead.
    #[deprecated(note = "use get_plugin_parameter_specs_by_id_str instead")]
    pub fn get_generator_parameter_specs_by_id_str(&self, id_str: &str) -> Option<Vec<ParameterSpec>> {
        self.get_plugin_parameter_specs_by_id_str(id_str)
    }

    /// Deprecated: use `get_plugin_parameter_specs_by_id` instead.
    #[deprecated(note = "use get_plugin_parameter_specs_by_id instead")]
    pub fn get_effect_parameter_specs_by_id(&self, id: u32) -> Option<Vec<ParameterSpec>> {
        self.get_plugin_parameter_specs_by_id(id)
    }

    /// Deprecated: use `get_plugin_parameter_specs_by_id_str` instead.
    #[deprecated(note = "use get_plugin_parameter_specs_by_id_str instead")]
    pub fn get_effect_parameter_specs_by_id_str(&self, id_str: &str) -> Option<Vec<ParameterSpec>> {
        self.get_plugin_parameter_specs_by_id_str(id_str)
    }

    // =========================================================================
    // Listing plugins (for UI)
    // =========================================================================

    pub fn list_plugins(&self) -> Vec<String> {
        self.plugins.values().map(|reg| reg.name.clone()).collect()
    }

    pub fn list_plugins_with_ids(&self) -> Vec<PluginInfo> {
        self.plugins
            .iter()
            .map(|(id, reg)| PluginInfo {
                id: *id,
                name: reg.name.clone(),
            })
            .collect()
    }

    pub fn list_generators(&self) -> Vec<String> {
        self.plugins
            .values()
            .filter(|reg| reg.is_synth)
            .map(|reg| reg.name.clone())
            .collect()
    }

    pub fn list_effects(&self) -> Vec<String> {
        self.plugins
            .values()
            .filter(|reg| !reg.is_synth)
            .map(|reg| reg.name.clone())
            .collect()
    }

    pub fn list_generators_with_ids(&self) -> Vec<PluginInfo> {
        self.plugins
            .iter()
            .filter(|(_, reg)| reg.is_synth)
            .map(|(id, reg)| PluginInfo {
                id: *id,
                name: reg.name.clone(),
            })
            .collect()
    }

    pub fn list_effects_with_ids(&self) -> Vec<PluginInfo> {
        self.plugins
            .iter()
            .filter(|(_, reg)| !reg.is_synth)
            .map(|(id, reg)| PluginInfo {
                id: *id,
                name: reg.name.clone(),
            })
            .collect()
    }

    // =========================================================================
    // Name lookup
    // =========================================================================

    pub fn get_plugin_name(&self, id: u32) -> Option<String> {
        self.plugins.get(&id).map(|reg| reg.name.clone())
    }

    pub fn get_plugin_name_from_id_str(&self, id_str: &str) -> Option<String> {
        self.get_plugin_name(hash_str(id_str))
    }

    /// Deprecated: use `get_plugin_name` instead.
    #[deprecated(note = "use get_plugin_name instead")]
    pub fn get_generator_name(&self, id: u32) -> Option<String> {
        self.get_plugin_name(id)
    }

    /// Deprecated: use `get_plugin_name_from_id_str` instead.
    #[deprecated(note = "use get_plugin_name_from_id_str instead")]
    pub fn get_generator_name_from_id_str(&self, id_str: &str) -> Option<String> {
        self.get_plugin_name_from_id_str(id_str)
    }

    /// Deprecated: use `get_plugin_name` instead.
    #[deprecated(note = "use get_plugin_name instead")]
    pub fn get_effect_name(&self, id: u32) -> Option<String> {
        self.get_plugin_name(id)
    }

    /// Deprecated: use `get_plugin_name_from_id_str` instead.
    #[deprecated(note = "use get_plugin_name_from_id_str instead")]
    pub fn get_effect_name_from_id_str(&self, id_str: &str) -> Option<String> {
        self.get_plugin_name_from_id_str(id_str)
    }
}