use karbeat_plugin_api::manifest::Manifestable;
use karbeat_plugins::{
    effect::{pitch_shifter::Pitcher, sidechain::DigidawSidechainCompressor},
    plugins::*,
};

/// A declarative macro to export manifests for a variadic list of plugins.
macro_rules! export_plugins {
    // Matches the directory expression, followed by a comma-separated list of types.
    ($dir:expr, $( $plugin:ty ),* $(,)?) => {
        $(
            <$plugin>::export_manifest(&$dir).unwrap();
        )*
    };
}

#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "the manifest export command must fail immediately when its inputs or writes are invalid"
)]
fn main() {
    println!("Starting Karbeat Manifest Extractor...");

    // HOW TO run script from root workspace:
    // PLUGIN_MANIFEST_DIR="../assets/manifests/audio-plugins/" cargo run --bin export_manifest
    let export_dir = std::env::var("PLUGIN_MANIFEST_DIR").expect("No PLUGIN_MANIFEST_DIR defined");

    // Call the export function on all plugins
    export_plugins!(
        export_dir,
        MyRetro,
        KarbeatzerV2,
        DigiParametricEQ,
        Pitcher,
        DigidawSidechainCompressor
    );

    println!("INFO: All manifests exported successfully to Flutter assets!");
}
