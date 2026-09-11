// src/core/plugin/registry.rs
use crate::{
    effect::{
        delay::DigidawDelay, parametric_eq::DigiParametricEQ, pitch_shifter::PitchShifter,
        sidechain::DigidawSidechainCompressor,
    },
    generator::{karbeatzer_v2::KarbeatzerV2, my_retro::MyRetro},
};
use hashbrown::HashMap;
use karbeat_plugin_api::{
    traits::{AudioPlugin, AudioPluginBuilder},
    types::PluginCategory,
};
use karbeat_plugin_types::ParameterSpec;
use karbeat_utils::hash::hash_str;

pub type PluginFactory = fn() -> Box<dyn AudioPlugin>;

/// A declarative macro to quickly register a list of plugins.
/// Usage: `register_plugins!(registry, ("id", "Name", PluginStruct), ...);`
macro_rules! register_plugins {
    ( $registry:expr, $( ($id:expr, $name:expr, $plugin_type:ty) ),* $(,)? ) => {
        $(
            $registry.register_plugin($id, $name, || Box::new(<$plugin_type>::build()));
        )*
    };
}

#[derive(Clone)]
pub struct RegisteredPlugin {
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
    pub is_synth: bool,
}

#[derive(Clone)]
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
        register_plugins!(
            registry,
            ("synth_karbeatzer_v2", "Karbeatzer V2", KarbeatzerV2),
            ("synth_my_retro", "My Retro", MyRetro),
            ("effect_param_eq", "Parametric EQ", DigiParametricEQ),
            ("effect_pitcher", "Pitcher", PitchShifter),
            (
                "effect_digidaw_sidechain_comp",
                "DigiDAW Sidechain Compressor",
                DigidawSidechainCompressor
            ),
            ("effect_delay", "DigiDAW Delay", DigidawDelay),
        );
        registry
    }

    pub fn register_plugin(&mut self, id_str: &str, name: &str, factory: PluginFactory) -> u32
    {
        let id = hash_str(id_str);
        let temp_plugin = factory();
        let parameter_specs = temp_plugin.get_parameter_specs();
        let is_synth = matches!(temp_plugin.category(), PluginCategory::Instrument);
        self.plugins.insert(
            id,
            RegisteredPlugin {
                name: name.to_string(),
                factory: factory,
                parameter_specs,
                is_synth,
            },
        );
        id
    }

    // =========================================================================
    // ID-based creation
    // =========================================================================

    pub fn create_plugin_by_id(
        &self,
        id: u32,
    ) -> Option<(PluginFactory, String)> {
        self.plugins.get(&id).map(|reg| {
            // let plugin = (reg.factory)();
            (reg.factory, reg.name.clone())
        })
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
    pub fn get_generator_parameter_specs_by_id_str(
        &self,
        id_str: &str,
    ) -> Option<Vec<ParameterSpec>> {
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
                is_synth: reg.is_synth,
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
                is_synth: reg.is_synth,
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
                is_synth: reg.is_synth,
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
