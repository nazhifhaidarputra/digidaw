//! Bouncing the loop region to a new audio source.
//!
//! A bounce bakes everything inside the loop region, every track and bus with their effects,
//! into one audio file and adds it to the project's sources. Playing that file costs far less
//! than running the plugins that produced it. The master bus is left out so the bounce is not
//! processed twice once it plays back through the master.

use std::collections::HashSet;
use std::path::{Path, PathBuf};

use anyhow::Context;
use karbeat_core::audio::exporter::{
    ExportRange, PendingAudioExport, RenderOptions, RenderPurpose, TailHandling, begin_export,
    execute_export,
};
use karbeat_core::audio::writer::{
    AudioExportConfig, BitDepth, BitPerSample, wav::WavAudioWriterConfig,
};
use karbeat_core::context::DawContext;
use karbeat_core::core::file_manager::{app_cache_dir, audio_loader::load_audio_file};
use karbeat_core::core::project::{ApplicationState, LoopRegion};
use karbeat_core::shared::id::AudioSourceId;

use crate::audio_waveform_api::{CompletedAudioImport, commit_audio_import};

/// Bounce captured from the project; render it with [`execute_bounce`].
pub struct PendingBounce {
    export: PendingAudioExport,
    region: LoopRegion,
    name: String,
    output_path: PathBuf,
    sample_rate: u32,
}

impl PendingBounce {
    /// Name the new source will get.
    pub fn name(&self) -> &str {
        &self.name
    }
}

/// Rendered bounce; add it with [`commit_bounce`].
pub struct CompletedBounce {
    import: CompletedAudioImport,
}

/// Captures the project for bouncing its loop region. Only needs a short read of the project.
pub fn begin_bounce(ctx: &DawContext) -> anyhow::Result<PendingBounce> {
    let region = ctx
        .app_state
        .timeline
        .loop_region
        .context("Set a loop region to choose what to bounce")?;
    let output_path = new_bounce_file()?;
    Ok(PendingBounce {
        export: begin_export(ctx),
        region,
        name: bounce_name(&ctx.app_state, region),
        output_path,
        sample_rate: ctx.audio_runtime_settings.read().requested_dsp.sample_rate,
    })
}

/// Renders the region and decodes the result. Holds no project lock.
///
/// `progress` receives values from 0 to 1 and returns `false` to cancel, which deletes the
/// partial file and fails the bounce.
pub fn execute_bounce(
    pending: PendingBounce,
    mut progress: impl FnMut(f32) -> bool + Send,
) -> anyhow::Result<CompletedBounce> {
    let PendingBounce {
        export,
        region,
        name,
        output_path,
        sample_rate,
    } = pending;
    let path = output_path
        .to_str()
        .context("The bounce file path is not valid UTF-8")?
        .to_owned();
    // Effect tails ring past the region end, so they are kept
    let options = RenderOptions {
        tail_handling: TailHandling::LeaveRemainder,
        range: ExportRange::Ticks {
            start_tick: region.start_tick,
            end_tick: region.end_tick,
        },
        purpose: RenderPurpose::Bounce,
    };
    let config = AudioExportConfig::Wav(WavAudioWriterConfig {
        sample_rate,
        channels: 2,
        bit_depth: BitDepth::BitPerSample(BitPerSample::B32),
    });

    let mut cancelled = false;
    let rendered = execute_export(export, &path, config, options, |fraction| {
        let keep_going = progress(fraction);
        cancelled |= !keep_going;
        keep_going
    });
    if let Err(error) = rendered {
        discard(&output_path);
        return Err(error.into());
    }
    if cancelled {
        discard(&output_path);
        anyhow::bail!("Bounce cancelled");
    }

    let waveform = load_audio_file(&path, Some(&name), sample_rate).inspect_err(|_| {
        discard(&output_path);
    })?;
    Ok(CompletedBounce {
        import: CompletedAudioImport::Decoded {
            waveform,
            normalized_path: output_path,
            known: HashSet::new(),
        },
    })
}

/// Adds the bounced audio to the project's sources and returns its ID.
pub fn commit_bounce(ctx: &mut DawContext, completed: CompletedBounce) -> AudioSourceId {
    commit_audio_import(ctx, completed.import)
}

/// Bounces the loop region in one call, holding `ctx` throughout. UIs that must stay
/// responsive call the three steps separately and release the project while rendering.
pub fn bounce_loop_region(ctx: &mut DawContext) -> anyhow::Result<AudioSourceId> {
    let pending = begin_bounce(ctx)?;
    let completed = execute_bounce(pending, |_| true)?;
    Ok(commit_bounce(ctx, completed))
}

/// Creates an empty, uniquely named WAV file in the app cache that outlives this session.
///
/// Saving the project embeds the file, so it only has to exist until then.
fn new_bounce_file() -> anyhow::Result<PathBuf> {
    let directory = app_cache_dir()
        .context("No cache directory is available for bounced audio")?
        .join("bounces");
    std::fs::create_dir_all(&directory)
        .with_context(|| format!("Failed to create {}", directory.display()))?;
    let (_, path) = tempfile::Builder::new()
        .prefix("bounce-")
        .suffix(".wav")
        .tempfile_in(&directory)
        .context("Failed to create the bounce file")?
        .keep()
        .context("Failed to keep the bounce file")?;
    Ok(path)
}

fn discard(path: &Path) {
    if let Err(error) = std::fs::remove_file(path) {
        log::warn!(
            "Failed to remove the bounce file {}: {error}",
            path.display()
        );
    }
}

/// Names a bounce after the bars it spans, such as "Bounce bars 5-8".
fn bounce_name(app: &ApplicationState, region: LoopRegion) -> String {
    let (numerator, denominator) = app.transport.time_signature;
    let ticks_per_bar =
        (960 * 4 * u64::from(numerator.max(1)) / u64::from(denominator.max(1))).max(1);
    let first_bar = region.start_tick / ticks_per_bar + 1;
    let last_bar = region.end_tick.saturating_sub(1) / ticks_per_bar + 1;
    if first_bar == last_bar {
        format!("Bounce bar {first_bar}")
    } else {
        format!("Bounce bars {first_bar}-{last_bar}")
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "fixture regions are valid and should fail the test immediately otherwise"
)]
mod tests {
    use super::*;

    #[test]
    fn bounce_names_list_the_bars_the_region_touches() {
        let app = ApplicationState::default();
        let bars = |start, end| bounce_name(&app, LoopRegion::new(start, end).unwrap());
        assert_eq!(bars(0, 3_840), "Bounce bar 1");
        assert_eq!(bars(15_360, 30_720), "Bounce bars 5-8");
        assert_eq!(bars(3_000, 4_000), "Bounce bars 1-2");
    }

    #[test]
    fn bouncing_needs_a_loop_region() {
        let ctx = crate::test::helpers::make_ctx();
        let error = begin_bounce(&ctx).err().unwrap();
        assert!(error.to_string().contains("loop region"), "{error}");
    }
}
