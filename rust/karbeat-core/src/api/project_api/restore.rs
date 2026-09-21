use crate::{
    audio::{
        event::PluginTarget,
        hosted_plugin::{HostedInstallResult, HostedPluginInstall, HostedProjectInstall},
        missing_plugin::MissingPlugin,
        render_state::AudioGraphState,
    },
    commands::{AudioCommand, EffectTarget, MixerChannelSeed, PreparedPluginTelemetry},
    context::DawContext,
    core::project::{
        ApplicationState, GeneratorInstanceType, mixer::MixerChannel, plugin::PluginInstance,
    },
};
use anyhow::Context;
use hashbrown::HashMap;
use indexmap::IndexMap;
use karbeat_host::{PluginKind, ProcessingConfig};
use karbeat_plugin_api::types::BusConfig;
use karbeat_plugins::registry::{PluginFactory, PluginRegistry};

pub(super) fn plugins(app: &ApplicationState) -> Vec<(PluginTarget, &PluginInstance)> {
    let mut plugins = Vec::new();
    for (id, generator) in &app.generator_pool {
        if let GeneratorInstanceType::Plugin(plugin) = &generator.instance_type {
            plugins.push((PluginTarget::Generator(id), plugin));
        }
    }
    for (track, channel) in &app.mixer.channels {
        plugins.extend(channel.channel.effects.iter().map(|effect| {
            (
                PluginTarget::TrackEffect(track, effect.id),
                &effect.instance,
            )
        }));
    }
    for (bus, channel) in &app.mixer.buses {
        plugins.extend(
            channel
                .channel
                .effects
                .iter()
                .map(|effect| (PluginTarget::BusEffect(bus, effect.id), &effect.instance)),
        );
    }
    plugins.extend(
        app.mixer
            .master_bus
            .effects
            .iter()
            .map(|effect| (PluginTarget::MasterEffect(effect.id), &effect.instance)),
    );
    plugins
}

pub(super) fn has_external(app: &ApplicationState) -> bool {
    plugins(app)
        .iter()
        .any(|(_, plugin)| plugin.external.is_some())
}

fn factory(
    plugin: &PluginInstance,
    target: PluginTarget,
    registry: &PluginRegistry,
    missing: &HashMap<PluginTarget, String>,
) -> Option<PluginFactory> {
    if plugin.external.is_some() {
        return missing.contains_key(&target).then_some(
            if matches!(target, PluginTarget::Generator(_)) {
                MissingPlugin::instrument
            } else {
                MissingPlugin::effect
            },
        );
    }
    registry
        .create_plugin_by_id(plugin.registry_id)
        .map(|(factory, _)| factory)
}

fn seed(channel: &MixerChannel) -> MixerChannelSeed {
    MixerChannelSeed {
        volume: channel.volume.get(),
        pan: channel.pan.get(),
        mute: channel.mute,
        solo: channel.solo,
        inverted_phase: channel.inverted_phase,
    }
}

pub(super) fn hydration_command(
    app: &ApplicationState,
    registry: &PluginRegistry,
    missing: &HashMap<PluginTarget, String>,
    sample_rate: u32,
    block_size: usize,
) -> AudioCommand {
    let mut generators = IndexMap::new();
    let mut track_effects: IndexMap<_, IndexMap<_, _>> = IndexMap::new();
    let mut bus_effects: IndexMap<_, IndexMap<_, _>> = IndexMap::new();
    let mut master_effects = IndexMap::new();
    for (target, plugin) in plugins(app) {
        let Some(factory) = factory(plugin, target, registry, missing) else {
            continue;
        };
        let mut prepared = factory();
        if !plugin.plugin_state.is_empty() {
            prepared.set_state(&plugin.plugin_state);
        }
        for spec in &plugin.parameter_specs {
            prepared.set_parameter(spec.id, spec.value as f32);
        }
        prepared.prepare(sample_rate as f32, block_size.max(512));
        let bus = BusConfig {
            name: "Main".into(),
            channel_count: 2,
            is_optional: false,
        };
        prepared.set_io_layout(std::slice::from_ref(&bus), std::slice::from_ref(&bus));
        let telemetry = PreparedPluginTelemetry::new(prepared.as_ref());
        let entry = (plugin.registry_id, prepared, telemetry);
        match target {
            PluginTarget::Generator(id) => {
                generators.insert(id, entry);
            }
            PluginTarget::TrackEffect(track, effect) => {
                track_effects
                    .entry(track)
                    .or_default()
                    .insert(effect, entry);
            }
            PluginTarget::BusEffect(bus, effect) => {
                bus_effects.entry(bus).or_default().insert(effect, entry);
            }
            PluginTarget::MasterEffect(effect) => {
                master_effects.insert(effect, entry);
            }
        }
    }
    AudioCommand::HydratePlugin {
        generators,
        track_effects,
        bus_effects,
        master_effects,
        track_channels: app
            .mixer
            .channels
            .iter()
            .map(|(id, channel)| (id, seed(&channel.channel)))
            .collect(),
        bus_channels: app
            .mixer
            .buses
            .iter()
            .map(|(id, channel)| (id, seed(&channel.channel)))
            .collect(),
        master_channel: seed(&app.mixer.master_bus),
    }
}

pub struct PendingProjectRestore {
    staged: ApplicationState,
    handles: crate::context::ControlHandles,
    plugin_registry: PluginRegistry,
    plugin_catalog: crate::audio::plugin_catalog::PluginCatalog,
    sample_rate: u32,
    block_size: usize,
    has_engine: bool,
}

pub struct CompletedProjectRestore {
    staged: ApplicationState,
    missing: HashMap<PluginTarget, String>,
    receipts: Vec<(
        PluginTarget,
        karbeat_host::ExternalPluginInstanceHandle,
        crate::audio::hosted_plugin::HostedInstallReceipt,
    )>,
}

pub(super) fn begin_replace(
    ctx: &DawContext,
    staged: ApplicationState,
) -> anyhow::Result<PendingProjectRestore> {
    let has_engine = ctx.command_sender.lock().is_some();
    if has_engine {
        anyhow::ensure!(
            ctx.telemetry_registry.is_some(),
            "Audio telemetry is not initialized"
        );
    }
    anyhow::ensure!(
        staged.audio_config.buffer_size <= 65_536,
        "Unsupported project processing block size"
    );
    let dsp = ctx.audio_runtime_settings.read().requested_dsp;
    Ok(PendingProjectRestore {
        staged,
        handles: ctx.control_handles(),
        plugin_registry: ctx.plugin_registry.clone(),
        plugin_catalog: ctx.plugin_catalog.clone(),
        sample_rate: dsp.sample_rate,
        block_size: dsp.block_size as usize,
        has_engine,
    })
}

pub(super) fn execute_replace(
    pending: PendingProjectRestore,
) -> anyhow::Result<CompletedProjectRestore> {
    if !pending.has_engine {
        let missing = plugins(&pending.staged)
            .into_iter()
            .filter(|(_, plugin)| plugin.external.is_some())
            .map(|(target, _)| (target, "Audio engine is unavailable".into()))
            .collect();
        return Ok(CompletedProjectRestore {
            staged: pending.staged,
            missing,
            receipts: Vec::new(),
        });
    }
    let mut missing = HashMap::new();
    let mut installs = Vec::new();
    let mut receipts = Vec::new();
    let mut control_retirements: Vec<Box<dyn FnMut() -> bool>> = Vec::new();
    for (target, plugin) in plugins(&pending.staged) {
        let Some(external) = &plugin.external else {
            continue;
        };
        let descriptor = pending
            .plugin_catalog
            .resolve(&external.descriptor.identity)
            .filter(|entry| entry.available)
            .map_or_else(
                || external.descriptor.clone(),
                |entry| entry.descriptor.clone(),
            );
        let config = ProcessingConfig {
            sample_rate: f64::from(pending.sample_rate),
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
        let state = external.state.clone();
        let prepared = futures_lite::future::block_on(pending.handles.external_plugins.prepare(
            karbeat_host::PrepareRequest {
                descriptor,
                config: config.clone(),
                state,
            },
        ));
        let prepared = match prepared {
            Ok(prepared) => prepared,
            Err(error) => {
                missing.insert(target, error.to_string());
                continue;
            }
        };
        let instance = prepared.instance;
        futures_lite::future::block_on(pending.handles.external_plugins.resume(instance))?;
        let track = if let PluginTarget::Generator(id) = target {
            Some(
                pending
                    .staged
                    .tracks
                    .values()
                    .find(|track| {
                        track
                            .generator
                            .as_ref()
                            .is_some_and(|generator| generator.id == id)
                    })
                    .context("External generator has no track")?
                    .id,
            )
        } else {
            None
        };
        let (install, receipt) = HostedPluginInstall::new(
            target,
            track,
            plugin.registry_id,
            config,
            prepared.processor,
        );
        let install = install.with_bypass(plugin.bypass);
        let (command, mut retirement) = karbeat_host::ControlTransfer::new(install);
        installs.push(AudioCommand::InstallHostedPlugin(command));
        control_retirements.push(Box::new(move || retirement.collect()));
        receipts.push((target, instance, receipt));
    }
    let mut graph = AudioGraphState::from(&pending.staged);
    graph.sample_rate = pending.sample_rate;
    let mut commands = vec![
        AudioCommand::StopAndReset,
        AudioCommand::ReplaceFullGraph { graph },
        hydration_command(
            &pending.staged,
            &pending.plugin_registry,
            &missing,
            pending.sample_rate,
            pending.block_size,
        ),
    ];
    commands.extend(installs);
    for (track, channel) in &pending.staged.mixer.channels {
        commands.extend(channel.channel.effects.iter().enumerate().map(
            |(new_position, effect)| AudioCommand::MoveEffect {
                target: EffectTarget::Track(track),
                effect_id: effect.id,
                new_position,
            },
        ));
    }
    for (bus, channel) in &pending.staged.mixer.buses {
        commands.extend(channel.channel.effects.iter().enumerate().map(
            |(new_position, effect)| AudioCommand::MoveEffect {
                target: EffectTarget::Bus(bus),
                effect_id: effect.id,
                new_position,
            },
        ));
    }
    commands.extend(
        pending
            .staged
            .mixer
            .master_bus
            .effects
            .iter()
            .enumerate()
            .map(|(new_position, effect)| AudioCommand::MoveEffect {
                target: EffectTarget::Master,
                effect_id: effect.id,
                new_position,
            }),
    );
    commands.push(AudioCommand::SetBPM(pending.staged.transport.bpm));
    let (project, mut receipt) = HostedProjectInstall::new(commands, pending.sample_rate);
    let (command, mut project_retirement) = karbeat_host::ControlTransfer::new(project);
    pending
        .handles
        .command_sender
        .lock()
        .as_mut()
        .context("Audio engine is unavailable")?
        .push(AudioCommand::InstallHostedProject(command))
        .map_err(|_| anyhow::anyhow!("Audio command queue is full"))?;
    match futures_lite::future::block_on(receipt.wait())? {
        HostedInstallResult::Installed => {}
        result => anyhow::bail!("Audio engine rejected project replacement: {result:?}"),
    }
    for (_, _, plugin_receipt) in &mut receipts {
        let result = futures_lite::future::block_on(plugin_receipt.wait())?;
        anyhow::ensure!(
            result == HostedInstallResult::Installed,
            "Prepared external plugin was rejected: {result:?}"
        );
    }
    if !project_retirement.collect() {
        log::warn!("Hosted project control transfer was not returned after acknowledgement");
    }
    for retirement in &mut control_retirements {
        if !retirement() {
            log::warn!("Hosted project plugin transfer was not returned after acknowledgement");
        }
    }
    Ok(CompletedProjectRestore {
        staged: pending.staged,
        missing,
        receipts,
    })
}

pub(super) fn commit_replace(ctx: &mut DawContext, completed: CompletedProjectRestore) {
    ctx.drain_telemetry_registrations();
    ctx.hosted_targets.clear();
    for (target, instance, mut receipt) in completed.receipts {
        if let Some(registry) = &mut ctx.telemetry_registry {
            if let Some(output) = receipt.take_telemetry() {
                registry.insert_plugin_consumer(target, output);
            }
        }
        ctx.hosted_targets
            .insert(target, crate::context::HostedTargetState::Active(instance));
    }
    ctx.external_plugin_failures = completed.missing;
    for (target, reason) in &ctx.external_plugin_failures {
        ctx.hosted_targets.insert(
            *target,
            crate::context::HostedTargetState::Failed(reason.clone()),
        );
    }
    ctx.app_state = completed.staged;
}

pub(super) fn replace(ctx: &mut DawContext, staged: ApplicationState) -> anyhow::Result<()> {
    let completed = execute_replace(begin_replace(ctx, staged)?)?;
    commit_replace(ctx, completed);
    Ok(())
}
