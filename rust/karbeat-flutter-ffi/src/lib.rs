pub(crate) use karbeat_core::
    context::INIT_LOGGER
;

pub mod api;
mod frb_generated;


pub fn init_logger() {
    // if release, use info, else use debug
    INIT_LOGGER.call_once(|| {
        use env_logger::Env;

        let default_level = if cfg!(debug_assertions) {
            "debug"
        } else {
            "info"
        };

        let _ = env_logger::Builder::from_env(Env::default().default_filter_or(default_level))
            .format_timestamp_millis()
            .target(env_logger::Target::Stdout)
            .try_init();
    });
}
