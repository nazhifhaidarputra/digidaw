use std::{
    ops::{Deref, DerefMut},
    sync::Arc,
};

use crate::sync::{Mutex, MutexGuard, RwLock, RwLockReadGuard, RwLockWriteGuard};
use karbeat_core::context::DawContext as CoreDawContext;

pub(crate) use crate::api::project::DawContext;

pub(crate) struct DawSessionInner {
    core: RwLock<CoreDawContext>,
    project_operation: Mutex<()>,
}

pub(crate) type CoreReadGuard<'a> = RwLockReadGuard<'a, CoreDawContext>;
pub(crate) type CoreWriteGuard<'a> = RwLockWriteGuard<'a, CoreDawContext>;

pub(crate) struct ProjectWriteGuard<'a> {
    core: CoreWriteGuard<'a>,
    _operation: MutexGuard<'a, ()>,
}

impl Deref for ProjectWriteGuard<'_> {
    type Target = CoreDawContext;

    fn deref(&self) -> &Self::Target {
        &self.core
    }
}

impl DerefMut for ProjectWriteGuard<'_> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.core
    }
}

pub(crate) struct ProjectOperationGuard<'a> {
    session: &'a DawSessionInner,
    _operation: MutexGuard<'a, ()>,
}

impl ProjectOperationGuard<'_> {
    pub(crate) fn read_core(&self) -> CoreReadGuard<'_> {
        self.session.core.read()
    }

    pub(crate) fn write_core(&self) -> CoreWriteGuard<'_> {
        self.session.core.write()
    }
}

impl DawContext {
    pub(crate) fn new(core: CoreDawContext) -> Self {
        Self {
            inner: Arc::new(DawSessionInner {
                core: RwLock::new(core),
                project_operation: Mutex::new(()),
            }),
        }
    }

    pub(crate) fn read(&self) -> CoreReadGuard<'_> {
        self.inner.core.read()
    }

    pub(crate) fn runtime_write(&self) -> CoreWriteGuard<'_> {
        self.inner.core.write()
    }

    pub(crate) fn project_write(&self) -> ProjectWriteGuard<'_> {
        let operation = self.inner.project_operation.lock();
        let core = self.inner.core.write();
        ProjectWriteGuard {
            core,
            _operation: operation,
        }
    }

    pub(crate) fn begin_project_operation(&self) -> ProjectOperationGuard<'_> {
        let operation = self.inner.project_operation.lock();
        ProjectOperationGuard {
            session: &self.inner,
            _operation: operation,
        }
    }

    pub(crate) fn try_runtime_operation(&self) -> Option<MutexGuard<'_, ()>> {
        self.inner.project_operation.try_lock()
    }
}

macro_rules! read_ctx {
    ($ctx:ident) => {
        let core_guard = $ctx.read();
        let $ctx = &*core_guard;
    };
}

macro_rules! runtime_ctx {
    ($ctx:ident) => {
        let mut core_guard = $ctx.runtime_write();
        let $ctx = &mut *core_guard;
    };
}

macro_rules! project_ctx {
    ($ctx:ident) => {
        let mut core_guard = $ctx.project_write();
        let $ctx = &mut *core_guard;
    };
}

pub(crate) use project_ctx;
pub(crate) use read_ctx;
pub(crate) use runtime_ctx;

#[cfg(test)]
mod tests {
    use super::DawContext;
    use crate::sync::{check_random, mpsc, thread};

    fn project_name(ctx: &karbeat_core::context::DawContext) -> &str {
        &ctx.app_state.metadata.name
    }

    fn set_project_name(ctx: &mut karbeat_core::context::DawContext, name: &str) {
        ctx.app_state.metadata.name = name.into();
    }

    #[test]
    fn guards_deref_to_the_core_context() {
        check_random(
            || {
                let session = DawContext::new(karbeat_core::context::DawContext::new());
                let read = session.read();
                assert_eq!(project_name(&read), "Untitled");
                drop(read);

                let mut write = session.project_write();
                set_project_name(&mut write, "Guarded");
                drop(write);

                assert_eq!(session.read().app_state.metadata.name, "Guarded");
            },
            1,
        );
    }

    #[test]
    fn project_operation_does_not_hold_the_core_lock() {
        check_random(
            || {
                let session = DawContext::new(karbeat_core::context::DawContext::new());
                let operation = session.begin_project_operation();
                assert!(session.try_runtime_operation().is_none());

                let (sender, receiver) = mpsc::channel();
                let writer_session = session.clone();
                let writer = thread::spawn(move || {
                    let _guard = writer_session.project_write();
                    sender.send(()).expect("test receiver is available");
                });

                assert_eq!(session.read().app_state.tracks.len(), 0);
                thread::yield_now();
                assert!(receiver.try_recv().is_err());
                drop(operation);
                receiver
                    .recv()
                    .expect("project mutation should continue after the transaction");
                writer.join().expect("writer thread should complete");
            },
            100,
        );
    }
}
