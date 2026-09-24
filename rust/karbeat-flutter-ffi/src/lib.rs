pub(crate) use karbeat_core::context::INIT_LOGGER;

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

/// Installs the process logger: stdout through `env_logger`, plus a
/// non-blocking queue forwarding the same records to the Flutter log viewer.
pub fn init_logger() {
    // if release, use info, else use debug
    INIT_LOGGER.call_once(|| {
        use env_logger::Env;

        let default_level = if cfg!(debug_assertions) {
            "debug"
        } else {
            "info"
        };

        let stdout = env_logger::Builder::from_env(Env::default().default_filter_or(default_level))
            .format_timestamp_millis()
            .target(env_logger::Target::Stdout)
            .build();
        let bridge = log_bridge::install();
        let logger = log_bridge::KarbeatLogger::new(stdout, bridge.as_ref().ok().copied());
        let max_level = logger.filter();
        if log::set_boxed_logger(Box::new(logger)).is_ok() {
            log::set_max_level(max_level);
        }
        if let Err(error) = bridge {
            log::warn!("Rust log forwarding to Flutter is unavailable: {error}");
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
            log::error!("failed to initialize the Windows main STA thread: {error}");
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
            log::error!("Windows main loop failed: {error}");
            1
        }
    }
}

/// Releases Rust-owned Windows main-thread state if Flutter bootstrap fails before loop entry.
#[cfg(target_os = "windows")]
#[unsafe(no_mangle)]
pub extern "C" fn digidaw_shutdown_windows_main_thread() {
    if let Err(error) = karbeat_host_api::shutdown_windows_main_thread() {
        log::error!("failed to shut down Windows main-thread state: {error}");
    }
}
