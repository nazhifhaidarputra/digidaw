use crate::api::context::{DawContext, ProjectOperationGuard};
use crate::api::project::UiApplicationState;
use flutter_rust_bridge::frb;
use karbeat_core::api::{mitigation_api, project_api};
use karbeat_core::core::project::ApplicationState;

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
    let ui_state = restore_loaded_project(&operation, loaded).map_err(|error| error.to_string())?;

    log::info!("Successfully loaded the project {}", path_name);
    Ok(ui_state)
}

/// Replaces the live project with `loaded`, rehydrating plugins and the engine.
pub(crate) fn restore_loaded_project(
    operation: &ProjectOperationGuard<'_>,
    loaded: ApplicationState,
) -> anyhow::Result<UiApplicationState> {
    let pending = project_api::begin_loaded_project_restore(&operation.read_core(), loaded)?;
    let completed = project_api::execute_project_restore(pending)?;
    let mut core = operation.write_core();
    project_api::commit_project_restore(&mut core, completed);
    Ok(UiApplicationState::from(core.app_state.clone()))
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

/// Whether the current project has no unsaved changes. Read it when the answer is needed, such
/// as before closing the window or replacing the project; it is not meant for polling.
#[frb(sync)]
pub fn is_project_saved(ctx: &DawContext) -> bool {
    mitigation_api::is_project_saved(&ctx.read())
}
