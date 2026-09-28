//! Concrete [`HistoryAction`](super::HistoryAction) implementations.
//!
//! Pool entries removed by a recorded edit are *detached* (`SlotMap::detach`), not removed, so
//! undo can put them back under the same key with `reattach`. `reattach` panics when a key was
//! removed instead of detached, so any edit that removes entities without recording history must
//! clear the history first; see `DawContext::clear_history`.

use slotmap::{Key, SlotMap};

use super::HistoryError;

/// Implements `HistoryAction` for an action whose undo and redo are the same `swap`.
///
/// `swap_action!(Type, "Label")` uses a fixed label; `swap_action!(Type, field label)` reads it
/// from the action's `label` field.
macro_rules! swap_action {
    ($action:ty, field $field:ident) => {
        impl HistoryAction for $action {
            fn undo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
                self.swap(app)
            }

            fn redo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
                self.swap(app)
            }

            fn label(&self) -> &'static str {
                self.$field
            }
        }
    };
    ($action:ty, $label:expr) => {
        impl HistoryAction for $action {
            fn undo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
                self.swap(app)
            }

            fn redo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
                self.swap(app)
            }

            fn label(&self) -> &'static str {
                $label
            }
        }
    };
}

mod automation;
mod batch;
mod clips;
mod names;
mod notes;
mod pools;
mod structure;
mod transport;

pub use automation::{AutomationChanged, AutomationRecorder};
pub use batch::Batch;
pub use clips::{ClipEditRecorder, ClipsChanged};
pub use names::{
    BusRecolored, BusRenamed, PatternRenamed, TrackRecolored, TrackRenamed, TracksReordered,
};
pub use notes::{NoteMove, NotesChanged, NotesMoved, NotesResized};
pub use structure::{
    EffectBypassed, EffectMoved, EffectToggled, RoutingChanged, RoutingRecorder, StructureChanged,
    StructureRecorder,
};
pub use transport::{MetadataChanged, TempoChanged};

/// Swaps one pool slot with the value history holds for the other side of an edit.
///
/// `other` is the slot's value on the other side; `None` means the key is vacant there. After the
/// call `other` holds what the project held before, and the project holds what `other` held.
pub(crate) fn swap_slot<K: Key, V>(
    pool: &mut SlotMap<K, V>,
    key: K,
    other: &mut Option<V>,
    kind: &'static str,
) -> Result<(), HistoryError> {
    match (pool.get_mut(key), other.take()) {
        (Some(current), Some(value)) => *other = Some(std::mem::replace(current, value)),
        (Some(_), None) => *other = pool.detach(key),
        (None, Some(value)) => reattach(pool, key, value, kind)?,
        (None, None) => return Err(HistoryError::missing(kind)),
    }
    Ok(())
}

/// Puts a detached value back under its original key.
pub(crate) fn reattach<K: Key, V>(
    pool: &mut SlotMap<K, V>,
    key: K,
    value: V,
    kind: &'static str,
) -> Result<(), HistoryError> {
    if pool.contains_key(key) {
        return Err(HistoryError::Rejected(format!(
            "{kind} is already present and cannot be restored"
        )));
    }
    pool.reattach(key, value);
    Ok(())
}
