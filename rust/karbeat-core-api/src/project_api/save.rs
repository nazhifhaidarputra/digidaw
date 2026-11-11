use std::{
    collections::HashMap,
    mem::take,
    path::{Path, PathBuf},
    sync::{
        Arc,
        atomic::{AtomicU32, Ordering},
    },
    time::{Duration, Instant},
};

use anyhow::{Context, bail, ensure};
use karbeat_host::{HostError, HostInstanceId, HostStateCapture, PluginState};
use karbeat_plugins::registry::PluginRegistry;
#[cfg(test)]
use shuttle::thread::sleep;
#[cfg(not(test))]
use std::thread::sleep;

use crate::external_plugin_api::plugin_instance;
use karbeat_audio::{
    commands::{AudioCommand, AudioFeedback, MixerChannelSnapshot, MixerChannelTarget},
    context::{ControlHandles, DawContext},
    event::PluginTarget,
    project_state::ProjectStateFeedback,
};
use karbeat_core::core::{
    file_manager::{
        channel_template::{ChannelTemplate, ensure_channel_template_path, save_channel_template},
        project_loader::save_daw_project,
    },
    project::{ApplicationState, GeneratorInstanceType, plugin::PluginInstance},
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
    handles: &ControlHandles,
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
    let inbox =
        ProjectStateFeedback::register(&handles.project_state_feedback, pending.keys().copied())?;
    {
        let mut sender = handles.command_sender.lock();
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
            let mut feedback = handles.feedback_consumer.lock();
            if let Some(feedback) = feedback.as_mut() {
                for _ in 0..1024 {
                    let Ok(response) = feedback.pop() else {
                        break;
                    };
                    drop(handles.project_state_feedback.lock().route(response));
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
        sleep(Duration::from_millis(2));
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
    use super::super::save_project as project_api_save_project;
    use super::*;
    use karbeat_core::core::{
        file_manager::project_loader::load_daw_project, project::plugin::ExternalPluginInstance,
    };
    use karbeat_host::{PluginDescriptor, PluginFormat, PluginIdentity, PluginKind};
    use shuttle::{
        scheduler::RandomScheduler,
        thread::{JoinHandle, spawn, yield_now},
    };
    use std::fs::{read, write};

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

    /// Serializing and loading a project needs more stack than a default Shuttle task provides.
    fn check_random(test: impl Fn() + Send + Sync + 'static, iterations: usize) {
        let mut config = shuttle::Config::new();
        config.stack_size = 1 << 21;
        shuttle::Runner::new(RandomScheduler::new(iterations), config).run(test);
    }

    fn respond(ctx: &mut DawContext, stale_only: bool) -> JoinHandle<()> {
        respond_with_stream(ctx, stale_only, false)
    }

    fn respond_with_stream(
        ctx: &mut DawContext,
        stale_only: bool,
        stream_active: bool,
    ) -> JoinHandle<()> {
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
        spawn(move || {
            for _ in 0..2 {
                let command = loop {
                    if let Ok(command) = commands.pop() {
                        break command;
                    }
                    yield_now();
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
    fn public_save_uses_host_capture_without_feedback_lock_and_round_trips() {
        for stream_active in [false, true] {
            check_random(
                move || {
                    let mut ctx = DawContext::new();
                    let mut fresh = external(&mut ctx);
                    fresh.component = vec![3, 4];
                    let feedback_lock = ctx.feedback_consumer.clone();
                    let captured = fresh.clone();
                    ctx.host_state_capture = Arc::new(
                        move |identity: &karbeat_host::PluginIdentity, id: HostInstanceId| {
                            assert_eq!(identity, &captured.identity);
                            assert_eq!(id, HostInstanceId(7));
                            assert!(feedback_lock.try_lock().is_some());
                            Ok(captured.clone())
                        },
                    );
                    let responder = respond_with_stream(&mut ctx, false, stream_active);
                    let directory = tempfile::tempdir().unwrap();
                    let path = directory.path().join("saved.karbeat");
                    project_api_save_project(&mut ctx, path.to_str().unwrap()).unwrap();
                    responder.join().unwrap();
                    let loaded = load_daw_project(&path, 48_000).unwrap();
                    let generator = loaded.generator_pool.values().next().unwrap();
                    let GeneratorInstanceType::Plugin(plugin) = &generator.instance_type else {
                        panic!("expected plugin");
                    };
                    assert_eq!(
                        plugin.external.as_ref().unwrap().state.as_ref(),
                        Some(&fresh)
                    );
                    assert_eq!(loaded.mixer.master_bus.volume.get_base(), 0.25);
                },
                100,
            );
        }
    }

    #[test]
    fn stale_duplicate_responses_and_native_errors_preserve_previous_project() {
        for stale_only in [false, true] {
            check_random(
                move || {
                    let mut ctx = DawContext::new();
                    let before = external(&mut ctx);
                    let responder = respond(&mut ctx, stale_only);
                    let directory = tempfile::tempdir().unwrap();
                    let path = directory.path().join("previous.karbeat");
                    write(&path, b"previous project").unwrap();
                    // Shuttle's sleep does not advance the wall clock this deadline reads, so
                    // keep it short enough to expire within the scheduler's step bound.
                    let result = save_project(&mut ctx, &path, Duration::from_millis(5), |_, _| {
                        Err(HostError::Busy)
                    });
                    assert!(result.is_err());
                    responder.join().unwrap();
                    assert_eq!(read(&path).unwrap(), b"previous project");
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
                },
                20,
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
        write(&path, b"previous project").unwrap();
        assert!(
            save_project(&mut ctx, &path, Duration::ZERO, |_, _| panic!(
                "must not dispatch native work"
            ))
            .is_err()
        );
        assert!(commands.pop().is_err());
        assert_eq!(read(&path).unwrap(), b"previous project");
    }

    /// A master chain of a built-in plugin and an external one, with this external state stored.
    fn master_chain(ctx: &mut DawContext) -> (PluginTarget, PluginTarget, PluginState) {
        let stored = PluginState {
            version: 1,
            identity: PluginIdentity {
                format: PluginFormat::Vst3,
                native_id: "0123456789ABCDEF0123456789ABCDEF".into(),
            },
            component: vec![1],
            controller: None,
        };
        let effects = &mut ctx.app_state.mixer.master_bus.effects;
        let built_in = effects.insert(PluginInstance {
            name: "Built-in fixture".into(),
            plugin_state: vec![1],
            bypass: true,
            display_name: Some("Renamed".into()),
            ..Default::default()
        });
        let external = effects.insert(PluginInstance {
            name: "External fixture".into(),
            external: Some(ExternalPluginInstance {
                descriptor: PluginDescriptor {
                    identity: stored.identity.clone(),
                    path: "/missing/Fixture.vst3".into(),
                    name: "External fixture".into(),
                    vendor: "Fixture".into(),
                    version: "1".into(),
                    kind: PluginKind::Effect,
                },
                state: Some(stored.clone()),
            }),
            ..Default::default()
        });
        (
            PluginTarget::MasterEffect(built_in),
            PluginTarget::MasterEffect(external),
            stored,
        )
    }

    /// Answers `expected` plugin state queries as an engine would, and rejects anything else.
    fn respond_to_plugin_queries(
        ctx: &mut DawContext,
        expected: Vec<PluginTarget>,
        external: Option<PluginTarget>,
    ) -> JoinHandle<()> {
        let (sender, mut commands) = rtrb::RingBuffer::new(16);
        let (mut feedback, consumer) = rtrb::RingBuffer::new(16);
        *ctx.command_sender.lock() = Some(sender);
        *ctx.feedback_consumer.lock() = Some(consumer);
        spawn(move || {
            for wanted in expected {
                let command = loop {
                    if let Ok(command) = commands.pop() {
                        break command;
                    }
                    yield_now();
                };
                let AudioCommand::QueryPluginState { target, request_id } = command else {
                    panic!("templates only ask for plugin state");
                };
                assert_eq!(target, wanted);
                let hosted = external == Some(target);
                let response = AudioFeedback::PluginStateSnapshot {
                    target,
                    request_id,
                    state: if hosted { Vec::new() } else { vec![9, 9] },
                    host_instance: hosted.then_some(HostInstanceId(7)),
                };
                assert!(feedback.push(response).is_ok());
            }
        })
    }

    fn read_template(path: &Path) -> ChannelTemplate {
        serde_json::from_slice(&read(path).unwrap()).unwrap()
    }

    fn master_template_pending(ctx: &DawContext, path: &Path) -> PendingChannelTemplateSave {
        begin_channel_template_save(ctx, MixerChannelTarget::Master, path).unwrap()
    }

    #[test]
    fn template_stores_live_state_in_order_and_leaves_the_project_alone() {
        check_random(
            || {
                let mut ctx = DawContext::new();
                let (built_in, external, stored) = master_chain(&mut ctx);
                let mut fresh = stored.clone();
                fresh.component = vec![3, 4];
                let revision = ctx.app_state.session.revision();
                let responder =
                    respond_to_plugin_queries(&mut ctx, vec![built_in, external], Some(external));
                let directory = tempfile::tempdir().unwrap();
                let path = directory.path().join("chain.effch");

                let captured = fresh.clone();
                execute_channel_template_save_with(
                    master_template_pending(&ctx, &path),
                    Duration::from_secs(2),
                    move |_, id| {
                        assert_eq!(id, HostInstanceId(7));
                        Ok(captured.clone())
                    },
                )
                .unwrap();
                responder.join().unwrap();

                let template = read_template(&path);
                assert_eq!(template.effects.len(), 2);
                assert_eq!(template.effects[0].name, "Built-in fixture");
                assert_eq!(template.effects[0].plugin_state, [9, 9]);
                assert!(template.effects[0].bypass);
                assert_eq!(template.effects[0].display_name.as_deref(), Some("Renamed"));
                assert_eq!(
                    template.effects[1]
                        .external
                        .as_ref()
                        .unwrap()
                        .state
                        .as_ref(),
                    Some(&fresh)
                );

                let effects: Vec<_> = ctx.app_state.mixer.master_bus.effects.to_vec();
                assert_eq!(effects[0].instance.plugin_state, [1]);
                assert_eq!(
                    effects[1]
                        .instance
                        .external
                        .as_ref()
                        .unwrap()
                        .state
                        .as_ref(),
                    Some(&stored)
                );
                assert_eq!(ctx.app_state.session.revision(), revision);
            },
            100,
        );
    }

    #[test]
    fn template_keeps_the_stored_state_of_a_failed_external_plugin() {
        check_random(
            || {
                let mut ctx = DawContext::new();
                let (built_in, external, stored) = master_chain(&mut ctx);
                ctx.external_plugin_failures
                    .insert(external, "Plugin crashed".into());
                let responder = respond_to_plugin_queries(&mut ctx, vec![built_in], None);
                let directory = tempfile::tempdir().unwrap();
                let path = directory.path().join("chain.effch");

                execute_channel_template_save_with(
                    master_template_pending(&ctx, &path),
                    Duration::from_secs(2),
                    |_, _| panic!("a failed plugin has no live instance"),
                )
                .unwrap();
                responder.join().unwrap();

                let template = read_template(&path);
                assert_eq!(template.effects[0].plugin_state, [9, 9]);
                assert_eq!(
                    template.effects[1]
                        .external
                        .as_ref()
                        .unwrap()
                        .state
                        .as_ref(),
                    Some(&stored)
                );
            },
            20,
        );
    }

    #[test]
    fn failed_capture_keeps_the_previous_template() {
        let mut ctx = DawContext::new();
        master_chain(&mut ctx);
        let (sender, _commands) = rtrb::RingBuffer::new(1);
        let (_feedback, consumer) = rtrb::RingBuffer::new(1);
        *ctx.command_sender.lock() = Some(sender);
        *ctx.feedback_consumer.lock() = Some(consumer);
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("chain.effch");
        write(&path, b"previous template").unwrap();

        // The two plugin queries do not fit the queue, so nothing is captured.
        assert!(
            execute_channel_template_save_with(
                master_template_pending(&ctx, &path),
                Duration::ZERO,
                |_, _| panic!("must not dispatch native work"),
            )
            .is_err()
        );
        assert_eq!(read(&path).unwrap(), b"previous template");
    }

    #[test]
    fn absent_engine_preserves_stored_external_identity_and_state() {
        let mut ctx = DawContext::new();
        let stored = external(&mut ctx);
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("stored.karbeat");
        save_project(&mut ctx, &path, Duration::ZERO, |_, _| {
            panic!("no live instance to capture")
        })
        .unwrap();
        let loaded = load_daw_project(&path, 48_000).unwrap();
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

pub struct PendingProjectSave {
    path: PathBuf,
    saved: ApplicationState,
    handles: ControlHandles,
    plugin_registry: PluginRegistry,
    external_plugin_failures: hashbrown::HashMap<PluginTarget, String>,
    host_state_capture: Arc<dyn HostStateCapture>,
    has_engine: bool,
}

pub struct CompletedProjectSave {
    path: PathBuf,
    saved: ApplicationState,
}

impl CompletedProjectSave {
    /// Project modification revision captured when this save began.
    pub fn revision(&self) -> u64 {
        self.saved.session.revision()
    }
}

pub(super) fn begin_save(ctx: &DawContext, path: &Path) -> PendingProjectSave {
    PendingProjectSave {
        path: path.to_owned(),
        saved: ctx.app_state.clone(),
        handles: ctx.control_handles(),
        plugin_registry: ctx.plugin_registry.clone(),
        external_plugin_failures: ctx.external_plugin_failures.clone(),
        host_state_capture: ctx.host_state_capture.clone(),
        has_engine: ctx.command_sender.lock().is_some(),
    }
}

pub(super) fn execute_save(
    pending: PendingProjectSave,
    timeout: Duration,
) -> anyhow::Result<CompletedProjectSave> {
    let host_state_capture = pending.host_state_capture.clone();
    execute_save_with(pending, timeout, move |identity, instance| {
        host_state_capture.capture_state(identity, instance)
    })
}

/// Copies the captured live state into `saved`, asking the host for each external plugin's state.
fn apply_captured_plugins(
    saved: &mut ApplicationState,
    plugin_registry: &PluginRegistry,
    plugins: Vec<CapturedPlugin>,
    capture_host_state: &mut impl FnMut(
        &karbeat_host::PluginIdentity,
        HostInstanceId,
    ) -> Result<PluginState, HostError>,
) -> anyhow::Result<()> {
    for captured in plugins {
        let plugin =
            plugin_mut(saved, captured.target).context("Project plugin disappeared during save")?;
        match (&mut plugin.external, captured.host) {
            (Some(external), Some(host)) => {
                let state = capture_host_state(&external.descriptor.identity, host)
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
                if let Some(specs) =
                    plugin_registry.get_plugin_parameter_specs_by_id(plugin.registry_id)
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
    Ok(())
}

fn execute_save_with(
    mut pending: PendingProjectSave,
    timeout: Duration,
    mut capture_host_state: impl FnMut(
        &karbeat_host::PluginIdentity,
        HostInstanceId,
    ) -> Result<PluginState, HostError>,
) -> anyhow::Result<CompletedProjectSave> {
    if pending.has_engine {
        let requested = targets(&pending.saved)
            .into_iter()
            .filter(|target| {
                !matches!(target, PendingTarget::Plugin(target) if pending.external_plugin_failures.contains_key(target))
            })
            .collect();
        let (plugins, mixer) = collect(&pending.handles, timeout, requested)?;
        apply_captured_plugins(
            &mut pending.saved,
            &pending.plugin_registry,
            plugins,
            &mut capture_host_state,
        )?;
        for snapshot in mixer {
            apply_mixer_snapshot(&mut pending.saved, &snapshot)
                .context("Mixer channel disappeared during save")?;
        }
    }
    save_daw_project(&pending.path, &pending.saved)?;
    Ok(CompletedProjectSave {
        path: pending.path,
        saved: pending.saved,
    })
}

/// Publishes the engine-synced project and marks it saved as of the revision captured at
/// `begin_save`, so edits that landed while the save ran keep the project unsaved.
pub(super) fn commit_save(ctx: &mut DawContext, completed: CompletedProjectSave) {
    let revision = completed.revision();
    let mut session = take(&mut ctx.app_state.session);
    session.mark_saved_at(revision);
    session.set_file_path(Some(completed.path));
    ctx.app_state = completed.saved;
    ctx.app_state.session = session;
}

pub(super) fn save_project(
    ctx: &mut DawContext,
    path: &Path,
    timeout: Duration,
    capture_host_state: impl FnMut(
        &karbeat_host::PluginIdentity,
        HostInstanceId,
    ) -> Result<PluginState, HostError>,
) -> anyhow::Result<()> {
    let completed = execute_save_with(begin_save(ctx, path), timeout, capture_host_state)?;
    commit_save(ctx, completed);
    Ok(())
}

/// A channel's effect chain waiting to be written as a template, detached from the live project.
pub struct PendingChannelTemplateSave {
    channel: MixerChannelTarget,
    project: PendingProjectSave,
}

/// Validates the destination and channel, and takes the copy the template is captured into.
pub(super) fn begin_channel_template_save(
    ctx: &DawContext,
    channel: MixerChannelTarget,
    path: &Path,
) -> anyhow::Result<PendingChannelTemplateSave> {
    ensure_channel_template_path(path)?;
    ensure!(
        ctx.app_state
            .get_mixer_channel_from_target(channel)
            .is_some(),
        "Cannot find the target mixer channel"
    );
    Ok(PendingChannelTemplateSave {
        channel,
        project: begin_save(ctx, path),
    })
}

pub(super) fn execute_channel_template_save(
    pending: PendingChannelTemplateSave,
    timeout: Duration,
) -> anyhow::Result<()> {
    let host_state_capture = pending.project.host_state_capture.clone();
    execute_channel_template_save_with(pending, timeout, move |identity, instance| {
        host_state_capture.capture_state(identity, instance)
    })
}

/// Writes the chain as it currently sounds. The live state goes into the pending copy only, so
/// the project itself stays as it was.
///
/// A failed external plugin has no live instance to ask, so it keeps its stored state.
fn execute_channel_template_save_with(
    pending: PendingChannelTemplateSave,
    timeout: Duration,
    mut capture_host_state: impl FnMut(
        &karbeat_host::PluginIdentity,
        HostInstanceId,
    ) -> Result<PluginState, HostError>,
) -> anyhow::Result<()> {
    let PendingChannelTemplateSave {
        channel,
        mut project,
    } = pending;
    if project.has_engine {
        let requested = channel_plugin_targets(&project.saved, &channel)
            .into_iter()
            .filter(|target| !project.external_plugin_failures.contains_key(target))
            .map(PendingTarget::Plugin)
            .collect();
        let (plugins, _) = collect(&project.handles, timeout, requested)?;
        apply_captured_plugins(
            &mut project.saved,
            &project.plugin_registry,
            plugins,
            &mut capture_host_state,
        )?;
    }
    let effects = project
        .saved
        .get_mixer_channel_from_target(channel)
        .context("Cannot find the target mixer channel")?
        .effects
        .iter()
        .map(|effect| effect.instance.clone())
        .collect();
    save_channel_template(&project.path, &ChannelTemplate::new(effects))
}

/// The plugin targets of a channel's effects, in processing order.
fn channel_plugin_targets(
    app: &ApplicationState,
    channel: &MixerChannelTarget,
) -> Vec<PluginTarget> {
    let Some(mixer_channel) = app.get_mixer_channel_from_target(*channel) else {
        return Vec::new();
    };
    mixer_channel
        .effects
        .iter()
        .map(|effect| match channel {
            MixerChannelTarget::Track(id) => PluginTarget::TrackEffect(*id, effect.id),
            MixerChannelTarget::Bus(id) => PluginTarget::BusEffect(*id, effect.id),
            MixerChannelTarget::Master => PluginTarget::MasterEffect(effect.id),
        })
        .collect()
}

fn apply_mixer_snapshot(app: &mut ApplicationState, snapshot: &MixerChannelSnapshot) -> Option<()> {
    let channel = match snapshot.target {
        MixerChannelTarget::Track(id) => &mut app.mixer.channels.get_mut(id)?.channel,
        MixerChannelTarget::Bus(id) => &mut app.mixer.buses.get_mut(id)?.channel,
        MixerChannelTarget::Master => &mut app.mixer.master_bus,
    };
    channel.volume.set_base(snapshot.volume);
    channel.pan.set_base(snapshot.pan);
    channel.mute = snapshot.mute;
    channel.solo = snapshot.solo;
    channel.inverted_phase = snapshot.inverted_phase;
    Some(())
}

/// How long an edit waits for the engine to report live state before going ahead without it.
#[cfg(not(test))]
const LIVE_CAPTURE_TIMEOUT: Duration = Duration::from_millis(500);
/// Unit tests never run an engine that could answer, so the capture gives up at once.
#[cfg(test)]
const LIVE_CAPTURE_TIMEOUT: Duration = Duration::ZERO;

/// Copies the live engine state of first-party plugins and mixer channels into the project.
///
/// Plugin parameters and mixer values live on the audio thread and reach the project only when
/// it is saved. Call this before recording an edit that removes those objects, so undo brings
/// them back as they sounded. Without a running engine the project copy is already current.
pub(crate) fn capture_live_state(
    ctx: &mut DawContext,
    plugins: &[PluginTarget],
    mixers: &[MixerChannelTarget],
) -> anyhow::Result<()> {
    if ctx.command_sender.lock().is_none() {
        return Ok(());
    }
    let requested = plugins
        .iter()
        .filter(|target| {
            !ctx.external_plugin_failures.contains_key(*target)
                && plugin_instance(ctx, **target).is_some_and(|plugin| plugin.external.is_none())
        })
        .map(|target| PendingTarget::Plugin(*target))
        .chain(mixers.iter().cloned().map(PendingTarget::Mixer))
        .collect();
    let (captured, snapshots) = collect(&ctx.control_handles(), LIVE_CAPTURE_TIMEOUT, requested)?;
    for captured in captured {
        if let Some(plugin) = plugin_mut(&mut ctx.app_state, captured.target)
            && plugin.external.is_none()
        {
            plugin.plugin_state = captured.state;
            if let Some(specs) = ctx
                .plugin_registry
                .get_plugin_parameter_specs_by_id(plugin.registry_id)
            {
                plugin.parameter_specs = specs;
            }
        }
    }
    for snapshot in snapshots {
        apply_mixer_snapshot(&mut ctx.app_state, &snapshot);
    }
    Ok(())
}

pub(crate) fn hosted_instance_with_handles(
    handles: &ControlHandles,
    target: PluginTarget,
) -> anyhow::Result<HostInstanceId> {
    let (plugins, _) = collect(
        handles,
        Duration::from_secs(2),
        vec![PendingTarget::Plugin(target)],
    )?;
    plugins
        .into_iter()
        .next()
        .and_then(|plugin| plugin.host)
        .context("External plugin is not available in the audio engine")
}
