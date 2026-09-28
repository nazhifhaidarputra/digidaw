use std::{path::PathBuf, sync::Once};

use signal_hook::{
    consts::{SIGHUP, SIGINT, SIGTERM},
    iterator::Signals,
    low_level::{emulate_default_handler, exit},
};

use super::session_marker;

static WATCHING: Once = Once::new();

/// Records Ctrl+C (`SIGINT`), `SIGTERM`, and `SIGHUP` as a forced shutdown in the session marker
/// at `marker`, then terminates the process as the signal's default action would.
///
/// Installed once per process; later calls, such as after a hot restart, are ignored. The marker
/// is written on a dedicated thread rather than inside the signal handler.
pub fn watch(marker: PathBuf) {
    WATCHING.call_once(|| {
        let mut signals = match Signals::new([SIGINT, SIGTERM, SIGHUP]) {
            Ok(signals) => signals,
            Err(error) => {
                log::warn!("Shutdown signals cannot be watched: {error}");
                return;
            }
        };
        let spawned = std::thread::Builder::new()
            .name("karbeat-shutdown-signals".into())
            .spawn(move || {
                if let Some(signal) = signals.forever().next() {
                    log::info!("Received signal {signal}; forcing shutdown");
                    if let Err(error) = session_marker::mark_forced_shutdown(&marker) {
                        log::warn!("Could not record the forced shutdown: {error}");
                    }
                    if let Err(error) = emulate_default_handler(signal) {
                        log::error!("Could not terminate on signal {signal}: {error}");
                        // Skips process teardown, like the signal's default action would.
                        exit(128_i32.saturating_add(signal));
                    }
                }
            });
        if let Err(error) = spawned {
            log::warn!("Shutdown signal thread could not start: {error}");
        }
    });
}
