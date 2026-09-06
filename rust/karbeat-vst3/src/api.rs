use std::{
    cell::{Cell, RefCell},
    ptr,
};

use karbeat_plugin_api::types::PluginCategory;
use vst3::{
    Class, ComPtr, ComWrapper, Interface,
    Steinberg::{
        Vst::{ParameterInfo_::ParameterFlags_, *},
        *,
    },
};

/// Metadata a plugin scanner already has from `PClassInfo`/`PClassInfo2` before `create()` is
/// ever called -- there is no way to ask a live `IComponent` for its own name/vendor/category.
pub struct Vst3PluginInfo {
    pub name: String,
    pub vendor: String,
    pub version: String,
    pub category: PluginCategory,
}

// ---------------------------------------------------------------------------
// MemoryStream -- in-memory IBStream for IComponent::getState/setState.
// ---------------------------------------------------------------------------

#[derive(Default)]
pub struct MemoryStream {
    pub data: RefCell<Vec<u8>>,
    pub position: Cell<usize>,
}

impl Class for MemoryStream {
    type Interfaces = (IBStream,);
}

impl IBStreamTrait for MemoryStream {
    unsafe fn read(
        &self,
        buffer: *mut std::ffi::c_void,
        num_bytes: i32,
        num_bytes_read: *mut i32,
    ) -> tresult {
        if buffer.is_null() || num_bytes < 0 {
            return kResultFalse;
        }
        let pos = self.position.get();
        let want = num_bytes as usize;
        let data = self.data.borrow();
        let take = want.min(data.len().saturating_sub(pos));
        if take > 0 {
            unsafe { ptr::copy_nonoverlapping(data.as_ptr().add(pos), buffer.cast::<u8>(), take) };
        }
        self.position.set(pos + take);
        if !num_bytes_read.is_null() {
            unsafe { *num_bytes_read = take as i32 };
        }
        kResultOk
    }

    unsafe fn write(
        &self,
        buffer: *mut std::ffi::c_void,
        num_bytes: i32,
        num_bytes_written: *mut i32,
    ) -> tresult {
        if buffer.is_null() || num_bytes < 0 {
            return kResultFalse;
        }
        let pos = self.position.get();
        let want = num_bytes as usize;
        let mut data = self.data.borrow_mut();
        if data.len() < pos + want {
            data.resize(pos + want, 0);
        }
        unsafe { ptr::copy_nonoverlapping(buffer.cast::<u8>(), data.as_mut_ptr().add(pos), want) };
        self.position.set(pos + want);
        if !num_bytes_written.is_null() {
            unsafe { *num_bytes_written = want as i32 };
        }
        kResultOk
    }

    unsafe fn seek(&self, pos: i64, mode: i32, result: *mut i64) -> tresult {
        let data_len = self.data.borrow().len() as i64;
        let current = self.position.get() as i64;
        let new_pos = match mode {
            0 => pos,
            1 => current + pos,
            2 => data_len + pos,
            _ => return kResultFalse,
        };
        if new_pos < 0 {
            return kResultFalse;
        }
        self.position.set(new_pos as usize);
        if !result.is_null() {
            unsafe { *result = new_pos };
        }
        kResultOk
    }

    unsafe fn tell(&self, pos: *mut i64) -> tresult {
        if pos.is_null() {
            return kResultFalse;
        }
        unsafe { *pos = self.position.get() as i64 };
        kResultOk
    }
}

// ---------------------------------------------------------------------------
// Minimal IParameterChanges / IParamValueQueue for feeding automation into process().
// ---------------------------------------------------------------------------

#[derive(Default)]
pub struct SimpleParamValueQueue {
    pub param_id: Cell<u32>,
    pub points: RefCell<Vec<(i32, f64)>>,
}

impl Class for SimpleParamValueQueue {
    type Interfaces = (IParamValueQueue,);
}

#[allow(
    non_snake_case,
    reason = "The method names follow the Vst3 API convention"
)]
impl IParamValueQueueTrait for SimpleParamValueQueue {
    unsafe fn getParameterId(&self) -> ParamID {
        self.param_id.get()
    }
    unsafe fn getPointCount(&self) -> i32 {
        self.points.borrow().len() as i32
    }
    unsafe fn getPoint(
        &self,
        index: i32,
        sample_offset: *mut i32,
        value: *mut ParamValue,
    ) -> tresult {
        let points = self.points.borrow();
        let Some(&(offset, val)) = points.get(index as usize) else {
            return kResultFalse;
        };
        unsafe {
            *sample_offset = offset;
            *value = val;
        }
        kResultOk
    }
    unsafe fn addPoint(&self, sample_offset: i32, value: ParamValue, index: *mut i32) -> tresult {
        let mut points = self.points.borrow_mut();
        points.push((sample_offset, value));
        if !index.is_null() {
            unsafe { *index = points.len() as i32 - 1 };
        }
        kResultOk
    }
}

#[derive(Default)]
pub struct SimpleParameterChanges {
    pub queues: RefCell<Vec<ComWrapper<SimpleParamValueQueue>>>,
}

impl Class for SimpleParameterChanges {
    type Interfaces = (IParameterChanges,);
}

impl IParameterChangesTrait for SimpleParameterChanges {
    unsafe fn getParameterCount(&self) -> i32 {
        self.queues.borrow().len() as i32
    }
    unsafe fn getParameterData(&self, index: i32) -> *mut IParamValueQueue {
        self.queues
            .borrow()
            .get(index as usize)
            .and_then(|q| q.as_com_ref::<IParamValueQueue>())
            .map(|r| r.as_ptr())
            .unwrap_or(ptr::null_mut())
    }
    unsafe fn addParameterData(
        &self,
        id: *const ParamID,
        index: *mut i32,
    ) -> *mut IParamValueQueue {
        let id = unsafe { *id };
        let queue = ComWrapper::new(SimpleParamValueQueue::default());
        queue.param_id.set(id);
        let out_ptr = queue
            .as_com_ref::<IParamValueQueue>()
            .map(|r| r.as_ptr())
            .unwrap_or(ptr::null_mut());
        let mut queues = self.queues.borrow_mut();
        queues.push(queue);
        if !index.is_null() {
            unsafe { *index = queues.len() as i32 - 1 };
        }
        out_ptr
    }
}

/// `factory.createInstance` for `I`, wrapped as a `ComPtr<I>`. Uses `I::IID` directly so the
/// plugin returns the interface we actually asked for.
pub unsafe fn create_instance<I: Interface>(
    factory: &ComPtr<IPluginFactory>,
    cid: &TUID,
) -> Option<ComPtr<I>> {
    let mut obj: *mut std::ffi::c_void = ptr::null_mut();
    let iid_bytes: &TUID = unsafe { &*(std::ptr::from_ref(&I::IID).cast::<TUID>()) };
    if unsafe { factory.createInstance(cid.as_ptr(), iid_bytes.as_ptr(), &raw mut obj) }
        != kResultOk
        || obj.is_null()
    {
        return None;
    }
    unsafe { ComPtr::<I>::from_raw(obj.cast()) }
}

pub type Vst3ParameterInfo = ParameterInfo;

pub fn empty_parameter_info() -> Vst3ParameterInfo {
    Vst3ParameterInfo {
        id: 0,
        title: [0; 128],
        shortTitle: [0; 128],
        units: [0; 128],
        stepCount: 0,
        defaultNormalizedValue: 0.0,
        unitId: 0,
        flags: 0,
    }
}

pub fn find_bypass_param(ctrl: &ComPtr<IEditController>) -> Option<u32> {
    let count = unsafe { ctrl.getParameterCount() };
    for i in 0..count {
        let mut info = empty_parameter_info();
        if unsafe { ctrl.getParameterInfo(i, &raw mut info) } == kResultOk
            && info.flags & ParameterFlags_::kIsBypass != 0
        {
            return Some(info.id);
        }
    }
    None
}

/// Decodes a `String128` (UTF-16, nul-terminated) the same way your `getName` impl already
/// writes one -- via a raw `u16` reinterpretation of the buffer.
pub fn string128_to_string(buf: &String128) -> String {
    let ptr = (buf as *const String128).cast::<u16>();
    let slice = unsafe { std::slice::from_raw_parts(ptr, 128) };
    let len = slice.iter().position(|&c| c == 0).unwrap_or(128);
    String::from_utf16_lossy(&slice[..len])
}
