use karbeat_host::{
    HostError, PluginController, PluginDescriptor, PluginInstanceManager, ProcessingConfig,
    StateOperation,
};
use karbeat_plugin_api::types::{
    AudioBuffers, AudioBusBuffer, MidiEvent, MidiMessage, ProcessContext, ProcessingMode,
};
use karbeat_vst3::native;
use std::{
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::{Duration, Instant},
};

pub fn exercise_state_gateway(descriptor: PluginDescriptor, config: ProcessingConfig) {
    assert!(!native::available());
    let worker = std::thread::spawn(move || {
        let initial_descriptor = descriptor.clone();
        let initial_config = config.clone();
        let prepared = native::call(move |owner| {
            owner.create_prepared(&initial_descriptor, &initial_config, None)
        })
        .unwrap();
        let id = prepared.instance;
        assert!(prepared.capabilities.controller);
        assert!(!prepared.parameters.is_empty());
        assert!(!prepared.state.component.is_empty());
        let mut corrupt = prepared.state.clone();
        corrupt.version = u32::MAX;
        let failed_descriptor = descriptor.clone();
        let failed_config = config.clone();
        assert!(matches!(
            native::call(move |owner| owner.create_prepared(
                &failed_descriptor,
                &failed_config,
                Some(&corrupt)
            )),
            Err(HostError::InvalidState(_))
        ));

        let cancelled = native::call(move |owner| {
            let request = owner.request_state(id, StateOperation::Capture)?;
            assert!(matches!(
                owner.request_state(id, StateOperation::Capture),
                Err(HostError::Busy)
            ));
            assert!(matches!(owner.destroy(id), Err(HostError::Busy)));
            assert!(request.cancel());
            Ok(request)
        })
        .unwrap();
        assert!(matches!(
            cancelled.wait(Duration::from_secs(5)),
            Err(HostError::Cancelled)
        ));
        native::call(move |owner| {
            let request = owner.request_state(id, StateOperation::Capture)?;
            assert!(matches!(
                request.wait(Duration::ZERO),
                Err(HostError::WrongThread)
            ));
            Ok(())
        })
        .unwrap();
        native::call(move |owner| owner.host.resume(id)).unwrap();

        let stop = Arc::new(AtomicBool::new(false));
        let audio_stop = stop.clone();
        let audio = std::thread::spawn(move || {
            let mut processor = prepared.processor.install().unwrap();
            let mut left = [0.0_f32; 128];
            let mut right = [0.0_f32; 128];
            let notes = [MidiEvent {
                sample_offset: 0,
                data: MidiMessage::NoteOn {
                    note_id: Some(41),
                    channel: 0,
                    key: 60,
                    velocity: 100,
                },
            }];
            let mut block = 0_u64;
            while !audio_stop.load(Ordering::Acquire) {
                let context = ProcessContext {
                    bpm: 120.0,
                    time_sig_numerator: 4,
                    time_sig_denominator: 4,
                    is_playing: true,
                    is_recording: false,
                    mode: ProcessingMode::Realtime,
                    project_time_seconds: f64::from(u32::try_from(block).unwrap()) * 128.0
                        / 48000.0,
                    project_time_samples: block * 128,
                    beat_position: 0.0,
                    bar_position: 0.0,
                    loop_start_beat: None,
                    loop_end_beat: None,
                    midi_events: if block == 0 { &notes } else { &[] },
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
                processor.process(&mut buffers, &context);
                assert!(left.iter().chain(&right).all(|sample| sample.is_finite()));
                block += 1;
                std::thread::yield_now();
            }
            processor.retire();
            block
        });
        for _ in 0..3 {
            let deadline = Instant::now() + Duration::from_secs(5);
            let state = loop {
                match native::capture_state(id) {
                    Err(HostError::Busy) if Instant::now() < deadline => {
                        std::thread::yield_now();
                    }
                    result => break result.unwrap(),
                }
            };
            assert!(!state.component.is_empty());
            assert!(native::call(move |owner| owner.host.is_processing(id)).unwrap());
            native::restore_state(id, state).unwrap();
            assert!(native::call(move |owner| owner.host.is_processing(id)).unwrap());
        }
        let duplicate = native::duplicate_instance(id).unwrap();
        let duplicate_id = duplicate.instance;
        assert_ne!(duplicate_id, id);
        assert!(!duplicate.state.component.is_empty());
        native::call(move |owner| {
            assert!(owner.host.is_processing(id)?);
            assert!(!owner.host.is_processing(duplicate_id)?);
            assert_eq!(
                owner.host.processing_config(id)?,
                owner.host.processing_config(duplicate_id)?
            );
            Ok(())
        })
        .unwrap();
        let mut duplicate_processor = duplicate.processor.install().unwrap();
        let parameter = duplicate.parameters[0].id;
        let previous = duplicate_processor.get_parameter(parameter);
        let changed: f32 = if previous > 0.5 { 0.0 } else { 1.0 };
        native::call(move |owner| {
            owner
                .host
                .set_parameter(duplicate_id, parameter, f64::from(changed))
        })
        .unwrap();
        assert_eq!(duplicate_processor.get_parameter(parameter), changed);
        let sibling = native::duplicate_instance(id).unwrap();
        let sibling_processor = sibling.processor.install().unwrap();
        assert_eq!(sibling_processor.get_parameter(parameter), previous);
        duplicate_processor.set_parameter(parameter, previous);
        duplicate_processor.retire();
        sibling_processor.retire();
        let offline = native::prepare_offline_instance(id, 44_100, 256, 2).unwrap();
        let offline_id = offline.instance;
        assert_ne!(offline_id, id);
        native::call(move |owner| {
            let live = owner.host.processing_config(id)?;
            let export = owner.host.processing_config(offline_id)?;
            assert!(!live.offline);
            assert_eq!(live.sample_rate, 48_000.0);
            assert!(export.offline);
            assert_eq!(export.sample_rate, 44_100.0);
            assert_eq!(export.max_block_size, 256);
            Ok(())
        })
        .unwrap();
        let mut offline_processor = offline.processor.install().unwrap();
        let mut left = [0.0_f32; 256];
        let mut right = [0.0_f32; 256];
        let notes = [MidiEvent {
            sample_offset: 5,
            data: MidiMessage::NoteOn {
                note_id: Some(42),
                channel: 0,
                key: 64,
                velocity: 100,
            },
        }];
        let mut energy = 0.0_f64;
        for block in 0_u32..32 {
            let context = ProcessContext {
                bpm: 120.0,
                time_sig_numerator: 4,
                time_sig_denominator: 4,
                is_playing: true,
                is_recording: false,
                mode: ProcessingMode::Offline,
                project_time_seconds: f64::from(block * 256) / 44100.0,
                project_time_samples: u64::from(block * 256),
                beat_position: 0.0,
                bar_position: 0.0,
                loop_start_beat: None,
                loop_end_beat: None,
                midi_events: if block == 0 { &notes } else { &[] },
                param_changes: &[],
            };
            let mut channels: [&mut [f32]; 2] = [&mut left, &mut right];
            let mut output = [AudioBusBuffer {
                channel_data: &mut channels,
                is_silent: false,
            }];
            offline_processor.process(
                &mut AudioBuffers {
                    main_inputs: &mut [],
                    main_outputs: &mut output,
                    aux_inputs: &mut [],
                    aux_outputs: &mut [],
                },
                &context,
            );
            for sample in left.iter().chain(&right) {
                assert!(sample.is_finite());
                energy += f64::from(sample.abs());
            }
        }
        assert!(
            energy > 0.01,
            "independent Vital export instance must produce audio"
        );
        drop(offline_processor);
        let deadline = Instant::now() + Duration::from_secs(5);
        while native::call(move |owner| owner.host.is_processing(offline_id)).is_ok() {
            assert!(
                Instant::now() < deadline,
                "worker-dropped offline instance did not retire"
            );
        }
        assert!(native::call(move |owner| owner.host.is_processing(id)).unwrap());
        stop.store(true, Ordering::Release);
        assert!(audio.join().unwrap() > 0);
        let deadline = Instant::now() + Duration::from_secs(5);
        while native::call(move |owner| owner.host.is_processing(id)).is_ok() {
            assert!(
                Instant::now() < deadline,
                "retired endpoint was not destroyed on the UI owner"
            );
        }

        let abandoned =
            native::call(move |owner| owner.create_prepared(&descriptor, &config, None)).unwrap();
        let abandoned_id = abandoned.instance;
        drop(abandoned);
        let deadline = Instant::now() + Duration::from_secs(5);
        loop {
            match native::capture_state(abandoned_id) {
                Err(HostError::UnknownInstance(stale)) if stale == abandoned_id => break,
                Ok(_) => assert!(
                    Instant::now() < deadline,
                    "abandoned transfer did not retire"
                ),
                result => panic!("unexpected retirement result: {result:?}"),
            }
        }
    });
    let context = glib::MainContext::default();
    let deadline = Instant::now() + Duration::from_secs(60);
    while !worker.is_finished() {
        assert!(Instant::now() < deadline, "native state gateway timed out");
        context.iteration(false);
        std::thread::sleep(Duration::from_millis(1));
    }
    worker.join().unwrap();
    assert!(native::available());
    assert!(matches!(
        native::call(|_| Ok(())),
        Err(HostError::WrongThread)
    ));
}
