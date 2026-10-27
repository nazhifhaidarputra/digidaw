use std::{
    ops::{Deref, DerefMut},
    sync::Arc,
};

use crate::sync::{Mutex, MutexGuard, RwLock, RwLockReadGuard, RwLockWriteGuard};
use karbeat_audio::context::DawContext as CoreDawContext;

pub(crate) use crate::api::project::DawContext;

pub(crate) struct DawSessionInner {
    core: RwLock<CoreDawContext>,
    project_operation: Mutex<()>,
    /// Wakes the auto save worker after a settings change; dropping it stops the worker.
    ///
    /// A plain OS lock rather than `crate::sync`: the worker runs on a real OS thread, outside
    /// any Shuttle schedule.
    pub(crate) auto_save_wake: parking_lot::Mutex<Option<std::sync::mpsc::Sender<()>>>,
    /// Told whenever a write leaves the project's saved status changed.
    ///
    /// A plain OS lock, taken only after the core lock and never held across a wait.
    save_status_listener: parking_lot::Mutex<Option<SaveStatusListener>>,
}

/// Receives whether the project has no unsaved changes. Returns `false` once it stops
/// listening, which removes it.
pub(crate) type SaveStatusListener = Box<dyn Fn(bool) -> bool + Send + Sync>;

impl DawSessionInner {
    fn write_core(&self) -> CoreWriteGuard<'_> {
        let core = self.core.write();
        CoreWriteGuard {
            was_saved: core.app_state.session.is_saved(),
            core,
            session: self,
        }
    }

    fn notify_save_status(&self, is_saved: bool) {
        let mut listener = self.save_status_listener.lock();
        if listener.as_ref().is_some_and(|notify| !notify(is_saved)) {
            *listener = None;
        }
    }
}

pub(crate) type CoreReadGuard<'a> = RwLockReadGuard<'a, CoreDawContext>;

/// Write access to the core context. Every write goes through this guard, so it reports a
/// change of the project's saved status when it is released, whichever API caused it.
pub(crate) struct CoreWriteGuard<'a> {
    core: RwLockWriteGuard<'a, CoreDawContext>,
    session: &'a DawSessionInner,
    was_saved: bool,
}

impl Deref for CoreWriteGuard<'_> {
    type Target = CoreDawContext;

    fn deref(&self) -> &Self::Target {
        &self.core
    }
}

impl DerefMut for CoreWriteGuard<'_> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.core
    }
}

impl Drop for CoreWriteGuard<'_> {
    fn drop(&mut self) {
        let is_saved = self.core.app_state.session.is_saved();
        if is_saved != self.was_saved {
            self.session.notify_save_status(is_saved);
        }
    }
}

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
        self.session.write_core()
    }
}

impl DawContext {
    pub(crate) fn new(core: CoreDawContext) -> Self {
        Self {
            inner: Arc::new(DawSessionInner {
                core: RwLock::new(core),
                project_operation: Mutex::new(()),
                auto_save_wake: parking_lot::Mutex::new(None),
                save_status_listener: parking_lot::Mutex::new(None),
            }),
        }
    }

    pub(crate) fn read(&self) -> CoreReadGuard<'_> {
        self.inner.core.read()
    }

    pub(crate) fn runtime_write(&self) -> CoreWriteGuard<'_> {
        self.inner.write_core()
    }

    /// Reports the project's saved status to `listener`: the current status now, then every
    /// change. Replaces the previous listener.
    pub(crate) fn set_save_status_listener(&self, listener: SaveStatusListener) {
        // Reading the core first keeps a write from changing the status between the initial
        // report and the listener being installed.
        let core = self.read();
        let listening = listener(core.app_state.session.is_saved());
        *self.inner.save_status_listener.lock() = listening.then_some(listener);
    }

    pub(crate) fn project_write(&self) -> ProjectWriteGuard<'_> {
        let operation = self.inner.project_operation.lock();
        let core = self.inner.write_core();
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

    fn project_name(ctx: &karbeat_audio::context::DawContext) -> &str {
        &ctx.app_state.metadata.name
    }

    fn set_project_name(ctx: &mut karbeat_audio::context::DawContext, name: &str) {
        ctx.app_state.metadata.name = name.into();
    }

    #[test]
    fn guards_deref_to_the_core_context() {
        check_random(
            || {
                let session = DawContext::new(karbeat_audio::context::DawContext::new());
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
    fn writes_report_a_changed_saved_status_once() {
        check_random(
            || {
                let session = DawContext::new(karbeat_audio::context::DawContext::new());
                let reported = std::sync::Arc::new(parking_lot::Mutex::new(Vec::new()));
                let sink = reported.clone();
                session.set_save_status_listener(Box::new(move |saved| {
                    sink.lock().push(saved);
                    true
                }));

                session.project_write().mark_project_modified();
                session.runtime_write().mark_project_modified();
                set_project_name(&mut session.runtime_write(), "Not a modification");
                {
                    let operation = session.begin_project_operation();
                    let mut core = operation.write_core();
                    let revision = core.app_state.session.revision();
                    core.app_state.session.mark_saved_at(revision);
                }

                assert_eq!(*reported.lock(), [true, false, true]);
            },
            1,
        );
    }

    #[test]
    fn a_listener_that_stops_listening_is_removed() {
        check_random(
            || {
                let session = DawContext::new(karbeat_audio::context::DawContext::new());
                let calls = std::sync::Arc::new(parking_lot::Mutex::new(0));
                let counter = calls.clone();
                session.set_save_status_listener(Box::new(move |_| {
                    *counter.lock() += 1;
                    *counter.lock() < 2
                }));

                session.project_write().mark_project_modified();
                let mut core = session.runtime_write();
                let revision = core.app_state.session.revision();
                core.app_state.session.mark_saved_at(revision);
                drop(core);

                assert_eq!(*calls.lock(), 2);
            },
            1,
        );
    }

    #[test]
    fn project_operation_does_not_hold_the_core_lock() {
        check_random(
            || {
                let session = DawContext::new(karbeat_audio::context::DawContext::new());
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
