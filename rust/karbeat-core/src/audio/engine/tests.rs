#![cfg(test)]

use crate::audio::engine::{AudioEngine, AudioEngineTelemetry};
use crate::audio::event::TransportFeedback;
use crate::audio::render_state::AudioGraphState;
use crate::commands::{AudioCommand, AudioFeedback, TelemetryRegistration};
use crate::core::project::automation::{
    AutomationLane, AutomationPoint, AutomationTarget, MixerChannelParamTarget,
    TrackAutomationTarget,
};
use crate::core::project::modulation::{ModulationLink, ModulationSource};
use crate::core::project::track::AudioTrack;
use crate::core::project::{ApplicationState, ModulationLinkForOrderedLaneView, TrackType};
use karbeat_utils::color::Color;
use karbeat_utils::types::NormalizedF64;
use rtrb::RingBuffer;
use std::sync::mpsc;
// use crate::audio::;

#[test]
fn browser_preview_stops_at_its_frame_limit() {
    let (_, cmd_consumer) = RingBuffer::<AudioCommand>::new(32);
    let (pos_producer, _) = RingBuffer::<TransportFeedback>::new(32);
    let (fb_producer, _) = RingBuffer::<AudioFeedback>::new(32);
    let (telemetry_tx, _) = mpsc::sync_channel::<TelemetryRegistration>(32);
    let sample_rate = 44_100;
    let mut engine = AudioEngine::new(
        cmd_consumer,
        pos_producer,
        fb_producer,
        sample_rate,
        2,
        120.0,
        16,
        AudioEngineTelemetry::new_for_export(),
        telemetry_tx,
    );

    let file = tempfile::NamedTempFile::new().expect("preview fixture file");
    let spec = hound::WavSpec {
        channels: 1,
        sample_rate,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };
    let mut writer = hound::WavWriter::new(file.reopen().expect("fixture handle"), spec)
        .expect("fixture writer");
    for _ in 0..64 {
        writer.write_sample(16_384_i16).expect("fixture sample");
    }
    writer.finalize().expect("finalize fixture");
    let waveform = crate::core::file_manager::audio_loader::load_audio_file(
        file.path().to_str().expect("fixture path"),
        None,
        sample_rate,
    )
    .expect("load preview fixture");

    engine.process_command(AudioCommand::PlayPreview {
        waveform,
        max_frames: 4,
    });

    let mut first_block = vec![0.0; 16 * 2];
    engine.process(&mut first_block);
    assert!(first_block[..8].iter().any(|sample| *sample != 0.0));
    assert!(first_block[8..].iter().all(|sample| *sample == 0.0));

    let mut second_block = vec![1.0; 16 * 2];
    engine.process(&mut second_block);
    assert!(second_block.iter().all(|sample| *sample == 0.0));
}

#[test]
fn test_automation_lane_applied_to_mixer_volume() {
    // Setup Audio Engine
    let (_, cmd_consumer) = RingBuffer::<AudioCommand>::new(1024);
    let (pos_producer, _) = RingBuffer::<TransportFeedback>::new(1024);
    let (fb_producer, _) = RingBuffer::<AudioFeedback>::new(1024);
    let (telemetry_tx, _) = mpsc::sync_channel::<TelemetryRegistration>(1024);

    let mut engine = AudioEngine::new(
        cmd_consumer,
        pos_producer,
        fb_producer,
        44100,
        2,
        120.0,
        512,
        AudioEngineTelemetry::new_for_export(),
        telemetry_tx,
    );

    let mut app_state = ApplicationState::default();
    let track_id = app_state.tracks.insert_with_key(|id| {
        AudioTrack::new(
            id,
            "Test Track",
            Color::new_from_rgb(0, 0, 0),
            TrackType::Audio,
        )
    });

    // Target: Track Volume
    let target = AutomationTarget::Track {
        track_id,
        track_target: TrackAutomationTarget::MixerChannel(MixerChannelParamTarget::Volume),
    };

    let automation_id = app_state.automation_pool.insert_with_key(|id| {
        let mut lane = AutomationLane::new(id, "Volume", 0.0, 1.0, 0.5);
        lane.add_point(AutomationPoint::new(0, NormalizedF64::new(0.75)));
        lane
    });
    let automation_lane = app_state.automation_pool[automation_id].clone();

    // Setup modulation source and link
    let mod_source_id = app_state
        .modulation_sources
        .insert(ModulationSource::Automation {
            lane_id: automation_id,
        });
    let mod_link_id =
        app_state
            .modulation_links
            .insert_with_key(|id| ModulationLinkForOrderedLaneView {
                order_idx: 0,
                prop: ModulationLink {
                    id,
                    source_id: mod_source_id,
                    target: target.clone(),
                    depth: 1.0,
                    base_value: 0.5,
                },
            });

    // Initialize Engine State
    engine.process_command(AudioCommand::ReplaceFullGraph {
        graph: AudioGraphState::from(&app_state),
    });

    let mut new_val = crate::audio::engine::AudioMixerChannelValues::default();
    new_val.volume.set_base(0.5);
    engine.mixer_state.track_channels.insert(track_id, new_val);

    engine.process_command(AudioCommand::AddModulationSource {
        id: mod_source_id,
        source: ModulationSource::Automation {
            lane_id: automation_id,
        },
    });
    engine.process_command(AudioCommand::AddModulationLink {
        id: mod_link_id,
        link: ModulationLink {
            id: mod_link_id,
            source_id: mod_source_id,
            target: target.clone(),
            depth: 1.0,
            base_value: 0.5,
        },
    });
    engine.process_command(AudioCommand::UpdateAutomationLane {
        id: automation_id,
        lane: automation_lane.into(),
    });

    // Let's set playhead to 0 and playback mode
    engine.process_command(AudioCommand::SetPlayhead(0));

    // Run one process block
    let mut output_buffer = vec![0.0; 512 * 2];
    engine.process(&mut output_buffer);

    //  Check if MixerChannel Volume was updated to 0.75
    let ch = engine
        .mixer_state
        .track_channels
        .get(&track_id)
        .expect("Track channel not found");
    assert_eq!(ch.volume.get(), 0.75, "Volume should be automated to 0.75");
}
