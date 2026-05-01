#[macro_export]
macro_rules! impl_plugin_parameters {
    (
        $struct_name:ident,
        [$($field:ident),+ $(,)?]
    ) => {
        impl $struct_name {
            /// Automatically route host sets to the correct parameter
            pub fn handle_set_parameter(&mut self, id: u32, value: f32) -> bool {
                $(
                    if self.$field.id == id {
                        self.$field.set_base(value);
                        return true;
                    }
                )+
                false
            }

            /// Automatically route host gets from the correct parameter
            pub fn handle_get_parameter(&self, id: u32) -> Option<f32> {
                $(
                    if self.$field.id == id {
                        return Some(self.$field.get_base().to_f32());
                    }
                )+
                None
            }

            /// Build the defaults map dynamically
            pub fn generate_default_parameters(&self) -> std::collections::HashMap<u32, f32> {
                let mut map = std::collections::HashMap::new();
                $( map.insert(self.$field.id, self.$field.get_base().to_f32()); )+
                map
            }

            /// Build the UI specifications dynamically
            pub fn generate_parameter_specs(&self) -> Vec<karbeat_plugin_api::wrapper::PluginParameter> {
                vec![
                    $( self.$field.to_spec() ),+
                ]
            }
        }
    };
}

/// A macro to directly inject redundant boilerplate implementation for
/// KarbeatEffect and KarbeatGenerator wrappers.
/// This assumes the wrapper struct has `base` and `engine` fields.
#[macro_export]
macro_rules! delegate_plugin_boilerplate {
    () => {
        fn set_parameter(&mut self, id: u32, value: f32) {
            if !self.base.set_parameter(id, value) {
                self.engine.set_custom_parameter(id, value);
            }
        }

        fn get_parameter(&self, id: u32) -> f32 {
            self.base
                .get_parameter(id)
                .or_else(|| self.engine.get_custom_parameter(id))
                .unwrap_or(0.0)
        }

        fn get_parameter_specs(&self) -> Vec<ParameterSpec> {
            self.get_all_parameters()
        }

        fn execute_custom_command(&mut self, command: &str, payload: &Value) -> Option<Value> {
            self.engine.execute_custom_command(command, payload)
        }

        fn as_any(&self) -> &dyn Any {
            self
        }

        fn apply_automation(&mut self, id: u32, value: f32) {
            // FIX: Route to engine if base doesn't handle it
            if !self.base.set_parameter(id, value) {
                // Assuming apply_automation uses the same ID check
                self.engine.apply_automation(id, value);
            } else {
                self.base.apply_automation(id, value);
            }
        }

        fn clear_automation(&mut self, id: u32) {
            // FIX: Route to engine if base doesn't handle it
            // (You may need a `base.has_parameter(id)` check here instead depending on your base API)
            self.base.clear_automation(id);
            self.engine.clear_automation(id);
        }
    };
}
