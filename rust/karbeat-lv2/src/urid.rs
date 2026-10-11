//! Process-wide URID map shared by every plugin instance, editor, and state operation.
//!
//! LV2 identifies types and properties by integer URIDs that the host hands out. One map for
//! the whole process means a plugin, its editor, and state serialisation always agree, and an
//! instance prepared again keeps the IDs it already cached.

use std::{
    collections::HashMap,
    ffi::{CStr, CString, c_char, c_void},
    sync::{LazyLock, Mutex, PoisonError},
};

/// Mapped URIs by ID. A URID is its position in `uris` plus one, since zero means "unmapped".
#[derive(Default)]
struct Table {
    ids: HashMap<CString, u32>,
    uris: Vec<CString>,
}

static TABLE: LazyLock<Mutex<Table>> = LazyLock::new(Mutex::default);

/// C-visible map and unmap records. Their callbacks use the process table, not a handle.
struct Records {
    map: lv2_sys::LV2_URID_Map,
    unmap: lv2_sys::LV2_URID_Unmap,
}

// SAFETY: The records are immutable and hold only null handles and function pointers.
unsafe impl Sync for Records {}

static RECORDS: Records = Records {
    map: lv2_sys::LV2_URID_Map {
        handle: std::ptr::null_mut(),
        map: Some(map_uri),
    },
    unmap: lv2_sys::LV2_URID_Unmap {
        handle: std::ptr::null_mut(),
        unmap: Some(unmap_urid),
    },
};

/// Returns the URID for `uri`, assigning the next free one the first time it is seen.
///
/// Returns zero only if the ID space is exhausted.
pub(crate) fn map(uri: &CStr) -> u32 {
    let mut table = TABLE.lock().unwrap_or_else(PoisonError::into_inner);
    if let Some(id) = table.ids.get(uri) {
        return *id;
    }
    let Some(id) = u32::try_from(table.uris.len())
        .ok()
        .and_then(|count| count.checked_add(1))
    else {
        return 0;
    };
    table.uris.push(uri.to_owned());
    table.ids.insert(uri.to_owned(), id);
    id
}

/// Maps a URI given as text, or returns zero for text that cannot be a C string.
pub(crate) fn map_str(uri: &str) -> u32 {
    CString::new(uri).map_or(0, |uri| map(&uri))
}

/// Pointer to the map record, for native calls that take `LV2_URID_Map*`.
pub(crate) fn map_ptr() -> *mut lv2_sys::LV2_URID_Map {
    std::ptr::from_ref(&RECORDS.map).cast_mut()
}

/// Pointer to the unmap record, for native calls that take `LV2_URID_Unmap*`.
pub(crate) fn unmap_ptr() -> *mut lv2_sys::LV2_URID_Unmap {
    std::ptr::from_ref(&RECORDS.unmap).cast_mut()
}

/// The `urid:map` feature record.
pub(crate) fn map_feature() -> lv2_sys::LV2_Feature {
    lv2_sys::LV2_Feature {
        URI: lv2_sys::LV2_URID__map.as_ptr().cast(),
        data: map_ptr().cast(),
    }
}

/// The `urid:unmap` feature record.
pub(crate) fn unmap_feature() -> lv2_sys::LV2_Feature {
    lv2_sys::LV2_Feature {
        URI: lv2_sys::LV2_URID__unmap.as_ptr().cast(),
        data: unmap_ptr().cast(),
    }
}

/// Builds a C string from host-authored text, which never contains a NUL byte.
pub(crate) fn c_string(text: &str) -> CString {
    CString::new(text).unwrap_or_default()
}

unsafe extern "C" fn map_uri(_handle: *mut c_void, uri: *const c_char) -> u32 {
    if uri.is_null() {
        return 0;
    }
    // SAFETY: The caller passes a NUL-terminated URI valid for this call.
    map(unsafe { CStr::from_ptr(uri) })
}

unsafe extern "C" fn unmap_urid(_handle: *mut c_void, urid: u32) -> *const c_char {
    let table = TABLE.lock().unwrap_or_else(PoisonError::into_inner);
    let index = usize::try_from(urid).ok().and_then(|id| id.checked_sub(1));
    // Entries are never removed, and a `CString`'s buffer does not move when the table grows,
    // so the pointer stays valid for the life of the process.
    index
        .and_then(|index| table.uris.get(index))
        .map_or(std::ptr::null(), |uri| uri.as_ptr())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn uris_map_to_stable_nonzero_ids_and_back() {
        let first = map(c"urn:digidaw:test:first");
        let second = map(c"urn:digidaw:test:second");
        assert!(first != 0 && second != 0 && first != second);
        assert_eq!(map(c"urn:digidaw:test:first"), first);
        assert_eq!(map_str("urn:digidaw:test:second"), second);
        assert_eq!(map_str("with\0nul"), 0);
        // SAFETY: The record's callback ignores its handle and returns a process-lifetime string.
        let unmapped = unsafe { unmap_urid(std::ptr::null_mut(), first) };
        assert!(!unmapped.is_null());
        // SAFETY: A non-null result is a NUL-terminated URI owned by the process table.
        let uri = unsafe { CStr::from_ptr(unmapped) };
        assert_eq!(uri, c"urn:digidaw:test:first");
        // SAFETY: As above; zero and unknown IDs have no URI.
        assert!(unsafe { unmap_urid(std::ptr::null_mut(), 0) }.is_null());
        // SAFETY: As above.
        assert!(unsafe { unmap_urid(std::ptr::null_mut(), u32::MAX) }.is_null());
        // SAFETY: The map callback receives a NUL-terminated URI.
        let mapped = unsafe { map_uri(std::ptr::null_mut(), c"urn:digidaw:test:first".as_ptr()) };
        assert_eq!(mapped, first);
    }
}
