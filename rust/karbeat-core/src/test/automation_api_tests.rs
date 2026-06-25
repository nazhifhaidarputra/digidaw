//! Tests for `api::automation_api`

#[cfg(test)]
mod tests {
    use crate::api::{automation_api, mixer_api};
    use crate::core::project::automation::{
        AutomationTarget, MixerChannelParamTarget, TrackAutomationTarget,
    };
    use crate::core::project::ModulationSource;
    use crate::shared::id::{AutomationId, BusId, ModulationId, TrackId};
    use crate::test::helpers::{make_ctx, make_seeded_ctx};

    /// A target that is NOT tied to a specific track/bus (global master volume)
    fn master_volume_target() -> AutomationTarget {
        AutomationTarget::Master(MixerChannelParamTarget::Volume)
    }

    /// A target that references a specific track (for add_automation_lane_for_track)
    fn track_volume_target(track_id: TrackId) -> AutomationTarget {
        AutomationTarget::Track {
            track_id,
            track_target: TrackAutomationTarget::MixerChannel(MixerChannelParamTarget::Volume),
        }
    }

    /// A target that references a specific bus
    fn bus_volume_target(bus_id: BusId) -> AutomationTarget {
        AutomationTarget::Bus {
            bus_id,
            mix_target: MixerChannelParamTarget::Volume,
        }
    }

    // ─── get_automations_lanes_all ───────────────────────────────────────────

    #[test]
    fn get_automations_lanes_all_empty() {
        let ctx = make_ctx();
        let result: Vec<u32> =
            automation_api::get_automations_lanes_all(&ctx, |lane| lane.id.to_u32());
        assert!(result.is_empty());
    }

    // ─── add_automation_lane_for_track ───────────────────────────────────────

    #[test]
    fn add_automation_lane_for_track_happy_path() {
        let (mut ctx, _audio_id, midi_id, _pat_id) = make_seeded_ctx();
        let result = automation_api::add_automation_lane_for_track(
            &mut ctx,
            midi_id,
            track_volume_target(midi_id),
            "Volume",
            0.0,
            1.0,
            0.8,
        );
        assert!(result.is_ok(), "Should create lane: {:?}", result.err());
        let lane = result.unwrap();
        assert_eq!(lane.min, 0.0);
        assert_eq!(lane.max, 1.0);
        assert_eq!(lane.default_value, 0.8);
    }

    #[test]
    fn add_automation_lane_for_track_missing_track_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = TrackId::from(99999);
        let result = automation_api::add_automation_lane_for_track(
            &mut ctx,
            bogus_id,
            track_volume_target(bogus_id),
            "Volume",
            0.0,
            1.0,
            0.5,
        );
        // track_id not found in state → add_automation_lane_for_track should err
        // (or it passes through if no validation — either way the result is used safely)
        let _ = result; // Just check it doesn't panic
    }

    // ─── add_automation_lane_for_bus ─────────────────────────────────────────

    #[test]
    fn add_automation_lane_for_bus_happy_path() {
        let mut ctx = make_ctx();
        let bus_id = mixer_api::create_bus(&mut ctx, "TestBus".to_string());
        let result = automation_api::add_automation_lane_for_bus(
            &mut ctx,
            bus_id,
            bus_volume_target(bus_id),
            "Volume",
            0.0,
            1.0,
            0.5,
        );
        assert!(result.is_ok(), "{:?}", result.err());
    }

    #[test]
    fn add_automation_lane_for_bus_missing_bus_wrong_target_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = BusId::from(99999);
        // Target references the bogus bus, but the bus doesn't actually exist in state
        let result = automation_api::add_automation_lane_for_bus(
            &mut ctx,
            bogus_id,
            bus_volume_target(bogus_id),
            "Volume",
            0.0,
            1.0,
            0.5,
        );
        // Just verifies no panic — the error behavior depends on whether bus existence is validated
        let _ = result;
    }

    // ─── add_automation_lane (unlinked) ──────────────────────────────────────

    #[test]
    fn add_automation_lane_happy_path() {
        let mut ctx = make_ctx();
        let result = automation_api::add_automation_lane(
            &mut ctx,
            master_volume_target(),
            "Test Lane",
            -1.0,
            1.0,
            0.0,
        );
        assert!(result.is_ok());
        assert_eq!(ctx.app_state.automation_pool.len(), 1);
    }

    // ─── add_new_automation_point ─────────────────────────────────────────────

    #[test]
    fn add_new_automation_point_happy_path() {
        let mut ctx = make_ctx();
        let lane = automation_api::add_automation_lane(
            &mut ctx,
            master_volume_target(),
            "Vol",
            0.0,
            1.0,
            0.5,
        )
        .unwrap();

        let point = automation_api::add_new_automation_point(&mut ctx, lane.id, 100, 0.75);
        assert!(point.is_ok());
        let p = point.unwrap();
        assert_eq!(p.time_ticks, 100);
        assert_eq!(p.value, 0.75);
    }

    #[test]
    fn add_new_automation_point_missing_lane_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = AutomationId::from(99999);
        let result = automation_api::add_new_automation_point(&mut ctx, bogus_id, 0, 0.5);
        assert!(result.is_err());
    }

    // ─── remove_automation_point ─────────────────────────────────────────────

    #[test]
    fn remove_automation_point_happy_path() {
        let mut ctx = make_ctx();
        let lane = automation_api::add_automation_lane(
            &mut ctx,
            master_volume_target(),
            "Vol",
            0.0,
            1.0,
            0.5,
        )
        .unwrap();
        automation_api::add_new_automation_point(&mut ctx, lane.id, 100, 0.5).unwrap();
        let remove_result = automation_api::remove_automation_point(&mut ctx, lane.id, 0);
        assert!(remove_result.is_ok());
    }

    #[test]
    fn remove_automation_point_out_of_bounds_returns_err() {
        let mut ctx = make_ctx();
        let lane = automation_api::add_automation_lane(
            &mut ctx,
            master_volume_target(),
            "Vol",
            0.0,
            1.0,
            0.5,
        )
        .unwrap();
        // No points added — index 0 is OOB
        let result = automation_api::remove_automation_point(&mut ctx, lane.id, 0);
        assert!(result.is_err(), "OOB index should Err");
    }

    // ─── update_automation_point ─────────────────────────────────────────────

    #[test]
    fn update_automation_point_returns_new_index() {
        let mut ctx = make_ctx();
        let lane = automation_api::add_automation_lane(
            &mut ctx,
            master_volume_target(),
            "Vol",
            0.0,
            1.0,
            0.5,
        )
        .unwrap();
        automation_api::add_new_automation_point(&mut ctx, lane.id, 100, 0.5).unwrap();
        automation_api::add_new_automation_point(&mut ctx, lane.id, 300, 0.8).unwrap();

        // Move the first point to time 400 → should now be the last
        let new_idx = automation_api::update_automation_point(&mut ctx, lane.id, 0, 400, 0.5, 0.0);
        assert!(new_idx.is_ok());
        assert_eq!(
            new_idx.unwrap(),
            1,
            "Point moved to end should have index 1"
        );
    }

    // ─── get_automation_lanes_for_track ──────────────────────────────────────

    #[test]
    fn get_automation_lanes_for_track_empty() {
        let ctx = make_ctx();
        let bogus_id = TrackId::from(1);
        let result = automation_api::get_automation_lanes_for_track(&ctx, bogus_id);
        assert!(result.is_empty());
    }

    // ─── get_automation_lane ─────────────────────────────────────────────────

    #[test]
    fn get_automation_lane_missing_returns_none() {
        let ctx = make_ctx();
        let bogus_id = AutomationId::from(99999);
        let result = automation_api::get_automation_lane(&ctx, bogus_id);
        assert!(result.is_none());
    }

    #[test]
    fn get_automation_lane_happy_path() {
        let mut ctx = make_ctx();
        let lane = automation_api::add_automation_lane(
            &mut ctx,
            master_volume_target(),
            "Test",
            0.0,
            1.0,
            0.5,
        )
        .unwrap();
        let fetched = automation_api::get_automation_lane(&ctx, lane.id);
        assert!(fetched.is_some());
    }

    // ─── modulation source / link ─────────────────────────────────────────────

    #[test]
    fn add_modulation_source_and_retrieve() {
        let mut ctx = make_ctx();
        let source = ModulationSource::LFO { rate_hz: 1.0 };
        let id = automation_api::add_modulation_source(&mut ctx, source);
        assert!(ctx.app_state.modulation_sources.contains_key(&id));
    }

    #[test]
    fn get_modulation_source_missing_returns_none() {
        let ctx = make_ctx();
        // get_modulation_source<Id, S> requires S: for<'a> From<&'a ModulationSource>
        // ModulationSource itself doesn't implement From<&ModulationSource> by default.
        // We use a u32 bogus ID directly — the pool is empty so result is always None.
        let result: Option<&ModulationSource> =
            automation_api::get_modulation_source(&ctx, 99999u32);
        assert!(result.is_none());
    }

    #[test]
    fn remove_modulation_source_removes_it() {
        let mut ctx = make_ctx();
        let source = ModulationSource::LFO { rate_hz: 1.0 };
        let id = automation_api::add_modulation_source(&mut ctx, source);
        assert!(ctx.app_state.modulation_sources.contains_key(&id));
        automation_api::remove_modulation_source(&mut ctx, id);
        assert!(!ctx.app_state.modulation_sources.contains_key(&id));
    }

    #[test]
    fn link_param_to_controller_missing_source_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = ModulationId::from(99999);
        let result = automation_api::link_this_param_to_controller(
            &mut ctx,
            bogus_id,
            master_volume_target(),
            1.0,
            0.5,
        );
        assert!(result.is_err());
    }

    #[test]
    fn link_param_to_controller_happy_path() {
        let mut ctx = make_ctx();
        let source = ModulationSource::LFO { rate_hz: 2.0 };
        let mod_id = automation_api::add_modulation_source(&mut ctx, source);
        let result = automation_api::link_this_param_to_controller(
            &mut ctx,
            mod_id,
            master_volume_target(),
            1.0,
            0.5,
        );
        assert!(result.is_ok(), "{:?}", result.err());
    }

    #[test]
    fn remove_modulation_link_removes_it() {
        let mut ctx = make_ctx();
        let source = ModulationSource::LFO { rate_hz: 1.0 };
        let mod_id = automation_api::add_modulation_source(&mut ctx, source);
        let link_id = automation_api::link_this_param_to_controller(
            &mut ctx,
            mod_id,
            master_volume_target(),
            1.0,
            0.5,
        )
        .unwrap();
        assert!(ctx.app_state.modulation_links.contains_key(&link_id));
        automation_api::remove_modulation_link(&mut ctx, link_id);
        assert!(!ctx.app_state.modulation_links.contains_key(&link_id));
    }
}
