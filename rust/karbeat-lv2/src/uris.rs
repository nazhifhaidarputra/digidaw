//! LV2 vocabulary used by the host, and its per-world lilv nodes.

use lilv::{World, node::Node};

pub(crate) const LV2_CORE: &str = "http://lv2plug.in/ns/lv2core#";
pub(crate) const ATOM: &str = "http://lv2plug.in/ns/ext/atom#";
pub(crate) const MIDI_EVENT: &str = "http://lv2plug.in/ns/ext/midi#MidiEvent";
pub(crate) const TIME: &str = "http://lv2plug.in/ns/ext/time#";
pub(crate) const UI: &str = "http://lv2plug.in/ns/extensions/ui#";
pub(crate) const UNITS: &str = "http://lv2plug.in/ns/extensions/units#";
pub(crate) const PORT_GROUPS: &str = "http://lv2plug.in/ns/ext/port-groups#";
pub(crate) const PORT_PROPS: &str = "http://lv2plug.in/ns/ext/port-props#";
pub(crate) const URID_MAP: &str = "http://lv2plug.in/ns/ext/urid#map";
pub(crate) const URID_UNMAP: &str = "http://lv2plug.in/ns/ext/urid#unmap";
pub(crate) const OPTIONS: &str = "http://lv2plug.in/ns/ext/options#options";
pub(crate) const INSTANCE_ACCESS: &str = "http://lv2plug.in/ns/ext/instance-access";
pub(crate) const PARAMETERS_SAMPLE_RATE: &str = "http://lv2plug.in/ns/ext/parameters#sampleRate";

/// Nodes for the predicates and classes the host queries, valid for one lilv world.
pub(crate) struct Uris {
    pub rdf_type: Node,
    pub rdf_value: Node,
    pub rdfs_label: Node,
    pub input_port: Node,
    pub output_port: Node,
    pub audio_port: Node,
    pub control_port: Node,
    pub cv_port: Node,
    pub atom_port: Node,
    pub instrument_plugin: Node,
    pub minor_version: Node,
    pub micro_version: Node,
    pub required_feature: Node,
    pub optional_feature: Node,
    pub designation: Node,
    pub free_wheeling: Node,
    pub is_side_chain: Node,
    pub toggled: Node,
    pub integer: Node,
    pub enumeration: Node,
    pub scale_point: Node,
    pub logarithmic: Node,
    pub expensive: Node,
    pub causes_artifacts: Node,
    pub group: Node,
    pub side_chain_of: Node,
    pub main_input: Node,
    pub main_output: Node,
    pub unit: Node,
    pub unit_symbol: Node,
    pub midi_event: Node,
    pub time_position: Node,
    pub minimum_size: Node,
    pub x11_ui: Node,
    pub no_user_resize: Node,
    pub fixed_size: Node,
    pub worker_schedule: Node,
}

impl Uris {
    pub fn new(world: &World) -> Self {
        let core = |name: &str| world.new_uri(&format!("{LV2_CORE}{name}"));
        let ui = |name: &str| world.new_uri(&format!("{UI}{name}"));
        let groups = |name: &str| world.new_uri(&format!("{PORT_GROUPS}{name}"));
        let props = |name: &str| world.new_uri(&format!("{PORT_PROPS}{name}"));
        Self {
            rdf_type: world.new_uri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"),
            rdf_value: world.new_uri("http://www.w3.org/1999/02/22-rdf-syntax-ns#value"),
            rdfs_label: world.new_uri("http://www.w3.org/2000/01/rdf-schema#label"),
            input_port: core("InputPort"),
            output_port: core("OutputPort"),
            audio_port: core("AudioPort"),
            control_port: core("ControlPort"),
            cv_port: core("CVPort"),
            atom_port: world.new_uri(&format!("{ATOM}AtomPort")),
            instrument_plugin: core("InstrumentPlugin"),
            minor_version: core("minorVersion"),
            micro_version: core("microVersion"),
            required_feature: core("requiredFeature"),
            optional_feature: core("optionalFeature"),
            designation: core("designation"),
            free_wheeling: core("freeWheeling"),
            is_side_chain: core("isSideChain"),
            toggled: core("toggled"),
            integer: core("integer"),
            enumeration: core("enumeration"),
            scale_point: core("scalePoint"),
            logarithmic: props("logarithmic"),
            expensive: props("expensive"),
            causes_artifacts: props("causesArtifacts"),
            group: groups("group"),
            side_chain_of: groups("sideChainOf"),
            main_input: groups("mainInput"),
            main_output: groups("mainOutput"),
            unit: world.new_uri(&format!("{UNITS}unit")),
            unit_symbol: world.new_uri(&format!("{UNITS}symbol")),
            midi_event: world.new_uri(MIDI_EVENT),
            time_position: world.new_uri(&format!("{TIME}Position")),
            minimum_size: world.new_uri("http://lv2plug.in/ns/ext/resize-port#minimumSize"),
            x11_ui: ui("X11UI"),
            no_user_resize: ui("noUserResize"),
            fixed_size: ui("fixedSize"),
            worker_schedule: world.new_uri("http://lv2plug.in/ns/ext/worker#schedule"),
        }
    }
}

/// Reads a numeric literal, which Turtle may type as decimal, integer, or boolean.
pub(crate) fn node_number(node: &Node) -> Option<f32> {
    if let Some(value) = node.as_float() {
        return value.is_finite().then_some(value);
    }
    if let Some(value) = node.as_int() {
        return Some(int_to_f32(value));
    }
    node.as_bool().map(|value| if value { 1.0 } else { 0.0 })
}

#[allow(
    clippy::as_conversions,
    clippy::cast_precision_loss,
    reason = "LV2 control values are single precision; integer bounds beyond 2^24 lose only range detail"
)]
pub(crate) const fn int_to_f32(value: i32) -> f32 {
    value as f32
}
