//! VST3 Linux event/timer dispatch; pumped by the native UI loop, including with closed editors.
#![allow(non_snake_case, reason = "VST3 interface method names are ABI-defined")]

use std::{
    cell::RefCell,
    rc::Rc,
    thread::ThreadId,
    time::{Duration, Instant},
};
use vst3::{
    ComPtr, ComRef,
    Steinberg::{Linux::*, kInvalidArgument, kResultFalse, kResultOk, tresult},
};

#[derive(Clone)]
struct Timer {
    handler: ComPtr<ITimerHandler>,
    interval: Duration,
    next: Instant,
}
#[derive(Clone)]
struct Event {
    handler: ComPtr<IEventHandler>,
    fd: FileDescriptor,
}

pub struct RunLoop {
    owner: ThreadId,
    events: RefCell<Vec<Event>>,
    timers: RefCell<Vec<Timer>>,
}
impl RunLoop {
    pub fn new() -> Rc<Self> {
        Rc::new(Self {
            owner: std::thread::current().id(),
            events: RefCell::new(Vec::new()),
            timers: RefCell::new(Vec::new()),
        })
    }
    fn on_thread(&self) -> bool {
        self.owner == std::thread::current().id()
    }
    pub fn pump(&self) {
        if !self.on_thread() {
            return;
        }
        let now = Instant::now();
        let due = {
            let mut timers = self.timers.borrow_mut();
            timers
                .iter_mut()
                .filter_map(|timer| {
                    if now < timer.next {
                        return None;
                    }
                    timer.next = now + timer.interval;
                    Some(timer.handler.clone())
                })
                .collect::<Vec<_>>()
        };
        for handler in due {
            if self
                .timers
                .borrow()
                .iter()
                .any(|t| t.handler.as_ptr() == handler.as_ptr())
            {
                // SAFETY: Retained handler is dispatched on its registering UI thread; no RefCell borrow spans callbacks.
                unsafe { handler.onTimer() };
            }
        }
        #[cfg(target_os = "linux")]
        let events = self.events.borrow().clone();
        #[cfg(target_os = "linux")]
        for event in events {
            let mut fd = PollFd {
                fd: event.fd,
                events: 1,
                revents: 0,
            };
            // SAFETY: One writable pollfd is passed; timeout zero never blocks the UI loop.
            let ready = unsafe { poll(&raw mut fd, 1, 0) };
            if ready > 0
                && fd.revents & 1 != 0
                && self
                    .events
                    .borrow()
                    .iter()
                    .any(|e| e.fd == event.fd && e.handler.as_ptr() == event.handler.as_ptr())
            {
                // SAFETY: Retained handler remains registered on this UI thread.
                unsafe { event.handler.onFDIsSet(event.fd) };
            }
        }
    }
    pub fn clear(&self) {
        self.events.borrow_mut().clear();
        self.timers.borrow_mut().clear();
    }
}
impl IRunLoopTrait for RunLoop {
    unsafe fn registerEventHandler(
        &self,
        handler: *mut IEventHandler,
        fd: FileDescriptor,
    ) -> tresult {
        if !self.on_thread() || fd < 0 {
            return kInvalidArgument;
        }
        // SAFETY: Plugin supplies a live event handler; ownership is retained until unregister.
        let Some(handler) = (unsafe { ComRef::from_raw(handler) }) else {
            return kInvalidArgument;
        };
        let mut events = self.events.borrow_mut();
        if events
            .iter()
            .any(|e| e.fd == fd && e.handler.as_ptr() == handler.as_ptr())
        {
            return kResultFalse;
        }
        events.push(Event {
            handler: handler.to_com_ptr(),
            fd,
        });
        kResultOk
    }
    unsafe fn unregisterEventHandler(&self, handler: *mut IEventHandler) -> tresult {
        if !self.on_thread() {
            return kInvalidArgument;
        }
        let mut events = self.events.borrow_mut();
        let before = events.len();
        events.retain(|e| e.handler.as_ptr() != handler);
        if events.len() == before {
            kResultFalse
        } else {
            kResultOk
        }
    }
    unsafe fn registerTimer(
        &self,
        handler: *mut ITimerHandler,
        milliseconds: TimerInterval,
    ) -> tresult {
        if !self.on_thread() || milliseconds == 0 {
            return kInvalidArgument;
        }
        // SAFETY: Plugin supplies a live timer handler, retained until unregister.
        let Some(handler) = (unsafe { ComRef::from_raw(handler) }) else {
            return kInvalidArgument;
        };
        let interval = Duration::from_millis(milliseconds.min(86_400_000));
        let mut timers = self.timers.borrow_mut();
        if timers
            .iter()
            .any(|t| t.handler.as_ptr() == handler.as_ptr())
        {
            return kResultFalse;
        }
        timers.push(Timer {
            handler: handler.to_com_ptr(),
            interval,
            next: Instant::now() + interval,
        });
        kResultOk
    }
    unsafe fn unregisterTimer(&self, handler: *mut ITimerHandler) -> tresult {
        if !self.on_thread() {
            return kInvalidArgument;
        }
        let mut timers = self.timers.borrow_mut();
        let before = timers.len();
        timers.retain(|t| t.handler.as_ptr() != handler);
        if timers.len() == before {
            kResultFalse
        } else {
            kResultOk
        }
    }
}

#[cfg(target_os = "linux")]
#[repr(C)]
struct PollFd {
    fd: i32,
    events: i16,
    revents: i16,
}
#[cfg(target_os = "linux")]
unsafe extern "C" {
    fn poll(fds: *mut PollFd, count: usize, timeout: i32) -> i32;
}

macro_rules! delegate_run_loop {
    ($target:ty) => {
        impl vst3::Steinberg::Linux::IRunLoopTrait for $target {
            unsafe fn registerEventHandler(
                &self,
                handler: *mut vst3::Steinberg::Linux::IEventHandler,
                fd: i32,
            ) -> i32 {
                // SAFETY: Forward the unchanged VST3 ABI arguments to the shared UI loop.
                unsafe { self.run_loop.registerEventHandler(handler, fd) }
            }
            unsafe fn unregisterEventHandler(
                &self,
                handler: *mut vst3::Steinberg::Linux::IEventHandler,
            ) -> i32 {
                // SAFETY: Forward a plugin-owned handler identity to the UI loop.
                unsafe { self.run_loop.unregisterEventHandler(handler) }
            }
            unsafe fn registerTimer(
                &self,
                handler: *mut vst3::Steinberg::Linux::ITimerHandler,
                interval: u64,
            ) -> i32 {
                // SAFETY: Forward the unchanged plugin handler and timer interval.
                unsafe { self.run_loop.registerTimer(handler, interval) }
            }
            unsafe fn unregisterTimer(
                &self,
                handler: *mut vst3::Steinberg::Linux::ITimerHandler,
            ) -> i32 {
                // SAFETY: Forward the plugin-owned handler identity.
                unsafe { self.run_loop.unregisterTimer(handler) }
            }
        }
    };
}
pub(crate) use delegate_run_loop;
