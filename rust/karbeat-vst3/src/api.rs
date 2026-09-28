//! Host-owned VST3 streams and bounded processing collections.
#![allow(non_snake_case, reason = "VST3 interface method names are ABI-defined")]

use std::{
    cell::{Cell, RefCell},
    ffi::c_void,
    ptr,
};
use vst3::{
    Class, ComPtr, ComWrapper, Interface,
    Steinberg::{Vst::*, *},
};

const MAX_STATE_BYTES: usize = 64 * 1024 * 1024;
/// Maximum number of events retained by one [`EventList`].
pub const EVENT_CAPACITY: usize = 2048;
/// Maximum number of points retained by one [`ParamQueue`].
pub const POINT_CAPACITY: usize = 64;

/// In-memory VST3 stream used for bounded component and controller state exchange.
///
/// The stream owns its bytes, maintains a seek position, and exposes the VST3
/// `IBStream` ABI through the implementation below. Reads may be partial at EOF;
/// writes are rejected once the stream would exceed the crate's state limit.
#[derive(Default)]
pub struct MemoryStream {
    /// Bytes currently stored in the stream.
    pub data: RefCell<Vec<u8>>,
    position: Cell<usize>,
}

impl MemoryStream {
    /// Creates a stream positioned at byte zero with a copy of `bytes`.
    pub fn from_bytes(bytes: &[u8]) -> Self {
        Self {
            data: RefCell::new(bytes.to_vec()),
            position: Cell::new(0),
        }
    }
    /// Rewinds the stream position to its beginning without changing its bytes.
    pub fn rewind(&self) {
        self.position.set(0);
    }
}

impl Class for MemoryStream {
    type Interfaces = (IBStream,);
}
impl IBStreamTrait for MemoryStream {
    unsafe fn read(&self, buffer: *mut c_void, count: i32, read: *mut i32) -> tresult {
        if !read.is_null() {
            // SAFETY: Non-null output is supplied writable by the caller.
            unsafe { *read = 0 };
        }
        let Ok(count) = usize::try_from(count) else {
            return kInvalidArgument;
        };
        if count > 0 && buffer.is_null() {
            return kInvalidArgument;
        }
        let Ok(data) = self.data.try_borrow() else {
            return kResultFalse;
        };
        let position = self.position.get();
        let taken = count.min(data.len().saturating_sub(position));
        if taken > 0 {
            // SAFETY: taken bounds the source and caller supplies count writable bytes.
            unsafe {
                ptr::copy_nonoverlapping(
                    data.as_ptr().wrapping_add(position),
                    buffer.cast::<u8>(),
                    taken,
                );
            };
        }
        self.position.set(position + taken);
        if !read.is_null() {
            // SAFETY: taken is at most the nonnegative i32 requested count.
            unsafe { *read = i32::try_from(taken).unwrap_or(i32::MAX) };
        }
        if taken > 0 || count == 0 {
            kResultOk
        } else {
            kResultFalse
        }
    }
    unsafe fn write(&self, buffer: *mut c_void, count: i32, written: *mut i32) -> tresult {
        if !written.is_null() {
            // SAFETY: Non-null output is writable by the caller's IBStream contract.
            unsafe { *written = 0 };
        }
        let Ok(count) = usize::try_from(count) else {
            return kInvalidArgument;
        };
        if count > 0 && buffer.is_null() {
            return kInvalidArgument;
        }
        let position = self.position.get();
        let Some(end) = position
            .checked_add(count)
            .filter(|&n| n <= MAX_STATE_BYTES)
        else {
            return kOutOfMemory;
        };
        let Ok(mut data) = self.data.try_borrow_mut() else {
            return kResultFalse;
        };
        if end > data.len() {
            data.resize(end, 0);
        }
        if count > 0 {
            // SAFETY: data was resized to end; caller provides count readable bytes.
            unsafe {
                ptr::copy_nonoverlapping(
                    buffer.cast::<u8>(),
                    data.as_mut_ptr().wrapping_add(position),
                    count,
                )
            };
        }
        self.position.set(end);
        if !written.is_null() {
            // SAFETY: count originated in a nonnegative i32.
            unsafe { *written = i32::try_from(count).unwrap_or(i32::MAX) };
        }
        kResultOk
    }
    unsafe fn seek(&self, offset: i64, mode: i32, result: *mut i64) -> tresult {
        let base = match mode {
            0 => 0,
            1 => i64::try_from(self.position.get()).unwrap_or(i64::MAX),
            2 => match self.data.try_borrow() {
                Ok(data) => i64::try_from(data.len()).unwrap_or(i64::MAX),
                Err(_) => return kResultFalse,
            },
            _ => return kInvalidArgument,
        };
        let Some(next) = base
            .checked_add(offset)
            .and_then(|n| usize::try_from(n).ok())
            .filter(|&n| n <= MAX_STATE_BYTES)
        else {
            return kInvalidArgument;
        };
        self.position.set(next);
        if !result.is_null() {
            // SAFETY: Non-null result is a writable i64 output.
            unsafe { *result = i64::try_from(next).unwrap_or(i64::MAX) };
        }
        kResultOk
    }
    unsafe fn tell(&self, result: *mut i64) -> tresult {
        if result.is_null() {
            return kInvalidArgument;
        }
        // SAFETY: Pointer was checked and represents the caller's writable output.
        unsafe { *result = i64::try_from(self.position.get()).unwrap_or(i64::MAX) };
        kResultOk
    }
}

/// Bounded event collection implementing the VST3 `IEventList` interface.
///
/// Events are copied into host-owned storage. Pointer-bearing event variants
/// are rejected because retaining their pointers would outlive the ABI call.
pub struct EventList {
    events: RefCell<Vec<Event>>,
    /// Set when an event was rejected because the fixed capacity was exhausted.
    pub overflow: Cell<bool>,
}
impl Default for EventList {
    fn default() -> Self {
        Self {
            events: RefCell::new(Vec::with_capacity(EVENT_CAPACITY)),
            overflow: Cell::new(false),
        }
    }
}
impl EventList {
    /// Removes all retained events and clears the overflow indicator.
    pub fn clear(&self) {
        self.events.borrow_mut().clear();
        self.overflow.set(false);
    }
    /// Attempts to append an event, returning `false` on borrow contention or capacity overflow.
    pub fn push(&self, event: Event) -> bool {
        let Ok(mut events) = self.events.try_borrow_mut() else {
            return false;
        };
        if events.len() == EVENT_CAPACITY {
            self.overflow.set(true);
            return false;
        }
        events.push(event);
        true
    }
}
impl Class for EventList {
    type Interfaces = (IEventList,);
}
impl IEventListTrait for EventList {
    unsafe fn getEventCount(&self) -> i32 {
        i32::try_from(self.events.borrow().len()).unwrap_or(0)
    }
    unsafe fn getEvent(&self, index: i32, out: *mut Event) -> tresult {
        if out.is_null() {
            return kInvalidArgument;
        }
        let Ok(index) = usize::try_from(index) else {
            return kInvalidArgument;
        };
        let events = self.events.borrow();
        let Some(event) = events.get(index) else {
            return kInvalidArgument;
        };
        // SAFETY: Non-null out points to one writable ABI Event, copied without owning pointers.
        unsafe { *out = *event };
        kResultOk
    }
    unsafe fn addEvent(&self, event: *mut Event) -> tresult {
        if event.is_null() {
            return kInvalidArgument;
        }
        // SAFETY: Plugin supplies a readable Event for the duration of this call.
        let event = unsafe { *event };
        // Pointer-bearing event payloads cannot outlive this call without copying their storage.
        if !matches!(event.r#type, 0 | 1 | 3 | 4 | 8 | 65535) {
            return kNotImplemented;
        }
        if self.push(event) {
            kResultOk
        } else {
            kResultFalse
        }
    }
}

/// Bounded, host-owned VST3 parameter point queue for one parameter identifier.
pub struct ParamQueue {
    /// VST3 parameter identifier represented by this queue.
    pub id: u32,
    /// Sorted `(sample_offset, normalized_value)` points for the current block.
    pub points: RefCell<Vec<(i32, f64)>>,
    /// Set when a new point was rejected because [`POINT_CAPACITY`] was reached.
    pub overflow: Cell<bool>,
}
impl Class for ParamQueue {
    type Interfaces = (IParamValueQueue,);
}
impl IParamValueQueueTrait for ParamQueue {
    unsafe fn getParameterId(&self) -> u32 {
        self.id
    }
    unsafe fn getPointCount(&self) -> i32 {
        i32::try_from(self.points.borrow().len()).unwrap_or(0)
    }
    unsafe fn getPoint(&self, index: i32, offset: *mut i32, value: *mut f64) -> tresult {
        if offset.is_null() || value.is_null() {
            return kInvalidArgument;
        }
        let Ok(index) = usize::try_from(index) else {
            return kInvalidArgument;
        };
        let points = self.points.borrow();
        let Some(&(sample, normalized)) = points.get(index) else {
            return kInvalidArgument;
        };
        // SAFETY: Both pointers refer to writable scalar outputs and were checked for null.
        unsafe { *offset = sample };
        // SAFETY: value is the caller's writable parameter value output.
        unsafe { *value = normalized };
        kResultOk
    }
    unsafe fn addPoint(&self, offset: i32, value: f64, index: *mut i32) -> tresult {
        if offset < 0 || !value.is_finite() {
            return kInvalidArgument;
        }
        let mut points = self.points.borrow_mut();
        let position = match points.binary_search_by_key(&offset, |p| p.0) {
            Ok(i) => {
                points[i].1 = value.clamp(0.0, 1.0);
                i
            }
            Err(i) if points.len() < POINT_CAPACITY => {
                points.insert(i, (offset, value.clamp(0.0, 1.0)));
                i
            }
            Err(_) => {
                self.overflow.set(true);
                return kResultFalse;
            }
        };
        if !index.is_null() {
            // SAFETY: position is bounded by POINT_CAPACITY and index is a writable output.
            unsafe { *index = i32::try_from(position).unwrap_or(0) };
        }
        kResultOk
    }
}

/// Bounded collection of parameter queues exposed through VST3 `IParameterChanges`.
///
/// Queue identifiers are fixed when the collection is created. Unknown identifiers
/// are rejected so the processor only observes parameters it advertised.
pub struct ParameterChanges {
    /// COM-wrapped queues for the accepted parameter identifiers.
    pub queues: Vec<ComWrapper<ParamQueue>>,
    active: RefCell<Vec<usize>>,
}
impl ParameterChanges {
    /// Creates empty queues for the sorted, de-duplicated identifiers in `ids`.
    pub fn new(ids: &[u32]) -> Self {
        let mut ids = ids.to_vec();
        ids.sort_unstable();
        ids.dedup();
        let queues = ids
            .iter()
            .map(|&id| {
                ComWrapper::new(ParamQueue {
                    id,
                    points: RefCell::new(Vec::with_capacity(POINT_CAPACITY)),
                    overflow: Cell::new(false),
                })
            })
            .collect();
        Self {
            queues,
            active: RefCell::new(Vec::with_capacity(ids.len())),
        }
    }
    /// Clears all points and overflow flags while retaining queue identifiers.
    pub fn clear(&self) {
        for &index in self.active.borrow().iter() {
            self.queues[index].points.borrow_mut().clear();
            self.queues[index].overflow.set(false);
        }
        self.active.borrow_mut().clear();
    }
    /// Adds a point to the matching queue, returning `false` for invalid or unknown input.
    pub fn push(&self, id: u32, offset: i32, value: f64) -> bool {
        // SAFETY: id is readable and an optional output index is not requested.
        let queue = unsafe { self.addParameterData(&id, ptr::null_mut()) };
        if queue.is_null() {
            return false;
        }
        let Some(queue) = self.queues.iter().find(|q| q.id == id) else {
            return false;
        };
        // SAFETY: Validated queue is owned for the entire block.
        (unsafe { queue.addPoint(offset, value, ptr::null_mut()) }) == kResultOk
    }
    /// Calls `f` once for the latest point of every queue that has received a point.
    ///
    /// The callback runs while queue storage is borrowed and must not re-enter this collection.
    pub fn for_each_last(&self, mut f: impl FnMut(u32, f64)) {
        for &index in self.active.borrow().iter() {
            let queue = &self.queues[index];
            if let Some(&(_, value)) = queue.points.borrow().last() {
                f(queue.id, value);
            }
        }
    }
}
impl Class for ParameterChanges {
    type Interfaces = (IParameterChanges,);
}
impl IParameterChangesTrait for ParameterChanges {
    unsafe fn getParameterCount(&self) -> i32 {
        i32::try_from(self.active.borrow().len()).unwrap_or(0)
    }
    unsafe fn getParameterData(&self, index: i32) -> *mut IParamValueQueue {
        let Ok(index) = usize::try_from(index) else {
            return ptr::null_mut();
        };
        self.active
            .borrow()
            .get(index)
            .and_then(|&i| self.queues.get(i))
            .and_then(|q| q.as_com_ref::<IParamValueQueue>())
            .map_or(ptr::null_mut(), |q| q.as_ptr())
    }
    unsafe fn addParameterData(&self, id: *const u32, index: *mut i32) -> *mut IParamValueQueue {
        if id.is_null() {
            return ptr::null_mut();
        }
        // SAFETY: Caller supplies one readable parameter ID.
        let id = unsafe { *id };
        let Ok(queue_index) = self.queues.binary_search_by_key(&id, |q| q.id) else {
            return ptr::null_mut();
        };
        let mut active = self.active.borrow_mut();
        let position = active
            .iter()
            .position(|&i| i == queue_index)
            .unwrap_or_else(|| {
                active.push(queue_index);
                active.len() - 1
            });
        if !index.is_null() {
            // SAFETY: Bounded active index is written to the optional output.
            unsafe { *index = i32::try_from(position).unwrap_or(0) };
        }
        self.queues[queue_index]
            .as_com_ref::<IParamValueQueue>()
            .map_or(ptr::null_mut(), |q| q.as_ptr())
    }
}

/// Creates an owned interface reference from the factory's native class ID.
///
/// # Safety
/// The factory must be initialized and callable on the current native UI thread.
pub unsafe fn create_instance<I: Interface>(
    factory: &ComPtr<IPluginFactory>,
    cid: &TUID,
) -> Option<ComPtr<I>> {
    let mut object: *mut c_void = ptr::null_mut();
    let iid = I::IID.map(|b| i8::from_ne_bytes([b]));
    // SAFETY: Class/IID arrays are valid and object is an aligned output pointer.
    let result = unsafe { factory.createInstance(cid.as_ptr(), iid.as_ptr(), &raw mut object) };
    if result != kResultOk {
        return None;
    }
    // SAFETY: Successful createInstance transfers an interface reference of exactly I.
    unsafe { ComPtr::from_raw(object.cast::<I>()) }
}

/// Converts a fixed-width VST3 UTF-16 string buffer to a Rust `String`.
///
/// Conversion stops at the first NUL code unit and replaces malformed UTF-16
/// sequences using Rust's lossy conversion rules.
pub fn string128_to_string(value: &String128) -> String {
    let chars = value
        .iter()
        .take_while(|&&c| c != 0)
        .map(|c| u16::from_ne_bytes(c.to_ne_bytes()))
        .collect::<Vec<_>>();
    String::from_utf16_lossy(&chars)
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "test fixtures use assertions for failure reporting"
)]
mod tests {
    use super::*;
    #[test]
    fn stream_bounds_and_partial_reads() {
        let stream = MemoryStream::from_bytes(&[1, 2]);
        let mut buffer = [0_u8; 4];
        let mut read = -1;
        assert_eq!(
            // SAFETY: The stack buffer has four writable bytes and read is a valid output.
            unsafe { stream.read(buffer.as_mut_ptr().cast(), 4, &raw mut read) },
            kResultOk
        );
        assert_eq!(read, 2);
        assert_eq!(
            // SAFETY: The optional output pointer may be null; invalid offsets are rejected.
            unsafe { stream.seek(-1, 0, ptr::null_mut()) },
            kInvalidArgument
        );
        assert_eq!(
            // SAFETY: No output is requested; the stream checks the overflowing offset.
            unsafe { stream.seek(i64::MAX, 1, ptr::null_mut()) },
            kInvalidArgument
        );
        assert_eq!(
            // SAFETY: The stream rejects null data pointers before dereferencing them.
            unsafe { stream.read(ptr::null_mut(), 1, &raw mut read) },
            kInvalidArgument
        );
    }
    #[test]
    fn bounded_parameter_queues_sort_coalesce_and_reject_unknown_ids() {
        let changes = ParameterChanges::new(&[7, 100]);
        assert!(!changes.push(8, 0, 0.5));
        assert!(changes.push(7, 4, 0.5));
        assert!(changes.push(7, 0, 0.1));
        assert!(changes.push(7, 4, 0.9));
        assert_eq!(&*changes.queues[0].points.borrow(), &[(0, 0.1), (4, 0.9)]);
        for i in 5..100 {
            changes.push(7, i, 0.5);
        }
        assert_eq!(changes.queues[0].points.borrow().len(), POINT_CAPACITY);
        assert!(changes.queues[0].overflow.get());
        changes.clear();
        assert!(changes.queues[0].points.borrow().is_empty());
    }
}
