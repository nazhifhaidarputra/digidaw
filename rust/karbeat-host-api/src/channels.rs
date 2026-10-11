//! Channel-layout adaptation between the engine's buses and a hosted processor's buffers.

use karbeat_plugin_api::types::AudioBuffers;

/// Maps `sources` onto `destinations` for the first `frames` samples.
///
/// Equal layouts copy channel by channel. A stereo source feeding a mono destination is averaged,
/// and a mono source feeding a wider destination is duplicated into its first two channels.
/// Otherwise the first shared channels are copied. Destination channels without a source keep
/// their existing contents, which callers clear beforehand.
pub fn adapt_channels<S: AsRef<[f32]>, D: AsMut<[f32]>>(
    sources: &[S],
    destinations: &mut [D],
    frames: usize,
) {
    match (sources, &mut *destinations) {
        ([left, right, ..], [mono]) => {
            let (left, right, mono) = (left.as_ref(), right.as_ref(), mono.as_mut());
            let count = frames.min(left.len()).min(right.len()).min(mono.len());
            for ((destination, left), right) in mono[..count]
                .iter_mut()
                .zip(&left[..count])
                .zip(&right[..count])
            {
                *destination = (left + right) * 0.5;
            }
        }
        ([mono], [first, second, ..]) => {
            let mono = mono.as_ref();
            for destination in [first.as_mut(), second.as_mut()] {
                let count = frames.min(mono.len()).min(destination.len());
                destination[..count].copy_from_slice(&mono[..count]);
            }
        }
        _ => {
            for (source, destination) in sources.iter().zip(destinations.iter_mut()) {
                let (source, destination) = (source.as_ref(), destination.as_mut());
                let count = frames.min(source.len()).min(destination.len());
                destination[..count].copy_from_slice(&source[..count]);
            }
        }
    }
}

/// Clears every main and auxiliary output channel.
pub fn silence(buffers: &mut AudioBuffers) {
    for bus in buffers
        .main_outputs
        .iter_mut()
        .chain(buffers.aux_outputs.iter_mut())
    {
        for channel in bus.channel_data.iter_mut() {
            channel.fill(0.0);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn channel_adaptation_covers_equal_widening_and_truncating_layouts() {
        let mut stereo = [vec![0.0_f32; 2], vec![0.0; 2]];
        adapt_channels(&[[2.0_f32, 4.0]], &mut stereo, 2);
        assert_eq!(stereo, [vec![2.0, 4.0], vec![2.0, 4.0]]);
        let mut three = [vec![9.0_f32; 2], vec![9.0; 2], vec![0.0; 2]];
        adapt_channels(&[[1.0_f32, 1.0], [2.0, 2.0]], &mut three, 1);
        assert_eq!(three, [vec![1.0, 9.0], vec![2.0, 9.0], vec![0.0, 0.0]]);
    }

    #[test]
    fn stereo_sources_average_into_a_mono_destination() {
        let mut mono = [vec![0.0_f32; 2]];
        adapt_channels(&[[1.0_f32, 3.0], [3.0, 5.0]], &mut mono, 2);
        assert_eq!(mono, [vec![2.0, 4.0]]);
    }
}
