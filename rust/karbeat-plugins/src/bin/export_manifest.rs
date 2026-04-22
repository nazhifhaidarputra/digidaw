use karbeat_plugin_api::manifest::Manifestable;
use karbeat_plugins::{
    effect::parametric_eq::{ KarbeatParametricEQEngine },
    generator::{ karbeatzer_v2::KarbeatzerEngine, my_retro::MyRetroEngine },
};

fn main() {
    println!("Starting Karbeat Manifest Extractor...");

    // Points to shared assets folder.
    // This runs from the root of the rust workspace.
    let export_dir = std::env
        ::var("PLUGIN_MANIFEST_DIR")
        .unwrap_or("../../assets/manifests/audio-plugins".into());

    // Call the export function on all plugins
    MyRetroEngine::export_manifest(&export_dir).unwrap();
    KarbeatzerEngine::export_manifest(&export_dir).unwrap();
    KarbeatParametricEQEngine::export_manifest(&export_dir).unwrap();

    println!("INFO: All manifests exported successfully to Flutter assets!");
}
