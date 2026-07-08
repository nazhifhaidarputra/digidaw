// //! Tests for `api::plugin_api`

// #[cfg(test)]
// mod tests {
//     use crate::api::{mixer_api, plugin_api};
//     use crate::audio::event::PluginTarget;
//     use crate::commands::EffectTarget;
//     use crate::shared::id::{EffectId, GeneratorId, TrackId};
//     use crate::test::helpers::{
//         karbeatzer_v2_registry_id, make_ctx, make_seeded_ctx, param_eq_registry_id,
//     };
//     use karbeat_utils::hash::hash_str;

//     // ─── IntoParamId trait ───────────────────────────────────────────────────

//     #[test]
//     fn into_param_id_u32_returns_self() {
//         use crate::api::plugin_api::IntoParamId;
//         let id: u32 = 42;
//         assert_eq!(id.into_id(), 42);
//     }

//     #[test]
//     fn into_param_id_str_matches_hash() {
//         use crate::api::plugin_api::IntoParamId;
//         let expected = hash_str("volume");
//         assert_eq!("volume".into_id(), expected);
//     }

//     #[test]
//     fn into_param_id_string_matches_str() {
//         use crate::api::plugin_api::IntoParamId;
//         let s = "cutoff".to_string();
//         let str_id = "cutoff".into_id();
//         let string_id = s.into_id();
//         assert_eq!(str_id, string_id);
//     }

//     // ─── get_available_generators ────────────────────────────────────────────

//     #[test]
//     fn get_available_generators_not_empty() {
//         let ctx = make_ctx();
//         let generators: Vec<u32> =
//             plugin_api::get_available_generators(&ctx, |info| info.id);
//         assert!(!generators.is_empty(), "Default registry should have at least 1 generator");
//     }

//     // ─── get_available_effects ───────────────────────────────────────────────

//     #[test]
//     fn get_available_effects_not_empty() {
//         let ctx = make_ctx();
//         let effects: Vec<u32> = plugin_api::get_available_effects(&ctx, |info| info.id);
//         assert!(!effects.is_empty(), "Default registry should have at least 1 effect");
//     }

//     // ─── get_available_plugins ───────────────────────────────────────────────

//     #[test]
//     fn get_available_plugins_includes_all() {
//         use karbeat_plugins::registry::PluginInfo;
//         let ctx = make_ctx();
//         let all: Vec<PluginInfo> = plugin_api::get_available_plugins(&ctx);
//         let gens: Vec<u32> = plugin_api::get_available_generators(&ctx, |i| i.id);
//         let effs: Vec<u32> = plugin_api::get_available_effects(&ctx, |i| i.id);
//         assert_eq!(all.len(), gens.len() + effs.len());
//     }

//     // ─── get_generator ───────────────────────────────────────────────────────

//     #[test]
//     fn get_generator_missing_returns_none() {
//         let ctx = make_ctx();
//         let bogus_id = GeneratorId::from(99999);
//         let result = plugin_api::get_generator(&ctx, &bogus_id, |_g| ());
//         assert!(result.is_none());
//     }

//     #[test]
//     fn get_generator_happy_path() {
//         let (ctx, _audio_id, _midi_id, _pat_id) = make_seeded_ctx();
//         let gen_id = *ctx.app_state.generator_pool.keys().next().unwrap();
//         let result = plugin_api::get_generator(&ctx, &gen_id, |g| g.id);
//         assert!(result.is_some());
//     }

//     // ─── get_effect ──────────────────────────────────────────────────────────

//     #[test]
//     fn get_effect_missing_track_returns_none() {
//         let ctx = make_ctx();
//         let bogus_track = TrackId::from(99999);
//         let bogus_effect = EffectId::from(99999);
//         let result = plugin_api::get_effect(&ctx, &bogus_track, &bogus_effect, |_| ());
//         assert!(result.is_none());
//     }

//     // ─── get_effect_from_master ──────────────────────────────────────────────

//     #[test]
//     fn get_effect_from_master_missing_returns_none() {
//         let ctx = make_ctx();
//         let bogus_id = EffectId::from(99999);
//         let result = plugin_api::get_effect_from_master(&ctx, &bogus_id, |_| ());
//         assert!(result.is_none());
//     }

//     // ─── get_effects_from_track ──────────────────────────────────────────────

//     #[test]
//     fn get_effects_from_track_missing_track_returns_none() {
//         let ctx = make_ctx();
//         let bogus_id = TrackId::from(99999);
//         let result: Option<Vec<_>> =
//             plugin_api::get_effects_from_track(&ctx, &bogus_id, |_e| ());
//         assert!(result.is_none());
//     }

//     // ─── get_master_effects ──────────────────────────────────────────────────

//     #[test]
//     fn get_master_effects_empty_when_no_effects() {
//         let ctx = make_ctx();
//         let effects: Vec<()> = plugin_api::get_master_effects(&ctx, |_| ());
//         assert!(effects.is_empty());
//     }

//     // ─── get_generator_parameter_specs ───────────────────────────────────────

//     #[test]
//     fn get_generator_parameter_specs_not_plugin_type_returns_err() {
//         // No generators of non-plugin type exist in default state, so missing gen returns Err
//         let ctx = make_ctx();
//         let bogus_id = GeneratorId::from(99999);
//         let result = plugin_api::get_generator_parameter_specs(&ctx, &bogus_id, |spec, val| (spec.id, val));
//         assert!(result.is_err());
//     }

//     #[test]
//     fn get_generator_parameter_specs_happy_path() {
//         let (ctx, _audio_id, _midi_id, _pat_id) = make_seeded_ctx();
//         let gen_id = *ctx.app_state.generator_pool.keys().next().unwrap();
//         let result = plugin_api::get_generator_parameter_specs(&ctx, &gen_id, |spec, val| (spec.id, val));
//         assert!(result.is_ok(), "{:?}", result.err());
//     }

//     // ─── get_generator_parameter ─────────────────────────────────────────────

//     #[test]
//     fn get_generator_parameter_always_returns_err() {
//         let gen_id = GeneratorId::from(1);
//         let result = plugin_api::get_generator_parameter(&gen_id, 42u32);
//         assert!(result.is_err(), "Should always Err (moved to audio thread)");
//         assert!(
//             result.unwrap_err().contains("no longer tracks"),
//             "Should mention tracking moved"
//         );
//     }

//     // ─── set_generator_parameter ─────────────────────────────────────────────

//     #[test]
//     fn set_generator_parameter_no_stream_returns_ok() {
//         let mut ctx = make_ctx();
//         let gen_id = GeneratorId::from(1);
//         // No ring buffer → silently no-ops
//         let result = plugin_api::set_generator_parameter(&mut ctx, &gen_id, 42u32, 0.5);
//         assert!(result.is_ok());
//     }

//     // ─── set_effect_parameter ────────────────────────────────────────────────

//     #[test]
//     fn set_effect_parameter_no_stream_returns_ok() {
//         let mut ctx = make_ctx();
//         let effect_id = EffectId::from(1);
//         let track_id = TrackId::from(1);
//         let result = plugin_api::set_effect_parameter(
//             &mut ctx,
//             &EffectTarget::Track(track_id),
//             &effect_id,
//             "volume",
//             0.8,
//         );
//         assert!(result.is_ok());
//     }

//     // ─── query_generator_parameters ──────────────────────────────────────────

//     #[test]
//     fn query_generator_parameters_no_stream_returns_err() {
//         let mut ctx = make_ctx();
//         let gen_id = GeneratorId::from(1);
//         let result = plugin_api::query_generator_parameters(&mut ctx, &gen_id);
//         assert!(result.is_err(), "Should Err when audio stream is not initialized");
//         assert!(result.unwrap_err().contains("not initialized"));
//     }

//     // ─── query_effect_parameters ─────────────────────────────────────────────

//     #[test]
//     fn query_effect_parameters_no_stream_returns_err() {
//         let mut ctx = make_ctx();
//         let effect_id = EffectId::from(1);
//         let track_id = TrackId::from(1);
//         let result = plugin_api::query_effect_parameters(
//             &mut ctx,
//             &EffectTarget::Track(track_id),
//             &effect_id,
//         );
//         assert!(result.is_err());
//     }

//     // ─── execute_plugin_command_generator ────────────────────────────────────

//     #[test]
//     fn execute_plugin_command_generator_invalid_registry_returns_none() {
//         let mut ctx = make_ctx();
//         let result = plugin_api::execute_plugin_command_generator(
//             &mut ctx,
//             0xDEADBEEF,
//             "get_state",
//             &serde_json::Value::Null,
//         );
//         assert!(result.is_none(), "Unknown registry ID should return None");
//     }

//     // ─── execute_generator_instance_command ──────────────────────────────────

//     #[test]
//     fn execute_generator_instance_command_missing_gen_returns_err() {
//         let ctx = make_ctx();
//         let bogus_id = GeneratorId::from(99999);
//         let result = plugin_api::execute_generator_instance_command(
//             &ctx,
//             &bogus_id,
//             "get_state",
//             &serde_json::Value::Null,
//         );
//         assert!(result.is_err());
//     }

//     // ─── execute_effect_instance_command ─────────────────────────────────────

//     #[test]
//     fn execute_effect_instance_command_missing_track_returns_err() {
//         let ctx = make_ctx();
//         let bogus_track = TrackId::from(99999);
//         let bogus_effect = EffectId::from(99999);
//         let result = plugin_api::execute_effect_instance_command(
//             &ctx,
//             &EffectTarget::Track(bogus_track),
//             &bogus_effect,
//             "get_state",
//             &serde_json::Value::Null,
//         );
//         assert!(result.is_err());
//     }

//     // ─── execute_plugin_command (real-time channel) ───────────────────────────

//     #[test]
//     fn execute_plugin_command_no_stream_returns_err() {
//         let mut ctx = make_ctx();
//         let target = PluginTarget::Generator(GeneratorId::from(1));
//         let result = plugin_api::execute_plugin_command(
//             &mut ctx,
//             target,
//             "ping".to_string(),
//             serde_json::Value::Null,
//         );
//         assert!(result.is_err(), "Should Err when audio stream not initialized");
//         assert!(result.unwrap_err().contains("not initialised"));
//     }

//     // ─── query_zero_copy_buffer_from_live_plugin ──────────────────────────────

//     #[test]
//     fn query_zero_copy_buffer_no_stream_returns_err() {
//         let mut ctx = make_ctx();
//         let target = PluginTarget::Generator(GeneratorId::from(1));
//         let result = plugin_api::query_zero_copy_buffer_from_live_plugin(
//             &mut ctx,
//             target,
//             "spectrum".to_string(),
//         );
//         assert!(result.is_err(), "Should Err when audio stream not initialized");
//     }
// }
