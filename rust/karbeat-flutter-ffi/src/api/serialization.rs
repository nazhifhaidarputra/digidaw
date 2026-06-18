use crate::api::project::UiApplicationState;
use karbeat_core::api::project_api;
use karbeat_core::context::DawContext;

/// Save the currrent project to path_name
pub fn save_project(ctx: &mut DawContext, path_name: &str) -> Result<(), String> {
    project_api::save_project(ctx, path_name).map_err(|e| e.to_string())?;

    log::info!("Successfully saved project to {}", path_name);
    Ok(())
}

/// Load the `.karbeat` or `.dgdaw` project.
pub fn load_project(
    ctx: &mut DawContext,
    path_name: &str,
) -> Result<crate::api::project::UiApplicationState, String> {
    let ui_state =
        project_api::load_project(ctx, path_name, |app| UiApplicationState::from(app.clone()))
            .map_err(|e| e.to_string())?;

    log::info!("Successfully loaded the project {}", path_name);
    Ok(ui_state)
}

pub fn new_blank_project(ctx: &mut DawContext) -> crate::api::project::UiApplicationState {
    let app = project_api::new_blank_project(ctx);
    UiApplicationState::from(app)
}
