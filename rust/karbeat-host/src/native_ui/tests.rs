use super::*;

#[test]
fn ids_are_monotonic_and_never_zero() {
    let mut ids = NativeWindowIdAllocator::default();
    let first = ids.allocate().unwrap();
    let second = ids.allocate().unwrap();
    assert_eq!(first.get(), 1);
    assert_eq!(second.get(), 2);
}

#[test]
fn sizes_and_fixed_constraints_are_validated() {
    let size = NativeWindowSize::new(640, 480).unwrap();
    assert_eq!(NativeWindowConstraints::fixed(size).min, Some(size));
    assert!(NativeWindowSize::new(0, 480).is_err());
    assert!(NativeWindowSize::new(MAX_NATIVE_WINDOW_DIMENSION + 1, 480).is_err());
}

#[test]
fn surface_preferences_require_or_fall_back() {
    let capabilities = NativeSurfaceCapabilities {
        x11: true,
        wayland: false,
        win32: false,
        appkit: false,
    };
    assert_eq!(
        capabilities
            .select(NativeSurfacePreference::Require(NativeSurfaceKind::X11))
            .unwrap(),
        NativeSurfaceKind::X11
    );
    assert_eq!(
        capabilities
            .select(NativeSurfacePreference::Prefer {
                primary: NativeSurfaceKind::Wayland,
                fallback: Some(NativeSurfaceKind::X11),
            })
            .unwrap(),
        NativeSurfaceKind::X11
    );
    assert!(
        capabilities
            .select(NativeSurfacePreference::Require(NativeSurfaceKind::Wayland))
            .is_err()
    );
}
