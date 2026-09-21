use std::{fs::File, path::PathBuf, process::ExitCode};

use karbeat_host_api::scanner::{ProbeResponse, SCANNER_PROTOCOL_VERSION};
use karbeat_vst3::module::Vst3Module;

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let mut arguments = std::env::args_os().skip(1);
    if arguments.next().as_deref() != Some(std::ffi::OsStr::new("--module")) {
        return Err("expected --module".into());
    }
    let module = PathBuf::from(arguments.next().ok_or("missing module")?);
    if arguments.next().as_deref() != Some(std::ffi::OsStr::new("--result")) {
        return Err("expected --result".into());
    }
    let result_path = PathBuf::from(arguments.next().ok_or("missing result path")?);
    if arguments.next().is_some() {
        return Err("unexpected arguments".into());
    }
    let response = match Vst3Module::load(&module).and_then(|module| module.descriptors()) {
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
