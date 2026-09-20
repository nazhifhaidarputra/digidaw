use slotmap::{Key, KeyData, new_key_type};

new_key_type! {
    /// Generation-aware key for a project track.
    pub struct TrackId;
    /// Generation-aware key for a clip in the project clip pool.
    pub struct ClipId;
    /// Generation-aware key for an automation lane.
    pub struct AutomationId;
    /// Lane-local key for an automation point.
    pub struct AutomationPointId;
    /// Generation-aware key for an effect instance.
    pub struct EffectId;
    /// Generation-aware key for an auxiliary mixer bus.
    pub struct BusId;
    /// Generation-aware key for a MIDI pattern.
    pub struct PatternId;
    /// Generation-aware key for an imported audio source.
    pub struct AudioSourceId;
    /// Generation-aware key for a generator instance.
    pub struct GeneratorId;
    /// Generation-aware key for a project source object.
    pub struct SourceId;
    /// Pattern-local note key encoded through the shared key representation.
    pub struct NoteId;
    /// Generation-aware key for a modulation source.
    pub struct ModulationId;
    /// Generation-aware key for a modulation connection.
    pub struct ModulationLinkId;
    /// Generation-aware key for a render-graph node.
    pub struct GraphNodeId;
}

macro_rules! impl_key_handle {
    ($($id:ty),+ $(,)?) => {$ (
        impl $id {
            /// Returns the complete, generation-aware opaque handle.
            pub fn to_u64(self) -> u64 {
                self.data().as_ffi()
            }

            /// Restores a key previously returned by [`Self::to_u64`].
            pub fn from_u64(handle: u64) -> Self {
                KeyData::from_ffi(handle).into()
            }

            /// Returns the slot index only.
            ///
            /// This exists for legacy DSP array indexing. Persisted IDs and FFI
            /// handles must use [`Self::to_u64`] so the generation is retained.
            pub fn to_u32(self) -> u32 {
                self.to_u64() as u32
            }
        }

        impl From<u64> for $id {
            fn from(handle: u64) -> Self {
                Self::from_u64(handle)
            }
        }

        impl From<u32> for $id {
            fn from(index: u32) -> Self {
                Self::from_u64((1_u64 << 32) | u64::from(index))
            }
        }

        impl From<i32> for $id {
            fn from(index: i32) -> Self {
                Self::from(index as u32)
            }
        }

        impl From<$id> for u32 {
            fn from(id: $id) -> Self {
                id.to_u32()
            }
        }

        impl PartialEq<u32> for $id {
            fn eq(&self, index: &u32) -> bool {
                self.to_u32() == *index
            }
        }

        impl From<$id> for u64 {
            fn from(id: $id) -> Self {
                id.to_u64()
            }
        }

        impl std::fmt::Display for $id {
            fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                write!(f, "{}", self.to_u64())
            }
        }
    )+ };
}

impl_key_handle!(
    TrackId,
    ClipId,
    AutomationId,
    AutomationPointId,
    EffectId,
    BusId,
    PatternId,
    AudioSourceId,
    GeneratorId,
    SourceId,
    NoteId,
    ModulationId,
    ModulationLinkId,
    GraphNodeId,
);

impl NoteId {
    /// Pattern-local ID allocation. Notes deliberately remain a plain Vec and
    /// are the one entity type that does not live in a slot-map arena.
    pub fn next(counter: &mut u32) -> Self {
        let id = Self::from(*counter);
        *counter = counter.saturating_add(1);
        id
    }
}

impl AutomationPointId {
    /// Lane-local ID allocation for the self-contained automation point Vec.
    pub fn next(counter: &mut u32) -> Self {
        let id = Self::from(*counter);
        *counter = counter.saturating_add(1);
        id
    }
}
