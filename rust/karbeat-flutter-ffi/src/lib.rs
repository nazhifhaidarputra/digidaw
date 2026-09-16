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

pub fn init_logger() {
    // if release, use info, else use debug
    INIT_LOGGER.call_once(|| {
        use env_logger::Env;

        let default_level = if cfg!(debug_assertions) {
            "debug"
        } else {
            "info"
        };

        drop(
            env_logger::Builder::from_env(Env::default().default_filter_or(default_level))
                .format_timestamp_millis()
                .target(env_logger::Target::Stdout)
                .try_init(),
        );
    });
}
