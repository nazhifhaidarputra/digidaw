//! Host struct and implementation of `clack-host` crate for Digidaw (Karbeat)
//!
//! This piece of code defines the shared host implementation and host implementation. Plugin
//! requests are only recorded here; the UI owner acts on them when it pumps the instance.

use std::{
    cell::{Cell, RefCell},
    sync::atomic::{AtomicBool, AtomicU64, Ordering},
    thread::ThreadId,
    time::{Duration, Instant},
};

use clack_extensions::{
    audio_ports::{AudioPortRescanFlags, HostAudioPorts, HostAudioPortsImpl},
    gui::{GuiSize, HostGui, HostGuiImpl},
    latency::{HostLatency, HostLatencyImpl},
    log::{HostLog, HostLogImpl, LogSeverity},
    note_ports::{HostNotePorts, HostNotePortsImpl, NoteDialects, NotePortRescanFlags},
    params::{
        HostParams, HostParamsImplMainThread, HostParamsImplShared, ParamClearFlags,
        ParamRescanFlags,
    },
    state::{HostState, HostStateImpl},
    thread_check::{HostThreadCheck, HostThreadCheckImpl},
    timer::{HostTimer, HostTimerImpl, TimerId},
};
use clack_host::{
    host::{
        HostError as ClackError, HostExtensions, HostHandlers, MainThreadHandler, SharedHandler,
    },
    plugin::InitializingPluginHandle,
};

use crate::wrapper::in_audio_context;

/// Largest editor dimension accepted from a plugin.
const MAX_EDITOR_DIMENSION: u32 = 16_384;
/// Shortest timer period honoured, so a misbehaving plugin cannot spin the UI loop.
const MIN_TIMER_PERIOD: Duration = Duration::from_millis(8);

/// Ties the CLAP host callback handlers of one plugin instance together.
pub(crate) struct ClapHostHandlers;

impl HostHandlers for ClapHostHandlers {
    type Shared<'a> = ClapHostSharedHandler;
    type MainThread<'a> = ClapHostMainThreadHandler<'a>;
    type AudioProcessor<'a> = ();

    fn declare_extensions(builder: &mut HostExtensions<Self>, _shared: &Self::Shared<'_>) {
        builder
            .register::<HostLog>()
            .register::<HostThreadCheck>()
            .register::<HostParams>()
            .register::<HostState>()
            .register::<HostLatency>()
            .register::<HostAudioPorts>()
            .register::<HostNotePorts>()
            .register::<HostGui>()
            .register::<HostTimer>();
        #[cfg(target_os = "linux")]
        builder.register::<clack_extensions::posix_fd::HostPosixFd>();
    }
}

/// The Karbeat struct which implement SharedHandler trait
///
/// SharedHandler is responsible for shared host implementation. which requires the
/// host to implement Send and Sync. even though the current system achieves thread
/// affinity (where editor and processor lives in separate thread), we need to
/// implement it
pub(crate) struct ClapHostSharedHandler {
    owner: ThreadId,
    /// Plugin name, prefixed to the messages it logs.
    label: String,
    /// The plugin asked for `on_main_thread` to be called.
    pub callback_requested: AtomicBool,
    /// The plugin asked to be deactivated and activated again.
    pub restart_requested: AtomicBool,
    /// The plugin asked for a parameter flush while it may not be processing.
    pub flush_requested: AtomicBool,
    /// Client size the editor asked for, packed by [`GuiSize::pack_to_u64`]; zero when none is
    /// pending.
    pub resize_requested: AtomicU64,
    /// The editor was closed or lost its connection to the plugin.
    pub editor_closed: AtomicBool,
}

impl ClapHostSharedHandler {
    /// Must be created on the UI owner, which CLAP calls the main thread.
    pub fn new(label: &str) -> Self {
        Self {
            owner: std::thread::current().id(),
            label: label.to_owned(),
            callback_requested: AtomicBool::new(false),
            restart_requested: AtomicBool::new(false),
            flush_requested: AtomicBool::new(false),
            resize_requested: AtomicU64::new(0),
            editor_closed: AtomicBool::new(false),
        }
    }

    /// Takes the editor size the plugin last asked for.
    pub fn take_resize_request(&self) -> Option<(u32, u32)> {
        let packed = self.resize_requested.swap(0, Ordering::AcqRel);
        (packed != 0).then(|| {
            let size = GuiSize::unpack_from_u64(packed);
            (size.width, size.height)
        })
    }
}

impl<'a> SharedHandler<'a> for ClapHostSharedHandler {
    fn initializing(&self, _instance: InitializingPluginHandle<'a>) {}

    fn request_restart(&self) {
        self.restart_requested.store(true, Ordering::Release);
    }

    fn request_process(&self) {
        // Prepared instances stay activated and are processed continuously while running.
    }

    fn request_callback(&self) {
        self.callback_requested.store(true, Ordering::Release);
    }
}

impl HostThreadCheckImpl for ClapHostSharedHandler {
    fn is_main_thread(&self) -> bool {
        std::thread::current().id() == self.owner
    }

    fn is_audio_thread(&self) -> bool {
        in_audio_context()
    }
}

impl HostLogImpl for ClapHostSharedHandler {
    fn log(&self, severity: LogSeverity, message: &str) {
        // Logging may block or allocate, which the audio thread must never do.
        if in_audio_context() {
            return;
        }
        let label = &self.label;
        match severity {
            LogSeverity::Debug => tracing::debug!("{label}: {message}"),
            LogSeverity::Info => tracing::info!("{label}: {message}"),
            LogSeverity::Warning => tracing::warn!("{label}: {message}"),
            LogSeverity::Error
            | LogSeverity::Fatal
            | LogSeverity::HostMisbehaving
            | LogSeverity::PluginMisbehaving => tracing::error!("{label}: {message}"),
        }
    }
}

impl HostParamsImplShared for ClapHostSharedHandler {
    fn request_flush(&self) {
        self.flush_requested.store(true, Ordering::Release);
    }
}

impl HostGuiImpl for ClapHostSharedHandler {
    fn resize_hints_changed(&self) {
        // Constraints are read again whenever the editor is opened.
    }

    fn request_resize(&self, new_size: GuiSize) -> Result<(), ClackError> {
        let range = 1..=MAX_EDITOR_DIMENSION;
        if !range.contains(&new_size.width) || !range.contains(&new_size.height) {
            return Err(ClackError::Message("editor size is out of range"));
        }
        self.resize_requested
            .store(new_size.pack_to_u64(), Ordering::Release);
        Ok(())
    }

    fn request_show(&self) -> Result<(), ClackError> {
        // The host window is shown as soon as the editor is attached to it.
        Ok(())
    }

    fn request_hide(&self) -> Result<(), ClackError> {
        Err(ClackError::Message(
            "embedded editors are closed by the host",
        ))
    }

    fn closed(&self, _was_destroyed: bool) {
        self.editor_closed.store(true, Ordering::Release);
    }
}

/// A timer the plugin registered for its main-thread work.
#[derive(Clone, Copy, Debug)]
pub(crate) struct Timer {
    pub id: u32,
    period: Duration,
    next: Instant,
}

/// Host callbacks the plugin makes on the main thread, which is the UI owner.
pub(crate) struct ClapHostMainThreadHandler<'a> {
    shared: &'a ClapHostSharedHandler,
    /// The plugin changed parameter values or text without reporting them as events.
    pub values_changed: Cell<bool>,
    timers: RefCell<Vec<Timer>>,
    next_timer: Cell<u32>,
    #[cfg(target_os = "linux")]
    pub fds: RefCell<Vec<(i32, clack_extensions::posix_fd::FdFlags)>>,
}

impl<'a> ClapHostMainThreadHandler<'a> {
    pub fn new(shared: &'a ClapHostSharedHandler) -> Self {
        Self {
            shared,
            values_changed: Cell::new(false),
            timers: RefCell::new(Vec::new()),
            next_timer: Cell::new(0),
            #[cfg(target_os = "linux")]
            fds: RefCell::new(Vec::new()),
        }
    }

    /// Collects the timers due at `now` into `due` and schedules their next run.
    pub fn due_timers(&self, now: Instant, due: &mut Vec<u32>) {
        due.clear();
        if let Ok(mut timers) = self.timers.try_borrow_mut() {
            for timer in timers.iter_mut().filter(|timer| timer.next <= now) {
                timer.next = now.checked_add(timer.period).unwrap_or(now);
                due.push(timer.id);
            }
        }
    }

    /// Whether `id` is still registered, since an earlier timer callback may remove it.
    pub fn has_timer(&self, id: u32) -> bool {
        self.timers
            .try_borrow()
            .is_ok_and(|timers| timers.iter().any(|timer| timer.id == id))
    }
}

impl<'a> MainThreadHandler<'a> for ClapHostMainThreadHandler<'a> {}

impl HostParamsImplMainThread for ClapHostMainThreadHandler<'_> {
    fn rescan(&self, flags: ParamRescanFlags) {
        if flags.requires_restart() {
            // A changed parameter list is only read when the instance is created again.
            tracing::warn!(
                "{}: the plugin changed its parameter list, which takes effect after reloading it",
                self.shared.label
            );
        }
        self.values_changed.set(true);
    }

    fn clear(&self, _param_id: clack_host::utils::ClapId, _flags: ParamClearFlags) {
        // The host keeps no automation or modulation of its own for external parameters.
    }
}

impl HostStateImpl for ClapHostMainThreadHandler<'_> {
    fn mark_dirty(&self) {
        // State is captured fresh whenever the project is saved.
    }
}

impl HostLatencyImpl for ClapHostMainThreadHandler<'_> {
    fn changed(&self) {
        // Latency is read at every activation, and an active plugin must request a restart to
        // change it.
    }
}

impl HostAudioPortsImpl for ClapHostMainThreadHandler<'_> {
    fn is_rescan_flag_supported(&self, _flag: AudioPortRescanFlags) -> bool {
        true
    }

    fn rescan(&self, flags: AudioPortRescanFlags) {
        if flags.requires_deactivate() {
            self.shared.restart_requested.store(true, Ordering::Release);
        }
    }
}

impl HostNotePortsImpl for ClapHostMainThreadHandler<'_> {
    fn supported_dialects(&self) -> NoteDialects {
        NoteDialects::CLAP | NoteDialects::MIDI
    }

    fn rescan(&self, flags: NotePortRescanFlags) {
        if flags.intersects(NotePortRescanFlags::ALL) {
            self.shared.restart_requested.store(true, Ordering::Release);
        }
    }
}

impl HostTimerImpl for ClapHostMainThreadHandler<'_> {
    fn register_timer(&self, period_ms: u32) -> Result<TimerId, ClackError> {
        let mut timers = self
            .timers
            .try_borrow_mut()
            .map_err(|_| ClackError::Message("timers are being serviced"))?;
        let id = self.next_timer.get();
        // `u32::MAX` is CLAP's invalid ID.
        let next = id.checked_add(1).filter(|next| *next != u32::MAX);
        self.next_timer.set(next.unwrap_or(0));
        let period = Duration::from_millis(u64::from(period_ms)).max(MIN_TIMER_PERIOD);
        let now = Instant::now();
        timers.push(Timer {
            id,
            period,
            next: now.checked_add(period).unwrap_or(now),
        });
        Ok(TimerId(id))
    }

    fn unregister_timer(&self, timer_id: TimerId) -> Result<(), ClackError> {
        let mut timers = self
            .timers
            .try_borrow_mut()
            .map_err(|_| ClackError::Message("timers are being serviced"))?;
        let before = timers.len();
        timers.retain(|timer| timer.id != timer_id.0);
        if timers.len() == before {
            Err(ClackError::Message("unknown timer"))
        } else {
            Ok(())
        }
    }
}

#[cfg(target_os = "linux")]
impl clack_extensions::posix_fd::HostPosixFdImpl for ClapHostMainThreadHandler<'_> {
    fn register_fd(
        &self,
        fd: i32,
        flags: clack_extensions::posix_fd::FdFlags,
    ) -> Result<(), ClackError> {
        let mut fds = self
            .fds
            .try_borrow_mut()
            .map_err(|_| ClackError::Message("descriptors are being serviced"))?;
        if fd < 0 || fds.iter().any(|(registered, _)| *registered == fd) {
            return Err(ClackError::Message(
                "descriptor is invalid or already registered",
            ));
        }
        fds.push((fd, flags));
        Ok(())
    }

    fn modify_fd(
        &self,
        fd: i32,
        flags: clack_extensions::posix_fd::FdFlags,
    ) -> Result<(), ClackError> {
        let mut fds = self
            .fds
            .try_borrow_mut()
            .map_err(|_| ClackError::Message("descriptors are being serviced"))?;
        let entry = fds
            .iter_mut()
            .find(|(registered, _)| *registered == fd)
            .ok_or(ClackError::Message("unknown descriptor"))?;
        entry.1 = flags;
        Ok(())
    }

    fn unregister_fd(&self, fd: i32) -> Result<(), ClackError> {
        let mut fds = self
            .fds
            .try_borrow_mut()
            .map_err(|_| ClackError::Message("descriptors are being serviced"))?;
        let before = fds.len();
        fds.retain(|(registered, _)| *registered != fd);
        if fds.len() == before {
            Err(ClackError::Message("unknown descriptor"))
        } else {
            Ok(())
        }
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used, reason = "test fixtures register known timers")]
mod tests {
    use super::*;

    #[test]
    fn timers_fire_when_due_and_stop_once_unregistered() {
        let shared = ClapHostSharedHandler::new("Test");
        let host = ClapHostMainThreadHandler::new(&shared);
        let first = host.register_timer(1).unwrap();
        let second = host.register_timer(1_000).unwrap();
        assert_ne!(first, second);
        let mut due = Vec::new();
        host.due_timers(Instant::now() + Duration::from_millis(20), &mut due);
        assert_eq!(due, [first.0]);
        host.unregister_timer(first).unwrap();
        assert!(!host.has_timer(first.0) && host.has_timer(second.0));
        assert!(host.unregister_timer(first).is_err());
    }

    #[test]
    fn editor_resize_requests_are_validated_and_taken_once() {
        let shared = ClapHostSharedHandler::new("Test");
        assert!(
            shared
                .request_resize(GuiSize {
                    width: 0,
                    height: 10
                })
                .is_err()
        );
        shared
            .request_resize(GuiSize {
                width: 800,
                height: 600,
            })
            .unwrap();
        assert_eq!(shared.take_resize_request(), Some((800, 600)));
        assert_eq!(shared.take_resize_request(), None);
        assert!(shared.is_main_thread() && !shared.is_audio_thread());
    }
}
