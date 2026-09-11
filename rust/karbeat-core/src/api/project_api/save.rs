use std::{
    collections::HashMap,
    path::Path,
    sync::atomic::{AtomicU32, Ordering},
    time::{Duration, Instant},
};

use anyhow::{Context, bail, ensure};
use karbeat_host::{HostError, HostInstanceId, PluginState};

use crate::{
    audio::event::PluginTarget,
    commands::{AudioCommand, AudioFeedback, MixerChannelSnapshot, MixerChannelTarget},
    context::DawContext,
    core::{
        file_manager::project_loader::save_daw_project,
        project::{ApplicationState, GeneratorInstanceType, plugin::PluginInstance},
    },
};

static NEXT_REQUEST: AtomicU32 = AtomicU32::new(1);

fn request_id() -> anyhow::Result<u32> {
    NEXT_REQUEST
        .fetch_update(Ordering::Relaxed, Ordering::Relaxed, |id| id.checked_add(1))
        .map_err(|_| anyhow::anyhow!("Project state request IDs exhausted"))
}

enum PendingTarget {
    Plugin(PluginTarget),
    Mixer(MixerChannelTarget),
}

fn plugin_mut(app: &mut ApplicationState, target: PluginTarget) -> Option<&mut PluginInstance> {
    match target {
        PluginTarget::Generator(id) => match &mut app.generator_pool.get_mut(id)?.instance_type {
            GeneratorInstanceType::Plugin(plugin) => Some(plugin),
            _ => None,
        },
        PluginTarget::TrackEffect(track, effect) => app
            .mixer
            .channels
            .get_mut(track)?
            .channel
            .effects
            .iter_mut()
            .find(|entry| entry.id == effect)
            .map(|entry| &mut entry.instance),
        PluginTarget::BusEffect(bus, effect) => app
            .mixer
            .buses
            .get_mut(bus)?
            .channel
            .effects
            .iter_mut()
            .find(|entry| entry.id == effect)
            .map(|entry| &mut entry.instance),
        PluginTarget::MasterEffect(effect) => app
            .mixer
            .master_bus
            .effects
            .iter_mut()
            .find(|entry| entry.id == effect)
            .map(|entry| &mut entry.instance),
    }
}

fn targets(app: &ApplicationState) -> Vec<PendingTarget> {
    let mut targets = Vec::new();
    for (id, generator) in &app.generator_pool {
        if matches!(generator.instance_type, GeneratorInstanceType::Plugin(_)) {
            targets.push(PendingTarget::Plugin(PluginTarget::Generator(id)));
        }
    }
    for (id, track) in &app.mixer.channels {
        targets.extend(
            track
                .channel
                .effects
                .iter()
                .map(|effect| PendingTarget::Plugin(PluginTarget::TrackEffect(id, effect.id))),
        );
        targets.push(PendingTarget::Mixer(MixerChannelTarget::Track(id)));
    }
    for (id, bus) in &app.mixer.buses {
        targets.extend(
            bus.channel
                .effects
                .iter()
                .map(|effect| PendingTarget::Plugin(PluginTarget::BusEffect(id, effect.id))),
        );
        targets.push(PendingTarget::Mixer(MixerChannelTarget::Bus(id)));
    }
    targets.extend(
        app.mixer
            .master_bus
            .effects
            .iter()
            .map(|effect| PendingTarget::Plugin(PluginTarget::MasterEffect(effect.id))),
    );
    targets.push(PendingTarget::Mixer(MixerChannelTarget::Master));
    targets
}

struct CapturedPlugin {
    target: PluginTarget,
    state: Vec<u8>,
    host: Option<HostInstanceId>,
}

fn collect(
    ctx: &mut DawContext,
    timeout: Duration,
    targets: Vec<PendingTarget>,
) -> anyhow::Result<(Vec<CapturedPlugin>, Vec<MixerChannelSnapshot>)> {
    let mut pending = HashMap::new();
    let mut commands = Vec::new();
    for target in targets {
        let id = request_id()?;
        let command = match &target {
            PendingTarget::Plugin(target) => AudioCommand::QueryPluginState {
                target: *target,
                request_id: id,
            },
            PendingTarget::Mixer(target) => AudioCommand::QueryMixerChannel {
                target: target.clone(),
                request_id: Some(id),
            },
        };
        pending.insert(id, target);
        commands.push(command);
    }
    let inbox = crate::audio::project_state::ProjectStateFeedback::register(
        &ctx.project_state_feedback,
        pending.keys().copied(),
    )?;
    {
        let mut sender = ctx.command_sender.lock();
        let sender = sender.as_mut().context("Audio engine is unavailable")?;
        ensure!(
            sender.slots() >= commands.len(),
            "Audio command queue cannot accept all project state requests"
        );
        for command in commands {
            sender
                .push(command)
                .map_err(|_| anyhow::anyhow!("Audio command queue is full"))?;
        }
    }
    let mut plugins = Vec::new();
    let mut mixer = Vec::new();
    let start = Instant::now();
    while !pending.is_empty() {
        {
            let mut feedback = ctx.feedback_consumer.lock();
            if let Some(feedback) = feedback.as_mut() {
                for _ in 0..1024 {
                    let Ok(response) = feedback.pop() else {
                        break;
                    };
                    drop(ctx.project_state_feedback.lock().route(response));
                }
            }
        }
        while let Ok(response) = inbox.receiver.try_recv() {
            match response {
                AudioFeedback::PluginStateSnapshot {
                    target,
                    state,
                    request_id,
                    host_instance,
                } if matches!(pending.get(&request_id), Some(PendingTarget::Plugin(expected)) if *expected == target) =>
                {
                    pending.remove(&request_id);
                    plugins.push(CapturedPlugin {
                        target,
                        state,
                        host: host_instance,
                    });
                }
                AudioFeedback::MixerChannelSnapshot(snapshot) => {
                    if let Some(id) = snapshot.request_id {
                        if matches!(pending.get(&id), Some(PendingTarget::Mixer(expected)) if *expected == snapshot.target)
                        {
                            pending.remove(&id);
                            mixer.push(snapshot);
                        }
                    }
                }
                _ => {}
            }
        }
        if pending.is_empty() {
            break;
        }
        ensure!(
            start.elapsed() < timeout,
            "Timed out capturing fresh project state ({} responses missing)",
            pending.len()
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    Ok((plugins, mixer))
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::panic,
    reason = "save fixtures fail on unexpected queue and persistence results"
)]
mod tests {
    use super::*;
    use crate::core::project::plugin::ExternalPluginInstance;
    use karbeat_host::{PluginDescriptor, PluginFormat, PluginIdentity, PluginKind};

    fn external(ctx: &mut DawContext) -> PluginState {
        let state = PluginState {
            version: 1,
            identity: PluginIdentity {
                format: PluginFormat::Vst3,
                native_id: "0123456789ABCDEF0123456789ABCDEF".into(),
            },
            component: vec![1],
            controller: Some(vec![2]),
        };
        ctx.app_state
            .add_generator(GeneratorInstanceType::Plugin(PluginInstance {
                name: "External fixture".into(),
                external: Some(ExternalPluginInstance {
                    descriptor: PluginDescriptor {
                        identity: state.identity.clone(),
                        path: "/missing/Fixture.vst3".into(),
                        name: "External fixture".into(),
                        vendor: "Fixture".into(),
                        version: "1".into(),
                        kind: PluginKind::Instrument,
                    },
                    state: Some(state.clone()),
                }),
                ..Default::default()
            }));
        state
    }

    fn respond(ctx: &mut DawContext, stale_only: bool) -> std::thread::JoinHandle<()> {
        respond_with_stream(ctx, stale_only, false)
    }

    fn respond_with_stream(
        ctx: &mut DawContext,
        stale_only: bool,
        stream_active: bool,
    ) -> std::thread::JoinHandle<()> {
        let (sender, mut commands) = rtrb::RingBuffer::new(16);
        let (mut feedback, consumer) = rtrb::RingBuffer::new(16);
        *ctx.command_sender.lock() = Some(sender);
        *ctx.feedback_consumer.lock() = Some(consumer);
        let mut stream = if stream_active {
            ctx.feedback_consumer.lock().take()
        } else {
            None
        };
        let router = ctx.project_state_feedback.clone();
        std::thread::spawn(move || {
            let deadline = Instant::now() + Duration::from_secs(5);
            for _ in 0..2 {
                let command = loop {
                    if let Ok(command) = commands.pop() {
                        break command;
                    }
                    assert!(Instant::now() < deadline);
                    std::thread::yield_now();
                };
                let response = match command {
                    AudioCommand::QueryPluginState { target, request_id } => {
                        AudioFeedback::PluginStateSnapshot {
                            target,
                            request_id: if stale_only { 0 } else { request_id },
                            state: Vec::new(),
                            host_instance: Some(HostInstanceId(7)),
                        }
                    }
                    AudioCommand::QueryMixerChannel { target, request_id } => {
                        AudioFeedback::MixerChannelSnapshot(MixerChannelSnapshot {
                            target,
                            request_id: if stale_only { Some(0) } else { request_id },
                            magnitude: 0.0,
                            volume: 0.25,
                            pan: 0.5,
                            mute: false,
                            solo: false,
                            inverted_phase: false,
                        })
                    }
                    _ => panic!("unexpected save command"),
                };
                assert!(feedback.push(response.clone()).is_ok());
                assert!(feedback.push(response).is_ok());
                if let Some(stream) = &mut stream {
                    while let Ok(response) = stream.pop() {
                        drop(router.lock().route(response));
                    }
                }
            }
        })
    }

    #[test]
    fn hosted_state_is_captured_without_feedback_lock_and_round_trips() {
        for stream_active in [false, true] {
            let mut ctx = DawContext::new();
            let mut fresh = external(&mut ctx);
            fresh.component = vec![3, 4];
            let feedback_lock = ctx.feedback_consumer.clone();
            let responder = respond_with_stream(&mut ctx, false, stream_active);
            let directory = tempfile::tempdir().unwrap();
            let path = directory.path().join("saved.karbeat");
            save_project(&mut ctx, &path, Duration::from_secs(2), |id| {
                assert_eq!(id, HostInstanceId(7));
                assert!(feedback_lock.try_lock().is_some());
                Ok(fresh.clone())
            })
            .unwrap();
            responder.join().unwrap();
            let loaded =
                crate::core::file_manager::project_loader::load_daw_project(&path, 48_000).unwrap();
            let generator = loaded.generator_pool.values().next().unwrap();
            let GeneratorInstanceType::Plugin(plugin) = &generator.instance_type else {
                panic!("expected plugin");
            };
            assert_eq!(
                plugin.external.as_ref().unwrap().state.as_ref(),
                Some(&fresh)
            );
            assert_eq!(loaded.mixer.master_bus.volume.get_base(), 0.25);
        }
    }

    #[test]
    fn stale_duplicate_responses_and_native_errors_preserve_previous_project() {
        for stale_only in [false, true] {
            let mut ctx = DawContext::new();
            let before = external(&mut ctx);
            let responder = respond(&mut ctx, stale_only);
            let directory = tempfile::tempdir().unwrap();
            let path = directory.path().join("previous.karbeat");
            std::fs::write(&path, b"previous project").unwrap();
            let result = save_project(&mut ctx, &path, Duration::from_millis(100), |_| {
                Err(HostError::Busy)
            });
            assert!(result.is_err());
            responder.join().unwrap();
            assert_eq!(std::fs::read(&path).unwrap(), b"previous project");
            let GeneratorInstanceType::Plugin(plugin) = &ctx
                .app_state
                .generator_pool
                .values()
                .next()
                .unwrap()
                .instance_type
            else {
                panic!("expected plugin");
            };
            assert_eq!(
                plugin.external.as_ref().unwrap().state.as_ref(),
                Some(&before)
            );
        }
    }

    #[test]
    fn full_queue_rejects_the_whole_save_batch_before_publication() {
        let mut ctx = DawContext::new();
        external(&mut ctx);
        let (sender, mut commands) = rtrb::RingBuffer::new(1);
        let (_feedback, consumer) = rtrb::RingBuffer::new(1);
        *ctx.command_sender.lock() = Some(sender);
        *ctx.feedback_consumer.lock() = Some(consumer);
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("previous.karbeat");
        std::fs::write(&path, b"previous project").unwrap();
        assert!(
            save_project(&mut ctx, &path, Duration::ZERO, |_| panic!(
                "must not dispatch native work"
            ))
            .is_err()
        );
        assert!(commands.pop().is_err());
        assert_eq!(std::fs::read(&path).unwrap(), b"previous project");
    }

    #[test]
    fn absent_engine_preserves_stored_external_identity_and_state() {
        let mut ctx = DawContext::new();
        let stored = external(&mut ctx);
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("stored.karbeat");
        save_project(&mut ctx, &path, Duration::ZERO, |_| {
            panic!("no live instance to capture")
        })
        .unwrap();
        let loaded =
            crate::core::file_manager::project_loader::load_daw_project(&path, 48_000).unwrap();
        let GeneratorInstanceType::Plugin(plugin) =
            &loaded.generator_pool.values().next().unwrap().instance_type
        else {
            panic!("expected plugin");
        };
        assert_eq!(
            plugin.external.as_ref().unwrap().state.as_ref(),
            Some(&stored)
        );
    }
}

pub(super) fn save_project(
    ctx: &mut DawContext,
    path: &Path,
    timeout: Duration,
    mut capture_native: impl FnMut(HostInstanceId) -> Result<PluginState, HostError>,
) -> anyhow::Result<()> {
    let has_engine = ctx.command_sender.lock().is_some();
    let mut saved = ctx.app_state.clone();
    if has_engine {
        let requested = targets(&ctx.app_state).into_iter().filter(|target| {
            !matches!(target, PendingTarget::Plugin(target) if ctx.external_plugin_failures.contains_key(target))
        }).collect();
        let (plugins, mixer) = collect(ctx, timeout, requested)?;
        for captured in plugins {
            let plugin = plugin_mut(&mut saved, captured.target)
                .context("Project plugin disappeared during save")?;
            match (&mut plugin.external, captured.host) {
                (Some(external), Some(host)) => {
                    // collect releases the feedback lock before dispatching any native UI work.
                    let state = capture_native(host)
                        .with_context(|| format!("Could not capture {}", plugin.name))?;
                    ensure!(
                        state.identity == external.descriptor.identity,
                        "Captured state belongs to a different plugin: {}",
                        plugin.name
                    );
                    external.state = Some(state);
                }
                (None, None) => {
                    plugin.plugin_state = captured.state;
                    if let Some(specs) = ctx
                        .plugin_registry
                        .get_plugin_parameter_specs_by_id(plugin.registry_id)
                    {
                        plugin.parameter_specs = specs;
                    }
                }
                _ => bail!(
                    "Project and audio engine disagree about plugin {}",
                    plugin.name
                ),
            }
        }
        for snapshot in mixer {
            let channel = match snapshot.target {
                MixerChannelTarget::Track(id) => {
                    &mut saved
                        .mixer
                        .channels
                        .get_mut(id)
                        .context("Track disappeared during save")?
                        .channel
                }
                MixerChannelTarget::Bus(id) => {
                    &mut saved
                        .mixer
                        .buses
                        .get_mut(id)
                        .context("Bus disappeared during save")?
                        .channel
                }
                MixerChannelTarget::Master => &mut saved.mixer.master_bus,
            };
            channel.volume.set_base(snapshot.volume);
            channel.pan.set_base(snapshot.pan);
            channel.mute = snapshot.mute;
            channel.solo = snapshot.solo;
            channel.inverted_phase = snapshot.inverted_phase;
        }
    }
    save_daw_project(path, &saved)?;
    ctx.app_state = saved;
    Ok(())
}

pub(crate) fn hosted_instance(
    ctx: &mut DawContext,
    target: PluginTarget,
) -> anyhow::Result<HostInstanceId> {
    ensure!(
        plugin_mut(&mut ctx.app_state, target).is_some_and(|plugin| plugin.external.is_some()),
        "Target is not an external plugin"
    );
    ensure!(
        !ctx.external_plugin_failures.contains_key(&target),
        "External plugin is unavailable; retry loading it first"
    );
    let (plugins, _) = collect(
        ctx,
        Duration::from_secs(2),
        vec![PendingTarget::Plugin(target)],
    )?;
    plugins
        .into_iter()
        .next()
        .and_then(|plugin| plugin.host)
        .context("External plugin is not available in the audio engine")
}
