use crate::api::context::DawContext;
use crate::api::project::UiApplicationState;
use karbeat_core::api::project_api;

/// Save the currrent project to path_name
pub fn save_project(ctx: &DawContext, path_name: &str) -> Result<(), String> {
    let operation = ctx.begin_project_operation();
    let pending = project_api::begin_save_project(&operation.read_core(), path_name);
    let completed = project_api::execute_save_project(pending).map_err(|e| e.to_string())?;
    project_api::commit_save_project(&mut operation.write_core(), completed);

    log::info!("Successfully saved project to {}", path_name);
    Ok(())
}

/// Load the `.karbeat` or `.dgdaw` project.
pub fn load_project(
    ctx: &DawContext,
    path_name: &str,
) -> Result<crate::api::project::UiApplicationState, String> {
    let operation = ctx.begin_project_operation();
    let sample_rate = operation
        .read_core()
        .audio_runtime_settings
        .read()
        .requested_dsp
        .sample_rate;
    let loaded = project_api::load_project_file(path_name, sample_rate)
        .map_err(|error| error.to_string())?;
    let pending = project_api::begin_loaded_project_restore(&operation.read_core(), loaded)
        .map_err(|error| error.to_string())?;
    let completed =
        project_api::execute_project_restore(pending).map_err(|error| error.to_string())?;
    let ui_state = {
        let mut core = operation.write_core();
        project_api::commit_project_restore(&mut core, completed);
        UiApplicationState::from(core.app_state.clone())
    };

    log::info!("Successfully loaded the project {}", path_name);
    Ok(ui_state)
}

pub fn new_blank_project(
    ctx: &DawContext,
) -> anyhow::Result<crate::api::project::UiApplicationState> {
    let operation = ctx.begin_project_operation();
    let mut staged = operation.read_core().app_state.clone();
    staged.new_blank_project();
    let pending = project_api::begin_project_restore(&operation.read_core(), staged)?;
    let completed = project_api::execute_project_restore(pending)?;
    let app = {
        let mut core = operation.write_core();
        project_api::commit_project_restore(&mut core, completed);
        core.app_state.clone()
    };
    Ok(UiApplicationState::from(app))
}
