//! Host-side model of one plugin's ports, read once from its Turtle description.
//!
//! LV2 has no bus negotiation: a plugin declares a fixed set of audio ports and the host maps
//! its own channels onto them. Roles come from port groups and the side-chain port property;
//! the classification policy is kept free of lilv calls so it can be tested directly.

use std::sync::Arc;

use karbeat_host_api::HostError;
use lilv::{World, node::Node, plugin::Plugin, port::Port};

use crate::{
    parameters::{ControlPort, ControlRange, ScalePoint, standard_unit_symbol},
    uris::{UNITS, Uris, node_number},
};

/// Channels the engine can route to one role.
const MAX_ROLE_CHANNELS: usize = 2;
/// Atom buffer size used when a port does not request one.
const DEFAULT_ATOM_CAPACITY: usize = 16 * 1024;
/// Largest atom buffer a port may request.
const MAX_ATOM_CAPACITY: usize = 4 * 1024 * 1024;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
/// Host-side meaning of one plugin audio port.
pub(crate) enum AudioRole {
    /// Carries the channel's own signal.
    Main,
    /// Fed from the plugin's sidechain route.
    Sidechain,
    /// Receives silence, or has its output discarded.
    Other,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
/// Grouping facts about one audio port, in port order.
pub(crate) struct AudioPortTraits {
    /// Whether the port belongs to the plugin's declared main group. `None` when the plugin
    /// declares no main group for this direction.
    pub in_main_group: Option<bool>,
    /// Marked `lv2:isSideChain`, or grouped under a `pg:sideChainOf` group.
    pub side_chain: bool,
}

/// Assigns host roles to the audio ports of one direction.
///
/// Up to two ports of the declared main group are `Main`; without a declared group the first
/// two ports that are not side-chain ports are. Up to two side-chain inputs are `Sidechain`.
/// A declared main group that matches no port is ignored rather than leaving the plugin
/// without a main bus.
pub(crate) fn classify(ports: &[AudioPortTraits], input: bool) -> Vec<AudioRole> {
    let assign = |respect_groups: bool| {
        let (mut main, mut sidechain) = (0, 0);
        ports
            .iter()
            .map(|port| {
                if port.side_chain {
                    if input && sidechain < MAX_ROLE_CHANNELS {
                        sidechain += 1;
                        AudioRole::Sidechain
                    } else {
                        AudioRole::Other
                    }
                } else if (respect_groups && port.in_main_group == Some(false))
                    || main >= MAX_ROLE_CHANNELS
                {
                    AudioRole::Other
                } else {
                    main += 1;
                    AudioRole::Main
                }
            })
            .collect::<Vec<_>>()
    };
    let roles = assign(true);
    if roles.contains(&AudioRole::Main) || ports.iter().all(|port| port.side_chain) {
        roles
    } else {
        assign(false)
    }
}

/// One atom port and what the host exchanges through it.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct AtomPort {
    /// LV2 port index.
    pub index: u32,
    /// Buffer size in bytes, honouring `rsz:minimumSize`.
    pub capacity: usize,
    pub supports_midi: bool,
    pub supports_position: bool,
}

/// Direction and data type of one port.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum PortKind {
    AudioInput,
    AudioOutput,
    ControlInput,
    ControlOutput,
    AtomInput,
    AtomOutput,
    CvInput,
    CvOutput,
}

/// Classifies a port, or returns `None` for a direction or data type the host does not run.
pub(crate) fn port_kind(port: &Port, uris: &Uris) -> Option<PortKind> {
    let input = if port.is_a(&uris.input_port) {
        true
    } else if port.is_a(&uris.output_port) {
        false
    } else {
        return None;
    };
    let (as_input, as_output) = if port.is_a(&uris.audio_port) {
        (PortKind::AudioInput, PortKind::AudioOutput)
    } else if port.is_a(&uris.control_port) {
        (PortKind::ControlInput, PortKind::ControlOutput)
    } else if port.is_a(&uris.atom_port) {
        (PortKind::AtomInput, PortKind::AtomOutput)
    } else if port.is_a(&uris.cv_port) {
        (PortKind::CvInput, PortKind::CvOutput)
    } else {
        return None;
    };
    Some(if input { as_input } else { as_output })
}

/// One audio port and what the host routes through it.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct AudioPort {
    /// LV2 port index.
    pub index: u32,
    pub role: AudioRole,
}

/// Everything the host needs to know about a plugin's ports.
#[derive(Clone, Debug)]
pub(crate) struct PluginModel {
    /// Audio inputs in port order.
    pub audio_inputs: Vec<AudioPort>,
    /// Audio outputs in port order.
    pub audio_outputs: Vec<AudioPort>,
    /// Port indices of CV inputs, which receive silence.
    pub cv_inputs: Vec<u32>,
    /// Port indices of CV outputs, which are discarded.
    pub cv_outputs: Vec<u32>,
    pub atom_inputs: Vec<AtomPort>,
    pub atom_outputs: Vec<AtomPort>,
    /// Control inputs exposed as parameters, sorted by port index.
    pub controls: Arc<[ControlPort]>,
    /// Control input the host drives while rendering offline.
    pub free_wheeling: Option<u32>,
    /// Indices of all control outputs, in port order.
    pub control_outputs: Vec<u32>,
    /// Control output that reports the plugin's latency in frames.
    pub latency: Option<u32>,
    /// Symbol of every port, indexed by port index.
    pub symbols: Vec<String>,
    /// Whether the plugin uses the worker extension for non-realtime jobs.
    pub schedules_work: bool,
}

impl PluginModel {
    /// Whether a sidechain input can be fed.
    pub fn has_sidechain(&self) -> bool {
        self.audio_inputs
            .iter()
            .any(|port| port.role == AudioRole::Sidechain)
    }

    /// Whether the plugin has an output the engine's main bus is taken from.
    pub fn has_main_output(&self) -> bool {
        self.audio_outputs
            .iter()
            .any(|port| port.role == AudioRole::Main)
    }

    /// Whether `port` is a control port of either direction.
    pub fn is_control(&self, port: u32) -> bool {
        self.control(port).is_some()
            || self.free_wheeling == Some(port)
            || self.control_outputs.contains(&port)
    }

    /// Looks up an exposed control input by port index.
    pub fn control(&self, index: u32) -> Option<&ControlPort> {
        self.controls
            .binary_search_by_key(&index, |control| control.index)
            .ok()
            .and_then(|position| self.controls.get(position))
    }

    /// Reads the port model of `plugin`, loading its description if lilv has not yet.
    ///
    /// # Errors
    ///
    /// Returns [`HostError::Unsupported`] for a port whose direction or data type the host
    /// does not run, or that has no symbol.
    pub fn read(plugin: &Plugin, world: &World, uris: &Uris) -> Result<Self, HostError> {
        // Duplicated so the group nodes do not borrow from the temporary collections.
        let first_group = |predicate: &Node| {
            plugin
                .value(predicate)
                .iter()
                .next()
                .map(|group| Node::clone(&group))
        };
        let main_input = first_group(&uris.main_input);
        let main_output = first_group(&uris.main_output);
        let (mut input_ports, mut input_traits) = (Vec::new(), Vec::new());
        let (mut output_ports, mut output_traits) = (Vec::new(), Vec::new());
        let mut model = Self {
            audio_inputs: Vec::new(),
            audio_outputs: Vec::new(),
            cv_inputs: Vec::new(),
            cv_outputs: Vec::new(),
            atom_inputs: Vec::new(),
            atom_outputs: Vec::new(),
            controls: Arc::from(Vec::new()),
            free_wheeling: None,
            control_outputs: Vec::new(),
            latency: None,
            symbols: Vec::new(),
            schedules_work: plugin.has_feature(&uris.worker_schedule),
        };
        let mut controls = Vec::new();
        for port in plugin.iter_ports() {
            let index = u32::try_from(port.index()).map_err(|_| HostError::InvalidConfiguration)?;
            let kind = port_kind(&port, uris).ok_or(HostError::Unsupported("LV2 port type"))?;
            let symbol = port
                .symbol()
                .and_then(|symbol| symbol.as_str().map(str::to_owned))
                .ok_or(HostError::Unsupported("LV2 port without a symbol"))?;
            match kind {
                PortKind::AudioInput => {
                    input_ports.push(index);
                    input_traits.push(audio_traits(&port, world, uris, main_input.as_ref()));
                }
                PortKind::AudioOutput => {
                    output_ports.push(index);
                    output_traits.push(audio_traits(&port, world, uris, main_output.as_ref()));
                }
                PortKind::CvInput => model.cv_inputs.push(index),
                PortKind::CvOutput => model.cv_outputs.push(index),
                PortKind::AtomInput => model.atom_inputs.push(atom_port(&port, index, uris)),
                PortKind::AtomOutput => model.atom_outputs.push(atom_port(&port, index, uris)),
                PortKind::ControlOutput => model.control_outputs.push(index),
                PortKind::ControlInput => {
                    let designation = port.get(&uris.designation);
                    if designation.as_ref() == Some(&uris.free_wheeling) {
                        model.free_wheeling = Some(index);
                    } else {
                        controls.push(control_port(&symbol, &port, index, world, uris));
                    }
                }
            }
            model.symbols.push(symbol);
        }
        let with_roles = |ports: Vec<u32>, roles: Vec<AudioRole>| {
            ports
                .into_iter()
                .zip(roles)
                .map(|(index, role)| AudioPort { index, role })
                .collect()
        };
        model.audio_inputs = with_roles(input_ports, classify(&input_traits, true));
        model.audio_outputs = with_roles(output_ports, classify(&output_traits, false));
        model.controls = Arc::from(controls);
        model.latency = plugin
            .latency_port_index()
            .and_then(|index| u32::try_from(index).ok())
            .filter(|index| model.control_outputs.contains(index));
        Ok(model)
    }
}

fn audio_traits(
    port: &Port,
    world: &World,
    uris: &Uris,
    main_group: Option<&Node>,
) -> AudioPortTraits {
    let group = port.get(&uris.group);
    let grouped_side_chain = group
        .as_ref()
        .is_some_and(|group| world.ask(Some(group), Some(&uris.side_chain_of), None));
    AudioPortTraits {
        in_main_group: main_group.map(|main| group.as_ref() == Some(main)),
        side_chain: grouped_side_chain || port.has_property(&uris.is_side_chain),
    }
}

fn atom_port(port: &Port, index: u32, uris: &Uris) -> AtomPort {
    let capacity = port
        .get(&uris.minimum_size)
        .and_then(|size| size.as_int())
        .and_then(|size| usize::try_from(size).ok())
        .map_or(DEFAULT_ATOM_CAPACITY, |size| {
            size.clamp(DEFAULT_ATOM_CAPACITY, MAX_ATOM_CAPACITY)
        });
    AtomPort {
        index,
        capacity,
        supports_midi: port.supports_event(&uris.midi_event),
        supports_position: port.supports_event(&uris.time_position),
    }
}

fn control_port(
    symbol: &str,
    described: &Port,
    index: u32,
    world: &World,
    uris: &Uris,
) -> ControlPort {
    let bounds = described.range();
    let number = |node: Option<Node>| node.as_ref().and_then(node_number);
    let mut scale_points = described
        .value(&uris.scale_point)
        .iter()
        .filter_map(|point| {
            let value = world.get(Some(&point), Some(&uris.rdf_value), None)?;
            let label = world.get(Some(&point), Some(&uris.rdfs_label), None)?;
            Some(ScalePoint {
                value: node_number(&value)?,
                label: label.as_str()?.to_owned(),
            })
        })
        .collect::<Vec<_>>();
    scale_points.sort_by(|left, right| left.value.total_cmp(&right.value));
    ControlPort {
        index,
        symbol: symbol.to_owned(),
        // The name is display text; a port that omits it is shown by its symbol.
        name: described
            .name()
            .and_then(|name| name.as_str().map(str::to_owned))
            .unwrap_or_else(|| symbol.to_owned()),
        range: ControlRange::new(
            number(bounds.minimum),
            number(bounds.maximum),
            number(bounds.default),
            described.has_property(&uris.logarithmic),
            described.has_property(&uris.integer),
            described.has_property(&uris.toggled),
        ),
        enumeration: described.has_property(&uris.enumeration) && !scale_points.is_empty(),
        scale_points,
        unit: unit_symbol(described, world, uris),
        automatable: !(described.has_property(&uris.expensive)
            || described.has_property(&uris.causes_artifacts)),
    }
}

/// Resolves a port's unit to a display suffix: a standard unit by name, or a unit the plugin
/// describes itself through `units:symbol`.
fn unit_symbol(port: &Port, world: &World, uris: &Uris) -> Option<String> {
    let unit = port.get(&uris.unit)?;
    if let Some(name) = unit.as_uri().and_then(|uri| uri.strip_prefix(UNITS)) {
        return standard_unit_symbol(name).map(str::to_owned);
    }
    world
        .get(Some(&unit), Some(&uris.unit_symbol), None)
        .and_then(|symbol| symbol.as_str().map(str::to_owned))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn traits(in_main_group: Option<bool>, side_chain: bool) -> AudioPortTraits {
        AudioPortTraits {
            in_main_group,
            side_chain,
        }
    }

    #[test]
    fn grouped_stereo_plugin_with_sidechain_gets_two_main_and_two_sidechain_inputs() {
        let ports = [
            traits(Some(true), false),
            traits(Some(true), false),
            traits(Some(false), true),
            traits(Some(false), true),
        ];
        assert_eq!(
            classify(&ports, true),
            [
                AudioRole::Main,
                AudioRole::Main,
                AudioRole::Sidechain,
                AudioRole::Sidechain
            ]
        );
    }

    #[test]
    fn ungrouped_ports_use_the_first_two_and_sidechain_outputs_are_discarded() {
        let ports = [traits(None, false); 3];
        assert_eq!(
            classify(&ports, false),
            [AudioRole::Main, AudioRole::Main, AudioRole::Other]
        );
        assert_eq!(
            classify(&[traits(None, false), traits(None, true)], false),
            [AudioRole::Main, AudioRole::Other]
        );
    }

    #[test]
    fn direct_outputs_outside_the_main_group_are_not_routed() {
        let ports = [
            traits(Some(false), false),
            traits(Some(false), false),
            traits(Some(true), false),
            traits(Some(true), false),
        ];
        assert_eq!(
            classify(&ports, false),
            [
                AudioRole::Other,
                AudioRole::Other,
                AudioRole::Main,
                AudioRole::Main
            ]
        );
    }

    #[test]
    fn a_main_group_that_matches_no_port_falls_back_to_port_order() {
        let ports = [traits(Some(false), false), traits(Some(false), false)];
        assert_eq!(classify(&ports, false), [AudioRole::Main, AudioRole::Main]);
    }

    #[test]
    fn extra_sidechain_inputs_and_a_sidechain_only_plugin_stay_unrouted() {
        let ports = [traits(None, true); 3];
        assert_eq!(
            classify(&ports, true),
            [AudioRole::Sidechain, AudioRole::Sidechain, AudioRole::Other]
        );
    }
}
