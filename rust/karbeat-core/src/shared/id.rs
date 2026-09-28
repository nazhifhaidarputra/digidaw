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

#[cfg(test)]
mod tests {
    use super::*;
    use std::fmt::Debug;

    fn assert_reused_slot_round_trip<K>()
    where
        K: Key + Copy + Debug + Eq + From<u64> + From<u32> + Into<u64> + Into<u32>,
    {
        let mut arena = slotmap::SlotMap::<K, ()>::with_key();
        let removed = arena.insert(());
        arena.remove(removed);
        let replacement = arena.insert(());
        let removed_index: u32 = removed.into();
        let replacement_index: u32 = replacement.into();
        let replacement_handle: u64 = replacement.into();

        assert_eq!(removed_index, replacement_index);
        assert_ne!(removed, replacement);
        assert_eq!(K::from(replacement_handle), replacement);
        assert_ne!(K::from(replacement_index), replacement);
    }

    #[test]
    fn slot_map_ids_preserve_their_generation_in_u64_handles() {
        assert_reused_slot_round_trip::<TrackId>();
        assert_reused_slot_round_trip::<ClipId>();
        assert_reused_slot_round_trip::<AutomationId>();
        assert_reused_slot_round_trip::<EffectId>();
        assert_reused_slot_round_trip::<BusId>();
        assert_reused_slot_round_trip::<PatternId>();
        assert_reused_slot_round_trip::<AudioSourceId>();
        assert_reused_slot_round_trip::<GeneratorId>();
        assert_reused_slot_round_trip::<ModulationId>();
        assert_reused_slot_round_trip::<ModulationLinkId>();
        assert_reused_slot_round_trip::<GraphNodeId>();
    }
}
