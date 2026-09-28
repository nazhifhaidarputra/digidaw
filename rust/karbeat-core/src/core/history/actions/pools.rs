use hashbrown::HashMap;
use slotmap::{Key, SlotMap};

use super::swap_slot;
use crate::core::history::HistoryError;

/// Changed entries of one slot map, as they are on the other side of an edit.
///
/// `None` marks a key that is vacant there: created by the edit, or deleted by it (depending on
/// the side). Swapping exchanges every entry with the pool, so the same call undoes and redoes.
#[derive(Debug)]
pub(crate) struct PoolSwap<K: Key, V> {
    entries: Box<[(K, Option<V>)]>,
}

impl<K: Key, V> PoolSwap<K, V> {
    /// Builds a swap from each key's value on the other side of the edit.
    pub(crate) fn from_entries(entries: Vec<(K, Option<V>)>) -> Self {
        Self {
            entries: entries.into_boxed_slice(),
        }
    }

    /// Keys this swap touches.
    pub(crate) fn keys(&self) -> impl Iterator<Item = K> + '_ {
        self.entries.iter().map(|(key, _)| *key)
    }

    pub(crate) fn swap(
        &mut self,
        pool: &mut SlotMap<K, V>,
        kind: &'static str,
    ) -> Result<(), HistoryError> {
        for (key, other) in &mut self.entries {
            swap_slot(pool, *key, other, kind)?;
        }
        Ok(())
    }

    pub(crate) fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// Keys whose entry exists on both sides of the edit (changed, not created or deleted),
    /// judged from the current project.
    pub(crate) fn changed_keys<'a>(
        &'a self,
        pool: &'a SlotMap<K, V>,
    ) -> impl Iterator<Item = K> + 'a {
        self.entries
            .iter()
            .filter(|(key, other)| other.is_some() && pool.contains_key(*key))
            .map(|(key, _)| *key)
    }

    /// Whether every entry exists on both sides: nothing was created or deleted.
    pub(crate) fn only_changes(&self, pool: &SlotMap<K, V>) -> bool {
        self.entries
            .iter()
            .all(|(key, other)| other.is_some() && pool.contains_key(*key))
    }
}

/// Copy of a slot map taken before an edit, diffed against the pool afterwards.
///
/// Entries the edit removed must have been *detached* (see the module docs) so the resulting
/// [`PoolSwap`] can reattach them under the same key.
#[derive(Debug)]
pub(crate) struct PoolBefore<K: Key, V> {
    entries: HashMap<K, V>,
}

impl<K: Key + std::hash::Hash, V: Clone + PartialEq> PoolBefore<K, V> {
    pub(crate) fn capture(pool: &SlotMap<K, V>) -> Self {
        Self {
            entries: pool
                .iter()
                .map(|(key, value)| (key, value.clone()))
                .collect(),
        }
    }

    /// Keeps the entries the edit created, changed, or removed; unchanged entries are dropped.
    pub(crate) fn diff(mut self, pool: &SlotMap<K, V>) -> PoolSwap<K, V> {
        let mut entries: Vec<(K, Option<V>)> = pool
            .iter()
            .filter_map(|(key, now)| match self.entries.remove(&key) {
                None => Some((key, None)),
                Some(before) if before == *now => None,
                Some(before) => Some((key, Some(before))),
            })
            .collect();
        entries.extend(
            self.entries
                .into_iter()
                .map(|(key, before)| (key, Some(before))),
        );
        PoolSwap {
            entries: entries.into_boxed_slice(),
        }
    }
}

#[cfg(test)]
#[allow(
    clippy::expect_used,
    reason = "pool diff tests fail immediately when a deterministic swap is rejected"
)]
mod tests {
    use super::*;

    slotmap::new_key_type! { struct TestKey; }

    #[test]
    fn diff_keeps_only_created_changed_and_detached_entries_and_swaps_back() {
        let mut pool: SlotMap<TestKey, i32> = SlotMap::with_key();
        let kept = pool.insert(1);
        let changed = pool.insert(2);
        let removed = pool.insert(3);
        let before = PoolBefore::capture(&pool);

        pool[changed] = 20;
        pool.detach(removed);
        let created = pool.insert(4);
        let mut swap = before.diff(&pool);
        assert_eq!(swap.entries.len(), 3);

        swap.swap(&mut pool, "Entry").expect("undo");
        assert_eq!(pool.get(kept), Some(&1));
        assert_eq!(pool.get(changed), Some(&2));
        assert_eq!(pool.get(removed), Some(&3));
        assert_eq!(pool.get(created), None);

        swap.swap(&mut pool, "Entry").expect("redo");
        assert_eq!(pool.get(changed), Some(&20));
        assert_eq!(pool.get(removed), None);
        assert_eq!(pool.get(created), Some(&4));
    }
}
