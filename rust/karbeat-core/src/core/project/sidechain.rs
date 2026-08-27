// use karbeat_utils::define_id;
// use serde::{Deserialize, Serialize};

// use crate::{audio::event::PluginTarget, shared::{BusId, TrackId}};

// define_id!(SidechainLinkId);

// #[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
// pub enum SidechainSource {
//     Track(TrackId),
//     Bus(BusId),
//     PluginOutput(PluginTarget),
// }

// #[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
// pub enum TapPoint {
//     PreFader,   // unaffected by mute/volume — typical for detectors
//     PostFader,
//     PostFx,
// }

// #[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
// pub struct SidechainLink {
//     pub id: SidechainLinkId,
//     pub source: SidechainSource,
//     pub target: PluginTarget,
//     pub target_bus_index: usize, // which aux_inputs[] slot on that plugin
//     pub tap_point: TapPoint,
//     pub send_level: f32,         // linear gain
//     pub enabled: bool,
// }
