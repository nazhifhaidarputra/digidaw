//! UI-thread host services and lock-free parameter exchange.
#![allow(non_snake_case, reason = "VST3 interface method names are ABI-defined")]

use std::{
    cell::RefCell,
    collections::HashMap,
    ffi::{CStr, CString, c_void},
    ptr,
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicI32, AtomicU8, AtomicU64, Ordering},
    },
    thread::ThreadId,
};
use vst3::{
    Class, ComWrapper, Interface,
    Steinberg::{Vst::*, *},
};

pub struct ParameterValue {
    pub id: u32,
    pub value: AtomicU64,
    pub pending: AtomicBool,
    pub edits: AtomicU8,
}
impl ParameterValue {
    pub fn get(&self) -> f64 {
        f64::from_bits(self.value.load(Ordering::Acquire))
    }
    pub fn set(&self, value: f64, edit: u8) {
        self.value.store(value.to_bits(), Ordering::Release);
        self.pending.store(true, Ordering::Release);
        self.edits.fetch_or(edit, Ordering::Relaxed);
    }
}

pub struct ParameterExchange {
    pub parameters: Vec<ParameterValue>,
    pub restart: AtomicI32,
    pub overflow: AtomicBool,
    pub process_error: Arc<AtomicI32>,
}
impl ParameterExchange {
    pub fn new(values: &[(u32, f64)]) -> Arc<Self> {
        Arc::new(Self {
            parameters: values
                .iter()
                .map(|&(id, value)| ParameterValue {
                    id,
                    value: AtomicU64::new(value.to_bits()),
                    pending: AtomicBool::new(false),
                    edits: AtomicU8::new(0),
                })
                .collect(),
            restart: AtomicI32::new(0),
            overflow: AtomicBool::new(false),
            process_error: Arc::new(AtomicI32::new(0)),
        })
    }
    pub fn parameter(&self, id: u32) -> Option<&ParameterValue> {
        self.parameters
            .binary_search_by_key(&id, |p| p.id)
            .ok()
            .map(|i| &self.parameters[i])
    }
}

pub struct ComponentHandler {
    pub exchange: Arc<ParameterExchange>,
}
impl Class for ComponentHandler {
    type Interfaces = (IComponentHandler,);
}
impl IComponentHandlerTrait for ComponentHandler {
    unsafe fn beginEdit(&self, id: u32) -> tresult {
        let Some(param) = self.exchange.parameter(id) else {
            return kInvalidArgument;
        };
        param.edits.fetch_or(1, Ordering::Relaxed);
        kResultOk
    }
    unsafe fn performEdit(&self, id: u32, value: f64) -> tresult {
        let Some(param) = self.exchange.parameter(id) else {
            return kInvalidArgument;
        };
        if !value.is_finite() || !(0.0..=1.0).contains(&value) {
            return kInvalidArgument;
        }
        param.set(value, 2);
        kResultOk
    }
    unsafe fn endEdit(&self, id: u32) -> tresult {
        let Some(param) = self.exchange.parameter(id) else {
            return kInvalidArgument;
        };
        param.edits.fetch_or(4, Ordering::Relaxed);
        kResultOk
    }
    unsafe fn restartComponent(&self, flags: i32) -> tresult {
        self.exchange.restart.fetch_or(flags, Ordering::Release);
        kResultOk
    }
}

pub struct Vst3HostContext {
    owner: ThreadId,
    pub run_loop: std::rc::Rc<crate::run_loop::RunLoop>,
}
impl Default for Vst3HostContext {
    fn default() -> Self {
        Self {
            owner: std::thread::current().id(),
            run_loop: crate::run_loop::RunLoop::new(),
        }
    }
}
#[cfg(target_os = "linux")]
impl Class for Vst3HostContext {
    type Interfaces = (IHostApplication, Linux::IRunLoop);
}
#[cfg(not(target_os = "linux"))]
impl Class for Vst3HostContext {
    type Interfaces = (IHostApplication,);
}
impl IHostApplicationTrait for Vst3HostContext {
    unsafe fn getName(&self, name: *mut String128) -> tresult {
        if name.is_null() {
            return kInvalidArgument;
        }
        let mut output = [0; 128];
        for (slot, ch) in output.iter_mut().zip("DigiDAW".encode_utf16()) {
            *slot = ch;
        }
        // SAFETY: Caller supplies a writable String128; its full initialized value is copied.
        unsafe { *name = output };
        kResultOk
    }
    unsafe fn createInstance(
        &self,
        cid: *mut TUID,
        iid: *mut TUID,
        out: *mut *mut c_void,
    ) -> tresult {
        if out.is_null() {
            return kInvalidArgument;
        }
        // SAFETY: out is a writable output pointer.
        unsafe { *out = ptr::null_mut() };
        if cid.is_null() || iid.is_null() || self.owner != std::thread::current().id() {
            return kInvalidArgument;
        }
        // SAFETY: Both IDs point to readable fixed arrays supplied by the plugin.
        let cid = unsafe { *cid }.map(|b| b.to_ne_bytes()[0]);
        // SAFETY: iid is a readable TUID checked above.
        let iid = unsafe { *iid }.map(|b| b.to_ne_bytes()[0]);
        let object = if cid == IMessage::IID && iid == IMessage::IID {
            ComWrapper::new(HostMessage::default())
                .to_com_ptr::<IMessage>()
                .map(|p| p.into_raw().cast::<c_void>())
        } else if cid == IAttributeList::IID && iid == IAttributeList::IID {
            ComWrapper::new(HostAttributes::default())
                .to_com_ptr::<IAttributeList>()
                .map(|p| p.into_raw().cast::<c_void>())
        } else {
            return kNoInterface;
        };
        let Some(object) = object else {
            return kNoInterface;
        };
        // SAFETY: Transfer the new object's owned reference to the caller.
        unsafe { *out = object };
        kResultOk
    }
}

enum Attribute {
    Int(i64),
    Float(f64),
    String(Vec<u16>),
    Binary(Vec<u8>),
}
struct HostAttributes {
    owner: ThreadId,
    values: RefCell<HashMap<Vec<u8>, Attribute>>,
}
impl Default for HostAttributes {
    fn default() -> Self {
        Self {
            owner: std::thread::current().id(),
            values: RefCell::new(HashMap::new()),
        }
    }
}
impl HostAttributes {
    unsafe fn key(&self, id: FIDString) -> Option<Vec<u8>> {
        if id.is_null() || self.owner != std::thread::current().id() {
            return None;
        }
        // SAFETY: VST3 FIDString is a NUL-terminated string valid for this call.
        Some(unsafe { CStr::from_ptr(id) }.to_bytes().to_vec())
    }
}
impl Class for HostAttributes {
    type Interfaces = (IAttributeList,);
}
impl IAttributeListTrait for HostAttributes {
    unsafe fn setInt(&self, id: FIDString, value: i64) -> tresult {
        // SAFETY: FIDString lifetime follows the method's ABI contract.
        let Some(key) = (unsafe { self.key(id) }) else {
            return kInvalidArgument;
        };
        self.values.borrow_mut().insert(key, Attribute::Int(value));
        kResultOk
    }
    unsafe fn getInt(&self, id: FIDString, out: *mut i64) -> tresult {
        if out.is_null() {
            return kInvalidArgument;
        }
        // SAFETY: FIDString lifetime follows the method's ABI contract.
        let Some(key) = (unsafe { self.key(id) }) else {
            return kInvalidArgument;
        };
        let values = self.values.borrow();
        let Some(Attribute::Int(value)) = values.get(&key) else {
            return kResultFalse;
        };
        // SAFETY: out is a checked writable i64 output.
        unsafe { *out = *value };
        kResultOk
    }
    unsafe fn setFloat(&self, id: FIDString, value: f64) -> tresult {
        // SAFETY: FIDString lifetime follows the method's ABI contract.
        let Some(key) = (unsafe { self.key(id) }) else {
            return kInvalidArgument;
        };
        self.values
            .borrow_mut()
            .insert(key, Attribute::Float(value));
        kResultOk
    }
    unsafe fn getFloat(&self, id: FIDString, out: *mut f64) -> tresult {
        if out.is_null() {
            return kInvalidArgument;
        }
        // SAFETY: FIDString lifetime follows the method's ABI contract.
        let Some(key) = (unsafe { self.key(id) }) else {
            return kInvalidArgument;
        };
        let values = self.values.borrow();
        let Some(Attribute::Float(value)) = values.get(&key) else {
            return kResultFalse;
        };
        // SAFETY: out is a checked writable f64 output.
        unsafe { *out = *value };
        kResultOk
    }
    unsafe fn setString(&self, id: FIDString, text: *const u16) -> tresult {
        if text.is_null() {
            return kInvalidArgument;
        }
        // SAFETY: FIDString lifetime follows the method's ABI contract.
        let Some(key) = (unsafe { self.key(id) }) else {
            return kInvalidArgument;
        };
        let mut value = Vec::new();
        for i in 0..1_048_576 {
            // SAFETY: text is a plugin-supplied NUL-terminated UTF-16 string.
            let ch = unsafe { *text.wrapping_add(i) };
            value.push(ch);
            if ch == 0 {
                self.values
                    .borrow_mut()
                    .insert(key, Attribute::String(value));
                return kResultOk;
            }
        }
        kInvalidArgument
    }
    unsafe fn getString(&self, id: FIDString, text: *mut u16, size: u32) -> tresult {
        if text.is_null() || size < 2 {
            return kInvalidArgument;
        }
        // SAFETY: FIDString lifetime follows the method's ABI contract.
        let Some(key) = (unsafe { self.key(id) }) else {
            return kInvalidArgument;
        };
        let values = self.values.borrow();
        let Some(Attribute::String(value)) = values.get(&key) else {
            return kResultFalse;
        };
        let capacity = usize::try_from(size / 2).unwrap_or(0);
        let count = value.len().min(capacity);
        // SAFETY: count bounds both the source and the caller's byte-sized output buffer.
        unsafe { ptr::copy_nonoverlapping(value.as_ptr(), text, count) };
        // SAFETY: size >= 2 ensures a writable final UTF-16 element.
        unsafe { *text.wrapping_add(count.saturating_sub(1)) = 0 };
        kResultOk
    }
    unsafe fn setBinary(&self, id: FIDString, data: *const c_void, size: u32) -> tresult {
        if size > 64 * 1024 * 1024 || (size > 0 && data.is_null()) {
            return kInvalidArgument;
        }
        // SAFETY: FIDString lifetime follows the method's ABI contract.
        let Some(key) = (unsafe { self.key(id) }) else {
            return kInvalidArgument;
        };
        let value = if size == 0 {
            Vec::new()
        } else {
            // SAFETY: Plugin provides size readable bytes; upper bound was checked.
            unsafe {
                std::slice::from_raw_parts(data.cast::<u8>(), usize::try_from(size).unwrap_or(0))
            }
            .to_vec()
        };
        self.values
            .borrow_mut()
            .insert(key, Attribute::Binary(value));
        kResultOk
    }
    unsafe fn getBinary(&self, id: FIDString, data: *mut *const c_void, size: *mut u32) -> tresult {
        if data.is_null() || size.is_null() {
            return kInvalidArgument;
        }
        // SAFETY: FIDString lifetime follows the method's ABI contract.
        let Some(key) = (unsafe { self.key(id) }) else {
            return kInvalidArgument;
        };
        let values = self.values.borrow();
        let Some(Attribute::Binary(value)) = values.get(&key) else {
            return kResultFalse;
        };
        // SAFETY: Owned vector storage remains valid until this attribute is changed or released.
        unsafe { *data = value.as_ptr().cast() };
        // SAFETY: size is a writable output and value length is bounded by setBinary.
        unsafe { *size = u32::try_from(value.len()).unwrap_or(0) };
        kResultOk
    }
}

struct HostMessage {
    owner: ThreadId,
    id: RefCell<CString>,
    attributes: ComWrapper<HostAttributes>,
}
impl Default for HostMessage {
    fn default() -> Self {
        let attributes = ComWrapper::new(HostAttributes::default());
        Self {
            owner: std::thread::current().id(),
            id: RefCell::new(CString::default()),
            attributes,
        }
    }
}
impl Class for HostMessage {
    type Interfaces = (IMessage,);
}
impl IMessageTrait for HostMessage {
    unsafe fn getMessageID(&self) -> FIDString {
        if self.owner != std::thread::current().id() {
            return ptr::null();
        }
        self.id.borrow().as_ptr()
    }
    unsafe fn setMessageID(&self, id: FIDString) {
        if id.is_null() || self.owner != std::thread::current().id() {
            return;
        }
        // SAFETY: Message ID is a NUL-terminated string valid for this call.
        *self.id.borrow_mut() = unsafe { CStr::from_ptr(id) }.to_owned();
    }
    unsafe fn getAttributes(&self) -> *mut IAttributeList {
        self.attributes
            .as_com_ref::<IAttributeList>()
            .map_or(ptr::null_mut(), |a| a.as_ptr())
    }
}

#[cfg(target_os = "linux")]
crate::run_loop::delegate_run_loop!(Vst3HostContext);
