use anyhow::Context;
use karbeat_host::{
    HostCapabilities, PluginController, PluginInstanceManager, PluginKind, ProcessingConfig,
};
use std::time::{Duration, Instant};

use crate::{
    audio::{
        event::PluginTarget,
        hosted_plugin::{HostedInstallStatus, HostedPluginInstall, HostedTrackGraph},
    },
    commands::{AudioCommand, EffectTarget},
    context::DawContext,
    core::project::{
        ApplicationState, AudioTrack, GeneratorInstanceType, TrackType,
        mixer::{EffectInstance, MixerChannel},
        plugin::{ExternalPluginInstance, PluginInstance},
    },
};

fn prepare(
    ctx: &DawContext,
    registry_id: u32,
    kind: PluginKind,
) -> anyhow::Result<(
    karbeat_vst3::native::PreparedNativeInstance,
    ProcessingConfig,
    PluginInstance,
)> {
    anyhow::ensure!(
        ctx.command_sender
            .lock()
            .as_ref()
            .is_some_and(|sender| sender.slots() >= 3),
        "Audio engine has no lifecycle command capacity"
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
    let descriptor = entry.descriptor.clone();
    let config = ProcessingConfig {
        sample_rate: f64::from(ctx.audio_runtime_settings.read().requested_dsp.sample_rate),
        max_block_size: 65_536,
        main_input_channels: if kind == PluginKind::Instrument { 0 } else { 2 },
        main_output_channels: 2,
        sidechain_channels: 0,
        offline: false,
    };
    let native_config = config.clone();
    let native_descriptor = descriptor.clone();
    let prepared = karbeat_vst3::native::call(move |owner| {
        owner.create_prepared(&native_descriptor, &native_config, None)
    })?;
    let plugin = PluginInstance {
        registry_id,
        name: descriptor.name.clone(),
        bypass: false,
        parameter_specs: prepared.parameters.clone(),
        plugin_state: Vec::new(),
        external: Some(ExternalPluginInstance {
            descriptor,
            state: Some(prepared.state.clone()),
        }),
    };
    Ok((prepared, config, plugin))
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

pub fn add_instrument(ctx: &mut DawContext, registry_id: u32) -> anyhow::Result<AudioTrack> {
    let (prepared, config, plugin) = prepare(ctx, registry_id, PluginKind::Instrument)?;
    let mut staged = ctx.app_state.clone();
    let track_id = staged.add_new_audio_track().id;
    let name = plugin.name.clone();
    let generator_id = staged.add_generator(GeneratorInstanceType::Plugin(plugin));
    let generator = staged
        .generator_pool
        .get(generator_id)
        .cloned()
        .context("Prepared generator is unavailable")?;
    let track = staged
        .tracks
        .get_mut(track_id)
        .context("Prepared track is unavailable")?;
    track.track_type = TrackType::Midi;
    track.name = name;
    track.generator = Some(generator);
    let track = track.clone();
    let install = HostedPluginInstall::new(
        PluginTarget::Generator(generator_id),
        Some(track_id),
        registry_id,
        config,
        prepared.processor,
    );
    let graph = HostedTrackGraph::from(&staged);
    publish(
        ctx,
        prepared.instance,
        staged,
        install.0.with_track_graph(graph),
        install.1,
        true,
    )?;
    Ok(track)
}

pub fn add_effect(
    ctx: &mut DawContext,
    target: EffectTarget,
    registry_id: u32,
) -> anyhow::Result<EffectInstance> {
    let (prepared, config, plugin) = prepare(ctx, registry_id, PluginKind::Effect)?;
    let mut staged = ctx.app_state.clone();
    let channel = channel_mut(&mut staged, &target)?;
    let effect_id = channel.effects.insert(plugin);
    let effect = channel
        .effects
        .get(effect_id)
        .cloned()
        .context("Prepared effect is unavailable")?;
    let plugin_target = match target {
        EffectTarget::Track(id) => PluginTarget::TrackEffect(id, effect_id),
        EffectTarget::Bus(id) => PluginTarget::BusEffect(id, effect_id),
        EffectTarget::Master => PluginTarget::MasterEffect(effect_id),
    };
    let (install, receipt) =
        HostedPluginInstall::new(plugin_target, None, registry_id, config, prepared.processor);
    publish(ctx, prepared.instance, staged, install, receipt, false)?;
    Ok(effect)
}

fn publish(
    ctx: &mut DawContext,
    instance: karbeat_host::HostInstanceId,
    staged: ApplicationState,
    install: HostedPluginInstall,
    mut receipt: crate::audio::hosted_plugin::HostedInstallReceipt,
    changes_graph: bool,
) -> anyhow::Result<()> {
    let target = install.target;
    let command = karbeat_vst3::native::call(move |owner| owner.prepare_control(install))?;
    {
        let mut sender = ctx.command_sender.lock();
        let sender = sender.as_mut().context("Audio engine is unavailable")?;
        anyhow::ensure!(
            sender.slots() >= 3,
            "Audio command queue has insufficient lifecycle capacity"
        );
        sender
            .push(AudioCommand::InstallHostedPlugin(command))
            .map_err(|_| anyhow::anyhow!("Audio command queue is full"))?;
    }
    let deadline = Instant::now() + Duration::from_secs(5);
    loop {
        match receipt.status() {
            HostedInstallStatus::Installed => break,
            HostedInstallStatus::Pending => {
                if Instant::now() >= deadline && receipt.cancel() {
                    anyhow::bail!("Plugin installation timed out before the engine accepted it");
                }
            }
            HostedInstallStatus::Applying => {}
            status => anyhow::bail!("Audio engine rejected plugin installation: {status:?}"),
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    if let Some(output) = receipt.take_telemetry() {
        if let Some(registry) = &mut ctx.telemetry_registry {
            registry.insert_plugin_consumer(target, output);
        }
    }
    if let Err(error) = karbeat_vst3::native::call(move |owner| owner.host.resume(instance)) {
        ctx.send_audio_command(remove_command(target))
            .context("Could not retire plugin after failed activation")?;
        if changes_graph {
            let graph = HostedTrackGraph::from(&ctx.app_state);
            ctx.send_audio_command(AudioCommand::UpdateTrackGraph {
                tracks: graph.tracks,
                clips: graph.clips,
                patterns: graph.patterns,
            })?;
            ctx.send_audio_command(AudioCommand::UpdateRouting {
                routing: graph.routing,
            })?;
        }
        return Err(error.into());
    }
    ctx.app_state = staged;
    Ok(())
}

fn remove_command(target: PluginTarget) -> AudioCommand {
    match target {
        PluginTarget::Generator(generator_id) => AudioCommand::RemoveGenerator { generator_id },
        PluginTarget::TrackEffect(id, effect_id) => AudioCommand::RemoveEffect {
            target: EffectTarget::Track(id),
            effect_id,
        },
        PluginTarget::BusEffect(id, effect_id) => AudioCommand::RemoveEffect {
            target: EffectTarget::Bus(id),
            effect_id,
        },
        PluginTarget::MasterEffect(effect_id) => AudioCommand::RemoveEffect {
            target: EffectTarget::Master,
            effect_id,
        },
    }
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

pub fn capabilities(
    ctx: &mut DawContext,
    target: PluginTarget,
) -> anyhow::Result<HostCapabilities> {
    let id = super::project_api::hosted_instance(ctx, target)?;
    Ok(karbeat_vst3::native::call(move |owner| {
        owner.host.capabilities(id)
    })?)
}

pub fn open_editor(ctx: &mut DawContext, target: PluginTarget) -> anyhow::Result<()> {
    let id = super::project_api::hosted_instance(ctx, target)?;
    let context = match target {
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
    };
    Ok(karbeat_vst3::native::call(move |owner| {
        owner.set_editor_context(id, context)?;
        owner.open_editor(id)
    })?)
}

pub fn close_editor(ctx: &mut DawContext, target: PluginTarget) -> anyhow::Result<()> {
    let id = super::project_api::hosted_instance(ctx, target)?;
    Ok(karbeat_vst3::native::call(move |owner| {
        owner.close_editor(id)
    })?)
}

pub fn set_parameter(
    ctx: &mut DawContext,
    target: PluginTarget,
    parameter: u32,
    value: f64,
) -> anyhow::Result<()> {
    let id = super::project_api::hosted_instance(ctx, target)?;
    Ok(karbeat_vst3::native::call(move |owner| {
        owner.host.set_parameter(id, parameter, value)
    })?)
}

fn remove_prepared(
    ctx: &mut DawContext,
    staged: ApplicationState,
    targets: Vec<PluginTarget>,
    changes_graph: bool,
    bus: Option<crate::shared::BusId>,
) -> anyhow::Result<()> {
    use crate::audio::hosted_plugin::{HostedPluginRemoval, HostedRemovalStatus};
    let mut expected = Vec::with_capacity(targets.len());
    for target in &targets {
        let instance = if descriptor(ctx, *target).is_some()
            && !ctx.external_plugin_failures.contains_key(target)
        {
            Some(super::project_api::hosted_instance(ctx, *target)?)
        } else {
            None
        };
        expected.push((*target, instance));
    }
    let graph = changes_graph.then(|| HostedTrackGraph::from(&staged));
    let (removal, receipt) = HostedPluginRemoval::new(expected, graph);
    let transfer =
        karbeat_vst3::native::call(move |owner| owner.prepare_control(removal.with_bus(bus)))?;
    ctx.send_audio_command(AudioCommand::RemoveHostedPlugins(transfer))?;
    let deadline = Instant::now() + Duration::from_secs(5);
    loop {
        match receipt.status() {
            HostedRemovalStatus::Removed => break,
            HostedRemovalStatus::Pending => {
                if Instant::now() >= deadline && receipt.cancel() {
                    anyhow::bail!("Plugin removal timed out before the engine accepted it");
                }
            }
            HostedRemovalStatus::Applying => {}
            status => anyhow::bail!("Audio engine rejected plugin removal: {status:?}"),
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    if let Some(registry) = &mut ctx.telemetry_registry {
        for target in &targets {
            registry.remove_plugin_consumer(target);
        }
    }
    for target in targets {
        ctx.external_plugin_failures.remove(&target);
    }
    ctx.app_state = staged;
    Ok(())
}

pub fn remove_effect(
    ctx: &mut DawContext,
    target: EffectTarget,
    effect: crate::shared::EffectId,
) -> anyhow::Result<()> {
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
    remove_prepared(ctx, staged, vec![target], false, None)
}

pub(crate) fn track_targets(ctx: &DawContext, track: crate::shared::TrackId) -> Vec<PluginTarget> {
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

pub fn delete_track(
    ctx: &mut DawContext,
    track: crate::shared::TrackId,
) -> anyhow::Result<crate::core::project::track::RemovedTrackType> {
    let targets = track_targets(ctx, track);
    let mut staged = ctx.app_state.clone();
    let removed = staged.remove_track(track)?;
    remove_prepared(ctx, staged, targets, true, None)?;
    Ok(removed)
}

pub fn parameter_text(
    ctx: &mut DawContext,
    target: PluginTarget,
    parameter: u32,
    value: f64,
) -> anyhow::Result<String> {
    let id = super::project_api::hosted_instance(ctx, target)?;
    Ok(karbeat_vst3::native::call(move |owner| {
        owner.host.parameter_text(id, parameter, value)
    })?)
}

pub fn parse_parameter(
    ctx: &mut DawContext,
    target: PluginTarget,
    parameter: u32,
    text: String,
) -> anyhow::Result<f64> {
    let id = super::project_api::hosted_instance(ctx, target)?;
    Ok(karbeat_vst3::native::call(move |owner| {
        owner.host.parse_parameter(id, parameter, &text)
    })?)
}

pub fn convert_parameter(
    ctx: &mut DawContext,
    target: PluginTarget,
    parameter: u32,
    value: f64,
    to_normalized: bool,
) -> anyhow::Result<f64> {
    let id = super::project_api::hosted_instance(ctx, target)?;
    Ok(karbeat_vst3::native::call(move |owner| {
        if to_normalized {
            owner.host.plain_to_normalized(id, parameter, value)
        } else {
            owner.host.normalized_to_plain(id, parameter, value)
        }
    })?)
}

pub fn failure(ctx: &DawContext, target: PluginTarget) -> Option<String> {
    ctx.external_plugin_failures.get(&target).cloned()
}

pub fn retry(ctx: &mut DawContext, target: PluginTarget) -> anyhow::Result<()> {
    anyhow::ensure!(
        ctx.external_plugin_failures.contains_key(&target),
        "Plugin is not awaiting recovery"
    );
    let plugin = plugin_instance(ctx, target)
        .context("Plugin target is unavailable")?
        .clone();
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
    let native_config = config.clone();
    let state = external.state.clone();
    let prepared = karbeat_vst3::native::call(move |owner| {
        owner.create_prepared(&descriptor, &native_config, state.as_ref())
    })?;
    let instance = prepared.instance;
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
    let (install, receipt) = HostedPluginInstall::new(
        target,
        track,
        plugin.registry_id,
        config,
        prepared.processor,
    );
    publish(
        ctx,
        instance,
        ctx.app_state.clone(),
        install.replacing_missing().with_bypass(plugin.bypass),
        receipt,
        false,
    )?;
    ctx.external_plugin_failures.remove(&target);
    Ok(())
}

pub(crate) fn bus_targets(ctx: &DawContext, bus: crate::shared::BusId) -> Vec<PluginTarget> {
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

pub fn delete_bus(ctx: &mut DawContext, bus: crate::shared::BusId) -> anyhow::Result<()> {
    let targets = bus_targets(ctx, bus);
    let mut staged = ctx.app_state.clone();
    staged.mixer.remove_bus(bus)?;
    remove_prepared(ctx, staged, targets, true, Some(bus))
}
