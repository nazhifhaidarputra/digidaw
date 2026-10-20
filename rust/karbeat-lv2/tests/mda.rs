//! Opt-in instrument tests with the mda plugins, which ship for Linux:
//! MDA_LV2_PATH=/usr/lib64/lv2/mda.lv2 cargo test -p karbeat-lv2 --test mda -- --ignored --test-threads=1
//!
//! The suite is compiled only on Linux; other platforms build an empty `main` because this
//! target runs without the libtest harness.

#![allow(
    clippy::unwrap_used,
    clippy::panic,
    reason = "integration test setup failures should fail the test"
)]

fn main() {
    #[cfg(target_os = "linux")]
    mda::main();
}

#[cfg(target_os = "linux")]
#[path = "support/native_state.rs"]
mod native_state;

#[cfg(target_os = "linux")]
mod mda {
    use karbeat_host_api::{
        HostError, PluginController, PluginInstanceManager, PluginKind, ProcessingConfig,
    };
    use karbeat_lv2::{Lv2PluginHost, world};
    use karbeat_plugin_api::prelude::AudioPlugin;
    use karbeat_plugin_api::types::{
        AudioBuffers, AudioBusBuffer, MidiEvent, MidiMessage, ProcessContext, ProcessingMode,
    };
    use std::{
        alloc::{GlobalAlloc, Layout, System},
        cell::Cell,
        path::PathBuf,
        sync::atomic::{AtomicUsize, Ordering},
    };

    const DX10: &str = "http://drobilla.net/plugins/mda/DX10";

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

    pub(super) fn main() {
        if std::env::var_os("MDA_LV2_PATH").is_none()
            && !std::env::args().any(|arg| arg == "--ignored")
        {
            return;
        }
        let path = std::env::var_os("MDA_LV2_PATH")
            .map_or_else(|| PathBuf::from("/usr/lib64/lv2/mda.lv2"), PathBuf::from);
        let descriptor = world::probe_bundle(&path)
            .unwrap()
            .into_iter()
            .find(|plugin| plugin.identity.native_id == DX10)
            .unwrap();
        assert_eq!(descriptor.kind, PluginKind::Instrument);
        let mut host = Lv2PluginHost::new();
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
        let capabilities = host.capabilities(first).unwrap();
        // mda ships no editor, so the host's generic parameter view is the only one.
        assert!(capabilities.controller && !capabilities.editor && !capabilities.sidechain);
        let mut processor = host.take_processor(first).unwrap();
        let mut retirement = processor.enable_retirement().unwrap();
        let other = host.take_processor(second).unwrap();
        assert!(host.take_processor(first).is_err());
        assert!(host.destroy(first).is_err());
        host.resume(first).unwrap();
        let (mut processor, energy, released) = std::thread::spawn(move || {
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
            let (mut energy, mut released) = (0.0, 0.0);
            for block in 0..1024 {
                let events = if block == 0 {
                    &note_on[..]
                } else if block == 64 {
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
                let block_energy: f64 = left
                    .iter()
                    .chain(&right)
                    .map(|sample| {
                        assert!(sample.is_finite());
                        f64::from(sample.abs())
                    })
                    .sum();
                energy += block_energy;
                if block >= 1000 {
                    released += block_energy;
                }
            }
            (processor, energy, released)
        })
        .join()
        .unwrap();
        assert!(
            energy > 0.01,
            "DX10 must render audible note energy, got {energy}"
        );
        assert!(
            released < energy * 0.001,
            "the note-off must release the voice: {released} of {energy}"
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
        host.suspend(first).unwrap();
        let state = host.save_state(first).unwrap();
        host.resume(first).unwrap();
        assert!(host.is_processing(first).unwrap());
        assert!(!state.component.is_empty());
        host.restore_state(second, &state).unwrap();
        assert!(!host.is_processing(second).unwrap());
        let restored = host.save_state(second).unwrap();
        assert_eq!(restored.component, state.component);
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
        let text = host.parameter_text(first, parameter.id, 0.73).unwrap();
        let parsed = host.parse_parameter(first, parameter.id, &text).unwrap();
        assert!(
            (parsed - 0.73).abs() < 0.01,
            "{text:?} parsed back as {parsed}"
        );
        let plain = host.normalized_to_plain(first, parameter.id, 0.73).unwrap();
        let normalized = host
            .plain_to_normalized(first, parameter.id, plain)
            .unwrap();
        assert!((normalized - 0.73).abs() < 0.0001);
        assert!(host.parameter_text(first, parameter.id, f64::NAN).is_err());
        assert!(
            host.parse_parameter(first, parameter.id, "not a number")
                .is_err()
        );
        assert!(host.parameter_text(first, u32::MAX, 0.5).is_err());
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
        super::native_state::exercise_state_gateway(descriptor, config);
    }
}
