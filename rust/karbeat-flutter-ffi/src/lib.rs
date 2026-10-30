use std::io::IsTerminal as _;

use tracing_subscriber::EnvFilter;
use tracing_subscriber::filter::LevelFilter;
use tracing_subscriber::fmt::format::Writer;
use tracing_subscriber::fmt::time::FormatTime;
use tracing_subscriber::layer::SubscriberExt as _;
use tracing_subscriber::util::SubscriberInitExt as _;

pub(crate) use karbeat_audio::context::INIT_LOGGER;

use crate::log_bridge::LogBridgeLayer;

#[allow(
    clippy::as_conversions,
    reason = "the FFI boundary preserves the established Dart wire schema before core-domain validation"
)]
pub mod api;
#[allow(
    clippy::allow_attributes_without_reason,
    clippy::as_conversions,
    clippy::expect_used,
    clippy::let_underscore_must_use,
    clippy::macro_metavars_in_unsafe,
    clippy::missing_safety_doc,
    clippy::multiple_unsafe_ops_per_block,
    clippy::panic,
    clippy::todo,
    clippy::undocumented_unsafe_blocks,
    clippy::unimplemented,
    clippy::unreachable,
    clippy::unwrap_used,
    reason = "Flutter Rust Bridge owns this generated module; lint fixes must be made in the generator"
)]
mod frb_generated;
mod log_bridge;
mod sync;

/// Formats timestamps as UTC RFC 3339 with millisecond precision.
struct MillisTimer;

impl FormatTime for MillisTimer {
    fn format_time(&self, writer: &mut Writer<'_>) -> std::fmt::Result {
        write!(writer, "{:.3}", jiff::Timestamp::now())
    }
}

/// Installs the process subscriber: stdout through a `fmt` layer, plus a
/// non-blocking queue forwarding the same events to the Flutter log viewer.
/// Records from dependencies using the `log` crate are captured as events too.
pub fn init_logger() {
    // if release, use info, else use debug
    INIT_LOGGER.call_once(|| {
        let default_level = if cfg!(debug_assertions) {
            LevelFilter::DEBUG
        } else {
            LevelFilter::INFO
        };

        let filter = EnvFilter::builder()
            .with_default_directive(default_level.into())
            .from_env_lossy();
        let stdout = tracing_subscriber::fmt::layer()
            .with_timer(MillisTimer)
            .with_ansi(std::io::stdout().is_terminal())
            .with_writer(std::io::stdout);
        let bridge = log_bridge::install();
        let bridge_layer = bridge.as_ref().ok().copied().map(LogBridgeLayer::new);
        let installed = tracing_subscriber::registry()
            .with(filter)
            .with(stdout)
            .with(bridge_layer)
            .try_init();
        if let Err(error) = installed {
            tracing::warn!("Rust logger was already installed: {error}");
        }
        if let Err(error) = bridge {
            tracing::warn!("Rust log forwarding to Flutter is unavailable: {error}");
        }
    });
}

/// Initializes the Rust-owned Windows main STA state before Flutter window creation.
#[cfg(target_os = "windows")]
#[unsafe(no_mangle)]
pub extern "C" fn digidaw_initialize_windows_main_thread() -> i32 {
    match karbeat_host_api::initialize_windows_main_thread() {
        Ok(()) => 0,
        Err(error) => {
            tracing::error!("failed to initialize the Windows main STA thread: {error}");
            1
        }
    }
}

/// Pumps all process Win32 messages on the Rust-owned main STA thread until shutdown.
#[cfg(target_os = "windows")]
#[unsafe(no_mangle)]
pub extern "C" fn digidaw_run_windows_main_loop() -> i32 {
    match karbeat_host_api::run_windows_main_loop() {
        Ok(exit_code) => exit_code,
        Err(error) => {
            tracing::error!("Windows main loop failed: {error}");
            1
        }
    }
}

/// Releases Rust-owned Windows main-thread state if Flutter bootstrap fails before loop entry.
#[cfg(target_os = "windows")]
#[unsafe(no_mangle)]
pub extern "C" fn digidaw_shutdown_windows_main_thread() {
    if let Err(error) = karbeat_host_api::shutdown_windows_main_thread() {
        tracing::error!("failed to shut down Windows main-thread state: {error}");
    }
}
