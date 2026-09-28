//! Audio bus negotiation between the engine's channel layout and a VST3 processor.
//!
//! VST3 lets a processor answer `setBusArrangements` with `kResultFalse` after adapting to the
//! closest layout it supports, so the host must read the accepted arrangements back and map
//! its own channels onto whatever the plugin chose. These helpers keep that policy free of COM
//! calls so it can be tested directly.

use karbeat_host_api::{HostError, ProcessingConfig};
use vst3::Steinberg::Vst::SpeakerArr;

/// Largest channel count accepted on one negotiated bus.
pub(crate) const MAX_BUS_CHANNELS: usize = 32;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
/// Host-side meaning of one plugin audio bus.
pub(crate) enum BusRole {
    /// First main bus in its direction; carries the channel's own signal.
    Main,
    /// First auxiliary input bus; fed from the plugin's sidechain route.
    Sidechain,
    /// Any further bus; receives silence or has its output discarded.
    Other,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
/// Metadata read from one plugin audio bus before negotiation.
pub(crate) struct BusDescription {
    pub role: BusRole,
    /// Arrangement the plugin currently reports for this bus.
    pub native: u64,
    /// Whether the plugin marks the bus `kDefaultActive`.
    pub default_active: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
/// Negotiated plugin-side layout of one audio bus.
pub(crate) struct BusPlan {
    pub role: BusRole,
    /// Channels the plugin processes on this bus.
    pub channels: usize,
    /// Whether the host activates this bus.
    pub active: bool,
}

/// Assigns host roles from native bus types (`0` = main, `1` = aux) in bus order.
pub(crate) fn classify(bus_types: &[i32], input: bool) -> Vec<BusRole> {
    let mut seen_main = false;
    let mut seen_sidechain = false;
    bus_types
        .iter()
        .map(|&bus_type| {
            if bus_type == 0 && !seen_main {
                seen_main = true;
                BusRole::Main
            } else if bus_type == 1 && input && !seen_sidechain {
                seen_sidechain = true;
                BusRole::Sidechain
            } else {
                BusRole::Other
            }
        })
        .collect()
}

/// Number of speakers in an arrangement, capped at [`MAX_BUS_CHANNELS`].
pub(crate) fn channel_count(arrangement: u64) -> usize {
    usize::try_from(arrangement.count_ones())
        .unwrap_or(MAX_BUS_CHANNELS)
        .min(MAX_BUS_CHANNELS)
}

/// Arrangement used when a plugin reports only a bus channel count.
pub(crate) fn arrangement_for_count(channels: usize) -> u64 {
    match channels {
        0 => SpeakerArr::kEmpty,
        1 => SpeakerArr::kMono,
        2 => SpeakerArr::kStereo,
        count => {
            let count = u32::try_from(count.min(MAX_BUS_CHANNELS)).unwrap_or(0);
            1_u64
                .checked_shl(count)
                .map_or(u64::MAX, |bit| bit.saturating_sub(1))
        }
    }
}

fn host_arrangement(channels: usize) -> Result<u64, HostError> {
    match channels {
        1 => Ok(SpeakerArr::kMono),
        2 => Ok(SpeakerArr::kStereo),
        _ => Err(HostError::InvalidConfiguration),
    }
}

/// Arrangements requested from the plugin for each input and output bus.
///
/// Main buses ask for the engine's layout. Sidechain buses ask for the engine layout only when a
/// sidechain is requested; every other bus keeps its native arrangement, because many plugins
/// reject an empty arrangement on buses whose ports they always process.
pub(crate) fn requested(
    inputs: &[BusDescription],
    outputs: &[BusDescription],
    config: &ProcessingConfig,
) -> Result<(Vec<u64>, Vec<u64>), HostError> {
    if !outputs.iter().any(|bus| bus.role == BusRole::Main) {
        return Err(HostError::Unsupported("plugin has no main audio output"));
    }
    if config.main_input_channels != 0 && !inputs.iter().any(|bus| bus.role == BusRole::Main) {
        return Err(HostError::Unsupported("requested input bus"));
    }
    let input = inputs
        .iter()
        .map(|bus| match bus.role {
            BusRole::Main if config.main_input_channels != 0 => {
                host_arrangement(config.main_input_channels)
            }
            BusRole::Sidechain if config.sidechain_channels != 0 => {
                host_arrangement(config.sidechain_channels)
            }
            _ => Ok(bus.native),
        })
        .collect::<Result<_, _>>()?;
    let output = outputs
        .iter()
        .map(|bus| match bus.role {
            BusRole::Main => host_arrangement(config.main_output_channels),
            _ => Ok(bus.native),
        })
        .collect::<Result<_, _>>()?;
    Ok((input, output))
}

/// Builds plugin-side bus plans from the arrangements the plugin accepted.
pub(crate) fn resolve(
    inputs: &[BusDescription],
    input_arrangements: &[u64],
    outputs: &[BusDescription],
    output_arrangements: &[u64],
    config: &ProcessingConfig,
) -> Result<(Vec<BusPlan>, Vec<BusPlan>), HostError> {
    if inputs.len() != input_arrangements.len() || outputs.len() != output_arrangements.len() {
        return Err(HostError::InvalidConfiguration);
    }
    let input = inputs
        .iter()
        .zip(input_arrangements)
        .map(|(bus, &arrangement)| BusPlan {
            role: bus.role,
            channels: channel_count(arrangement),
            active: match bus.role {
                BusRole::Main => config.main_input_channels != 0,
                BusRole::Sidechain => true,
                BusRole::Other => bus.default_active,
            },
        })
        .collect();
    let output: Vec<BusPlan> = outputs
        .iter()
        .zip(output_arrangements)
        .map(|(bus, &arrangement)| BusPlan {
            role: bus.role,
            channels: channel_count(arrangement),
            active: bus.role == BusRole::Main || bus.default_active,
        })
        .collect();
    if !output
        .iter()
        .any(|bus| bus.role == BusRole::Main && bus.channels != 0)
    {
        return Err(HostError::Unsupported("plugin has no main audio output"));
    }
    Ok((input, output))
}

#[cfg(test)]
#[allow(clippy::unwrap_used, reason = "test fixtures are valid layouts")]
mod tests {
    use super::*;

    fn config(inputs: usize, sidechain: usize) -> ProcessingConfig {
        ProcessingConfig {
            sample_rate: 48_000.0,
            max_block_size: 512,
            main_input_channels: inputs,
            main_output_channels: 2,
            sidechain_channels: sidechain,
            offline: false,
        }
    }

    fn bus(role: BusRole, native: u64) -> BusDescription {
        BusDescription {
            role,
            native,
            default_active: role != BusRole::Other,
        }
    }

    #[test]
    fn roles_follow_the_first_main_and_first_aux_input() {
        assert_eq!(
            classify(&[1, 0, 1, 0], true),
            [
                BusRole::Sidechain,
                BusRole::Main,
                BusRole::Other,
                BusRole::Other
            ]
        );
        assert_eq!(classify(&[0, 1], false), [BusRole::Main, BusRole::Other]);
    }

    #[test]
    fn unused_sidechain_keeps_its_native_arrangement() {
        let inputs = [
            bus(BusRole::Main, SpeakerArr::kStereo),
            bus(BusRole::Sidechain, SpeakerArr::kStereo),
            bus(BusRole::Other, SpeakerArr::kMono),
        ];
        let outputs = [bus(BusRole::Main, SpeakerArr::kStereo)];
        let (input, output) = requested(&inputs, &outputs, &config(2, 0)).unwrap();
        assert_eq!(
            input,
            [SpeakerArr::kStereo, SpeakerArr::kStereo, SpeakerArr::kMono]
        );
        assert_eq!(output, [SpeakerArr::kStereo]);
    }

    #[test]
    fn requested_sidechain_uses_the_engine_layout_and_is_optional() {
        let inputs = [
            bus(BusRole::Main, SpeakerArr::kMono),
            bus(BusRole::Sidechain, SpeakerArr::kMono),
        ];
        let outputs = [bus(BusRole::Main, SpeakerArr::kMono)];
        let (input, _) = requested(&inputs, &outputs, &config(2, 2)).unwrap();
        assert_eq!(input, [SpeakerArr::kStereo, SpeakerArr::kStereo]);
        let (input, _) = requested(&inputs[..1], &outputs, &config(2, 2)).unwrap();
        assert_eq!(input, [SpeakerArr::kStereo]);
    }

    #[test]
    fn instruments_keep_native_inputs_but_leave_them_inactive() {
        let inputs = [bus(BusRole::Main, SpeakerArr::kStereo)];
        let outputs = [bus(BusRole::Main, SpeakerArr::kStereo)];
        let (input, output) = requested(&inputs, &outputs, &config(0, 0)).unwrap();
        let (input, _) = resolve(&inputs, &input, &outputs, &output, &config(0, 0)).unwrap();
        assert_eq!(
            input,
            [BusPlan {
                role: BusRole::Main,
                channels: 2,
                active: false
            }]
        );
    }

    #[test]
    fn adapted_mono_variant_resolves_to_single_channel_buses() {
        let inputs = [
            bus(BusRole::Main, SpeakerArr::kMono),
            bus(BusRole::Sidechain, SpeakerArr::kMono),
        ];
        let outputs = [bus(BusRole::Main, SpeakerArr::kMono)];
        let (input, output) = resolve(
            &inputs,
            &[SpeakerArr::kMono, SpeakerArr::kMono],
            &outputs,
            &[SpeakerArr::kMono],
            &config(2, 2),
        )
        .unwrap();
        assert!(input.iter().all(|plan| plan.channels == 1 && plan.active));
        assert!(output.iter().all(|plan| plan.channels == 1 && plan.active));
    }

    #[test]
    fn missing_or_empty_main_output_is_rejected() {
        let inputs = [bus(BusRole::Main, SpeakerArr::kStereo)];
        assert!(matches!(
            requested(
                &inputs,
                &[bus(BusRole::Other, SpeakerArr::kStereo)],
                &config(2, 0)
            ),
            Err(HostError::Unsupported(_))
        ));
        let outputs = [bus(BusRole::Main, SpeakerArr::kStereo)];
        assert!(matches!(
            resolve(
                &inputs,
                &[SpeakerArr::kStereo],
                &outputs,
                &[SpeakerArr::kEmpty],
                &config(2, 0)
            ),
            Err(HostError::Unsupported(_))
        ));
    }

    #[test]
    fn channel_counts_come_from_speaker_bits() {
        assert_eq!(channel_count(SpeakerArr::kMono), 1);
        assert_eq!(channel_count(SpeakerArr::kStereo), 2);
        assert_eq!(channel_count(u64::MAX), MAX_BUS_CHANNELS);
        assert_eq!(arrangement_for_count(6).count_ones(), 6);
        assert_eq!(arrangement_for_count(64).count_ones(), 32);
    }
}
