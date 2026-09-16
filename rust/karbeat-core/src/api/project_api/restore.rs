use crate::{
    audio::{
        event::PluginTarget,
        hosted_plugin::{HostedInstallStatus, HostedPluginInstall, HostedProjectInstall},
        missing_plugin::MissingPlugin,
        render_state::AudioGraphState,
    },
    commands::{AudioCommand, EffectTarget, MixerChannelSeed},
    context::DawContext,
    core::project::{
        ApplicationState, GeneratorInstanceType, mixer::MixerChannel, plugin::PluginInstance,
    },
};
use anyhow::Context;
use hashbrown::HashMap;
use indexmap::IndexMap;
use karbeat_host::{PluginInstanceManager, PluginKind, ProcessingConfig};
use karbeat_plugins::registry::{PluginFactory, PluginRegistry};
use std::time::{Duration, Instant};

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
) -> AudioCommand {
    let mut generators = IndexMap::new();
    let mut track_effects: IndexMap<_, IndexMap<_, _>> = IndexMap::new();
    let mut bus_effects: IndexMap<_, IndexMap<_, _>> = IndexMap::new();
    let mut master_effects = IndexMap::new();
    for (target, plugin) in plugins(app) {
        let Some(factory) = factory(plugin, target, registry, missing) else {
            continue;
        };
        let entry = (plugin.clone(), factory);
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

pub(super) fn replace(ctx: &mut DawContext, staged: ApplicationState) -> anyhow::Result<()> {
    if ctx.command_sender.lock().is_none() {
        ctx.external_plugin_failures = plugins(&staged)
            .into_iter()
            .filter(|(_, plugin)| plugin.external.is_some())
            .map(|(target, _)| (target, "Audio engine is unavailable".into()))
            .collect();
        ctx.app_state = staged;
        return Ok(());
    }
    anyhow::ensure!(
        ctx.telemetry_registry.is_some(),
        "Audio telemetry is not initialized"
    );
    anyhow::ensure!(
        staged.audio_config.buffer_size <= 65_536,
        "Unsupported project processing block size"
    );
    let sample_rate = ctx.audio_runtime_settings.read().requested_dsp.sample_rate;
    let mut missing = HashMap::new();
    let mut installs = Vec::new();
    let mut receipts = Vec::new();
    for (target, plugin) in plugins(&staged) {
        let Some(external) = &plugin.external else {
            continue;
        };
        let descriptor = ctx
            .plugin_catalog
            .resolve(&external.descriptor.identity)
            .filter(|entry| entry.available)
            .map_or_else(
                || external.descriptor.clone(),
                |entry| entry.descriptor.clone(),
            );
        let config = ProcessingConfig {
            sample_rate: f64::from(sample_rate),
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
        let prepared = karbeat_vst3::native::prepare_instance(descriptor, config.clone(), state);
        let prepared = match prepared {
            Ok(prepared) => prepared,
            Err(error) => {
                missing.insert(target, error.to_string());
                continue;
            }
        };
        let instance = prepared.instance;
        karbeat_vst3::native::call(move |owner| owner.host.resume(instance))?;
        let track = if let PluginTarget::Generator(id) = target {
            Some(
                staged
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
        let command = karbeat_vst3::native::call(move |owner| owner.prepare_control(install))?;
        installs.push(AudioCommand::InstallHostedPlugin(command));
        receipts.push((target, receipt));
    }
    let mut graph = AudioGraphState::from(&staged);
    graph.sample_rate = sample_rate;
    let mut commands = vec![
        AudioCommand::StopAndReset,
        AudioCommand::ReplaceFullGraph { graph },
        hydration_command(&staged, &ctx.plugin_registry, &missing),
    ];
    commands.extend(installs);
    for (track, channel) in &staged.mixer.channels {
        commands.extend(channel.channel.effects.iter().enumerate().map(
            |(new_position, effect)| AudioCommand::MoveEffect {
                target: EffectTarget::Track(track),
                effect_id: effect.id,
                new_position,
            },
        ));
    }
    for (bus, channel) in &staged.mixer.buses {
        commands.extend(channel.channel.effects.iter().enumerate().map(
            |(new_position, effect)| AudioCommand::MoveEffect {
                target: EffectTarget::Bus(bus),
                effect_id: effect.id,
                new_position,
            },
        ));
    }
    commands.extend(staged.mixer.master_bus.effects.iter().enumerate().map(
        |(new_position, effect)| AudioCommand::MoveEffect {
            target: EffectTarget::Master,
            effect_id: effect.id,
            new_position,
        },
    ));
    commands.push(AudioCommand::SetBPM(staged.transport.bpm));
    let (project, receipt) = HostedProjectInstall::new(commands, sample_rate);
    let command = karbeat_vst3::native::call(move |owner| owner.prepare_control(project))?;
    ctx.send_audio_command(AudioCommand::InstallHostedProject(command))?;
    let deadline = Instant::now() + Duration::from_secs(5);
    loop {
        match receipt.status() {
            HostedInstallStatus::Installed => break,
            HostedInstallStatus::Pending => {
                if Instant::now() >= deadline && receipt.cancel() {
                    anyhow::bail!("Project replacement timed out before the engine accepted it");
                }
            }
            HostedInstallStatus::Applying => {}
            status => anyhow::bail!("Audio engine rejected project replacement: {status:?}"),
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    ctx.drain_telemetry_registrations();
    if let Some(registry) = &mut ctx.telemetry_registry {
        for (target, mut receipt) in receipts {
            anyhow::ensure!(
                receipt.status() == HostedInstallStatus::Installed,
                "Prepared external plugin was rejected: {:?}",
                receipt.status()
            );
            if let Some(output) = receipt.take_telemetry() {
                registry.insert_plugin_consumer(target, output);
            }
        }
    }
    ctx.external_plugin_failures = missing;
    ctx.app_state = staged;
    Ok(())
}
