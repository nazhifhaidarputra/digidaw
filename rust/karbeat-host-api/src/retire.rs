//! Deferred destruction of values the audio thread lets go of.
//!
//! The audio thread must never free memory or run a destructor that may block. Everything it
//! can drop therefore lives in a [`Retiree`]: a heap node allocated off the audio thread
//! together with the value and an intrusive list link. Dropping a `Retiree` pushes its own
//! node onto a lock-free list with one compare-and-swap. The push needs no storage beyond the
//! node itself, so there is no queue that can fill up and no allocation on the audio thread.
//!
//! [`RetirementService`] drains the lists. Values whose [`Owner`] is
//! [`Owner::AnyThread`] are destroyed on its drain thread. Values that must die on the native
//! UI owner ([`Owner::UiThread`]) are posted to that thread's task queue, which keeps the
//! thread-affinity rules of VST3 and CLAP.
//!
//! Each node carries its own dispose function rather than requiring a `Retire` trait on the
//! value. A trait would need implementations for foreign types such as `Vec`, `Arc` or a
//! triple-buffer handle, which the orphan rule forbids outside this crate.
//!
//! Leaks that remain unavoidable (a return queue whose owner has gone away) go through
//! [`leak`], which counts them so tests can assert that none happened.

use std::{
    cell::Cell,
    fmt,
    marker::PhantomData,
    mem::{ManuallyDrop, forget},
    ops::{Deref, DerefMut},
    ptr::{NonNull, null_mut},
    sync::{
        Mutex, OnceLock, PoisonError,
        atomic::{AtomicPtr, AtomicU64, AtomicUsize, Ordering},
    },
    thread::{Builder, Thread, park_timeout, sleep},
    time::{Duration, Instant},
};

use crate::native_ui::NativeUiDispatcher;

/// How long the drain thread sleeps when it finds nothing to do. The audio thread never wakes
/// it, because waking a thread is a system call.
const IDLE_INTERVAL: Duration = Duration::from_millis(10);

/// Which thread may destroy a retired value.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Owner {
    /// Any thread except the audio thread; destroyed on the service's drain thread.
    AnyThread,
    /// The native UI owner thread; posted to its task queue.
    UiThread,
}

/// A destruction task for the native UI owner.
pub type UiTask = Box<dyn FnOnce() + Send>;

/// Why the UI owner did not accept a task; the task comes back so it is not lost.
pub enum UiPostError {
    /// The owner's queue is full; retry later.
    Full(UiTask),
    /// No native UI owner runs in this process.
    Unavailable(UiTask),
}

/// Posts a task to the thread that owns native UI objects.
pub type UiPost = fn(UiTask) -> Result<(), UiPostError>;

/// Intrusive list link at the start of every node.
#[repr(C)]
struct Link {
    next: *mut Link,
    owner: Owner,
    service: &'static RetirementService,
    /// Rebuilds the typed node from this link and destroys it.
    dispose: unsafe fn(NonNull<Link>),
}

/// A value with its list link, allocated as one block.
///
/// `repr(C)` puts `link` at offset 0, so a pointer to the link is also a pointer to the node.
#[repr(C)]
struct Node<T> {
    link: Link,
    value: T,
    /// Consumes the value on the drain loop; `None` drops it.
    custom: Option<fn(T)>,
}

/// Destroys the node behind `link` and the value inside it.
///
/// # Safety
///
/// `link` must point to the link of a live `Node<T>` allocated by [`Retiree::wrap`] with this
/// same `T`, and nothing else may access that node afterwards.
unsafe fn dispose_node<T>(link: NonNull<Link>) {
    // SAFETY: the caller guarantees `link` is the first field of a `Box<Node<T>>` that it owns;
    // `repr(C)` makes the cast to the node valid.
    let node = unsafe { Box::from_raw(link.as_ptr().cast::<Node<T>>()) };
    let Node { value, custom, .. } = *node;
    match custom {
        Some(dispose) => dispose(value),
        None => drop(value),
    }
}

/// A value that is destroyed off the audio thread when dropped.
///
/// Create it off the audio thread: [`Retiree::new`] allocates. Dropping it anywhere, including
/// on the audio thread, only links its node into the service's list without allocating or
/// blocking.
pub struct Retiree<T: Send + 'static> {
    node: NonNull<Node<T>>,
    _owns: PhantomData<Box<Node<T>>>,
}

// SAFETY: a `Retiree` uniquely owns its node, like `Box<T>`; moving it to another thread moves
// the value, which is `Send`.
unsafe impl<T: Send + 'static> Send for Retiree<T> {}
// SAFETY: shared access only hands out `&T`, which is sound to share when `T: Sync`.
unsafe impl<T: Send + Sync + 'static> Sync for Retiree<T> {}

impl<T: Send + 'static> Retiree<T> {
    /// Wraps `value` for the global service, destroyed by dropping it. Allocates.
    pub fn new(owner: Owner, value: T) -> Self {
        RetirementService::global().wrap(owner, value, None)
    }

    /// Wraps `value` for the global service, destroyed by passing it to `dispose`. Allocates.
    pub fn with_dispose(owner: Owner, value: T, dispose: fn(T)) -> Self {
        RetirementService::global().wrap(owner, value, Some(dispose))
    }

    /// The thread that will destroy the value.
    pub fn owner(&self) -> Owner {
        // SAFETY: `node` is live while `self` exists.
        unsafe { self.node.as_ref() }.link.owner
    }

    /// Unwraps the value and frees the node on this thread. Never call on the audio thread.
    pub fn into_inner(self) -> T {
        let this = ManuallyDrop::new(self);
        // SAFETY: `this` is never dropped, so the node is reclaimed exactly once, here.
        let node = unsafe { Box::from_raw(this.node.as_ptr()) };
        node.value
    }
}

impl<T: Clone + Send + 'static> Clone for Retiree<T> {
    /// Clones the value into a new node with the same owner and disposal. Allocates.
    fn clone(&self) -> Self {
        // SAFETY: `node` is live while `self` exists.
        let node = unsafe { self.node.as_ref() };
        node.link
            .service
            .wrap(node.link.owner, node.value.clone(), node.custom)
    }
}

impl<T: Send + 'static> Deref for Retiree<T> {
    type Target = T;

    fn deref(&self) -> &T {
        // SAFETY: `node` is live and uniquely owned while `self` exists.
        &unsafe { self.node.as_ref() }.value
    }
}

impl<T: Send + 'static> DerefMut for Retiree<T> {
    fn deref_mut(&mut self) -> &mut T {
        // SAFETY: `node` is live and `&mut self` guarantees exclusive access.
        &mut unsafe { self.node.as_mut() }.value
    }
}

impl<T: Send + 'static> Drop for Retiree<T> {
    fn drop(&mut self) {
        let link = self.node.cast::<Link>();
        // SAFETY: the link stays valid until a drain disposes the node, after this push.
        let service = unsafe { link.as_ref() }.service;
        service.push(link);
    }
}

impl<T: Send + fmt::Debug + 'static> fmt::Debug for Retiree<T> {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Debug::fmt(&**self, formatter)
    }
}

/// A node pointer moved to the thread that disposes it.
struct SendLink(NonNull<Link>);

// SAFETY: every node holds a `Send` value and is owned by exactly one list or task at a time.
unsafe impl Send for SendLink {}

/// Drains retired values on a background thread and hands UI-owned ones to the UI owner.
pub struct RetirementService {
    any_thread: AtomicPtr<Link>,
    ui_thread: AtomicPtr<Link>,
    /// Retired values not destroyed yet, across both lists and posted UI tasks.
    queued: AtomicUsize,
    ui_post: UiPost,
    /// UI tasks the UI owner has not accepted yet. Never touched by the audio thread.
    ui_pending: Mutex<Vec<UiTask>>,
    drain_thread: OnceLock<Thread>,
}

impl RetirementService {
    /// The process-wide service, posting UI-owned values to the native UI owner.
    pub fn global() -> &'static Self {
        static GLOBAL: OnceLock<&'static RetirementService> = OnceLock::new();
        GLOBAL.get_or_init(|| Self::start(NativeUiDispatcher::post))
    }

    /// Starts a service with its own drain thread. The service lives for the rest of the
    /// process, because nodes refer to it.
    pub fn start(ui_post: UiPost) -> &'static Self {
        let service: &'static Self = Box::leak(Box::new(Self {
            any_thread: AtomicPtr::new(null_mut()),
            ui_thread: AtomicPtr::new(null_mut()),
            queued: AtomicUsize::new(0),
            ui_post,
            ui_pending: Mutex::new(Vec::new()),
            drain_thread: OnceLock::new(),
        }));
        let spawned = Builder::new()
            .name("karbeat-retirement".to_owned())
            .spawn(move || service.drain_loop());
        match spawned {
            Ok(handle) => {
                // Only set here, so it is never set already and the result is always `Ok`.
                drop(service.drain_thread.set(handle.thread().clone()));
            }
            // Without the thread, `drain_all` still drains on its caller's thread.
            Err(error) => tracing::error!("Could not start the retirement thread: {error}"),
        }
        service
    }

    /// Wraps `value` in a node owned by this service. Allocates.
    pub fn wrap<T: Send + 'static>(
        &'static self,
        owner: Owner,
        value: T,
        dispose: Option<fn(T)>,
    ) -> Retiree<T> {
        let node = Box::new(Node {
            link: Link {
                next: null_mut(),
                owner,
                service: self,
                dispose: dispose_node::<T>,
            },
            value,
            custom: dispose,
        });
        Retiree {
            node: NonNull::from(Box::leak(node)),
            _owns: PhantomData,
        }
    }

    /// Links a dropped node into its owner's list. Lock-free and allocation-free; safe on the
    /// audio thread.
    fn push(&self, link: NonNull<Link>) {
        // Counted before it becomes visible, so `drain_all` never sees an empty count while
        // the node is still waiting.
        self.queued.fetch_add(1, Ordering::Relaxed);
        // SAFETY: the dropped `Retiree` owned the node; nobody else can reach it until the
        // compare-and-swap below publishes it.
        let node = unsafe { &mut *link.as_ptr() };
        let head = match node.owner {
            Owner::AnyThread => &self.any_thread,
            Owner::UiThread => &self.ui_thread,
        };
        let mut current = head.load(Ordering::Relaxed);
        loop {
            node.next = current;
            match head.compare_exchange_weak(
                current,
                link.as_ptr(),
                Ordering::Release,
                Ordering::Relaxed,
            ) {
                Ok(_) => return,
                Err(actual) => current = actual,
            }
        }
    }

    /// Takes the whole list in retirement order. Taking everything at once with one swap rules
    /// out the ABA problem of popping single nodes.
    fn take_all(head: &AtomicPtr<Link>) -> Vec<SendLink> {
        let mut next = head.swap(null_mut(), Ordering::Acquire);
        let mut taken = Vec::new();
        while let Some(link) = NonNull::new(next) {
            // SAFETY: the swap made this thread the only owner of every node in the list.
            next = unsafe { link.as_ref() }.next;
            taken.push(SendLink(link));
        }
        // The list is a stack; destroy the oldest value first.
        taken.reverse();
        taken
    }

    fn dispose(&self, link: SendLink) {
        // SAFETY: `take_all` handed over sole ownership of the node, which stays valid until
        // its dispose function below frees it.
        let dispose = unsafe { link.0.as_ref() }.dispose;
        // SAFETY: `dispose` was set by `wrap` for this node's own value type, and nothing else
        // can reach the node.
        unsafe { dispose(link.0) };
        self.queued.fetch_sub(1, Ordering::Release);
    }

    /// One pass over both lists. Returns whether it did any work.
    fn drain_once(&'static self) -> bool {
        let mut worked = false;
        for link in Self::take_all(&self.any_thread) {
            self.dispose(link);
            worked = true;
        }
        let mut pending = self
            .ui_pending
            .lock()
            .unwrap_or_else(PoisonError::into_inner);
        for link in Self::take_all(&self.ui_thread) {
            pending.push(Box::new(move || self.dispose(link)));
        }
        let mut retry = Vec::new();
        for task in pending.drain(..) {
            worked = true;
            match (self.ui_post)(task) {
                Ok(()) => {}
                Err(UiPostError::Full(task)) => retry.push(task),
                // Without a UI owner in the process, no native UI object can exist, so the
                // value has no thread to be bound to.
                Err(UiPostError::Unavailable(task)) => task(),
            }
        }
        *pending = retry;
        worked
    }

    fn drain_loop(&'static self) {
        loop {
            if !self.drain_once() {
                park_timeout(IDLE_INTERVAL);
            }
        }
    }

    /// Retired values not destroyed yet.
    pub fn queued(&self) -> usize {
        self.queued.load(Ordering::Acquire)
    }

    /// Blocks until every value retired before the call is destroyed, or `timeout` elapses.
    /// Returns whether everything was destroyed. Never call on the audio thread.
    ///
    /// Drains on the calling thread as well, so it finishes even without the drain thread.
    /// Values posted to the UI owner count as destroyed only once that thread ran them.
    pub fn drain_all(&'static self, timeout: Duration) -> bool {
        let started = Instant::now();
        if let Some(thread) = self.drain_thread.get() {
            thread.unpark();
        }
        loop {
            self.drain_once();
            if self.queued() == 0 {
                return true;
            }
            if started.elapsed() >= timeout {
                return false;
            }
            sleep(Duration::from_millis(1));
        }
    }
}

thread_local! {
    static REALTIME: Cell<bool> = const { Cell::new(false) };
}

static LEAKED: AtomicU64 = AtomicU64::new(0);
static LEAKS_REPORTED: AtomicU64 = AtomicU64::new(0);

/// Marks the calling thread as real-time, so [`leak`] only counts there and never logs.
pub fn mark_realtime_thread() {
    REALTIME.with(|realtime| realtime.set(true));
}

/// Whether the calling thread was marked with [`mark_realtime_thread`].
pub fn is_realtime_thread() -> bool {
    REALTIME.with(Cell::get)
}

/// The one place where a value is deliberately never destroyed.
///
/// Use it only when destroying the value on this thread is unsafe and no owner is left to
/// destroy it, such as a return queue whose control owner shut down. Counts the leak; off the
/// audio thread it also logs `what`. Safe on the audio thread.
pub fn leak<T>(value: T, what: &'static str) {
    forget(value);
    LEAKED.fetch_add(1, Ordering::Relaxed);
    if !is_realtime_thread() {
        tracing::error!("Leaked {what} to keep it from being destroyed on the wrong thread");
    }
}

/// Values leaked through [`leak`] since the process started.
pub fn leaked_objects() -> u64 {
    LEAKED.load(Ordering::Relaxed)
}

/// Logs the leaks not reported yet, once. Call it after teardown, off the audio thread.
pub fn report_leaks() {
    let leaked = leaked_objects();
    let reported = LEAKS_REPORTED.swap(leaked, Ordering::Relaxed);
    if leaked > reported {
        tracing::error!(
            "{} values were leaked to avoid destroying them on the wrong thread",
            leaked.saturating_sub(reported)
        );
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used, reason = "tests report failures by panicking")]
mod tests {
    use std::{
        sync::{
            Arc, Mutex,
            atomic::AtomicBool,
            mpsc::{Receiver, Sender, channel},
        },
        thread::{self, ThreadId},
    };

    use super::*;

    /// Records the thread that dropped it.
    struct Probe(Arc<Mutex<Option<ThreadId>>>);

    impl Drop for Probe {
        fn drop(&mut self) {
            *self.0.lock().unwrap() = Some(thread::current().id());
        }
    }

    fn probe() -> (Probe, Arc<Mutex<Option<ThreadId>>>) {
        let dropped = Arc::new(Mutex::new(None));
        (Probe(Arc::clone(&dropped)), dropped)
    }

    fn no_ui(task: UiTask) -> Result<(), UiPostError> {
        Err(UiPostError::Unavailable(task))
    }

    static UI_SENDER: OnceLock<Mutex<Sender<UiTask>>> = OnceLock::new();
    static UI_FULL: AtomicBool = AtomicBool::new(false);

    fn fake_ui(task: UiTask) -> Result<(), UiPostError> {
        if UI_FULL.load(Ordering::Acquire) {
            return Err(UiPostError::Full(task));
        }
        UI_SENDER.get().unwrap().lock().unwrap().send(task).unwrap();
        Ok(())
    }

    fn ui_thread() -> (ThreadId, Receiver<()>) {
        let (sender, tasks) = channel::<UiTask>();
        UI_SENDER.set(Mutex::new(sender)).ok().unwrap();
        let (ran, done) = channel();
        let ui = thread::spawn(move || {
            for task in tasks {
                task();
                ran.send(()).unwrap();
            }
        });
        (ui.thread().id(), done)
    }

    #[test]
    fn a_value_dropped_anywhere_is_destroyed_on_the_drain_thread() {
        let service = RetirementService::start(no_ui);
        let (value, dropped) = probe();
        let retiree = service.wrap(Owner::AnyThread, value, None);

        let audio = thread::spawn(move || {
            mark_realtime_thread();
            drop(retiree);
            thread::current().id()
        })
        .join()
        .unwrap();

        assert!(service.drain_all(Duration::from_secs(5)));
        assert_ne!(dropped.lock().unwrap().unwrap(), audio);
        assert_eq!(service.queued(), 0);
    }

    #[test]
    fn ui_owned_values_die_on_the_ui_owner_even_when_its_queue_was_full() {
        let service = RetirementService::start(fake_ui);
        let (ui, ran) = ui_thread();
        let (value, dropped) = probe();

        UI_FULL.store(true, Ordering::Release);
        drop(service.wrap(Owner::UiThread, value, None));
        sleep(IDLE_INTERVAL * 3);
        assert!(dropped.lock().unwrap().is_none());
        assert_eq!(service.queued(), 1);

        UI_FULL.store(false, Ordering::Release);
        assert!(service.drain_all(Duration::from_secs(5)));
        ran.recv().unwrap();
        assert_eq!(*dropped.lock().unwrap(), Some(ui));
    }

    #[test]
    fn a_custom_dispose_receives_the_value_and_values_retire_in_order() {
        static ORDER: Mutex<Vec<u32>> = Mutex::new(Vec::new());
        let service = RetirementService::start(no_ui);
        let record = |value: u32| ORDER.lock().unwrap().push(value);
        let first = service.wrap(Owner::AnyThread, 1_u32, Some(record));
        let second = service.wrap(Owner::AnyThread, 2_u32, Some(record));
        drop(first);
        drop(second);

        assert!(service.drain_all(Duration::from_secs(5)));
        assert_eq!(*ORDER.lock().unwrap(), [1, 2]);
    }

    #[test]
    fn many_threads_retire_without_losing_a_value() {
        let service = RetirementService::start(no_ui);
        let destroyed = Arc::new(AtomicUsize::new(0));
        let count = |destroyed: Arc<AtomicUsize>| {
            destroyed.fetch_add(1, Ordering::Relaxed);
        };
        let producers: Vec<_> = (0..4)
            .map(|_| {
                let retirees: Vec<_> = (0..1_000)
                    .map(|_| service.wrap(Owner::AnyThread, Arc::clone(&destroyed), Some(count)))
                    .collect();
                thread::spawn(move || drop(retirees))
            })
            .collect();
        for producer in producers {
            producer.join().unwrap();
        }

        assert!(service.drain_all(Duration::from_secs(5)));
        assert_eq!(destroyed.load(Ordering::Relaxed), 4_000);
    }

    #[test]
    fn into_inner_returns_the_value_without_retiring_it() {
        let service = RetirementService::start(no_ui);
        let (value, dropped) = probe();
        let value = service.wrap(Owner::AnyThread, value, None).into_inner();

        assert_eq!(service.queued(), 0);
        drop(value);
        assert_eq!(*dropped.lock().unwrap(), Some(thread::current().id()));
    }

    #[test]
    fn leaks_are_counted_and_reported_once() {
        let before = leaked_objects();
        leak(vec![1_u8], "test buffer");
        assert_eq!(leaked_objects(), before + 1);
        report_leaks();
        assert_eq!(LEAKS_REPORTED.load(Ordering::Relaxed), leaked_objects());
    }
}
