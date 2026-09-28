use crate::core::{
    history::{EngineSync, HistoryAction, HistoryError},
    project::ApplicationState,
};

/// Several actions undone and redone as one step. Undo runs them in reverse order.
#[derive(Debug)]
pub struct Batch {
    label: &'static str,
    actions: Box<[Box<dyn HistoryAction>]>,
}

impl Batch {
    /// Groups `actions`, which were applied in the given order.
    pub fn new(label: &'static str, actions: Vec<Box<dyn HistoryAction>>) -> Self {
        Self {
            label,
            actions: actions.into_boxed_slice(),
        }
    }
}

impl HistoryAction for Batch {
    fn undo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let mut sync = EngineSync::none();
        for action in self.actions.iter_mut().rev() {
            sync.merge(action.undo(app)?);
        }
        Ok(sync)
    }

    fn redo(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        let mut sync = EngineSync::none();
        for action in &mut self.actions {
            sync.merge(action.redo(app)?);
        }
        Ok(sync)
    }

    fn label(&self) -> &'static str {
        self.label
    }
}
