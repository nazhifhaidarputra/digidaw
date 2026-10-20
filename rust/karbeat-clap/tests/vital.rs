//! Opt-in instrument tests with Vital's CLAP build:
//! VITAL_CLAP_PATH=/usr/lib/clap/Vital.clap cargo test -p karbeat-clap --test vital -- --ignored --test-threads=1
//!
//! The suite is compiled only on Linux, where the default path applies; other platforms build an
//! empty `main` because this target runs without the libtest harness.

#![allow(
    clippy::unwrap_used,
    clippy::panic,
    reason = "integration test setup failures should fail the test"
)]

fn main() {
    #[cfg(target_os = "linux")]
    vital::main();
}

#[cfg(target_os = "linux")]
mod vital {
    use karbeat_clap::{ClapPluginHost, module::ClapModule};
    use karbeat_host_api::{
        HostError, PluginController, PluginInstanceManager, PluginKind, ProcessingConfig,
    };
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

    fn context(block: u32, events: &[MidiEvent]) -> ProcessContext<'_> {
        ProcessContext {
            bpm: 120.0,
            time_sig_numerator: 4,
            time_sig_denominator: 4,
            is_playing: true,
            is_recording: false,
            mode: ProcessingMode::Realtime,
            project_time_seconds: f64::from(block.saturating_mul(128)) / 48_000.0,
            project_time_samples: u64::from(block.saturating_mul(128)),
            beat_position: 0.0,
            bar_position: 0.0,
            loop_start_beat: None,
            loop_end_beat: None,
            midi_events: events,
            param_changes: &[],
        }
    }

    pub fn main() {
        if std::env::var_os("VITAL_CLAP_PATH").is_none()
            && !std::env::args().any(|arg| arg == "--ignored")
        {
            return;
        }
        let path = std::env::var_os("VITAL_CLAP_PATH")
            .map_or_else(|| PathBuf::from("/usr/lib/clap/Vital.clap"), PathBuf::from);
        let descriptor = ClapModule::load(&path)
            .unwrap()
            .descriptors()
            .unwrap()
            .into_iter()
            .find(|p| p.name == "Vital")
            .unwrap();
        assert_eq!(descriptor.kind, PluginKind::Instrument);
        assert_eq!(karbeat_clap::probe_module(&path).unwrap().len(), 1);
        let mut host = ClapPluginHost::new();
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
        let parameters = host.parameters(first).unwrap();
        assert!(!parameters.is_empty());
        assert!(parameters.iter().all(|p| p.path.starts_with("clap/")));
        let continuous = parameters.iter().find(|p| p.step == 0.0).unwrap().id;
        assert!(
            !host
                .parameter_text(first, continuous, 0.5)
                .unwrap()
                .is_empty()
        );

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
                let events = match block {
                    0 => &note_on[..],
                    256 => &note_off[..],
                    _ => &[],
                };
                let context = context(block, events);
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
                // The first block starts processing, which plugins may allocate for.
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
        assert!(processor.processing_error().is_none());
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
        assert!(!host.save_state(second).unwrap().component.is_empty());
        let mut invalid = state;
        invalid.version = u32::MAX;
        host.suspend(first).unwrap();
        assert!(matches!(
            host.restore_state(first, &invalid),
            Err(HostError::InvalidState(_))
        ));
        host.resume(first).unwrap();

        let other_value = other.get_parameter(continuous);
        processor.set_parameter(continuous, 0.73);
        assert!((processor.get_parameter(continuous) - 0.73).abs() < 0.0001);
        assert_eq!(other.get_parameter(continuous), other_value);
        host.suspend(first).unwrap();
        host.flush_parameters(first).unwrap();
        let flushed = host
            .parameters(first)
            .unwrap()
            .into_iter()
            .find(|p| p.id == continuous)
            .unwrap();
        assert!((flushed.value - 0.73).abs() < 0.001, "{}", flushed.value);
        host.resume(first).unwrap();

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
        assert!(host.destroy(first).is_err());
        drop(retirement.take().unwrap());
        assert!(host.take_processor(first).is_err());
        drop(other);
        host.destroy(first).unwrap();
        host.destroy(second).unwrap();
        assert!(host.parameters(first).is_err());
    }
}
