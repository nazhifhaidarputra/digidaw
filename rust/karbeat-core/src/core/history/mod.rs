//! Undo/redo history built from [`HistoryAction`] trait objects.
//!
//! Every action implements both [`HistoryAction::undo`] and [`HistoryAction::redo`], so a new
//! kind of edit cannot be recorded without its reverse. Actions take `&mut self` and *swap* the
//! state they changed with the project: while an edit is applied the action holds the previous
//! state, and after an undo it holds the edited state. Exactly one copy of any value exists,
//! either in the project or in history, so no `Arc` sharing is needed.

use std::{any::Any, time::Duration, time::Instant};

use thiserror::Error;

use crate::core::project::ApplicationState;

/// Concrete history actions, grouped by the project area they change.
pub mod actions;
mod engine_sync;

pub use engine_sync::{EngineSync, PluginSync};

/// Number of undoable actions retained by a new history manager.
pub const DEFAULT_HISTORY_LIMIT: usize = 100;
/// Largest history limit accepted to bound memory retained by action snapshots.
pub const MAX_HISTORY_LIMIT: usize = 1000;
/// Consecutive mergeable actions recorded within this window become one undo step.
pub const MERGE_WINDOW: Duration = Duration::from_millis(750);

#[derive(Debug, Error, PartialEq, Eq)]
/// Invalid history-retention configuration.
pub enum HistoryLimitError {
    #[error("History limit {requested} exceeds the maximum of {maximum}")]
    TooLarge {
        /// Limit supplied by the caller.
        requested: usize,
        /// Maximum limit supported by the manager.
        maximum: usize,
    },
}

/// Failure while undoing or redoing an action.
#[derive(Debug, Error, PartialEq, Eq)]
pub enum HistoryError {
    /// The undo stack is empty.
    #[error("Nothing to undo")]
    NothingToUndo,
    /// The redo stack is empty.
    #[error("Nothing to redo")]
    NothingToRedo,
    /// The project no longer contains something the action needs.
    #[error("{kind} not found")]
    Missing {
        /// Kind of project entity that is missing.
        kind: &'static str,
    },
    /// The project rejected the change.
    #[error("{0}")]
    Rejected(String),
}

impl HistoryError {
    /// A project entity required by the action is missing.
    pub fn missing(kind: &'static str) -> Self {
        Self::Missing { kind }
    }
}

impl From<anyhow::Error> for HistoryError {
    fn from(error: anyhow::Error) -> Self {
        Self::Rejected(error.to_string())
    }
}

/// A reversible project edit.
///
/// `undo` and `redo` are both required, and usually swap the same state in opposite
/// directions. They must leave the project exactly as it was before the matching call, including
/// entity keys, because later history entries refer to them.
pub trait HistoryAction: Send + Sync + std::fmt::Debug + 'static {
    /// Reverts the edit and reports what the audio engine must republish.
    fn undo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError>;

    /// Reapplies the edit after an undo and reports what the audio engine must republish.
    fn redo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError>;

    /// Short user-facing description, such as "Rename Track".
    fn label(&self) -> &'static str;

    /// Folds `next`, recorded right after this action, into this action.
    ///
    /// Returning `true` means the combined edit is undone in one step and `next` is discarded.
    /// `next` is a `&mut dyn Any` of the new action's concrete type; implementations downcast it.
    fn merge(&mut self, _next: &mut dyn Any) -> bool {
        false
    }
}

/// One undoable step.
#[derive(Debug)]
pub struct HistoryEntry {
    action: Box<dyn HistoryAction>,
    recorded_at: Instant,
}

impl HistoryEntry {
    /// Short user-facing description of the step.
    pub fn label(&self) -> &'static str {
        self.action.label()
    }
}

/// Bounded undo/redo stacks of [`HistoryEntry`] values.
#[derive(Debug)]
pub struct HistoryManager {
    /// Steps available to undo, oldest first.
    pub undo_stack: Vec<HistoryEntry>,
    /// Undone steps available to redo, oldest first.
    pub redo_stack: Vec<HistoryEntry>,
    /// Maximum entries retained independently in each stack.
    pub max_history: usize,
}

impl Default for HistoryManager {
    fn default() -> Self {
        Self::new()
    }
}

impl HistoryManager {
    /// Creates empty stacks with the default retention limit.
    pub fn new() -> Self {
        Self {
            undo_stack: Vec::new(),
            redo_stack: Vec::new(),
            max_history: DEFAULT_HISTORY_LIMIT,
        }
    }

    /// Sets the retention limit and immediately discards the oldest excess entries.
    pub fn set_max_history(&mut self, limit: usize) -> Result<(), HistoryLimitError> {
        if limit > MAX_HISTORY_LIMIT {
            return Err(HistoryLimitError::TooLarge {
                requested: limit,
                maximum: MAX_HISTORY_LIMIT,
            });
        }

        self.max_history = limit;
        Self::trim_oldest(&mut self.undo_stack, limit);
        Self::trim_oldest(&mut self.redo_stack, limit);
        Ok(())
    }

    fn trim_oldest(stack: &mut Vec<HistoryEntry>, limit: usize) {
        let remove_count = stack.len().saturating_sub(limit);
        if remove_count > 0 {
            stack.drain(..remove_count);
        }
    }

    /// Records an applied edit, clears redo history, and enforces the retention limit.
    ///
    /// An edit recorded within [`MERGE_WINDOW`] of the previous one may be merged into it
    /// (see [`HistoryAction::merge`]).
    pub fn push(&mut self, action: impl HistoryAction) {
        self.push_at(action, Instant::now());
    }

    fn push_at(&mut self, mut action: impl HistoryAction, now: Instant) {
        self.redo_stack.clear();
        if self.max_history == 0 {
            return;
        }
        if let Some(top) = self.undo_stack.last_mut()
            && now.saturating_duration_since(top.recorded_at) <= MERGE_WINDOW
            && top.action.merge(&mut action)
        {
            top.recorded_at = now;
            return;
        }

        self.undo_stack.push(HistoryEntry {
            action: Box::new(action),
            recorded_at: now,
        });
        Self::trim_oldest(&mut self.undo_stack, self.max_history);
    }

    /// Reverts the latest step and moves it to the redo stack.
    ///
    /// If the step fails it may have changed part of the project, so both stacks are cleared:
    /// the remaining entries could no longer be trusted to match the project.
    pub fn undo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let mut entry = self.undo_stack.pop().ok_or(HistoryError::NothingToUndo)?;
        match entry.action.undo(app) {
            Ok(sync) => {
                self.redo_stack.push(entry);
                Ok(sync)
            }
            Err(error) => {
                self.clear();
                Err(error)
            }
        }
    }

    /// Reapplies the latest undone step and moves it back to the undo stack.
    ///
    /// Failure clears both stacks, as for [`Self::undo`].
    pub fn redo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let mut entry = self.redo_stack.pop().ok_or(HistoryError::NothingToRedo)?;
        match entry.action.redo(app) {
            Ok(sync) => {
                self.undo_stack.push(entry);
                Ok(sync)
            }
            Err(error) => {
                self.clear();
                Err(error)
            }
        }
    }

    /// Discards every step. Call when the project is replaced, or after an edit that history
    /// cannot reverse.
    pub fn clear(&mut self) {
        self.undo_stack.clear();
        self.redo_stack.clear();
    }

    /// Description of the step [`Self::undo`] would revert.
    pub fn undo_label(&self) -> Option<&'static str> {
        self.undo_stack.last().map(HistoryEntry::label)
    }

    /// Description of the step [`Self::redo`] would reapply.
    pub fn redo_label(&self) -> Option<&'static str> {
        self.redo_stack.last().map(HistoryEntry::label)
    }
}

#[cfg(test)]
#[allow(
    clippy::expect_used,
    reason = "history tests fail immediately when a deterministic state transition is rejected"
)]
mod tests {
    use super::*;

    /// Swaps the project BPM, and merges with later instances of itself.
    #[derive(Debug)]
    struct SetBpm {
        bpm: f32,
        mergeable: bool,
    }

    impl HistoryAction for SetBpm {
        fn undo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
            std::mem::swap(&mut app.transport.bpm, &mut self.bpm);
            Ok(EngineSync::tempo())
        }

        fn redo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
            self.undo(app)
        }

        fn label(&self) -> &'static str {
            "Set BPM"
        }

        fn merge(&mut self, next: &mut dyn Any) -> bool {
            self.mergeable && next.downcast_mut::<Self>().is_some()
        }
    }

    #[derive(Debug)]
    struct Failing;

    impl HistoryAction for Failing {
        fn undo(&mut self, _: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
            Err(HistoryError::missing("Thing"))
        }

        fn redo(&mut self, _: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
            Err(HistoryError::missing("Thing"))
        }

        fn label(&self) -> &'static str {
            "Fail"
        }
    }

    fn set_bpm(app: &mut ApplicationState, bpm: f32, mergeable: bool) -> SetBpm {
        let previous = std::mem::replace(&mut app.transport.bpm, bpm);
        SetBpm {
            bpm: previous,
            mergeable,
        }
    }

    #[test]
    fn undo_and_redo_swap_state_and_move_entries() {
        let mut app = ApplicationState::default();
        let mut history = HistoryManager::new();
        app.transport.bpm = 120.0;
        let action = set_bpm(&mut app, 140.0, false);
        history.push(action);

        assert_eq!(history.undo_label(), Some("Set BPM"));
        assert_eq!(history.undo(&mut app), Ok(EngineSync::tempo()));
        assert_eq!(app.transport.bpm, 120.0);
        assert_eq!(history.redo_label(), Some("Set BPM"));

        assert_eq!(history.redo(&mut app).expect("redo"), EngineSync::tempo());
        assert_eq!(app.transport.bpm, 140.0);
        assert_eq!(
            history.undo(&mut app).expect("undo again"),
            EngineSync::tempo()
        );
        assert_eq!(app.transport.bpm, 120.0);
    }

    #[test]
    fn empty_stacks_report_nothing_to_do() {
        let mut app = ApplicationState::default();
        let mut history = HistoryManager::new();
        assert_eq!(history.undo(&mut app), Err(HistoryError::NothingToUndo));
        assert_eq!(history.redo(&mut app), Err(HistoryError::NothingToRedo));
    }

    #[test]
    fn failing_step_clears_both_stacks() {
        let mut app = ApplicationState::default();
        let mut history = HistoryManager::new();
        let action = set_bpm(&mut app, 90.0, false);
        history.push(action);
        history.push(Failing);

        assert!(history.undo(&mut app).is_err());
        assert!(history.undo_stack.is_empty());
        assert!(history.redo_stack.is_empty());
    }

    #[test]
    fn mergeable_steps_within_the_window_become_one() {
        let mut app = ApplicationState::default();
        app.transport.bpm = 120.0;
        let mut history = HistoryManager::new();
        let start = Instant::now();
        for (step, bpm) in [121.0, 122.0, 123.0].into_iter().enumerate() {
            let action = set_bpm(&mut app, bpm, true);
            history.push_at(action, start + Duration::from_millis(100) * step as u32);
        }
        let action = set_bpm(&mut app, 150.0, true);
        history.push_at(action, start + Duration::from_secs(5));

        assert_eq!(history.undo_stack.len(), 2);
        assert_eq!(
            history.undo(&mut app).expect("undo late change"),
            EngineSync::tempo()
        );
        assert_eq!(app.transport.bpm, 123.0);
        assert_eq!(
            history.undo(&mut app).expect("undo merged drag"),
            EngineSync::tempo()
        );
        assert_eq!(app.transport.bpm, 120.0);
    }

    #[test]
    fn reducing_limit_trims_oldest_undo_and_redo_entries() {
        let mut app = ApplicationState::default();
        let mut history = HistoryManager::new();
        for bpm in [100.0, 110.0, 120.0, 130.0, 140.0] {
            let action = set_bpm(&mut app, bpm, false);
            history.push(action);
        }
        assert_eq!(history.undo(&mut app).expect("undo"), EngineSync::tempo());
        assert_eq!(history.undo(&mut app).expect("undo"), EngineSync::tempo());

        history.set_max_history(1).expect("valid history limit");

        assert_eq!(history.undo_stack.len(), 1);
        assert_eq!(history.redo_stack.len(), 1);
        assert_eq!(history.max_history, 1);
    }

    #[test]
    fn zero_disables_and_clears_history() {
        let mut app = ApplicationState::default();
        let mut history = HistoryManager::new();
        let action = set_bpm(&mut app, 100.0, false);
        history.push(action);

        history.set_max_history(0).expect("zero is supported");
        let action = set_bpm(&mut app, 110.0, false);
        history.push(action);

        assert!(history.undo_stack.is_empty());
        assert!(history.redo_stack.is_empty());
    }

    #[test]
    fn rejects_limits_above_the_supported_maximum() {
        let mut history = HistoryManager::new();

        let result = history.set_max_history(MAX_HISTORY_LIMIT + 1);

        assert!(result.is_err());
        assert_eq!(history.max_history, 100);
    }
}
