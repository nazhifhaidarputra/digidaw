use vst3::{
    Class,
    Steinberg::{
        Vst::{IHostApplication, IHostApplicationTrait},
        kNotImplemented, kResultOk,
    },
};

pub struct Vst3HostContext {
    pub host_name: String,
}

impl Class for Vst3HostContext {
    type Interfaces = (IHostApplication,);
}

#[allow(
    non_snake_case,
    reason = "the implementation method names are fixed by the VST3 COM interface"
)]
impl IHostApplicationTrait for Vst3HostContext {
    unsafe fn getName(
        &self,
        name: *mut vst3::Steinberg::Vst::String128,
    ) -> vst3::Steinberg::tresult {
        // VST3 strings are UTF-16 arrays
        let mut encoded: Vec<u16> = self.host_name.encode_utf16().collect();
        encoded.push(0); // Null terminator

        // SAFETY: VST3 supplies a writable String128 buffer for the duration of this call.
        let out_slice = unsafe { std::slice::from_raw_parts_mut(name.cast::<u16>(), 128) };
        let len = encoded.len().min(128);
        out_slice[..len].copy_from_slice(&encoded[..len]);

        kResultOk
    }

    unsafe fn createInstance(
        &self,
        _cid: *mut vst3::Steinberg::TUID,
        _iid: *mut vst3::Steinberg::TUID,
        _obj: *mut *mut ::std::ffi::c_void,
    ) -> vst3::Steinberg::tresult {
        // Used for advanced routing/sub-plugins. Safe to return Not Implemented for now.
        kNotImplemented
    }
}
