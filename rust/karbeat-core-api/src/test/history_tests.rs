//! Round-trip tests for undoable API edits.

#[cfg(test)]
mod tests {
    use std::fmt::Debug;

    use karbeat_utils::types::NormalizedF64;

    use crate as api;
    use crate::test::helpers::make_seeded_ctx;
    use crate::test::helpers::{karbeatzer_v2_registry_id, param_eq_registry_id};
    use crate::{
        automation_api, clip_api, mixer_api, note_api, pattern_api, project_api, track_api,
        transport_api,
    };
    use karbeat_core::commands::{EffectTarget, MixerChannelTarget};
    use karbeat_core::context::DawContext;
    use karbeat_core::core::history::PluginSync;
    use karbeat_core::core::project::{
        AutomationLane, ModulationSource,
        automation::{
            AutomationTarget, EffectAutomationTarget, MixerChannelParamTarget,
            TrackAutomationTarget,
        },
        mixer::{RoutingConnection, RoutingNode},
    };
    use karbeat_core::shared::id::{BusId, ClipId, EffectId, GeneratorId, GraphNodeId, TrackId};

    /// Applies `edit`, then checks that undo restores `observe`'s original value and redo the
    /// edited one, twice, through the public undo/redo API.
    fn assert_round_trip<T: PartialEq + Debug>(
        ctx: &mut DawContext,
        label: &str,
        edit: impl FnOnce(&mut DawContext),
        observe: impl Fn(&DawContext) -> T,
    ) {
        let original = observe(ctx);
        edit(ctx);
        let edited = observe(ctx);
        assert_ne!(original, edited, "{label}: the edit changed nothing");
        assert_eq!(ctx.history.undo_label(), Some(label));

        for _ in 0..2 {
            api::undo(ctx).expect("undo");
            assert_eq!(observe(ctx), original, "{label}: undo");
            api::redo(ctx).expect("redo");
            assert_eq!(observe(ctx), edited, "{label}: redo");
        }
    }

    #[test]
    fn track_name_color_and_order_round_trip() {
        let (mut ctx, audio, midi, _) = make_seeded_ctx();

        assert_round_trip(
            &mut ctx,
            "Rename Track",
            |ctx| track_api::change_track_name(ctx, audio, "Drums").expect("rename"),
            |ctx| ctx.app_state.tracks[audio].name.clone(),
        );
        assert_round_trip(
            &mut ctx,
            "Change Track Color",
            |ctx| track_api::change_track_color(ctx, audio, "#FF0000").expect("color"),
            |ctx| ctx.app_state.tracks[audio].color.to_string(),
        );
        assert_round_trip(
            &mut ctx,
            "Reorder Tracks",
            |ctx| track_api::update_track_order(ctx, audio, 1).expect("reorder"),
            |ctx| {
                (
                    ctx.app_state.tracks[audio].order_idx,
                    ctx.app_state.tracks[midi].order_idx,
                )
            },
        );
    }

    #[test]
    fn pattern_and_clip_renames_round_trip() {
        let (mut ctx, _, midi, pattern) = make_seeded_ctx();
        let clip = ctx.app_state.tracks[midi].clips[0];

        assert_round_trip(
            &mut ctx,
            "Rename Pattern",
            |ctx| pattern_api::rename_pattern(ctx, pattern, "Hook").expect("rename pattern"),
            |ctx| {
                (
                    ctx.app_state.pattern_pool[pattern].name.clone(),
                    ctx.app_state.clips_pool[clip].name.clone(),
                )
            },
        );
        assert_round_trip(
            &mut ctx,
            "Rename Clip",
            |ctx| clip_api::rename_clip(ctx, clip, "Verse").expect("rename clip"),
            |ctx| ctx.app_state.clips_pool[clip].name.clone(),
        );
    }

    #[test]
    fn bus_name_and_color_round_trip() {
        let (mut ctx, ..) = make_seeded_ctx();
        let bus = mixer_api::create_bus(&mut ctx, "Reverb".into());

        assert_round_trip(
            &mut ctx,
            "Rename Bus",
            |ctx| mixer_api::rename_bus(ctx, bus, "Delay").expect("rename bus"),
            |ctx| ctx.app_state.mixer.buses[bus].name.clone(),
        );
        assert_round_trip(
            &mut ctx,
            "Change Bus Color",
            |ctx| mixer_api::change_bus_color(ctx, bus, "#00FF00").expect("bus color"),
            |ctx| ctx.app_state.mixer.buses[bus].color.to_string(),
        );
    }

    #[test]
    fn tempo_drag_undoes_in_one_step() {
        let (mut ctx, ..) = make_seeded_ctx();
        let original = ctx.app_state.transport.bpm;
        for bpm in [121.0, 122.0, 123.0, 124.0] {
            transport_api::set_bpm(&mut ctx, bpm);
        }
        let depth = ctx.history.undo_stack.len();

        api::undo(&mut ctx).expect("undo drag");
        assert_eq!(ctx.app_state.transport.bpm, original);
        api::redo(&mut ctx).expect("redo drag");
        assert_eq!(ctx.app_state.transport.bpm, 124.0);
        assert_eq!(ctx.history.undo_stack.len(), depth);
    }

    #[test]
    fn metadata_round_trips() {
        let (mut ctx, ..) = make_seeded_ctx();
        assert_round_trip(
            &mut ctx,
            "Edit Project Information",
            |ctx| {
                let mut metadata = ctx.app_state.metadata.clone();
                metadata.name = "Renamed".into();
                metadata.genre = "House".into();
                project_api::update_project_metadata(ctx, metadata).expect("metadata");
            },
            |ctx| {
                (
                    ctx.app_state.metadata.name.clone(),
                    ctx.app_state.metadata.genre.clone(),
                )
            },
        );
    }

    fn volume_target(track: karbeat_core::shared::TrackId) -> AutomationTarget {
        AutomationTarget::Track {
            track_id: track,
            track_target: TrackAutomationTarget::MixerChannel(MixerChannelParamTarget::Volume),
        }
    }

    /// Lanes, sources, and links with their keys, for comparing whole automation states.
    fn automation_state(ctx: &DawContext) -> AutomationSnapshot {
        let mut lanes: Vec<_> = ctx
            .app_state
            .automation_pool
            .iter()
            .map(|(id, lane)| (id, lane.clone()))
            .collect();
        lanes.sort_by_key(|(id, _)| *id);
        let mut sources: Vec<_> = ctx
            .app_state
            .modulation_sources
            .iter()
            .map(|(id, source)| (id, source.clone()))
            .collect();
        sources.sort_by_key(|(id, _)| *id);
        let mut links: Vec<_> = ctx
            .app_state
            .modulation_links
            .iter()
            .map(|(id, link)| (id, link.clone()))
            .collect();
        links.sort_by_key(|(id, _)| *id);
        (lanes, sources, links)
    }

    type AutomationSnapshot = (
        Vec<(karbeat_core::shared::AutomationId, AutomationLane)>,
        Vec<(karbeat_core::shared::ModulationId, ModulationSource)>,
        Vec<(
            karbeat_core::shared::ModulationLinkId,
            karbeat_core::core::project::ModulationLinkForOrderedLaneView,
        )>,
    );

    #[test]
    fn automation_lane_lifecycle_round_trips_with_stable_keys() {
        let (mut ctx, audio, ..) = make_seeded_ctx();

        assert_round_trip(
            &mut ctx,
            "Add Automation Lane",
            |ctx| {
                automation_api::add_automation_lane_for_track(
                    ctx,
                    audio,
                    volume_target(audio),
                    "Volume",
                    0.0,
                    1.0,
                    0.5,
                )
                .expect("add lane");
            },
            automation_state,
        );
        let lane = *ctx
            .app_state
            .automation_pool
            .keys()
            .collect::<Vec<_>>()
            .first()
            .expect("lane");

        assert_round_trip(
            &mut ctx,
            "Add Automation Point",
            |ctx| {
                automation_api::add_new_automation_point(ctx, lane, 480, NormalizedF64::new(0.8))
                    .expect("add point");
            },
            automation_state,
        );
        let point = ctx.app_state.automation_pool[lane]
            .points
            .iter()
            .find(|point| point.time_ticks == 480)
            .expect("point")
            .id
            .to_u64();

        assert_round_trip(
            &mut ctx,
            "Edit Automation Point",
            |ctx| {
                automation_api::update_automation_point(
                    ctx,
                    lane,
                    point,
                    Some(960),
                    Some(NormalizedF64::new(0.2)),
                    None,
                    None,
                )
                .expect("edit point");
            },
            automation_state,
        );
        assert_round_trip(
            &mut ctx,
            "Toggle Automation Lane",
            |ctx| {
                let enabled = ctx.app_state.automation_pool[lane].enabled;
                automation_api::set_automation_lane_enabled(ctx, lane, !enabled).expect("toggle");
            },
            automation_state,
        );
        assert_round_trip(
            &mut ctx,
            "Remove Automation Point",
            |ctx| {
                automation_api::remove_automation_point(ctx, lane, point).expect("remove point");
            },
            automation_state,
        );
        assert_round_trip(
            &mut ctx,
            "Remove Automation Lane",
            |ctx| {
                automation_api::remove_automation_lane(ctx, volume_target(audio))
                    .expect("remove lane");
            },
            automation_state,
        );
    }

    #[test]
    fn modulation_sources_and_links_round_trip() {
        let (mut ctx, audio, ..) = make_seeded_ctx();
        assert_round_trip(
            &mut ctx,
            "Add Modulation Source",
            |ctx| {
                automation_api::add_modulation_source(ctx, ModulationSource::LFO { rate_hz: 2.0 });
            },
            automation_state,
        );
        let source = *ctx
            .app_state
            .modulation_sources
            .keys()
            .collect::<Vec<_>>()
            .first()
            .expect("source");

        assert_round_trip(
            &mut ctx,
            "Link Modulation",
            |ctx| {
                automation_api::link_this_param_to_controller(
                    ctx,
                    source,
                    volume_target(audio),
                    0.5,
                    0.5,
                )
                .expect("link");
            },
            automation_state,
        );
        assert_round_trip(
            &mut ctx,
            "Remove Modulation Source",
            |ctx| automation_api::remove_modulation_source(ctx, source),
            automation_state,
        );
    }

    /// Everything a structural edit can touch, with keys, for exact before/after comparison.
    #[derive(Debug, PartialEq)]
    struct StructureSnapshot {
        tracks: Vec<(TrackId, String, usize, Vec<ClipId>)>,
        clips: Vec<ClipId>,
        generators: Vec<GeneratorId>,
        channels: Vec<(TrackId, Vec<(EffectId, bool)>)>,
        buses: Vec<(BusId, String, Vec<EffectId>)>,
        master: Vec<EffectId>,
        graph_nodes: Vec<(GraphNodeId, RoutingNode)>,
        routing: Vec<(RoutingNode, RoutingNode, bool)>,
        automation: AutomationSnapshot,
    }

    fn structure(ctx: &DawContext) -> StructureSnapshot {
        let app = &ctx.app_state;
        let mut tracks: Vec<_> = app
            .tracks
            .iter()
            .map(|(id, t)| (id, t.name.clone(), t.order_idx, t.clips.clone()))
            .collect();
        tracks.sort_by_key(|t| t.0);
        let mut clips: Vec<_> = app.clips_pool.keys().collect();
        clips.sort();
        let mut generators: Vec<_> = app.generator_pool.keys().collect();
        generators.sort();
        let mut channels: Vec<_> = app
            .mixer
            .channels
            .iter()
            .map(|(id, c)| {
                (
                    id,
                    c.channel
                        .effects
                        .iter()
                        .map(|e| (e.id, e.instance.bypass))
                        .collect(),
                )
            })
            .collect();
        channels.sort_by_key(|c| c.0);
        let mut buses: Vec<_> = app
            .mixer
            .buses
            .iter()
            .map(|(id, b)| {
                (
                    id,
                    b.name.clone(),
                    b.channel.effects.iter().map(|e| e.id).collect(),
                )
            })
            .collect();
        buses.sort_by_key(|b| b.0);
        let mut graph_nodes: Vec<_> = app.mixer.graph_nodes.iter().map(|(k, n)| (k, *n)).collect();
        graph_nodes.sort_by_key(|n| n.0);
        StructureSnapshot {
            tracks,
            clips,
            generators,
            channels,
            buses,
            master: app.mixer.master_bus.effects.iter().map(|e| e.id).collect(),
            graph_nodes,
            routing: app
                .mixer
                .routing
                .iter()
                .map(|c| (c.source, c.destination, c.is_send))
                .collect(),
            automation: automation_state(ctx),
        }
    }

    #[test]
    fn adding_tracks_round_trips_with_stable_keys() {
        let (mut ctx, ..) = make_seeded_ctx();
        assert_round_trip(
            &mut ctx,
            "Add Audio Track",
            |ctx| {
                track_api::add_new_audio_track(ctx);
            },
            structure,
        );
        assert_round_trip(
            &mut ctx,
            "Add Instrument Track",
            |ctx| {
                track_api::add_midi_track_with_generator_id(ctx, karbeatzer_v2_registry_id())
                    .expect("instrument track");
            },
            structure,
        );
    }

    #[test]
    fn deleting_a_track_restores_clips_effects_automation_and_routing() {
        let (mut ctx, audio, midi, pattern) = make_seeded_ctx();
        mixer_api::add_effect_to_mixer_channel_by_id(&mut ctx, midi, param_eq_registry_id())
            .expect("effect");
        automation_api::add_automation_lane_for_track(
            &mut ctx,
            midi,
            volume_target(midi),
            "Volume",
            0.0,
            1.0,
            0.5,
        )
        .expect("lane");
        let bus = mixer_api::create_bus(&mut ctx, "Reverb".into());
        mixer_api::set_routing(
            &mut ctx,
            RoutingConnection::new_send(RoutingNode::Track(midi), RoutingNode::Bus(bus), 0.5),
        )
        .expect("send");
        let _ = audio;

        assert_round_trip(
            &mut ctx,
            "Delete Track",
            |ctx| {
                track_api::delete_track(ctx, midi).expect("delete track");
            },
            structure,
        );

        // Earlier history entries still apply to the restored track's pattern.
        api::undo(&mut ctx).expect("undo delete");
        note_api::add_note(&mut ctx, pattern, 72, 3840, Some(480)).expect("note");
        api::undo(&mut ctx).expect("undo note");
        assert!(
            !ctx.app_state.pattern_pool[pattern]
                .notes
                .iter()
                .any(|note| note.start_tick == 3840)
        );
    }

    #[test]
    fn undoing_a_track_delete_reinstalls_its_plugins() {
        let (mut ctx, _, midi, _) = make_seeded_ctx();
        mixer_api::add_effect_to_mixer_channel_by_id(&mut ctx, midi, param_eq_registry_id())
            .expect("effect");
        let generator = ctx.app_state.tracks[midi]
            .generator
            .as_ref()
            .expect("generator")
            .id;
        let effect = ctx.app_state.mixer.channels[midi]
            .channel
            .effects
            .last()
            .expect("effect")
            .id;
        track_api::delete_track(&mut ctx, midi).expect("delete track");

        let sync = ctx.history.undo(&mut ctx.app_state).expect("undo");
        assert!(sync.full_graph);
        assert!(sync.plugins.contains(&PluginSync::InstallGenerator {
            generator_id: generator,
            track_id: midi,
        }));
        assert!(sync.plugins.contains(&PluginSync::InstallEffect {
            target: EffectTarget::Track(midi),
            effect_id: effect,
        }));

        let sync = ctx.history.redo(&mut ctx.app_state).expect("redo");
        assert!(sync.plugins.contains(&PluginSync::RemoveGenerator {
            generator_id: generator,
        }));
    }

    #[test]
    fn buses_round_trip() {
        let (mut ctx, ..) = make_seeded_ctx();
        assert_round_trip(
            &mut ctx,
            "Create Bus",
            |ctx| {
                mixer_api::create_bus(ctx, "Reverb".into());
            },
            structure,
        );
        let bus = *ctx
            .app_state
            .mixer
            .buses
            .keys()
            .collect::<Vec<_>>()
            .first()
            .expect("bus");
        mixer_api::add_effect_to_bus(&mut ctx, bus, param_eq_registry_id()).expect("bus effect");
        assert_round_trip(
            &mut ctx,
            "Delete Bus",
            |ctx| mixer_api::delete_bus(ctx, bus).expect("delete bus"),
            structure,
        );
    }

    #[test]
    fn effects_round_trip() {
        let (mut ctx, audio, ..) = make_seeded_ctx();
        // Bypass changes are only accepted with an engine queue attached.
        let (producer, _engine) =
            rtrb::RingBuffer::<karbeat_core::commands::AudioCommand>::new(4096);
        *ctx.command_sender.lock() = Some(producer);
        let target = MixerChannelTarget::Track(audio);
        assert_round_trip(
            &mut ctx,
            "Add Effect",
            |ctx| {
                mixer_api::add_effect_to_mixer_channel_by_id(ctx, audio, param_eq_registry_id())
                    .expect("add effect");
            },
            structure,
        );
        mixer_api::add_effect_to_mixer_channel_by_id(&mut ctx, audio, param_eq_registry_id())
            .expect("second effect");
        let effects: Vec<_> = ctx.app_state.mixer.channels[audio]
            .channel
            .effects
            .iter()
            .map(|e| e.id)
            .collect();

        assert_round_trip(
            &mut ctx,
            "Move Effect",
            |ctx| mixer_api::move_effect_order(ctx, target.clone(), effects[1], 0).expect("move"),
            structure,
        );
        assert_round_trip(
            &mut ctx,
            "Bypass Effect",
            |ctx| {
                mixer_api::set_effect_bypass(ctx, target.clone(), effects[0], true)
                    .expect("bypass");
            },
            structure,
        );
        automation_api::add_automation_lane(
            &mut ctx,
            AutomationTarget::Track {
                track_id: audio,
                track_target: TrackAutomationTarget::MixerChannel(
                    MixerChannelParamTarget::Plugin {
                        effect_id: effects[0],
                        target: EffectAutomationTarget::PluginParam { param_id: 0 },
                    },
                ),
            },
            "Gain",
            0.0,
            1.0,
            0.5,
        )
        .expect("effect lane");
        assert_round_trip(
            &mut ctx,
            "Remove Effect",
            |ctx| {
                mixer_api::remove_effect_from_target_mixer_channel(ctx, target.clone(), effects[0])
                    .expect("remove effect");
            },
            structure,
        );
    }

    #[test]
    fn routing_round_trips() {
        let (mut ctx, audio, ..) = make_seeded_ctx();
        let bus = mixer_api::create_bus(&mut ctx, "Reverb".into());
        assert_round_trip(
            &mut ctx,
            "Add Route",
            |ctx| {
                mixer_api::set_routing(
                    ctx,
                    RoutingConnection::new_send(
                        RoutingNode::Track(audio),
                        RoutingNode::Bus(bus),
                        0.7,
                    ),
                )
                .expect("route");
            },
            structure,
        );
        assert_round_trip(
            &mut ctx,
            "Remove Route",
            |ctx| {
                mixer_api::remove_routing(
                    ctx,
                    RoutingNode::Track(audio),
                    RoutingNode::Bus(bus),
                    true,
                )
                .expect("remove route");
            },
            structure,
        );
    }

    #[test]
    fn replacing_the_project_clears_history() {
        let (mut ctx, audio, ..) = make_seeded_ctx();
        track_api::change_track_name(&mut ctx, audio, "Drums").expect("rename");
        assert!(ctx.history.undo_label().is_some());

        project_api::new_blank_project(&mut ctx).expect("new project");

        assert!(ctx.history.undo_stack.is_empty());
        assert!(api::undo(&mut ctx).is_err());
    }
}
