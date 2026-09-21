//! Opt-in integration tests: VITAL_VST3_PATH=/path/to/Vital.vst3 cargo test -p karbeat-vst3 --test vital -- --ignored --test-threads=1

#![allow(
    clippy::unwrap_used,
    clippy::panic,
    reason = "integration test setup failures should fail the test"
)]

use karbeat_host_api::{HostError, PluginController, PluginInstanceManager, ProcessingConfig};
use karbeat_plugin_api::prelude::AudioPlugin;
use karbeat_plugin_api::types::{
    AudioBuffers, AudioBusBuffer, MidiEvent, MidiMessage, ProcessContext, ProcessingMode,
};
use karbeat_vst3::{Vst3PluginHost, module::Vst3Module};

#[path = "support/native_state.rs"]
mod native_state;
#[cfg(target_os = "linux")]
#[path = "support/x11_editor.rs"]
mod x11_editor;
use std::{
    alloc::{GlobalAlloc, Layout, System},
    cell::Cell,
    path::PathBuf,
    sync::atomic::{AtomicUsize, Ordering},
};

struct CountingAllocator;
thread_local! { static WATCH: Cell<bool> = const { Cell::new(false) }; }
static ALLOCATIONS: AtomicUsize = AtomicUsize::new(0);
static DEALLOCATIONS: AtomicUsize = AtomicUsize::new(0);
// SAFETY: All memory operations forward unchanged to System; counting does not allocate.
unsafe impl GlobalAlloc for CountingAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        if WATCH.try_with(Cell::get).unwrap_or(false) {
            ALLOCATIONS.fetch_add(1, Ordering::Relaxed);
        }
        // SAFETY: Forward the caller's valid allocation layout to System.
        unsafe { System.alloc(layout) }
    }
    unsafe fn dealloc(&self, pointer: *mut u8, layout: Layout) {
        if WATCH.try_with(Cell::get).unwrap_or(false) {
            DEALLOCATIONS.fetch_add(1, Ordering::Relaxed);
        }
        // SAFETY: Pointer and layout are forwarded to their original allocator.
        unsafe { System.dealloc(pointer, layout) };
    }
    unsafe fn realloc(&self, pointer: *mut u8, layout: Layout, size: usize) -> *mut u8 {
        if WATCH.try_with(Cell::get).unwrap_or(false) {
            ALLOCATIONS.fetch_add(1, Ordering::Relaxed);
        }
        // SAFETY: Forward caller's original pointer/layout and requested size to System.
        unsafe { System.realloc(pointer, layout, size) }
    }
}
#[global_allocator]
static ALLOCATOR: CountingAllocator = CountingAllocator;

fn main() {
    if std::env::var_os("VITAL_VST3_PATH").is_none()
        && !std::env::args().any(|arg| arg == "--ignored")
    {
        return;
    }
    let path = std::env::var_os("VITAL_VST3_PATH")
        .map_or_else(|| PathBuf::from("/usr/lib/vst3/Vital.vst3"), PathBuf::from);
    let descriptor = Vst3Module::load(&path)
        .unwrap()
        .descriptors()
        .unwrap()
        .into_iter()
        .find(|p| p.name == "Vital")
        .unwrap();
    let mut host = Vst3PluginHost::new();
    let first = host.create(&descriptor).unwrap();
    let second = host.create(&descriptor).unwrap();
    assert_ne!(first, second);
    let config = ProcessingConfig {
        sample_rate: 48_000.0,
        max_block_size: 128,
        main_input_channels: 0,
        main_output_channels: 2,
        sidechain_channels: 0,
        offline: false,
    };
    host.prepare(first, &config).unwrap();
    host.prepare(second, &config).unwrap();
    let mut processor = host.take_processor(first).unwrap();
    let mut retirement = processor.enable_retirement().unwrap();
    let other = host.take_processor(second).unwrap();
    assert!(host.take_processor(first).is_err());
    assert!(host.destroy(first).is_err());
    host.resume(first).unwrap();
    let (mut processor, energy) = std::thread::spawn(move || {
        let note_on = [MidiEvent {
            sample_offset: 7,
            data: MidiMessage::NoteOn {
                note_id: Some(123),
                channel: 0,
                key: 60,
                velocity: 100,
            },
        }];
        let note_off = [MidiEvent {
            sample_offset: 13,
            data: MidiMessage::NoteOff {
                note_id: Some(123),
                channel: 0,
                key: 60,
            },
        }];
        let mut left = [0.0_f32; 128];
        let mut right = [0.0_f32; 128];
        let mut energy = 0.0;
        for block in 0..512 {
            let events = if block == 0 {
                &note_on[..]
            } else if block == 256 {
                &note_off[..]
            } else {
                &[]
            };
            let context = ProcessContext {
                bpm: 120.0,
                time_sig_numerator: 4,
                time_sig_denominator: 4,
                is_playing: true,
                is_recording: false,
                mode: ProcessingMode::Realtime,
                project_time_seconds: f64::from(block * 128) / 48000.0,
                project_time_samples: u64::try_from(block * 128).unwrap(),
                beat_position: 0.0,
                bar_position: 0.0,
                loop_start_beat: None,
                loop_end_beat: None,
                midi_events: events,
                param_changes: &[],
            };
            let mut channels: [&mut [f32]; 2] = [&mut left, &mut right];
            let mut output = [AudioBusBuffer {
                channel_data: &mut channels,
                is_silent: false,
            }];
            let mut buffers = AudioBuffers {
                main_inputs: &mut [],
                main_outputs: &mut output,
                aux_inputs: &mut [],
                aux_outputs: &mut [],
            };
            WATCH.with(|watch| watch.set(block > 0));
            processor.process(&mut buffers, &context);
            WATCH.with(|watch| watch.set(false));
            for sample in left.iter().chain(&right) {
                assert!(sample.is_finite());
                energy += f64::from(sample.abs());
            }
        }
        (processor, energy)
    })
    .join()
    .unwrap();
    assert!(
        energy > 0.01,
        "Vital must render audible note energy, got {energy}"
    );
    assert_eq!(
        ALLOCATIONS.load(Ordering::Relaxed),
        0,
        "host audio path allocated after preparation"
    );
    assert_eq!(
        DEALLOCATIONS.load(Ordering::Relaxed),
        0,
        "host audio path destroyed storage after preparation"
    );
    #[cfg(target_os = "linux")]
    if std::env::var_os("VITAL_TEST_EDITOR").is_some() {
        x11_editor::exercise_editor(&mut host, first);
    }
    host.suspend(first).unwrap();
    let state = host.save_state(first).unwrap();
    host.resume(first).unwrap();
    assert!(host.is_processing(first).unwrap());
    assert!(!state.component.is_empty());
    host.restore_state(second, &state).unwrap();
    assert!(!host.is_processing(second).unwrap());
    let restored = host.save_state(second).unwrap();
    assert!(!restored.component.is_empty());
    let mut invalid = state;
    invalid.version = u32::MAX;
    host.suspend(first).unwrap();
    assert!(matches!(
        host.restore_state(first, &invalid),
        Err(HostError::InvalidState(_))
    ));
    host.resume(first).unwrap();
    assert!(host.is_processing(first).unwrap());
    let parameter = host
        .parameters(first)
        .unwrap()
        .into_iter()
        .find(|p| p.step == 0.0)
        .unwrap();
    let other_value = other.get_parameter(parameter.id);
    processor.set_parameter(parameter.id, 0.73);
    assert!((processor.get_parameter(parameter.id) - 0.73).abs() < 0.0001);
    assert_eq!(other.get_parameter(parameter.id), other_value);
    std::thread::spawn(move || {
        WATCH.with(|watch| watch.set(true));
        processor.retire();
        WATCH.with(|watch| watch.set(false));
    })
    .join()
    .unwrap();
    assert_eq!(
        ALLOCATIONS.load(Ordering::Relaxed),
        0,
        "endpoint retirement allocated"
    );
    assert_eq!(
        DEALLOCATIONS.load(Ordering::Relaxed),
        0,
        "endpoint retirement destroyed storage on the audio thread"
    );
    assert!(host.destroy(first).is_err());
    drop(retirement.take().unwrap());
    assert!(host.take_processor(first).is_err());
    drop(other);
    host.destroy(first).unwrap();
    host.destroy(second).unwrap();
    assert!(host.parameters(first).is_err());
    drop(host);
    native_state::exercise_state_gateway(descriptor, config);
}
