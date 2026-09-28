use karbeat_host_api::{
    HostInstanceId, NativeEditorBinding, NativeEditorEvent, NativeSurfaceKind, NativeUiPlatform,
    NativeWindow, NativeWindowIdAllocator, NativeWindowSize, NativeWindowSpec, PluginEditorManager,
    SystemNativeUi,
};
use karbeat_vst3::Vst3PluginHost;
use std::{
    cell::RefCell,
    rc::Rc,
    time::{Duration, Instant},
};

pub fn exercise_editor(host: &mut Vst3PluginHost, instance: HostInstanceId) {
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
                    title: "DigiDAW — Vital editor acceptance",
                    initial_size: size,
                    constraints,
                    initially_visible: false,
                    preferred_surface,
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
        binding.borrow_mut().mark_attached().unwrap();
        binding.borrow_mut().show().unwrap();
        binding.borrow_mut().request_focus().unwrap();

        let until = Instant::now() + Duration::from_secs(3);
        while Instant::now() < until {
            native_ui
                .poll_events(|event| {
                    if let NativeEditorEvent::ExternalResize(size) =
                        binding.borrow_mut().handle_event(event).unwrap()
                    {
                        host.resize_editor(instance, size.width, size.height)
                            .unwrap();
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
