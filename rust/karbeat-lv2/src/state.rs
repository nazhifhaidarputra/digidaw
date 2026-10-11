//! Plugin state capture and restore through lilv's state API.
//!
//! lilv serialises a plugin's `state:interface` properties and its control-port values to
//! Turtle, resolving every URID to its URI. Properties may be nested atoms that carry URIDs,
//! which differ between sessions and between instances with separate URID maps, so storing the
//! raw property bytes would not survive a project reload. Plugins without a state interface
//! still round-trip their control ports.
//!
//! The lilv calls below bypass the `lilv` crate's world mutex. A bundle's world is owned and
//! used by the native UI thread alone, which is also where state work runs.

use std::ffi::{CStr, CString, c_char, c_void};

use karbeat_host_api::{HostError, PluginIdentity, PluginState};
use lilv_sys as sys;

use crate::{plugin::PluginInstance, urid, uris::ATOM, world::Lv2Bundle};

const STATE_VERSION: u32 = 1;
const MAX_STATE_BYTES: usize = 64 * 1024 * 1024;
/// Subject of the serialised state description; lilv requires one.
const STATE_URI: &CStr = c"urn:digidaw:plugin-state";

/// Plain value of one control input, saved and restored by port symbol.
pub(crate) struct PortValue {
    pub symbol: CString,
    pub value: f32,
}

fn invalid(message: &str) -> HostError {
    HostError::InvalidState(message.to_owned())
}

/// Rejects envelopes this backend did not write for this plugin.
pub(crate) fn validate(identity: &PluginIdentity, state: &PluginState) -> Result<(), HostError> {
    if state.version != STATE_VERSION
        || state.identity != *identity
        || state.component.len() > MAX_STATE_BYTES
        || state
            .controller
            .as_ref()
            .is_some_and(|controller| controller.len() > MAX_STATE_BYTES)
    {
        return Err(invalid("unsupported state version, identity, or size"));
    }
    Ok(())
}

fn atom_urid(name: &str) -> u32 {
    urid::map_str(&format!("{ATOM}{name}"))
}

struct CaptureContext<'a> {
    ports: &'a [PortValue],
    float: u32,
}

unsafe extern "C" fn port_value(
    symbol: *const c_char,
    user_data: *mut c_void,
    size: *mut u32,
    value_type: *mut u32,
) -> *const c_void {
    if symbol.is_null() || user_data.is_null() || size.is_null() || value_type.is_null() {
        return std::ptr::null();
    }
    // SAFETY: `user_data` is the context `capture` passes for this synchronous call.
    let context = unsafe { &*user_data.cast::<CaptureContext>() };
    // SAFETY: lilv passes a NUL-terminated port symbol valid for this call.
    let symbol = unsafe { CStr::from_ptr(symbol) };
    let Some(port) = context
        .ports
        .iter()
        .find(|port| port.symbol.as_c_str() == symbol)
    else {
        return std::ptr::null();
    };
    // SAFETY: lilv supplies a writable size output, checked for null above.
    unsafe { size.write(4) };
    // SAFETY: lilv supplies a writable type output, checked for null above.
    unsafe { value_type.write(context.float) };
    std::ptr::from_ref(&port.value).cast()
}

/// Captures the plugin's state and `ports` as a Turtle description.
///
/// The caller must hold exclusive suspended access to `instance`.
pub(crate) fn capture(
    bundle: &Lv2Bundle,
    identity: &PluginIdentity,
    instance: &PluginInstance,
    ports: &[PortValue],
) -> Result<PluginState, HostError> {
    let plugin = bundle.plugin_record(&identity.native_id)?;
    let context = CaptureContext {
        ports,
        float: atom_urid("Float"),
    };
    let features = [urid::map_feature(), urid::unmap_feature()];
    // State save must not overlap a worker job.
    let _worker = instance.exclude_worker();
    let feature_list = [
        std::ptr::from_ref(&features[0]),
        std::ptr::from_ref(&features[1]),
        std::ptr::null(),
    ];
    let flags = lv2_sys::LV2_State_Flags::LV2_STATE_IS_POD.0
        | lv2_sys::LV2_State_Flags::LV2_STATE_IS_PORTABLE.0;
    // SAFETY: Runs on the UI owner with processing suspended. Every pointer outlives this
    // synchronous call.
    let state = unsafe {
        sys::lilv_state_new_from_instance(
            plugin,
            instance.raw(),
            urid::map_ptr().cast(),
            std::ptr::null(),
            std::ptr::null(),
            std::ptr::null(),
            std::ptr::null(),
            Some(port_value),
            std::ptr::from_ref(&context).cast_mut().cast(),
            flags,
            feature_list.as_ptr().cast(),
        )
    };
    if state.is_null() {
        return Err(invalid("plugin state could not be captured"));
    }
    // SAFETY: The state was just created; the world and both URID records are alive.
    let text = unsafe {
        sys::lilv_state_to_string(
            bundle.world.as_ptr(),
            urid::map_ptr().cast(),
            urid::unmap_ptr().cast(),
            state,
            STATE_URI.as_ptr(),
            std::ptr::null(),
        )
    };
    // SAFETY: The state is owned here and not used again.
    unsafe { sys::lilv_state_free(state) };
    if text.is_null() {
        return Err(invalid("plugin state could not be serialised"));
    }
    // SAFETY: lilv returns a NUL-terminated string that stays valid until it is freed below.
    let component = unsafe { CStr::from_ptr(text) }.to_bytes().to_vec();
    // SAFETY: The string was allocated by lilv and is not used after this point.
    unsafe { sys::lilv_free(text.cast()) };
    if component.len() > MAX_STATE_BYTES {
        return Err(invalid("plugin state exceeds the size limit"));
    }
    Ok(PluginState {
        version: STATE_VERSION,
        identity: identity.clone(),
        component,
        controller: None,
    })
}

struct RestoreContext<'a> {
    apply: &'a mut dyn FnMut(&CStr, f32),
    float: u32,
    double: u32,
    int: u32,
    long: u32,
    boolean: u32,
}

#[allow(
    clippy::as_conversions,
    clippy::cast_possible_truncation,
    clippy::cast_precision_loss,
    reason = "control ports are single precision; lilv may hand back the saved value in a wider type"
)]
unsafe extern "C" fn port_restored(
    symbol: *const c_char,
    user_data: *mut c_void,
    value: *const c_void,
    size: u32,
    value_type: u32,
) {
    if symbol.is_null() || user_data.is_null() || value.is_null() {
        return;
    }
    // SAFETY: `user_data` is the context `restore` passes for this synchronous call.
    let context = unsafe { &mut *user_data.cast::<RestoreContext>() };
    // Pretty-printed Turtle numbers come back as doubles or longs, not as the float written.
    let plain = if value_type == context.float && size == 4 {
        // SAFETY: lilv passes `size` readable bytes of the stated type.
        unsafe { value.cast::<f32>().read_unaligned() }
    } else if value_type == context.double && size == 8 {
        // SAFETY: As above.
        (unsafe { value.cast::<f64>().read_unaligned() }) as f32
    } else if (value_type == context.int || value_type == context.boolean) && size == 4 {
        // SAFETY: As above.
        (unsafe { value.cast::<i32>().read_unaligned() }) as f32
    } else if value_type == context.long && size == 8 {
        // SAFETY: As above.
        (unsafe { value.cast::<i64>().read_unaligned() }) as f32
    } else {
        return;
    };
    if plain.is_finite() {
        // SAFETY: lilv passes a NUL-terminated port symbol valid for this call.
        let symbol = unsafe { CStr::from_ptr(symbol) };
        (context.apply)(symbol, plain);
    }
}

/// Restores a state written by [`capture`], reporting each saved control value to `apply`.
///
/// The caller must hold exclusive suspended access to `instance`.
pub(crate) fn restore(
    bundle: &Lv2Bundle,
    identity: &PluginIdentity,
    instance: &PluginInstance,
    state: &PluginState,
    apply: &mut dyn FnMut(&CStr, f32),
) -> Result<(), HostError> {
    validate(identity, state)?;
    let text = CString::new(state.component.as_slice())
        .map_err(|_| invalid("plugin state contains a NUL byte"))?;
    let expected = CString::new(identity.native_id.as_str())
        .map_err(|_| invalid("plugin URI contains a NUL byte"))?;
    // SAFETY: The world and URID map are alive and the text is NUL-terminated.
    let native_state = unsafe {
        sys::lilv_state_new_from_string(
            bundle.world.as_ptr(),
            urid::map_ptr().cast(),
            text.as_ptr(),
        )
    };
    if native_state.is_null() {
        return Err(invalid("plugin state could not be parsed"));
    }
    // SAFETY: The state was just created and is alive.
    let described = unsafe { sys::lilv_state_get_plugin_uri(native_state) };
    let matches = !described.is_null() && {
        // SAFETY: The node belongs to the live state.
        let uri = unsafe { sys::lilv_node_as_uri(described) };
        // SAFETY: A URI node's string is NUL-terminated and lives as long as the state.
        !uri.is_null() && unsafe { CStr::from_ptr(uri) } == expected.as_c_str()
    };
    if matches {
        let mut context = RestoreContext {
            apply,
            float: atom_urid("Float"),
            double: atom_urid("Double"),
            int: atom_urid("Int"),
            long: atom_urid("Long"),
            boolean: atom_urid("Bool"),
        };
        let features = [urid::map_feature(), urid::unmap_feature()];
        // State restore must not overlap a worker job.
        let _worker = instance.exclude_worker();
        let feature_list = [
            std::ptr::from_ref(&features[0]),
            std::ptr::from_ref(&features[1]),
            std::ptr::null(),
        ];
        // SAFETY: Runs on the UI owner with processing suspended; every pointer outlives this
        // synchronous call.
        unsafe {
            sys::lilv_state_restore(
                native_state,
                instance.raw(),
                Some(port_restored),
                (&raw mut context).cast(),
                0,
                feature_list.as_ptr().cast(),
            );
        };
    }
    // SAFETY: The state is owned here and not used again.
    unsafe { sys::lilv_state_free(native_state) };
    if matches {
        Ok(())
    } else {
        Err(invalid("plugin state describes a different plugin"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use karbeat_host_api::PluginFormat;

    fn identity(uri: &str) -> PluginIdentity {
        PluginIdentity {
            format: PluginFormat::Lv2,
            native_id: uri.into(),
        }
    }

    fn state(uri: &str) -> PluginState {
        PluginState {
            version: STATE_VERSION,
            identity: identity(uri),
            component: b"state".to_vec(),
            controller: None,
        }
    }

    #[test]
    fn envelopes_for_another_version_or_plugin_are_rejected() {
        let plugin = identity("urn:test:plugin");
        assert!(validate(&plugin, &state("urn:test:plugin")).is_ok());
        assert!(validate(&plugin, &state("urn:test:other")).is_err());
        let mut newer = state("urn:test:plugin");
        newer.version = STATE_VERSION + 1;
        assert!(matches!(
            validate(&plugin, &newer),
            Err(HostError::InvalidState(_))
        ));
        let mut vst3 = state("urn:test:plugin");
        vst3.identity.format = PluginFormat::Vst3;
        assert!(validate(&plugin, &vst3).is_err());
    }
}
