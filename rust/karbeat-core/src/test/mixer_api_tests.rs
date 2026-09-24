//! Tests for `api::mixer_api`

#[cfg(test)]
mod tests {
    use crate::api::mixer_api;
    use crate::audio::event::PluginTarget;
    use crate::commands::{AudioCommand, MixerChannelTarget};
    use crate::context::DawContext;
    use crate::core::project::automation::{
        AutomationTarget, EffectAutomationTarget, MixerChannelParamTarget, TrackAutomationTarget,
    };

    use crate::core::project::mixer::{RoutingConnection, RoutingNode};
    use crate::shared::id::{AutomationId, BusId, EffectId, TrackId};
    use crate::test::helpers::{
        make_ctx, make_seeded_ctx, param_eq_registry_id, sidechain_compressor_registry_id,
    };

    #[test]
    fn get_mixer_state_returns_default_on_empty() {
        let ctx = make_ctx();
        let _state = mixer_api::get_mixer_state(&ctx, |m| m.channels.len());
        // Just checks it doesn't panic
    }

    #[test]
    fn get_mixer_channel_missing_track_returns_err() {
        let ctx = make_ctx();
        let bogus_id = TrackId::from(99999);
        let result = mixer_api::get_mixer_channel(&ctx, bogus_id, |_c| ());
        assert!(result.is_err());
    }

    #[test]
    fn get_mixer_channel_happy_path() {
        let (ctx, audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        let result = mixer_api::get_mixer_channel(&ctx, audio_id, |c| c.mute);
        assert!(result.is_ok());
    }

    #[test]
    fn get_track_mixer_channel_specs_missing_returns_none() {
        let ctx = make_ctx();
        let bogus_id = TrackId::from(99999);
        let result: Option<Vec<_>> =
            mixer_api::get_track_mixer_channel_specs(&ctx, &bogus_id, |s| s.id);
        assert!(result.is_none());
    }

    #[test]
    fn get_track_mixer_channel_specs_happy_path() {
        let (ctx, audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        let specs: Option<Vec<_>> =
            mixer_api::get_track_mixer_channel_specs(&ctx, &audio_id, |s| s.id);
        assert!(specs.is_some());
    }

    #[test]
    fn get_bus_mixer_channel_specs_missing_returns_none() {
        let ctx = make_ctx();
        let bogus_id = BusId::from(99999);
        let result: Option<Vec<_>> =
            mixer_api::get_bus_mixer_channel_specs(&ctx, &bogus_id, |s| s.id);
        assert!(result.is_none());
    }

    #[test]
    fn get_master_channel_specs_always_returns() {
        let ctx = make_ctx();
        let specs: Vec<u32> = mixer_api::get_master_channel_specs(&ctx, |s| s.id);
        // Master bus always exists — may have 0 specs if no effects, but call succeeds
        let _ = specs; // no panic = success
    }

    #[test]
    fn get_buses_empty_on_fresh_ctx() {
        let ctx = make_ctx();
        let buses: Vec<_> = mixer_api::get_buses(&ctx, |id, _b| *id);
        assert!(buses.is_empty());
    }

    #[test]
    fn get_routing_matrix_returns_default_routes() {
        // Fresh context has no buses, tracks have default routing to master
        let (ctx, _audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        let routes: Vec<_> = mixer_api::get_routing_matrix(&ctx, |conn| conn.clone());
        // At minimum, the two tracks have default master routing
        assert!(!routes.is_empty(), "Seeded ctx should have routing entries");
    }

    #[test]
    fn create_bus_and_delete_happy_path() {
        let mut ctx = make_ctx();
        let bus_id = mixer_api::create_bus(&mut ctx, "My Bus".to_string());
        assert!(ctx.app_state.mixer.buses.contains_key(bus_id));

        let result = mixer_api::delete_bus(&mut ctx, bus_id);
        assert!(result.is_ok());
        assert!(!ctx.app_state.mixer.buses.contains_key(bus_id));
    }

    #[test]
    fn delete_bus_missing_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = BusId::from(99999);
        let result = mixer_api::delete_bus(&mut ctx, bogus_id);
        assert!(result.is_err());
    }

    #[test]
    fn rename_bus_happy_path() {
        let mut ctx = make_ctx();
        let bus_id = mixer_api::create_bus(&mut ctx, "Old Name".to_string());
        let result = mixer_api::rename_bus(&mut ctx, bus_id, "New Name");
        assert!(result.is_ok());
        let name = ctx.app_state.mixer.buses[bus_id].name.clone();
        assert_eq!(name, "New Name");
    }

    #[test]
    fn rename_bus_missing_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = BusId::from(99999);
        let result = mixer_api::rename_bus(&mut ctx, bogus_id, "Whatever");
        assert!(result.is_err());
    }

    #[test]
    fn set_routing_happy_path() {
        let (mut ctx, audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        let bus_id = mixer_api::create_bus(&mut ctx, "FX Bus".to_string());

        let conn = RoutingConnection {
            source: RoutingNode::Track(audio_id),
            destination: RoutingNode::Bus(bus_id),
            is_send: true,
            send_level: 1.0,
        };
        let result = mixer_api::set_routing(&mut ctx, conn);
        assert!(result.is_ok(), "{:?}", result.err());
    }

    #[test]
    fn remove_routing_missing_returns_err() {
        let mut ctx = make_ctx();
        let track_id = TrackId::from(1);
        let result = mixer_api::remove_routing(
            &mut ctx,
            RoutingNode::Track(track_id),
            RoutingNode::Master,
            false,
        );
        assert!(result.is_err());
    }

    #[test]
    fn add_effect_to_mixer_channel_invalid_track_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = TrackId::from(99999);
        let result = mixer_api::add_effect_to_mixer_channel_by_id(
            &mut ctx,
            bogus_id,
            param_eq_registry_id(),
        );
        assert!(result.is_err());
    }

    #[test]
    fn add_effect_to_mixer_channel_happy_path() {
        let (mut ctx, audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        let result = mixer_api::add_effect_to_mixer_channel_by_id(
            &mut ctx,
            audio_id,
            param_eq_registry_id(),
        );
        assert!(result.is_ok(), "{:?}", result.err());
        let effects_count = ctx
            .app_state
            .mixer
            .channels
            .get(audio_id)
            .map(|ch| ch.channel.effects.len())
            .unwrap_or(0);
        assert_eq!(effects_count, 1);
    }

    #[test]
    fn sidechain_compressor_is_available_in_the_default_registry() {
        let (mut ctx, audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        mixer_api::add_effect_to_mixer_channel_by_id(
            &mut ctx,
            audio_id,
            sidechain_compressor_registry_id(),
        )
        .unwrap();

        let effect = ctx.app_state.mixer.channels[audio_id]
            .channel
            .effects
            .last()
            .unwrap();
        assert_eq!(
            effect.instance.registry_id,
            sidechain_compressor_registry_id()
        );
        assert_eq!(effect.instance.name, "DigiDAW Sidechain Compressor");
    }

    #[test]
    fn remove_effect_from_mixer_channel_missing_effect_returns_err() {
        let (mut ctx, audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        let bogus_effect = EffectId::from(99999);
        let result = mixer_api::remove_effect_from_mixer_channel(&mut ctx, audio_id, bogus_effect);
        assert!(result.is_err());
    }

    #[test]
    fn remove_effect_from_mixer_channel_happy_path() {
        let (mut ctx, audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        mixer_api::add_effect_to_mixer_channel_by_id(&mut ctx, audio_id, param_eq_registry_id())
            .unwrap();
        let effect_id = ctx.app_state.mixer.channels[audio_id]
            .channel
            .effects
            .last()
            .unwrap()
            .id;
        let result = mixer_api::remove_effect_from_mixer_channel(&mut ctx, audio_id, effect_id);
        assert!(result.is_ok());
        assert!(
            ctx.app_state.mixer.channels[audio_id]
                .channel
                .effects
                .is_empty()
        );
    }

    #[test]
    fn move_effect_order_updates_the_target_chain() {
        let (mut ctx, audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        mixer_api::add_effect_to_mixer_channel_by_id(&mut ctx, audio_id, param_eq_registry_id())
            .unwrap();
        mixer_api::add_effect_to_mixer_channel_by_id(
            &mut ctx,
            audio_id,
            sidechain_compressor_registry_id(),
        )
        .unwrap();
        let second_effect_id = ctx.app_state.mixer.channels[audio_id]
            .channel
            .effects
            .iter()
            .nth(1)
            .unwrap()
            .id;

        mixer_api::move_effect_order(
            &mut ctx,
            MixerChannelTarget::Track(audio_id),
            second_effect_id,
            0,
        )
        .unwrap();

        assert_eq!(
            ctx.app_state.mixer.channels[audio_id]
                .channel
                .effects
                .iter()
                .next()
                .unwrap()
                .id,
            second_effect_id
        );
    }

    #[test]
    fn add_effect_to_master_bus_happy_path() {
        let mut ctx = make_ctx();
        let result = mixer_api::add_effect_to_master_bus(&mut ctx, param_eq_registry_id());
        assert!(result.is_ok(), "{:?}", result.err());
        assert_eq!(ctx.app_state.mixer.master_bus.effects.len(), 1);
    }

    #[test]
    fn remove_effect_from_master_bus_missing_returns_err() {
        let mut ctx = make_ctx();
        let bogus_effect = EffectId::from(99999);
        let result = mixer_api::remove_effect_from_master_bus(&mut ctx, bogus_effect);
        assert!(result.is_err());
    }

    #[test]
    fn add_effect_to_bus_missing_bus_returns_err() {
        let mut ctx = make_ctx();
        let bogus_id = BusId::from(99999);
        let result = mixer_api::add_effect_to_bus(&mut ctx, bogus_id, param_eq_registry_id());
        assert!(result.is_err());
    }

    #[test]
    fn add_effect_to_bus_happy_path() {
        let mut ctx = make_ctx();
        let bus_id = mixer_api::create_bus(&mut ctx, "FX Bus".to_string());
        let result = mixer_api::add_effect_to_bus(&mut ctx, bus_id, param_eq_registry_id());
        assert!(result.is_ok(), "{:?}", result.err());
    }

    #[test]
    fn remove_effect_from_target_mixer_channel_supports_buses() {
        let mut ctx = make_ctx();
        let bus_id = mixer_api::create_bus(&mut ctx, "FX Bus".to_string());
        mixer_api::add_effect_to_bus(&mut ctx, bus_id, param_eq_registry_id()).unwrap();
        let effect_id = ctx.app_state.mixer.buses[bus_id]
            .channel
            .effects
            .iter()
            .next()
            .unwrap()
            .id;

        mixer_api::remove_effect_from_target_mixer_channel(
            &mut ctx,
            MixerChannelTarget::Bus(bus_id),
            effect_id,
        )
        .unwrap();

        assert!(ctx.app_state.mixer.buses[bus_id].channel.effects.is_empty());
    }

    fn effect_param_target(track_id: TrackId, effect_id: EffectId) -> AutomationTarget {
        AutomationTarget::Track {
            track_id,
            track_target: TrackAutomationTarget::MixerChannel(MixerChannelParamTarget::Plugin {
                effect_id,
                target: EffectAutomationTarget::PluginParam { param_id: 0 },
            }),
        }
    }

    /// Seeds an audio track with one effect, one lane on that effect, and one volume lane.
    fn seeded_effect_automation() -> (DawContext, TrackId, EffectId, AutomationId, AutomationId) {
        let (mut ctx, audio_id, _midi_id, _pat_id) = make_seeded_ctx();
        mixer_api::add_effect_to_mixer_channel_by_id(&mut ctx, audio_id, param_eq_registry_id())
            .unwrap();
        let effect_id = ctx.app_state.mixer.channels[audio_id]
            .channel
            .effects
            .last()
            .unwrap()
            .id;
        let (effect_lane, _) = ctx
            .app_state
            .add_automation_lane(
                effect_param_target(audio_id, effect_id),
                "Gain",
                0.0,
                1.0,
                0.5,
            )
            .unwrap();
        let (volume_lane, _) = ctx
            .app_state
            .add_automation_lane(
                AutomationTarget::Track {
                    track_id: audio_id,
                    track_target: TrackAutomationTarget::MixerChannel(
                        MixerChannelParamTarget::Volume,
                    ),
                },
                "Volume",
                0.0,
                1.0,
                0.5,
            )
            .unwrap();
        (ctx, audio_id, effect_id, effect_lane.id, volume_lane.id)
    }

    #[test]
    fn removing_an_effect_removes_only_its_automation() {
        let (mut ctx, audio_id, effect_id, effect_lane, volume_lane) = seeded_effect_automation();

        let removed =
            mixer_api::remove_effect_from_mixer_channel(&mut ctx, audio_id, effect_id).unwrap();

        assert_eq!(removed.automation_lanes, vec![effect_lane]);
        assert_eq!(removed.modulation_sources.len(), 1);
        assert_eq!(removed.modulation_links.len(), 1);
        let app = &ctx.app_state;
        assert!(app.automation_pool.get(effect_lane).is_none());
        assert!(
            app.modulation_sources
                .get(removed.modulation_sources[0])
                .is_none()
        );
        assert!(
            app.modulation_links
                .get(removed.modulation_links[0])
                .is_none()
        );
        assert!(app.automation_pool.get(volume_lane).is_some());
        assert_eq!(app.modulation_links.len(), 1);
        assert!(
            app.modulation_links
                .values()
                .all(|link| link.order_idx == 0)
        );
    }

    #[test]
    fn rejected_effect_removal_leaves_effect_and_automation_intact() {
        let (mut ctx, audio_id, effect_id, effect_lane, _) = seeded_effect_automation();
        let (mut producer, _consumer) = rtrb::RingBuffer::<AudioCommand>::new(1);
        producer.push(AudioCommand::SetBPM(120.0)).unwrap();
        *ctx.command_sender.lock() = Some(producer);
        let links_before = ctx.app_state.modulation_links.len();

        let result = mixer_api::remove_effect_from_mixer_channel(&mut ctx, audio_id, effect_id);

        assert!(result.is_err());
        let app = &ctx.app_state;
        assert!(
            app.mixer.channels[audio_id]
                .channel
                .effects
                .get(effect_id)
                .is_some()
        );
        assert!(app.automation_pool.get(effect_lane).is_some());
        assert_eq!(app.modulation_links.len(), links_before);
    }

    #[test]
    fn effect_removal_reaches_the_engine_as_one_command() {
        let (mut ctx, audio_id, effect_id, _, _) = seeded_effect_automation();
        let (producer, mut consumer) = rtrb::RingBuffer::<AudioCommand>::new(8);
        *ctx.command_sender.lock() = Some(producer);

        mixer_api::remove_effect_from_mixer_channel(&mut ctx, audio_id, effect_id).unwrap();

        assert!(matches!(
            consumer.pop(),
            Ok(AudioCommand::RemoveEffect { effect_id: removed, .. }) if removed == effect_id
        ));
        assert!(consumer.pop().is_err());
    }

    #[test]
    fn get_master_bus_populated_empty() {
        let ctx = make_ctx();
        let effects: Vec<u32> = mixer_api::get_master_bus_populated(&ctx, |e| e.id.to_u32());
        assert!(effects.is_empty());
    }

    #[test]
    fn sidechain_sources_exclude_the_effect_owner_and_support_crud() {
        let (mut ctx, target_track, source_track, _pat_id) = make_seeded_ctx();
        mixer_api::add_effect_to_mixer_channel_by_id(
            &mut ctx,
            target_track,
            param_eq_registry_id(),
        )
        .unwrap();
        let effect_id = ctx.app_state.mixer.channels[target_track]
            .channel
            .effects
            .last()
            .unwrap()
            .id;
        let target = PluginTarget::TrackEffect(target_track, effect_id);

        let sources = mixer_api::get_sidechain_sources(&ctx, target);
        assert!(
            sources
                .iter()
                .any(|item| item.source == RoutingNode::Track(source_track))
        );
        assert!(
            !sources
                .iter()
                .any(|item| item.source == RoutingNode::Track(target_track))
        );

        mixer_api::set_sidechain_source(
            &mut ctx,
            target,
            RoutingNode::Track(source_track),
            Some(0.5),
        )
        .unwrap();
        let sources = mixer_api::get_sidechain_sources(&ctx, target);
        let source = sources
            .iter()
            .find(|item| item.source == RoutingNode::Track(source_track))
            .unwrap();
        assert_eq!(source.send_level, Some(0.5));

        mixer_api::set_sidechain_source(
            &mut ctx,
            target,
            RoutingNode::Track(source_track),
            Some(0.25),
        )
        .unwrap();
        let matching_routes = ctx
            .app_state
            .mixer
            .routing
            .iter()
            .filter(|connection| {
                connection.source == RoutingNode::Track(source_track)
                    && matches!(connection.destination, RoutingNode::PluginSidechain(_))
            })
            .collect::<Vec<_>>();
        assert_eq!(matching_routes.len(), 1);
        assert_eq!(matching_routes[0].send_level, 0.25);

        mixer_api::set_sidechain_source(&mut ctx, target, RoutingNode::Track(source_track), None)
            .unwrap();
        assert!(!ctx.app_state.mixer.routing.iter().any(|connection| {
            connection.source == RoutingNode::Track(source_track)
                && matches!(connection.destination, RoutingNode::PluginSidechain(_))
        }));
    }

    #[test]
    fn sidechain_sources_reject_self_routes_and_feedback_cycles() {
        let (mut ctx, target_track, _source_track, _pat_id) = make_seeded_ctx();
        mixer_api::add_effect_to_mixer_channel_by_id(
            &mut ctx,
            target_track,
            param_eq_registry_id(),
        )
        .unwrap();
        let effect_id = ctx.app_state.mixer.channels[target_track]
            .channel
            .effects
            .last()
            .unwrap()
            .id;
        let target = PluginTarget::TrackEffect(target_track, effect_id);

        assert!(
            mixer_api::set_sidechain_source(
                &mut ctx,
                target,
                RoutingNode::Track(target_track),
                Some(1.0),
            )
            .is_err()
        );

        let bus_id = mixer_api::create_bus(&mut ctx, "Downstream Bus".to_string());
        mixer_api::set_routing(
            &mut ctx,
            RoutingConnection::new_send(
                RoutingNode::Track(target_track),
                RoutingNode::Bus(bus_id),
                1.0,
            ),
        )
        .unwrap();

        assert!(
            !mixer_api::get_sidechain_sources(&ctx, target)
                .iter()
                .any(|item| item.source == RoutingNode::Bus(bus_id))
        );
        assert!(
            mixer_api::set_sidechain_source(&mut ctx, target, RoutingNode::Bus(bus_id), Some(1.0),)
                .is_err()
        );
    }
}
