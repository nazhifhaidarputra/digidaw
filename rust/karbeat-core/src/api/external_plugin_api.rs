use anyhow::Context;
use karbeat_host::{
    ConvertParameterRequest, ExternalPluginInstanceHandle, HostCapabilities, HostClient,
    OpenEditorRequest, ParameterTextRequest, ParseParameterRequest, PluginKind, PrepareRequest,
    ProcessingConfig, ReconfigureRequest, SetParameterRequest,
};

use crate::{
    audio::{
        event::PluginTarget,
        hosted_plugin::{
            HostedInstallResult, HostedPluginInstall, HostedPluginReconfiguration,
            HostedPluginReplacement, HostedTrackGraph,
        },
    },
    commands::{AudioCommand, EffectTarget},
    context::{ControlHandles, DawContext},
    core::project::{
        ApplicationState, AudioTrack, GeneratorInstanceType, TrackType,
        mixer::{EffectInstance, MixerChannel},
        plugin::{ExternalPluginInstance, PluginInstance},
    },
};

pub enum HostedTargetLookup {
    Resolved {
        client: HostClient,
        instance: ExternalPluginInstanceHandle,
    },
    Query {
        handles: ControlHandles,
        target: PluginTarget,
        format: karbeat_host::PluginFormat,
    },
}

pub struct HostedTargetAccess {
    pub client: HostClient,
    pub instance: ExternalPluginInstanceHandle,
}

pub fn prepare_hosted_target(
    ctx: &DawContext,
    target: PluginTarget,
) -> anyhow::Result<HostedTargetLookup> {
    anyhow::ensure!(
        plugin_instance(ctx, target).is_some_and(|plugin| plugin.external.is_some()),
        "Target is not an external plugin"
    );
    anyhow::ensure!(
        !ctx.external_plugin_failures.contains_key(&target),
        "External plugin is unavailable; retry loading it first"
    );
    match ctx.hosted_targets.get(&target) {
        Some(crate::context::HostedTargetState::Active(instance)) => {
            Ok(HostedTargetLookup::Resolved {
                client: ctx.external_plugins.clone(),
                instance: *instance,
            })
        }
        Some(crate::context::HostedTargetState::Transitioning) => {
            anyhow::bail!("External plugin lifecycle operation is in progress")
        }
        Some(crate::context::HostedTargetState::Failed(reason)) => {
            anyhow::bail!("External plugin is unavailable: {reason}")
        }
        None => Ok(HostedTargetLookup::Query {
            handles: ctx.control_handles(),
            target,
            format: plugin_instance(ctx, target)
                .and_then(|plugin| plugin.external.as_ref())
                .map(|external| external.descriptor.identity.format)
                .context("External plugin format is unavailable")?,
        }),
    }
}

pub fn resolve_hosted_target(lookup: HostedTargetLookup) -> anyhow::Result<HostedTargetAccess> {
    match lookup {
        HostedTargetLookup::Resolved { client, instance } => {
            Ok(HostedTargetAccess { client, instance })
        }
        HostedTargetLookup::Query {
            handles,
            target,
            format,
        } => Ok(HostedTargetAccess {
            instance: ExternalPluginInstanceHandle {
                format,
                id: super::project_api::hosted_instance_with_handles(&handles, target)?,
            },
            client: handles.external_plugins,
        }),
    }
}

pub fn capabilities_for(access: HostedTargetAccess) -> anyhow::Result<HostCapabilities> {
    Ok(futures_lite::future::block_on(
        access.client.capabilities(access.instance),
    )?)
}

pub fn open_editor_for(access: HostedTargetAccess, context: String) -> anyhow::Result<()> {
    Ok(futures_lite::future::block_on(access.client.open_editor(
        OpenEditorRequest {
            instance: access.instance,
            context,
        },
    ))?)
}

pub fn close_editor_for(access: HostedTargetAccess) -> anyhow::Result<()> {
    Ok(futures_lite::future::block_on(
        access.client.close_editor(access.instance),
    )?)
}

pub fn set_parameter_for(
    access: HostedTargetAccess,
    parameter: u32,
    value: f64,
) -> anyhow::Result<()> {
    Ok(futures_lite::future::block_on(
        access.client.set_parameter(SetParameterRequest {
            instance: access.instance,
            parameter,
            value,
        }),
    )?)
}

pub fn parameter_text_for(
    access: HostedTargetAccess,
    parameter: u32,
    value: f64,
) -> anyhow::Result<String> {
    Ok(futures_lite::future::block_on(
        access.client.parameter_text(ParameterTextRequest {
            instance: access.instance,
            parameter,
            value,
        }),
    )?)
}

pub fn parse_parameter_for(
    access: HostedTargetAccess,
    parameter: u32,
    text: String,
) -> anyhow::Result<f64> {
    Ok(futures_lite::future::block_on(
        access.client.parse_parameter(ParseParameterRequest {
            instance: access.instance,
            parameter,
            text,
        }),
    )?)
}

pub fn convert_parameter_for(
    access: HostedTargetAccess,
    parameter: u32,
    value: f64,
    to_normalized: bool,
) -> anyhow::Result<f64> {
    Ok(futures_lite::future::block_on(
        access.client.convert_parameter(ConvertParameterRequest {
            instance: access.instance,
            parameter,
            value,
            to_normalized,
        }),
    )?)
}

fn channel_mut<'a>(
    app: &'a mut ApplicationState,
    target: &EffectTarget,
) -> anyhow::Result<&'a mut MixerChannel> {
    match target {
        EffectTarget::Track(id) => Ok(&mut app
            .mixer
            .channels
            .get_mut(*id)
            .context("Track mixer channel is unavailable")?
            .channel),
        EffectTarget::Bus(id) => Ok(&mut app
            .mixer
            .buses
            .get_mut(*id)
            .context("Mixer bus is unavailable")?
            .channel),
        EffectTarget::Master => Ok(&mut app.mixer.master_bus),
    }
}

pub enum InstalledPlugin {
    Instrument(AudioTrack),
    Effect(EffectInstance),
}

enum PendingInstallTarget {
    Instrument,
    Effect(EffectTarget),
}

pub struct PendingPluginInstall {
    staged: ApplicationState,
    registry_id: u32,
    descriptor: karbeat_host::PluginDescriptor,
    config: ProcessingConfig,
    target: PendingInstallTarget,
    handles: ControlHandles,
}

pub struct CompletedPluginInstall {
    staged: ApplicationState,
    target: PluginTarget,
    telemetry: Option<triple_buffer::Output<crate::audio::engine::PluginTelemetrySnapshot>>,
    installed: InstalledPlugin,
    instance: ExternalPluginInstanceHandle,
}

fn begin_install(
    ctx: &DawContext,
    registry_id: u32,
    kind: PluginKind,
    target: PendingInstallTarget,
) -> anyhow::Result<PendingPluginInstall> {
    anyhow::ensure!(
        ctx.command_sender.lock().as_ref().is_some(),
        "Audio engine is unavailable"
    );
    anyhow::ensure!(
        ctx.telemetry_registry.is_some(),
        "Audio telemetry is not initialized"
    );
    let entry = ctx
        .plugin_catalog
        .external(registry_id)
        .context("External plugin is not in the catalog")?;
    anyhow::ensure!(
        entry.available,
        "External plugin is unavailable: {}",
        entry.descriptor.name
    );
    anyhow::ensure!(
        entry.descriptor.kind == kind,
        "Plugin has an incompatible instrument/effect type"
    );
    let config = ProcessingConfig {
        sample_rate: f64::from(ctx.audio_runtime_settings.read().requested_dsp.sample_rate),
        max_block_size: 65_536,
        main_input_channels: if kind == PluginKind::Instrument { 0 } else { 2 },
        main_output_channels: 2,
        sidechain_channels: 0,
        offline: false,
    };
    Ok(PendingPluginInstall {
        staged: ctx.app_state.clone(),
        registry_id,
        descriptor: entry.descriptor.clone(),
        config,
        target,
        handles: ctx.control_handles(),
    })
}

pub fn begin_add_instrument(
    ctx: &DawContext,
    registry_id: u32,
) -> anyhow::Result<PendingPluginInstall> {
    begin_install(
        ctx,
        registry_id,
        PluginKind::Instrument,
        PendingInstallTarget::Instrument,
    )
}

pub fn begin_add_effect(
    ctx: &DawContext,
    target: EffectTarget,
    registry_id: u32,
) -> anyhow::Result<PendingPluginInstall> {
    begin_install(
        ctx,
        registry_id,
        PluginKind::Effect,
        PendingInstallTarget::Effect(target),
    )
}

fn wait_for_install(
    mut receipt: crate::audio::hosted_plugin::HostedInstallReceipt,
) -> anyhow::Result<Option<triple_buffer::Output<crate::audio::engine::PluginTelemetrySnapshot>>> {
    match futures_lite::future::block_on(receipt.wait())? {
        HostedInstallResult::Installed => Ok(receipt.take_telemetry()),
        result => anyhow::bail!("Audio engine rejected plugin installation: {result:?}"),
    }
}

pub fn execute_install(
    mut pending: PendingPluginInstall,
) -> anyhow::Result<CompletedPluginInstall> {
    let prepared =
        futures_lite::future::block_on(pending.handles.external_plugins.prepare(PrepareRequest {
            descriptor: pending.descriptor.clone(),
            config: pending.config.clone(),
            state: None,
        }))?;
    let instance = prepared.instance;
    let plugin = PluginInstance {
        registry_id: pending.registry_id,
        name: pending.descriptor.name.clone(),
        bypass: false,
        parameter_specs: prepared.parameters.clone(),
        plugin_state: Vec::new(),
        external: Some(ExternalPluginInstance {
            descriptor: pending.descriptor,
            state: Some(prepared.state.clone()),
        }),
    };

    let (installed, install, receipt) = match pending.target {
        PendingInstallTarget::Instrument => {
            let track_id = pending.staged.add_new_audio_track().id;
            let name = plugin.name.clone();
            let generator_id = pending
                .staged
                .add_generator(GeneratorInstanceType::Plugin(plugin));
            let generator = pending
                .staged
                .generator_pool
                .get(generator_id)
                .cloned()
                .context("Prepared generator is unavailable")?;
            let track = pending
                .staged
                .tracks
                .get_mut(track_id)
                .context("Prepared track is unavailable")?;
            track.track_type = TrackType::Midi;
            track.name = name;
            track.generator = Some(generator);
            let track = track.clone();
            let (install, receipt) = HostedPluginInstall::new(
                PluginTarget::Generator(generator_id),
                Some(track_id),
                pending.registry_id,
                pending.config,
                prepared.processor,
            );
            let graph = HostedTrackGraph::from(&pending.staged);
            (
                InstalledPlugin::Instrument(track),
                install.with_track_graph(graph),
                receipt,
            )
        }
        PendingInstallTarget::Effect(effect_target) => {
            let channel = channel_mut(&mut pending.staged, &effect_target)?;
            let effect_id = channel.effects.insert(plugin);
            let effect = channel
                .effects
                .get(effect_id)
                .cloned()
                .context("Prepared effect is unavailable")?;
            let target = match effect_target {
                EffectTarget::Track(id) => PluginTarget::TrackEffect(id, effect_id),
                EffectTarget::Bus(id) => PluginTarget::BusEffect(id, effect_id),
                EffectTarget::Master => PluginTarget::MasterEffect(effect_id),
            };
            let (install, receipt) = HostedPluginInstall::new(
                target,
                None,
                pending.registry_id,
                pending.config,
                prepared.processor,
            );
            (InstalledPlugin::Effect(effect), install, receipt)
        }
    };

    futures_lite::future::block_on(pending.handles.external_plugins.resume(instance))?;
    let target = install.target;
    let (command, mut control_retirement) = karbeat_host::ControlTransfer::new(install);
    {
        let mut sender = pending.handles.command_sender.lock();
        let sender = sender.as_mut().context("Audio engine is unavailable")?;
        sender
            .push(AudioCommand::InstallHostedPlugin(command))
            .map_err(|_| anyhow::anyhow!("Audio command queue is full"))?;
    }
    let telemetry = wait_for_install(receipt)?;
    if !control_retirement.collect() {
        log::warn!("Hosted install control transfer was not returned after acknowledgement");
    }
    Ok(CompletedPluginInstall {
        staged: pending.staged,
        target,
        telemetry,
        installed,
        instance,
    })
}

pub fn commit_install(ctx: &mut DawContext, completed: CompletedPluginInstall) -> InstalledPlugin {
    if let Some(output) = completed.telemetry
        && let Some(registry) = &mut ctx.telemetry_registry
    {
        registry.insert_plugin_consumer(completed.target, output);
    }
    ctx.app_state = completed.staged;
    ctx.hosted_targets.insert(
        completed.target,
        crate::context::HostedTargetState::Active(completed.instance),
    );
    completed.installed
}

/// Prepares an external instrument, creates its MIDI track, and installs it on the audio thread.
///
/// Project state is staged and becomes visible only after the engine accepts the installation and
/// the native instance resumes. Failure leaves the live project unchanged.
pub fn add_instrument(ctx: &mut DawContext, registry_id: u32) -> anyhow::Result<AudioTrack> {
    let pending = begin_add_instrument(ctx, registry_id)?;
    let completed = execute_install(pending)?;
    match commit_install(ctx, completed) {
        InstalledPlugin::Instrument(track) => Ok(track),
        InstalledPlugin::Effect(_) => anyhow::bail!("instrument transaction returned an effect"),
    }
}

/// Prepares and appends an external effect to the selected mixer channel.
///
/// The staged project mutation is committed only after the audio thread accepts the corresponding
/// hosted processor and native activation succeeds.
pub fn add_effect(
    ctx: &mut DawContext,
    target: EffectTarget,
    registry_id: u32,
) -> anyhow::Result<EffectInstance> {
    let pending = begin_add_effect(ctx, target, registry_id)?;
    let completed = execute_install(pending)?;
    match commit_install(ctx, completed) {
        InstalledPlugin::Effect(effect) => Ok(effect),
        InstalledPlugin::Instrument(_) => {
            anyhow::bail!("effect transaction returned an instrument")
        }
    }
}

pub enum RemovedProjectItem {
    Effect,
    Track(crate::core::project::track::RemovedTrackType),
    Bus,
}

pub struct PendingPluginRemoval {
    staged: ApplicationState,
    targets: Vec<(PluginTarget, bool)>,
    graph: Option<HostedTrackGraph>,
    bus: Option<crate::shared::BusId>,
    handles: ControlHandles,
    removed: RemovedProjectItem,
}

pub struct CompletedPluginRemoval {
    staged: ApplicationState,
    targets: Vec<PluginTarget>,
    removed: RemovedProjectItem,
}

fn begin_removal(
    ctx: &DawContext,
    staged: ApplicationState,
    targets: Vec<PluginTarget>,
    changes_graph: bool,
    bus: Option<crate::shared::BusId>,
    removed: RemovedProjectItem,
) -> PendingPluginRemoval {
    let targets = targets
        .into_iter()
        .map(|target| {
            let active = descriptor(ctx, target).is_some()
                && !ctx.external_plugin_failures.contains_key(&target);
            (target, active)
        })
        .collect();
    let graph = changes_graph.then(|| HostedTrackGraph::from(&staged));
    PendingPluginRemoval {
        staged,
        targets,
        graph,
        bus,
        handles: ctx.control_handles(),
        removed,
    }
}

pub fn begin_remove_effect(
    ctx: &DawContext,
    target: EffectTarget,
    effect: crate::shared::EffectId,
) -> anyhow::Result<PendingPluginRemoval> {
    let mut staged = ctx.app_state.clone();
    channel_mut(&mut staged, &target)?
        .effects
        .remove(effect)
        .context("Effect is unavailable")?;
    let target = match target {
        EffectTarget::Track(track) => PluginTarget::TrackEffect(track, effect),
        EffectTarget::Bus(bus) => PluginTarget::BusEffect(bus, effect),
        EffectTarget::Master => PluginTarget::MasterEffect(effect),
    };
    Ok(begin_removal(
        ctx,
        staged,
        vec![target],
        false,
        None,
        RemovedProjectItem::Effect,
    ))
}

pub fn begin_delete_track(
    ctx: &DawContext,
    track: crate::shared::TrackId,
) -> anyhow::Result<PendingPluginRemoval> {
    let targets = track_targets(ctx, track);
    let mut staged = ctx.app_state.clone();
    let removed = staged.remove_track(track)?;
    Ok(begin_removal(
        ctx,
        staged,
        targets,
        true,
        None,
        RemovedProjectItem::Track(removed),
    ))
}

pub fn begin_delete_bus(
    ctx: &DawContext,
    bus: crate::shared::BusId,
) -> anyhow::Result<PendingPluginRemoval> {
    let targets = bus_targets(ctx, bus);
    let mut staged = ctx.app_state.clone();
    staged.mixer.remove_bus(bus)?;
    Ok(begin_removal(
        ctx,
        staged,
        targets,
        true,
        Some(bus),
        RemovedProjectItem::Bus,
    ))
}

pub fn execute_removal(pending: PendingPluginRemoval) -> anyhow::Result<CompletedPluginRemoval> {
    use crate::audio::hosted_plugin::{HostedPluginRemoval, HostedRemovalResult};

    let mut expected = Vec::with_capacity(pending.targets.len());
    for (target, active) in &pending.targets {
        let instance = if *active {
            Some(super::project_api::hosted_instance_with_handles(
                &pending.handles,
                *target,
            )?)
        } else {
            None
        };
        expected.push((*target, instance));
    }
    let targets = pending.targets.iter().map(|(target, _)| *target).collect();
    let (removal, mut receipt) = HostedPluginRemoval::new(expected, pending.graph);
    let (transfer, mut control_retirement) =
        karbeat_host::ControlTransfer::new(removal.with_bus(pending.bus));
    {
        let mut sender = pending.handles.command_sender.lock();
        sender
            .as_mut()
            .context("Audio engine is unavailable")?
            .push(AudioCommand::RemoveHostedPlugins(transfer))
            .map_err(|_| anyhow::anyhow!("Audio command queue is full"))?;
    }
    match futures_lite::future::block_on(receipt.wait())? {
        HostedRemovalResult::Removed => {}
        result => anyhow::bail!("Audio engine rejected plugin removal: {result:?}"),
    }
    if !control_retirement.collect() {
        log::warn!("Hosted removal control transfer was not returned after acknowledgement");
    }
    Ok(CompletedPluginRemoval {
        staged: pending.staged,
        targets,
        removed: pending.removed,
    })
}

pub fn commit_removal(
    ctx: &mut DawContext,
    completed: CompletedPluginRemoval,
) -> RemovedProjectItem {
    if let Some(registry) = &mut ctx.telemetry_registry {
        for target in &completed.targets {
            registry.remove_plugin_consumer(target);
        }
    }
    for target in completed.targets {
        ctx.external_plugin_failures.remove(&target);
        ctx.hosted_targets.remove(&target);
    }
    ctx.app_state = completed.staged;
    completed.removed
}

pub(crate) fn plugin_instance(ctx: &DawContext, target: PluginTarget) -> Option<&PluginInstance> {
    match target {
        PluginTarget::Generator(id) => match &ctx.app_state.generator_pool.get(id)?.instance_type {
            GeneratorInstanceType::Plugin(plugin) => Some(plugin),
            _ => None,
        },
        PluginTarget::TrackEffect(track, effect) => ctx
            .app_state
            .mixer
            .channels
            .get(track)?
            .channel
            .effects
            .get(effect)
            .map(|entry| &entry.instance),
        PluginTarget::BusEffect(bus, effect) => ctx
            .app_state
            .mixer
            .buses
            .get(bus)?
            .channel
            .effects
            .get(effect)
            .map(|entry| &entry.instance),
        PluginTarget::MasterEffect(effect) => ctx
            .app_state
            .mixer
            .master_bus
            .effects
            .get(effect)
            .map(|entry| &entry.instance),
    }
}

fn plugin_instance_mut(ctx: &mut DawContext, target: PluginTarget) -> Option<&mut PluginInstance> {
    match target {
        PluginTarget::Generator(id) => {
            match &mut ctx.app_state.generator_pool.get_mut(id)?.instance_type {
                GeneratorInstanceType::Plugin(plugin) => Some(plugin),
                _ => None,
            }
        }
        PluginTarget::TrackEffect(track, effect) => ctx
            .app_state
            .mixer
            .channels
            .get_mut(track)?
            .channel
            .effects
            .get_mut(effect)
            .map(|entry| &mut entry.instance),
        PluginTarget::BusEffect(bus, effect) => ctx
            .app_state
            .mixer
            .buses
            .get_mut(bus)?
            .channel
            .effects
            .get_mut(effect)
            .map(|entry| &mut entry.instance),
        PluginTarget::MasterEffect(effect) => ctx
            .app_state
            .mixer
            .master_bus
            .effects
            .get_mut(effect)
            .map(|entry| &mut entry.instance),
    }
}

/// Returns a clone of the external descriptor for `target`, or `None` for missing/built-in plugins.
pub fn descriptor(
    ctx: &DawContext,
    target: PluginTarget,
) -> Option<karbeat_host::PluginDescriptor> {
    Some(
        plugin_instance(ctx, target)?
            .external
            .as_ref()?
            .descriptor
            .clone(),
    )
}

/// Queries the live native instance's supported host capabilities.
pub fn capabilities(
    ctx: &mut DawContext,
    target: PluginTarget,
) -> anyhow::Result<HostCapabilities> {
    capabilities_for(resolve_hosted_target(prepare_hosted_target(ctx, target)?)?)
}

pub fn editor_context(ctx: &DawContext, target: PluginTarget) -> String {
    match target {
        PluginTarget::Generator(generator) => ctx
            .app_state
            .tracks
            .values()
            .find(|track| {
                track
                    .generator
                    .as_ref()
                    .is_some_and(|entry| entry.id == generator)
            })
            .map(|track| track.name.clone())
            .unwrap_or_else(|| "Instrument".into()),
        PluginTarget::TrackEffect(track, _) => ctx
            .app_state
            .tracks
            .get(track)
            .map(|track| track.name.clone())
            .unwrap_or_else(|| "Track".into()),
        PluginTarget::BusEffect(bus, _) => ctx
            .app_state
            .mixer
            .buses
            .get(bus)
            .map(|bus| bus.name.clone())
            .unwrap_or_else(|| "Bus".into()),
        PluginTarget::MasterEffect(_) => "Master".into(),
    }
}

/// Opens an external plugin's native editor after assigning a project-derived window context label.
pub fn open_editor(ctx: &mut DawContext, target: PluginTarget) -> anyhow::Result<()> {
    open_editor_for(
        resolve_hosted_target(prepare_hosted_target(ctx, target)?)?,
        editor_context(ctx, target),
    )
}

/// Closes the native editor associated with the targeted external plugin instance.
pub fn close_editor(ctx: &mut DawContext, target: PluginTarget) -> anyhow::Result<()> {
    close_editor_for(resolve_hosted_target(prepare_hosted_target(ctx, target)?)?)
}

/// Sets a normalized parameter value through the external plugin's main-thread controller.
pub fn set_parameter(
    ctx: &mut DawContext,
    target: PluginTarget,
    parameter: u32,
    value: f64,
) -> anyhow::Result<()> {
    set_parameter_for(
        resolve_hosted_target(prepare_hosted_target(ctx, target)?)?,
        parameter,
        value,
    )
}

/// Removes an external effect after the audio thread has retired its hosted processor.
///
/// The project copy is staged first and committed only after removal succeeds.
pub fn remove_effect(
    ctx: &mut DawContext,
    target: EffectTarget,
    effect: crate::shared::EffectId,
) -> anyhow::Result<()> {
    let pending = begin_remove_effect(ctx, target, effect)?;
    let completed = execute_removal(pending)?;
    let _ = commit_removal(ctx, completed);
    Ok(())
}

pub fn track_targets(ctx: &DawContext, track: crate::shared::TrackId) -> Vec<PluginTarget> {
    let mut targets = Vec::new();
    if let Some(generator) = ctx
        .app_state
        .tracks
        .get(track)
        .and_then(|track| track.generator.as_ref())
    {
        targets.push(PluginTarget::Generator(generator.id));
    }
    if let Some(channel) = ctx.app_state.mixer.channels.get(track) {
        targets.extend(
            channel
                .channel
                .effects
                .iter()
                .map(|effect| PluginTarget::TrackEffect(track, effect.id)),
        );
    }
    targets
}

/// Removes a track and all hosted plugins owned by it as one staged lifecycle operation.
pub fn delete_track(
    ctx: &mut DawContext,
    track: crate::shared::TrackId,
) -> anyhow::Result<crate::core::project::track::RemovedTrackType> {
    let pending = begin_delete_track(ctx, track)?;
    let completed = execute_removal(pending)?;
    match commit_removal(ctx, completed) {
        RemovedProjectItem::Track(removed) => Ok(removed),
        RemovedProjectItem::Effect | RemovedProjectItem::Bus => {
            anyhow::bail!("Track removal transaction returned an incompatible result")
        }
    }
}

/// Formats a normalized parameter value using the external plugin controller's display rules.
pub fn parameter_text(
    ctx: &mut DawContext,
    target: PluginTarget,
    parameter: u32,
    value: f64,
) -> anyhow::Result<String> {
    parameter_text_for(
        resolve_hosted_target(prepare_hosted_target(ctx, target)?)?,
        parameter,
        value,
    )
}

/// Parses plugin-specific display text into a normalized parameter value.
pub fn parse_parameter(
    ctx: &mut DawContext,
    target: PluginTarget,
    parameter: u32,
    text: String,
) -> anyhow::Result<f64> {
    parse_parameter_for(
        resolve_hosted_target(prepare_hosted_target(ctx, target)?)?,
        parameter,
        text,
    )
}

/// Converts between a parameter's plain and normalized domains.
///
/// When `to_normalized` is true, `value` is interpreted as plain; otherwise it is interpreted as
/// normalized.
pub fn convert_parameter(
    ctx: &mut DawContext,
    target: PluginTarget,
    parameter: u32,
    value: f64,
    to_normalized: bool,
) -> anyhow::Result<f64> {
    convert_parameter_for(
        resolve_hosted_target(prepare_hosted_target(ctx, target)?)?,
        parameter,
        value,
        to_normalized,
    )
}

/// Returns the recorded hosting failure for an external plugin target, if one is awaiting recovery.
pub fn failure(ctx: &DawContext, target: PluginTarget) -> Option<String> {
    ctx.external_plugin_failures.get(&target).cloned()
}

pub struct PendingPluginRetry {
    target: PluginTarget,
    track: Option<crate::shared::TrackId>,
    registry_id: u32,
    bypass: bool,
    descriptor: karbeat_host::PluginDescriptor,
    config: ProcessingConfig,
    state: Option<karbeat_host::PluginState>,
    handles: ControlHandles,
}

pub struct CompletedPluginRetry {
    target: PluginTarget,
    instance: ExternalPluginInstanceHandle,
    telemetry: Option<triple_buffer::Output<crate::audio::engine::PluginTelemetrySnapshot>>,
}

pub fn begin_retry(ctx: &DawContext, target: PluginTarget) -> anyhow::Result<PendingPluginRetry> {
    anyhow::ensure!(
        ctx.external_plugin_failures.contains_key(&target),
        "Plugin is not awaiting recovery"
    );
    let plugin = plugin_instance(ctx, target).context("Plugin target is unavailable")?;
    let external = plugin.external.as_ref().context("Plugin is not external")?;
    let descriptor = ctx
        .plugin_catalog
        .resolve(&external.descriptor.identity)
        .filter(|entry| entry.available)
        .map_or_else(
            || external.descriptor.clone(),
            |entry| entry.descriptor.clone(),
        );
    let config = ProcessingConfig {
        sample_rate: f64::from(ctx.audio_runtime_settings.read().requested_dsp.sample_rate),
        max_block_size: 65_536,
        main_input_channels: if descriptor.kind == PluginKind::Instrument {
            0
        } else {
            2
        },
        main_output_channels: 2,
        sidechain_channels: 0,
        offline: false,
    };
    let track = if let PluginTarget::Generator(id) = target {
        Some(
            ctx.app_state
                .tracks
                .values()
                .find(|track| {
                    track
                        .generator
                        .as_ref()
                        .is_some_and(|generator| generator.id == id)
                })
                .context("Generator has no track")?
                .id,
        )
    } else {
        None
    };
    Ok(PendingPluginRetry {
        target,
        track,
        registry_id: plugin.registry_id,
        bypass: plugin.bypass,
        descriptor,
        config,
        state: external.state.clone(),
        handles: ctx.control_handles(),
    })
}

pub fn execute_retry(pending: PendingPluginRetry) -> anyhow::Result<CompletedPluginRetry> {
    let prepared =
        futures_lite::future::block_on(pending.handles.external_plugins.prepare(PrepareRequest {
            descriptor: pending.descriptor,
            config: pending.config.clone(),
            state: pending.state,
        }))?;
    let instance = prepared.instance;
    let (install, receipt) = HostedPluginInstall::new(
        pending.target,
        pending.track,
        pending.registry_id,
        pending.config,
        prepared.processor,
    );
    futures_lite::future::block_on(pending.handles.external_plugins.resume(instance))?;
    let (command, mut control_retirement) =
        karbeat_host::ControlTransfer::new(install.replacing_missing().with_bypass(pending.bypass));
    {
        let mut sender = pending.handles.command_sender.lock();
        sender
            .as_mut()
            .context("Audio engine is unavailable")?
            .push(AudioCommand::InstallHostedPlugin(command))
            .map_err(|_| anyhow::anyhow!("Audio command queue is full"))?;
    }
    let telemetry = wait_for_install(receipt)?;
    if !control_retirement.collect() {
        log::warn!("Hosted retry control transfer was not returned after acknowledgement");
    }
    Ok(CompletedPluginRetry {
        target: pending.target,
        instance,
        telemetry,
    })
}

pub fn commit_retry(ctx: &mut DawContext, completed: CompletedPluginRetry) {
    if let Some(output) = completed.telemetry
        && let Some(registry) = &mut ctx.telemetry_registry
    {
        registry.insert_plugin_consumer(completed.target, output);
    }
    ctx.external_plugin_failures.remove(&completed.target);
    ctx.hosted_targets.insert(
        completed.target,
        crate::context::HostedTargetState::Active(completed.instance),
    );
}

/// Recreates and reinstalls an external plugin previously marked as failed.
///
/// The saved state and bypass flag are restored, and the failure marker is removed only after the
/// replacement has been accepted and activated.
pub fn retry(ctx: &mut DawContext, target: PluginTarget) -> anyhow::Result<()> {
    let pending = begin_retry(ctx, target)?;
    let completed = execute_retry(pending)?;
    commit_retry(ctx, completed);
    Ok(())
}

struct PendingReconfigurationTarget {
    target: PluginTarget,
    kind: PluginKind,
    format: karbeat_host::PluginFormat,
    bypass: bool,
}

pub struct PendingPluginReconfiguration {
    targets: Vec<PendingReconfigurationTarget>,
    sample_rate: u32,
    block_size: usize,
    handles: ControlHandles,
}

pub struct CompletedPluginReconfiguration {
    states: Vec<(
        PluginTarget,
        karbeat_host::PluginState,
        ExternalPluginInstanceHandle,
    )>,
}

pub fn begin_reconfigure_for_audio_config(
    ctx: &DawContext,
    sample_rate: u32,
    block_size: usize,
) -> anyhow::Result<Option<PendingPluginReconfiguration>> {
    let mut targets = Vec::new();
    for target in all_external_targets(ctx) {
        if ctx.external_plugin_failures.contains_key(&target) {
            continue;
        }
        let plugin = plugin_instance(ctx, target).context("External plugin target disappeared")?;
        let kind = plugin
            .external
            .as_ref()
            .context("External plug-in metadata disappeared")?
            .descriptor
            .kind;
        targets.push(PendingReconfigurationTarget {
            target,
            kind,
            format: plugin
                .external
                .as_ref()
                .context("External plug-in metadata disappeared")?
                .descriptor
                .identity
                .format,
            bypass: plugin.bypass,
        });
    }
    if targets.is_empty() {
        return Ok(None);
    }
    Ok(Some(PendingPluginReconfiguration {
        targets,
        sample_rate,
        block_size,
        handles: ctx.control_handles(),
    }))
}

fn all_external_targets(ctx: &DawContext) -> Vec<PluginTarget> {
    let mut targets = Vec::new();
    for (id, generator) in &ctx.app_state.generator_pool {
        if matches!(
            &generator.instance_type,
            GeneratorInstanceType::Plugin(plugin) if plugin.external.is_some()
        ) {
            targets.push(PluginTarget::Generator(id));
        }
    }
    for (track, channel) in &ctx.app_state.mixer.channels {
        targets.extend(channel.channel.effects.iter().filter_map(|effect| {
            effect
                .instance
                .external
                .as_ref()
                .map(|_| PluginTarget::TrackEffect(track, effect.id))
        }));
    }
    for (bus, channel) in &ctx.app_state.mixer.buses {
        targets.extend(channel.channel.effects.iter().filter_map(|effect| {
            effect
                .instance
                .external
                .as_ref()
                .map(|_| PluginTarget::BusEffect(bus, effect.id))
        }));
    }
    targets.extend(
        ctx.app_state
            .mixer
            .master_bus
            .effects
            .iter()
            .filter_map(|effect| {
                effect
                    .instance
                    .external
                    .as_ref()
                    .map(|_| PluginTarget::MasterEffect(effect.id))
            }),
    );
    targets
}

pub fn execute_reconfiguration(
    pending: PendingPluginReconfiguration,
) -> anyhow::Result<CompletedPluginReconfiguration> {
    let mut replacements = Vec::with_capacity(pending.targets.len());
    let mut states = Vec::with_capacity(pending.targets.len());
    for item in pending.targets {
        let current =
            super::project_api::hosted_instance_with_handles(&pending.handles, item.target)?;
        let current_handle = ExternalPluginInstanceHandle {
            format: item.format,
            id: current,
        };
        let prepared =
            futures_lite::future::block_on(pending.handles.external_plugins.reconfigure(
                ReconfigureRequest {
                    instance: current_handle,
                    sample_rate: pending.sample_rate,
                    max_block_size: pending.block_size.max(512),
                },
            ))?;
        let instance = prepared.instance;
        futures_lite::future::block_on(pending.handles.external_plugins.resume(instance))?;
        let config = ProcessingConfig {
            sample_rate: f64::from(pending.sample_rate),
            max_block_size: 65_536_usize.max(pending.block_size),
            main_input_channels: if item.kind == PluginKind::Instrument {
                0
            } else {
                2
            },
            main_output_channels: 2,
            sidechain_channels: 0,
            offline: false,
        };
        states.push((item.target, prepared.state.clone(), instance));
        replacements.push(HostedPluginReplacement::new(
            item.target,
            current,
            config,
            prepared.processor,
            item.bypass,
        ));
    }
    let (reconfiguration, receipt) =
        HostedPluginReconfiguration::new(replacements, pending.sample_rate, pending.block_size);
    let (transfer, mut control_retirement) = karbeat_host::ControlTransfer::new(reconfiguration);
    {
        let mut sender = pending.handles.command_sender.lock();
        sender
            .as_mut()
            .context("Audio engine is unavailable")?
            .push(AudioCommand::ReconfigureHostedPlugins(transfer))
            .map_err(|_| anyhow::anyhow!("Audio command queue is full"))?;
    }
    let _ = wait_for_install(receipt)?;
    if !control_retirement.collect() {
        log::warn!(
            "Hosted reconfiguration control transfer was not returned after acknowledgement"
        );
    }
    Ok(CompletedPluginReconfiguration { states })
}

pub fn commit_reconfiguration(ctx: &mut DawContext, completed: CompletedPluginReconfiguration) {
    for (target, state, instance) in completed.states {
        if let Some(external) =
            plugin_instance_mut(ctx, target).and_then(|plugin| plugin.external.as_mut())
        {
            external.state = Some(state);
        }
        ctx.hosted_targets
            .insert(target, crate::context::HostedTargetState::Active(instance));
    }
}

pub(crate) fn reconfigure_for_audio_config(
    ctx: &mut DawContext,
    sample_rate: u32,
    block_size: usize,
) -> anyhow::Result<()> {
    let Some(pending) = begin_reconfigure_for_audio_config(ctx, sample_rate, block_size)? else {
        return Ok(());
    };
    let completed = execute_reconfiguration(pending)?;
    commit_reconfiguration(ctx, completed);
    Ok(())
}

pub fn bus_targets(ctx: &DawContext, bus: crate::shared::BusId) -> Vec<PluginTarget> {
    ctx.app_state
        .mixer
        .buses
        .get(bus)
        .map(|bus_channel| {
            bus_channel
                .channel
                .effects
                .iter()
                .map(|effect| PluginTarget::BusEffect(bus, effect.id))
                .collect()
        })
        .unwrap_or_default()
}

/// Removes a mixer bus and retires every external effect hosted by that bus before committing state.
pub fn delete_bus(ctx: &mut DawContext, bus: crate::shared::BusId) -> anyhow::Result<()> {
    let pending = begin_delete_bus(ctx, bus)?;
    let completed = execute_removal(pending)?;
    let _ = commit_removal(ctx, completed);
    Ok(())
}
