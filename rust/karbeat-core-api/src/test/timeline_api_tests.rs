//! Tests for `timeline_api`

#[cfg(test)]
mod tests {
    use crate::test::helpers::make_ctx;
    use crate::{redo, timeline_api, undo};
    use karbeat_core::core::project::LoopRegion;

    #[test]
    fn loop_region_is_validated_and_undoable() {
        let mut ctx = make_ctx();
        assert!(timeline_api::set_loop_region(&mut ctx, Some((960, 960))).is_err());
        assert!(ctx.app_state.timeline.loop_region.is_none());

        timeline_api::set_loop_region(&mut ctx, Some((960, 3_840))).unwrap();
        assert_eq!(
            ctx.app_state.timeline.loop_region,
            Some(LoopRegion::new(960, 3_840).unwrap())
        );
        assert!(!ctx.app_state.session.is_saved());

        undo(&mut ctx).unwrap();
        assert!(ctx.app_state.timeline.loop_region.is_none());
        redo(&mut ctx).unwrap();
        assert_eq!(
            ctx.app_state.timeline.loop_region.map(LoopRegion::as_ticks),
            Some((960, 3_840))
        );
    }

    #[test]
    fn dragging_a_loop_edge_undoes_in_one_step() {
        let mut ctx = make_ctx();
        for end in [1_920, 2_880, 3_840] {
            timeline_api::set_loop_region(&mut ctx, Some((0, end))).unwrap();
        }
        undo(&mut ctx).unwrap();
        assert!(ctx.app_state.timeline.loop_region.is_none());
    }

    #[test]
    fn cue_markers_can_be_added_edited_moved_and_removed() {
        let mut ctx = make_ctx();
        let intro = timeline_api::add_cue_marker(&mut ctx, 0, None).unwrap();
        let drop = timeline_api::add_cue_marker(&mut ctx, 7_680, Some("Drop".into())).unwrap();
        assert_eq!(ctx.app_state.timeline.markers[intro].name, "Marker 1");

        timeline_api::update_cue_marker(&mut ctx, drop, "Drop".into(), 8_640, "#FF0000").unwrap();
        timeline_api::update_cue_marker(&mut ctx, drop, "Drop".into(), 9_600, "#FF0000").unwrap();
        assert_eq!(ctx.app_state.timeline.markers[drop].tick, 9_600);

        // The recolor is its own step; the two moves after it would merge
        undo(&mut ctx).unwrap();
        assert_eq!(ctx.app_state.timeline.markers[drop].tick, 8_640);

        assert!(timeline_api::update_cue_marker(&mut ctx, drop, " ".into(), 0, "#FF0000").is_err());
        assert!(timeline_api::update_cue_marker(&mut ctx, drop, "Drop".into(), 0, "red").is_err());

        timeline_api::remove_cue_marker(&mut ctx, intro).unwrap();
        assert!(!ctx.app_state.timeline.markers.contains_key(intro));
        undo(&mut ctx).unwrap();
        assert!(ctx.app_state.timeline.markers.contains_key(intro));
    }

    #[test]
    fn consecutive_moves_of_one_marker_merge() {
        let mut ctx = make_ctx();
        let id = timeline_api::add_cue_marker(&mut ctx, 0, Some("A".into())).unwrap();
        let color = "#FFB300FF";
        for tick in [960, 1_920, 2_880] {
            timeline_api::update_cue_marker(&mut ctx, id, "A".into(), tick, color).unwrap();
        }
        undo(&mut ctx).unwrap();
        assert_eq!(ctx.app_state.timeline.markers[id].tick, 0);
    }
}
