use std::{fs::File, path::PathBuf, process::ExitCode};

use karbeat_host_api::{
    HostError, PluginDescriptor, PluginFormat,
    scanner::{ProbeResponse, SCANNER_PROTOCOL_VERSION, format_argument},
};
use karbeat_vst3::module::Vst3Module;

/// Loads one module of `format` in this disposable process and lists its plugin classes.
fn probe(
    format: PluginFormat,
    module: &std::path::Path,
) -> Result<Vec<PluginDescriptor>, HostError> {
    match format {
        PluginFormat::Vst3 => Vst3Module::load(module).and_then(|module| module.descriptors()),
        PluginFormat::Clap => karbeat_clap::probe_module(module),
        PluginFormat::Lv2 => Err(HostError::Unsupported(
            "LV2 bundles are read without a helper process",
        )),
    }
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    #[cfg(target_os = "windows")]
    let _com = karbeat_host_api::WindowsStaGuard::initialize()?;
    let mut arguments = std::env::args_os().skip(1);
    if arguments.next().as_deref() != Some(std::ffi::OsStr::new("--module")) {
        return Err("expected --module".into());
    }
    let module = PathBuf::from(arguments.next().ok_or("missing module")?);
    if arguments.next().as_deref() != Some(std::ffi::OsStr::new("--result")) {
        return Err("expected --result".into());
    }
    let result_path = PathBuf::from(arguments.next().ok_or("missing result path")?);
    // Older hosts omit the format, which then means VST3.
    let format = match arguments.next() {
        None => PluginFormat::Vst3,
        Some(flag) if flag == "--format" => {
            let name = arguments.next().ok_or("missing format")?;
            [PluginFormat::Vst3, PluginFormat::Clap]
                .into_iter()
                .find(|format| name == format_argument(*format))
                .ok_or("unsupported format")?
        }
        Some(_) => return Err("expected --format".into()),
    };
    if arguments.next().is_some() {
        return Err("unexpected arguments".into());
    }
    let response = match probe(format, &module) {
        Ok(plugins) => ProbeResponse {
            version: SCANNER_PROTOCOL_VERSION,
            plugins,
            error: None,
        },
        Err(error) => ProbeResponse {
            version: SCANNER_PROTOCOL_VERSION,
            plugins: Vec::new(),
            error: Some(error.to_string()),
        },
    };
    let file = File::create(result_path)?;
    serde_json::to_writer(&file, &response)?;
    file.sync_all()?;
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            log::error!("plugin scanner failed: {error}");
            ExitCode::FAILURE
        }
    }
}
