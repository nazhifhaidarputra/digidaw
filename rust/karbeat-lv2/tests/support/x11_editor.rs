#![allow(
    clippy::unwrap_used,
    reason = "integration test setup failures should fail the test"
)]

use karbeat_host_api::{
    HostInstanceId, NativeEditorBinding, NativeEditorEvent, NativeSurfaceKind, NativeUiPlatform,
    NativeWindow, NativeWindowIdAllocator, NativeWindowSize, NativeWindowSpec, PluginEditorManager,
    SystemNativeUi,
};
use karbeat_lv2::Lv2PluginHost;
use std::{
    cell::RefCell,
    rc::Rc,
    time::{Duration, Instant},
};

/// Opens the instance's editor twice in a host window, pumping it for a few seconds each time
/// while `audio` keeps the plugin processing.
pub fn exercise_editor(
    host: &mut Lv2PluginHost,
    instance: HostInstanceId,
    audio: &mut dyn FnMut(),
) {
    let (mut native_ui, _) = SystemNativeUi::initialize().unwrap();
    let mut window_ids = NativeWindowIdAllocator::default();
    for _ in 0..2 {
        let size = host.editor_size(instance).unwrap();
        let constraints = host.editor_constraints(instance).unwrap();
        let preferred_surface = host.editor_surface_preference(instance).unwrap();
        assert_eq!(
            native_ui.capabilities().select(preferred_surface).unwrap(),
            NativeSurfaceKind::X11
        );
        let window = native_ui
            .create_window(
                window_ids.allocate().unwrap(),
                &NativeWindowSpec {
                    title: "DigiDAW — LV2 editor acceptance",
                    initial_size: size,
                    constraints,
                    initially_visible: false,
                    preferred_surface,
                    stay_on_top: false,
                },
            )
            .unwrap();
        let binding = Rc::new(RefCell::new(NativeEditorBinding::new(window).unwrap()));
        let resize_binding = Rc::downgrade(&binding);
        host.set_editor_resize_handler(
            instance,
            Rc::new(move |width, height| {
                let Ok(size) = NativeWindowSize::new(width, height) else {
                    return false;
                };
                resize_binding.upgrade().is_some_and(|binding| {
                    binding
                        .try_borrow_mut()
                        .is_ok_and(|mut binding| binding.resize_window(size).is_ok())
                })
            }),
        )
        .unwrap();
        let parent = binding.borrow().window().unwrap().parent_handle().unwrap();
        host.open_editor(instance, &parent).unwrap();
        // An X11 UI only knows its size once it exists inside the parent.
        let attached = host.editor_size(instance).unwrap();
        assert!(attached.width > 1 && attached.height > 1);
        binding.borrow_mut().resize_window(attached).unwrap();
        binding.borrow_mut().mark_attached().unwrap();
        binding.borrow_mut().show().unwrap();
        binding.borrow_mut().request_focus().unwrap();

        let until = Instant::now() + Duration::from_secs(3);
        while Instant::now() < until {
            audio();
            native_ui
                .poll_events(|event| {
                    if let NativeEditorEvent::ExternalResize(size) =
                        binding.borrow_mut().handle_event(event).unwrap()
                    {
                        drop(host.resize_editor(instance, size.width, size.height));
                    }
                })
                .unwrap();
            native_ui.pump().unwrap();
            host.pump().unwrap();
            std::thread::sleep(Duration::from_millis(8));
        }

        assert!(binding.borrow_mut().begin_close());
        host.close_editor(instance).unwrap();
        binding.borrow_mut().finish_close().unwrap();
        host.close_editor(instance).unwrap();
        host.pump().unwrap();
    }
}

/// Opens the editor through the native runtime, the way the application does: the runtime
/// creates the host window, attaches the editor, and sizes the window to what the editor
/// reports once it exists.
pub fn exercise_native_editor(
    descriptor: karbeat_host_api::PluginDescriptor,
    config: karbeat_host_api::ProcessingConfig,
) {
    use karbeat_host_api::PluginInstanceManager as _;
    use karbeat_lv2::native;
    use karbeat_plugin_api::types::{AudioBuffers, AudioBusBuffer, ProcessContext, ProcessingMode};
    use std::sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    };

    fn run<T>(
        future: impl Future<Output = Result<T, karbeat_host_api::HostError>>,
    ) -> Result<T, karbeat_host_api::HostError> {
        futures_lite::future::block_on(future)
    }

    let worker = std::thread::spawn(move || {
        let prepared = run(native::prepare_instance(descriptor, config, None)).unwrap();
        let id = prepared.instance;
        assert!(prepared.capabilities.editor);
        run(native::call(move |owner| owner.host.resume(id))).unwrap();
        let stop = Arc::new(AtomicBool::new(false));
        let audio_stop = stop.clone();
        let audio = std::thread::spawn(move || {
            let mut processor = prepared.processor.install().unwrap();
            let mut block = 0_u64;
            while !audio_stop.load(Ordering::Acquire) {
                let (mut in_l, mut in_r) = ([0.1_f32; 128], [0.1_f32; 128]);
                let (mut out_l, mut out_r) = ([0.0_f32; 128], [0.0_f32; 128]);
                let mut inputs: [&mut [f32]; 2] = [&mut in_l, &mut in_r];
                let mut outputs: [&mut [f32]; 2] = [&mut out_l, &mut out_r];
                let mut main = [AudioBusBuffer {
                    channel_data: &mut inputs,
                    is_silent: false,
                }];
                let mut output = [AudioBusBuffer {
                    channel_data: &mut outputs,
                    is_silent: false,
                }];
                processor.process(
                    &mut AudioBuffers {
                        main_inputs: &mut main,
                        main_outputs: &mut output,
                        aux_inputs: &mut [],
                        aux_outputs: &mut [],
                    },
                    &ProcessContext {
                        bpm: 120.0,
                        time_sig_numerator: 4,
                        time_sig_denominator: 4,
                        is_playing: true,
                        is_recording: false,
                        mode: ProcessingMode::Realtime,
                        project_time_seconds: 0.0,
                        project_time_samples: block * 128,
                        beat_position: 0.0,
                        bar_position: 0.0,
                        loop_start_beat: None,
                        loop_end_beat: None,
                        midi_events: &[],
                        param_changes: &[],
                    },
                );
                assert!(out_l.iter().chain(&out_r).all(|sample| sample.is_finite()));
                block += 1;
                std::thread::sleep(Duration::from_millis(2));
            }
            processor.retire();
        });
        for round in 0..2 {
            run(native::call(move |owner| {
                owner.set_editor_context(id, format!("Track {round}"))?;
                owner.open_editor(id)
            }))
            .unwrap();
            // Opening an editor that is already open only focuses its window.
            run(native::call(move |owner| owner.open_editor(id))).unwrap();
            std::thread::sleep(Duration::from_secs(2));
            let size = run(native::call(move |owner| owner.host.editor_size(id))).unwrap();
            assert!(
                size.width > 1 && size.height > 1,
                "the editor must report a real size once attached"
            );
            assert!(run(native::call(move |owner| owner.host.is_processing(id))).unwrap());
            run(native::call(move |owner| owner.close_editor(id))).unwrap();
        }
        stop.store(true, Ordering::Release);
        audio.join().unwrap();
        let deadline = Instant::now() + Duration::from_secs(5);
        while run(native::call(move |owner| owner.host.is_processing(id))).is_ok() {
            assert!(
                Instant::now() < deadline,
                "retired endpoint was not destroyed on the UI owner"
            );
        }
    });
    let context = glib::MainContext::default();
    let deadline = Instant::now() + Duration::from_secs(60);
    while !worker.is_finished() {
        assert!(Instant::now() < deadline, "native editor run timed out");
        context.iteration(false);
        std::thread::sleep(Duration::from_millis(1));
    }
    worker.join().unwrap();
}
