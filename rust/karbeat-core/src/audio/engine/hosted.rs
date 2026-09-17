use super::AudioEngine;
use crate::{
    audio::{
        event::PluginTarget,
        hosted_plugin::{HostedInstallStatus, HostedPluginInstall, HostedPluginReconfiguration},
        render_state::{AudioEffectInstance, AudioGeneratorInstance},
    },
    commands::EffectTarget,
};

impl AudioEngine {
    pub(super) fn reconfigure_hosted_plugins(
        &mut self,
        mut transfer: karbeat_host::ControlTransfer<HostedPluginReconfiguration>,
    ) {
        let Some(reconfiguration) = transfer.get_mut() else {
            return;
        };
        if !reconfiguration.begin() {
            return;
        }
        let configuration_is_valid = reconfiguration.sample_rate > 0
            && reconfiguration.block_size > 0
            && reconfiguration.replacements.iter().all(|replacement| {
                replacement.config.validate().is_ok()
                    && replacement.config.sample_rate == f64::from(reconfiguration.sample_rate)
                    && replacement.config.main_output_channels
                        == usize::from(self.config.num_channels)
                    && replacement.config.max_block_size >= reconfiguration.block_size.max(512)
                    && !replacement.config.offline
                    && replacement.endpoint.is_some()
            });
        if !configuration_is_valid {
            reconfiguration.complete(HostedInstallStatus::InvalidConfiguration);
            return;
        }
        let targets_are_current = reconfiguration.replacements.iter().all(|replacement| {
            self.plugin_state
                .plugin(&replacement.target)
                .and_then(|plugin| {
                    plugin
                        .as_any()
                        .downcast_ref::<karbeat_host::HostedProcessor>()
                })
                .is_some_and(|plugin| plugin.instance == replacement.expected)
        });
        if !targets_are_current {
            reconfiguration.complete(HostedInstallStatus::MissingTarget);
            return;
        }

        let mut prepared = Vec::with_capacity(reconfiguration.replacements.len());
        for replacement in &mut reconfiguration.replacements {
            let Some(endpoint) = replacement.endpoint.take() else {
                for endpoint in prepared {
                    karbeat_plugin_api::traits::AudioPlugin::retire(endpoint);
                }
                reconfiguration.complete(HostedInstallStatus::Cancelled);
                return;
            };
            match endpoint.install() {
                Ok(mut endpoint) => {
                    endpoint.set_bypass(replacement.bypass);
                    prepared.push(endpoint);
                }
                Err(_) => {
                    for endpoint in prepared {
                        karbeat_plugin_api::traits::AudioPlugin::retire(endpoint);
                    }
                    reconfiguration.complete(HostedInstallStatus::Cancelled);
                    return;
                }
            }
        }

        self.process_command(crate::commands::AudioCommand::UpdateAudioConfig {
            sample_rate: Some(reconfiguration.sample_rate),
            buffer_size: Some(reconfiguration.block_size),
        });

        for (replacement, endpoint) in reconfiguration.replacements.iter().zip(prepared) {
            let plugin = match replacement.target {
                PluginTarget::Generator(id) => self
                    .plugin_state
                    .get_generator_mut(id)
                    .map(|generator| std::mem::replace(&mut generator.plugin, endpoint)),
                PluginTarget::TrackEffect(track, effect) => self
                    .plugin_state
                    .get_track_effects_mut(track.to_u32() as usize)
                    .and_then(|chain| chain.iter_mut().find(|item| item.id == effect))
                    .map(|item| std::mem::replace(&mut item.plugin, endpoint)),
                PluginTarget::BusEffect(bus, effect) => self
                    .plugin_state
                    .get_bus_effects_mut(bus.to_u32() as usize)
                    .and_then(|chain| chain.iter_mut().find(|item| item.id == effect))
                    .map(|item| std::mem::replace(&mut item.plugin, endpoint)),
                PluginTarget::MasterEffect(effect) => self
                    .plugin_state
                    .master_effects
                    .iter_mut()
                    .find(|item| item.id == effect)
                    .map(|item| std::mem::replace(&mut item.plugin, endpoint)),
            };
            if let Some(plugin) = plugin {
                plugin.retire();
            }
        }
        self.recalculate_latencies();
        reconfiguration.complete(HostedInstallStatus::Installed);
    }

    pub(super) fn remove_hosted_plugins(
        &mut self,
        mut transfer: karbeat_host::ControlTransfer<
            crate::audio::hosted_plugin::HostedPluginRemoval,
        >,
    ) {
        use crate::{audio::hosted_plugin::HostedRemovalStatus, commands::AudioCommand};
        let Some(removal) = transfer.get_mut() else {
            return;
        };
        if !removal.begin() {
            return;
        }
        if removal
            .bus
            .is_some_and(|bus| !self.mixer_state.bus_channels.contains_key(&bus))
        {
            removal.complete(HostedRemovalStatus::StaleTarget);
            return;
        }
        for (target, expected) in &removal.targets {
            let Some(plugin) = self.plugin_state.plugin(target) else {
                removal.complete(HostedRemovalStatus::StaleTarget);
                return;
            };
            let actual = plugin
                .as_any()
                .downcast_ref::<karbeat_host::HostedProcessor>()
                .map(|plugin| plugin.instance);
            if actual != *expected {
                removal.complete(HostedRemovalStatus::StaleTarget);
                return;
            }
        }
        for (target, _) in &removal.targets {
            if let Some(input) = self.telemetry.param_telemetry_producers.remove(target) {
                removal.telemetry.push(input);
            }
            let command = match *target {
                PluginTarget::Generator(generator_id) => {
                    AudioCommand::RemoveGenerator { generator_id }
                }
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
            };
            self.process_command(command);
        }
        if let Some(bus_id) = removal.bus {
            self.process_command(AudioCommand::RemoveBus { bus_id });
        }
        if let Some(graph) = removal.graph.take() {
            self.process_command(AudioCommand::UpdateTrackGraph {
                tracks: graph.tracks,
                clips: graph.clips,
                patterns: graph.patterns,
            });
            self.process_command(AudioCommand::UpdateRouting {
                routing: graph.routing,
            });
        }
        removal.complete(HostedRemovalStatus::Removed);
    }

    /// Check sticky backend failures from an offline/control worker after rendering a block.
    pub fn validate_hosted_processing(
        &self,
    ) -> Result<(), crate::audio::engine::AudioExportSnapshotError> {
        let plugins = self
            .plugin_state
            .generators
            .iter()
            .map(|(_, generator)| &generator.plugin)
            .chain(
                self.plugin_state
                    .track_effects
                    .iter()
                    .flatten()
                    .map(|effect| &effect.plugin),
            )
            .chain(
                self.plugin_state
                    .bus_effects
                    .iter()
                    .flatten()
                    .map(|effect| &effect.plugin),
            )
            .chain(
                self.plugin_state
                    .master_effects
                    .iter()
                    .map(|effect| &effect.plugin),
            );
        for plugin in plugins {
            if let Some(hosted) = plugin
                .as_any()
                .downcast_ref::<karbeat_host::HostedProcessor>()
            {
                if let Some(source) = hosted.processing_error() {
                    return Err(
                        crate::audio::engine::AudioExportSnapshotError::HostedPlugin {
                            instance: hosted.instance,
                            source,
                        },
                    );
                }
            }
        }
        Ok(())
    }

    pub(super) fn install_hosted_plugin(
        &mut self,
        mut transfer: karbeat_host::ControlTransfer<HostedPluginInstall>,
    ) {
        let Some(install) = transfer.get_mut() else {
            return;
        };
        if !install.begin() {
            return;
        }
        let config = &install.config;
        if config.validate().is_err()
            || config.sample_rate != f64::from(self.config.sample_rate)
            || config.main_output_channels != usize::from(self.config.num_channels)
            || config.max_block_size < self.current_state.graph.buffer_size.max(512)
            || config.offline
                != matches!(
                    self.processing_mode,
                    karbeat_plugin_api::types::ProcessingMode::Offline
                )
        {
            install.complete(HostedInstallStatus::InvalidConfiguration);
            return;
        }
        let (effect_target, effect_id) = match install.target {
            PluginTarget::Generator(id) => {
                let Some(track_id) = install.generator_track else {
                    install.complete(HostedInstallStatus::MissingTarget);
                    return;
                };
                let tracks = install
                    .graph
                    .as_ref()
                    .map_or(&self.current_state.graph.tracks, |graph| &graph.tracks);
                if !tracks.iter().any(|track| track.id == track_id) {
                    install.complete(HostedInstallStatus::MissingTarget);
                    return;
                }
                let existing = self.plugin_state.get_generator(id);
                if install.replace_missing {
                    if !existing.is_some_and(|generator| {
                        generator
                            .plugin
                            .as_any()
                            .is::<crate::audio::missing_plugin::MissingPlugin>()
                    }) {
                        install.complete(HostedInstallStatus::MissingTarget);
                        return;
                    }
                } else if existing.is_some() {
                    install.complete(HostedInstallStatus::OccupiedTarget);
                    return;
                }
                let Some(endpoint) = install.endpoint.take() else {
                    install.complete(HostedInstallStatus::Cancelled);
                    return;
                };
                let Ok(mut plugin) = endpoint.install() else {
                    install.complete(HostedInstallStatus::Cancelled);
                    return;
                };
                plugin.set_bypass(install.bypass);
                if let Some(graph) = install.graph.take() {
                    self.process_command(crate::commands::AudioCommand::UpdateTrackGraph {
                        tracks: graph.tracks,
                        clips: graph.clips,
                        patterns: graph.patterns,
                    });
                    self.process_command(crate::commands::AudioCommand::UpdateRouting {
                        routing: graph.routing,
                    });
                }
                self.plugin_state.insert_generator(AudioGeneratorInstance {
                    id,
                    track_id,
                    registry_id: install.registry_id,
                    plugin,
                });
                if let Some(input) = install.telemetry.take() {
                    self.telemetry
                        .param_telemetry_producers
                        .insert(install.target, input);
                }
                install.complete(HostedInstallStatus::Installed);
                return;
            }
            PluginTarget::TrackEffect(track, effect) => {
                if !self
                    .current_state
                    .graph
                    .tracks
                    .iter()
                    .any(|item| item.id == track)
                {
                    install.complete(HostedInstallStatus::MissingTarget);
                    return;
                }
                (EffectTarget::Track(track), effect)
            }
            PluginTarget::BusEffect(bus, effect) => {
                if !self.mixer_state.bus_channels.contains_key(&bus) {
                    install.complete(HostedInstallStatus::MissingTarget);
                    return;
                }
                (EffectTarget::Bus(bus), effect)
            }
            PluginTarget::MasterEffect(effect) => (EffectTarget::Master, effect),
        };
        let existing = self
            .get_effect_list_mut(&effect_target)
            .and_then(|chain| chain.iter().find(|effect| effect.id == effect_id));
        if install.replace_missing {
            if !existing.is_some_and(|effect| {
                effect
                    .plugin
                    .as_any()
                    .is::<crate::audio::missing_plugin::MissingPlugin>()
            }) {
                install.complete(HostedInstallStatus::MissingTarget);
                return;
            }
        } else if existing.is_some() {
            install.complete(HostedInstallStatus::OccupiedTarget);
            return;
        }
        let Some(endpoint) = install.endpoint.take() else {
            install.complete(HostedInstallStatus::Cancelled);
            return;
        };
        let Ok(mut plugin) = endpoint.install() else {
            install.complete(HostedInstallStatus::Cancelled);
            return;
        };
        plugin.set_bypass(install.bypass);
        let effect = AudioEffectInstance {
            id: effect_id,
            registry_id: install.registry_id,
            plugin,
        };
        if install.replace_missing {
            if let Some(existing) = self
                .get_effect_list_mut(&effect_target)
                .and_then(|chain| chain.iter_mut().find(|item| item.id == effect_id))
            {
                std::mem::replace(existing, effect).plugin.retire();
            }
        } else {
            match effect_target {
                EffectTarget::Track(track) => self
                    .plugin_state
                    .add_track_effect(track.to_u32() as usize, effect),
                EffectTarget::Bus(bus) => self
                    .plugin_state
                    .add_bus_effect(bus.to_u32() as usize, effect),
                EffectTarget::Master => self.plugin_state.master_effects.push(effect),
            }
        }
        if let Some(input) = install.telemetry.take() {
            self.telemetry
                .param_telemetry_producers
                .insert(install.target, input);
        }
        install.complete(HostedInstallStatus::Installed);
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "test fixture construction and ownership assertions"
)]
mod tests {
    use super::*;
    use crate::{
        audio::{
            engine::AudioEngineTelemetry, event::TransportFeedback,
            hosted_plugin::HostedInstallReceipt,
        },
        commands::{AudioCommand, AudioFeedback, TelemetryRegistration},
        shared::EffectId,
    };
    use karbeat_host::{HostInstanceId, HostedProcessor, ProcessingConfig, ProcessorRetirement};
    use karbeat_plugin_api::traits::AudioPluginBuilder;
    use karbeat_plugins::effect::delay::DigidawDelay;

    fn process_install(engine: &mut AudioEngine, install: HostedPluginInstall) {
        let (command, mut retirement) = karbeat_host::ControlTransfer::new(install);
        engine.process_command(AudioCommand::InstallHostedPlugin(command));
        assert!(retirement.collect());
    }

    fn engine() -> AudioEngine {
        let (_, commands) = rtrb::RingBuffer::<AudioCommand>::new(8);
        let (position, _) = rtrb::RingBuffer::<TransportFeedback>::new(8);
        let (feedback, _) = rtrb::RingBuffer::<AudioFeedback>::new(8);
        let (telemetry, _) = std::sync::mpsc::sync_channel::<TelemetryRegistration>(8);
        AudioEngine::new(
            commands,
            position,
            feedback,
            48_000,
            2,
            120.0,
            512,
            AudioEngineTelemetry::new_for_export(),
            telemetry,
        )
    }

    fn install(
        rate: f64,
    ) -> (
        HostedPluginInstall,
        HostedInstallReceipt,
        ProcessorRetirement,
    ) {
        let endpoint = Box::new(HostedProcessor::new(
            Box::new(DigidawDelay::build()),
            HostInstanceId(1),
        ));
        let (endpoint, retirement) = endpoint.prepare_transfer().unwrap();
        let config = ProcessingConfig {
            sample_rate: rate,
            max_block_size: 65_536,
            main_input_channels: 2,
            main_output_channels: 2,
            sidechain_channels: 0,
            offline: false,
        };
        let (command, receipt) = HostedPluginInstall::new(
            PluginTarget::MasterEffect(EffectId::from(11)),
            None,
            123,
            config,
            endpoint,
        );
        (command, receipt, retirement)
    }

    #[test]
    fn hosted_reconfiguration_swaps_endpoint_and_updates_engine_rate() {
        let mut engine = engine();
        let (install, receipt, mut old_retirement) = install(48_000.0);
        process_install(&mut engine, install);
        assert_eq!(receipt.status(), HostedInstallStatus::Installed);

        let replacement = Box::new(HostedProcessor::new(
            Box::new(DigidawDelay::build()),
            HostInstanceId(2),
        ));
        let (endpoint, mut replacement_retirement) = replacement
            .prepare_transfer()
            .expect("replacement transfer");
        let config = ProcessingConfig {
            sample_rate: 96_000.0,
            max_block_size: 65_536,
            main_input_channels: 2,
            main_output_channels: 2,
            sidechain_channels: 0,
            offline: false,
        };
        let target = PluginTarget::MasterEffect(EffectId::from(11));
        let replacement = crate::audio::hosted_plugin::HostedPluginReplacement::new(
            target,
            HostInstanceId(1),
            config,
            endpoint,
            false,
        );
        let (reconfiguration, reconfiguration_receipt) =
            crate::audio::hosted_plugin::HostedPluginReconfiguration::new(
                vec![replacement],
                96_000,
                256,
            );
        let (command, mut control_retirement) = karbeat_host::ControlTransfer::new(reconfiguration);

        engine.process_command(AudioCommand::ReconfigureHostedPlugins(command));

        assert!(control_retirement.collect());
        assert_eq!(
            reconfiguration_receipt.status(),
            HostedInstallStatus::Installed
        );
        assert_eq!(engine.config.sample_rate, 96_000);
        assert_eq!(engine.current_state.graph.sample_rate, 96_000);
        assert_eq!(engine.current_state.graph.buffer_size, 256);
        let active = engine
            .plugin_state
            .plugin(&target)
            .and_then(|plugin| plugin.as_any().downcast_ref::<HostedProcessor>())
            .expect("replacement should be installed");
        assert_eq!(active.instance, HostInstanceId(2));
        assert!(old_retirement.take().is_some());
        assert!(replacement_retirement.take().is_none());
        drop(engine);
        assert!(replacement_retirement.take().is_some());
    }

    #[test]
    fn stale_hosted_reconfiguration_preserves_endpoint_and_engine_rate() {
        let mut engine = engine();
        let (install, receipt, mut old_retirement) = install(48_000.0);
        process_install(&mut engine, install);
        assert_eq!(receipt.status(), HostedInstallStatus::Installed);

        let replacement = Box::new(HostedProcessor::new(
            Box::new(DigidawDelay::build()),
            HostInstanceId(2),
        ));
        let (endpoint, mut replacement_retirement) = replacement
            .prepare_transfer()
            .expect("replacement transfer");
        let config = ProcessingConfig {
            sample_rate: 96_000.0,
            max_block_size: 65_536,
            main_input_channels: 2,
            main_output_channels: 2,
            sidechain_channels: 0,
            offline: false,
        };
        let target = PluginTarget::MasterEffect(EffectId::from(11));
        let replacement = crate::audio::hosted_plugin::HostedPluginReplacement::new(
            target,
            HostInstanceId(99),
            config,
            endpoint,
            false,
        );
        let (reconfiguration, reconfiguration_receipt) =
            crate::audio::hosted_plugin::HostedPluginReconfiguration::new(
                vec![replacement],
                96_000,
                256,
            );
        let (command, mut control_retirement) = karbeat_host::ControlTransfer::new(reconfiguration);

        engine.process_command(AudioCommand::ReconfigureHostedPlugins(command));

        assert!(control_retirement.collect());
        assert_eq!(
            reconfiguration_receipt.status(),
            HostedInstallStatus::MissingTarget
        );
        assert_eq!(engine.config.sample_rate, 48_000);
        let active = engine
            .plugin_state
            .plugin(&target)
            .and_then(|plugin| plugin.as_any().downcast_ref::<HostedProcessor>())
            .expect("original endpoint should remain installed");
        assert_eq!(active.instance, HostInstanceId(1));
        assert!(replacement_retirement.take().is_some());
        drop(engine);
        assert!(old_retirement.take().is_some());
    }

    #[test]
    fn hosted_save_query_returns_handle_instead_of_serializing_the_audio_endpoint() {
        let mut engine = engine();
        let (feedback, mut responses) = rtrb::RingBuffer::new(8);
        engine.io.feedback_producer = feedback;
        let (command, receipt, mut retirement) = install(48_000.0);
        process_install(&mut engine, command);
        assert_eq!(receipt.status(), HostedInstallStatus::Installed);
        let target = PluginTarget::MasterEffect(EffectId::from(11));
        engine.process_command(AudioCommand::QueryPluginState {
            target,
            request_id: 91,
        });
        assert!(
            matches!(responses.pop().unwrap(), AudioFeedback::PluginStateSnapshot {
            target: actual, request_id: 91, host_instance: Some(HostInstanceId(1)), state,
        } if actual == target && state.is_empty())
        );
        drop(engine);
        assert!(retirement.take().is_some());
    }

    #[test]
    fn installation_is_acknowledged_and_removal_returns_the_endpoint() {
        let mut engine = engine();
        let (command, receipt, mut retirement) = install(48_000.0);
        process_install(&mut engine, command);
        assert_eq!(receipt.status(), HostedInstallStatus::Installed);
        assert_eq!(engine.plugin_state.master_effects.len(), 1);
        assert!(retirement.take().is_none());
        assert!(!receipt.cancel());
        engine.process_command(AudioCommand::RemoveEffect {
            target: EffectTarget::Master,
            effect_id: EffectId::from(11),
        });
        assert!(engine.plugin_state.master_effects.is_empty());
        assert!(retirement.take().is_some());
    }

    #[test]
    fn cancellation_and_changed_configuration_return_uninstalled_endpoints() {
        let mut engine = engine();
        let (command, receipt, mut retirement) = install(48_000.0);
        assert!(receipt.cancel());
        process_install(&mut engine, command);
        assert_eq!(receipt.status(), HostedInstallStatus::Cancelled);
        assert!(retirement.take().is_some());
        let (command, receipt, mut retirement) = install(44_100.0);
        process_install(&mut engine, command);
        assert_eq!(receipt.status(), HostedInstallStatus::InvalidConfiguration);
        assert!(retirement.take().is_some());
        assert!(engine.plugin_state.master_effects.is_empty());
    }

    #[test]
    fn duplicate_install_keeps_the_existing_instance_and_shutdown_retires_it() {
        let mut engine = engine();
        let (command, receipt, mut original) = install(48_000.0);
        process_install(&mut engine, command);
        assert_eq!(receipt.status(), HostedInstallStatus::Installed);
        let (duplicate, receipt, mut rejected) = install(48_000.0);
        process_install(&mut engine, duplicate);
        assert_eq!(receipt.status(), HostedInstallStatus::OccupiedTarget);
        assert!(rejected.take().is_some());
        assert!(original.take().is_none());
        drop(engine);
        assert!(original.take().is_some());
    }

    #[test]
    fn full_command_queue_retains_endpoint_return_ownership() {
        let (mut sender, _receiver) = rtrb::RingBuffer::new(1);
        assert!(sender.push(AudioCommand::StopAllPreviews).is_ok());
        let (command, receipt, mut retirement) = install(48_000.0);
        let (command, mut control) = karbeat_host::ControlTransfer::new(command);
        let rejected = sender.push(AudioCommand::InstallHostedPlugin(command));
        assert!(rejected.is_err());
        drop(rejected);
        assert!(control.collect());
        assert_eq!(receipt.status(), HostedInstallStatus::Cancelled);
        assert!(retirement.take().is_some());
    }

    #[test]
    fn removal_rejects_stale_handles_and_cancellation_without_partial_changes() {
        use crate::audio::hosted_plugin::{HostedPluginRemoval, HostedRemovalStatus};
        let mut engine = engine();
        let (install, _, mut returned) = install(48_000.0);
        process_install(&mut engine, install);
        let target = PluginTarget::MasterEffect(EffectId::from(11));
        for cancel in [false, true] {
            let (removal, receipt) = HostedPluginRemoval::new(
                vec![(target, Some(HostInstanceId(if cancel { 1 } else { 99 })))],
                None,
            );
            if cancel {
                assert!(receipt.cancel());
            }
            let (command, mut control) = karbeat_host::ControlTransfer::new(removal);
            engine.process_command(AudioCommand::RemoveHostedPlugins(command));
            assert!(control.collect());
            assert_eq!(
                receipt.status(),
                if cancel {
                    HostedRemovalStatus::Cancelled
                } else {
                    HostedRemovalStatus::StaleTarget
                }
            );
            assert_eq!(engine.plugin_state.master_effects.len(), 1);
            assert!(returned.take().is_none());
        }
        let (removal, receipt) =
            HostedPluginRemoval::new(vec![(target, Some(HostInstanceId(1)))], None);
        let (command, mut control) = karbeat_host::ControlTransfer::new(removal);
        engine.process_command(AudioCommand::RemoveHostedPlugins(command));
        assert_eq!(receipt.status(), HostedRemovalStatus::Removed);
        assert!(engine.plugin_state.master_effects.is_empty());
        assert!(
            !engine
                .telemetry
                .param_telemetry_producers
                .contains_key(&target)
        );
        assert!(returned.take().is_some());
        assert!(control.collect());
    }

    #[test]
    fn hosted_telemetry_keeps_parameters_across_all_three_buffers() {
        let mut engine = engine();
        let (command, mut receipt, mut returned) = install(48_000.0);
        let mut output = receipt.take_telemetry().unwrap();
        process_install(&mut engine, command);
        let parameter = engine.plugin_state.master_effects[0]
            .plugin
            .get_parameter_specs()[0]
            .id;
        engine.telemetry.active_telemetry_subscriptions.insert(
            PluginTarget::MasterEffect(EffectId::from(11)),
            Default::default(),
        );
        for value in [0.15, 0.25, 0.35, 0.45, 0.55] {
            engine.plugin_state.master_effects[0]
                .plugin
                .set_parameter(parameter, value);
            for _ in 0..8 {
                engine.process(&mut [0.0_f32; 512][..]);
            }
            let values = &output.read().parameters;
            let actual = values.iter().find(|(id, _)| *id == parameter).unwrap().1;
            assert!((actual - value).abs() < 0.0001);
        }
        drop(engine);
        assert!(returned.take().is_some());
    }

    #[test]
    fn project_replacement_checks_cancellation_and_configuration_before_mutation() {
        use crate::audio::hosted_plugin::HostedProjectInstall;
        let mut engine = engine();
        let (install, _, mut returned) = install(48_000.0);
        process_install(&mut engine, install);
        for (rate, cancel, expected) in [
            (44_100, false, HostedInstallStatus::InvalidConfiguration),
            (48_000, true, HostedInstallStatus::Cancelled),
            (48_000, false, HostedInstallStatus::Installed),
        ] {
            let (project, receipt) = HostedProjectInstall::new(
                vec![AudioCommand::RemoveEffect {
                    target: EffectTarget::Master,
                    effect_id: EffectId::from(11),
                }],
                rate,
            );
            if cancel {
                assert!(receipt.cancel());
            }
            let (command, mut control) = karbeat_host::ControlTransfer::new(project);
            engine.process_command(AudioCommand::InstallHostedProject(command));
            assert!(control.collect());
            assert_eq!(receipt.status(), expected);
            if expected == HostedInstallStatus::Installed {
                assert!(engine.plugin_state.master_effects.is_empty());
                assert!(returned.take().is_some());
            } else {
                assert_eq!(engine.plugin_state.master_effects.len(), 1);
                assert!(returned.take().is_none());
            }
        }
    }

    fn offline(
        snapshot: crate::audio::engine::AudioExportSnapshot,
    ) -> Result<AudioEngine, crate::audio::engine::AudioExportSnapshotError> {
        let (_, commands) = rtrb::RingBuffer::new(8);
        let (position, _) = rtrb::RingBuffer::new(8);
        let (feedback, _) = rtrb::RingBuffer::new(8);
        AudioEngine::from_export_snapshot(
            snapshot,
            &karbeat_plugins::registry::PluginRegistry::new_with_defaults(),
            2,
            commands,
            position,
            feedback,
        )
    }

    #[test]
    fn hosted_export_requires_control_capture_and_restores_an_independent_endpoint() {
        use karbeat_plugin_api::traits::AudioPlugin;
        let mut engine = engine();
        let (command, _, mut live_retirement) = install(48_000.0);
        process_install(&mut engine, command);
        let live = &mut engine.plugin_state.master_effects[0].plugin;
        let parameter = live.get_parameter_specs()[0].id;
        live.set_parameter(parameter, 0.37);
        live.set_bypass(true);
        let state = live.get_state();
        let captured = crate::audio::render_state::EffectPluginSnapshot::from(
            &engine.plugin_state.master_effects[0],
        );
        assert_eq!(captured.host_instance, Some(HostInstanceId(1)));
        assert!(captured.serialized_state.is_empty());
        assert!(matches!(
            offline(engine.export_snapshot()),
            Err(crate::audio::engine::AudioExportSnapshotError::HostedPlugin { .. })
        ));

        let mut snapshot = engine.export_snapshot();
        let mut retirement = None;
        snapshot
            .prepare_hosted(|id| {
                assert_eq!(id, HostInstanceId(1));
                let mut plugin = DigidawDelay::build();
                plugin.set_state(&state);
                plugin.prepare(48_000.0, 512);
                let (prepared, returned) =
                    Box::new(HostedProcessor::new(Box::new(plugin), HostInstanceId(2)))
                        .prepare_transfer()?;
                retirement = Some(returned);
                Ok(prepared)
            })
            .unwrap();
        let mut offline = offline(snapshot).unwrap();
        let plugin = &mut offline.plugin_state.master_effects[0].plugin;
        let hosted = plugin.as_any().downcast_ref::<HostedProcessor>().unwrap();
        assert_eq!(hosted.instance, HostInstanceId(2));
        assert!(hosted.is_bypassed());
        assert!((plugin.get_parameter(parameter) - 0.37).abs() < 0.0001);
        plugin.set_parameter(parameter, 0.81);
        assert!(
            (engine.plugin_state.master_effects[0]
                .plugin
                .get_parameter(parameter)
                - 0.37)
                .abs()
                < 0.0001
        );
        drop(offline);
        assert!(retirement.as_mut().unwrap().take().is_some());
        assert!(live_retirement.take().is_none());
        drop(engine);
        assert!(live_retirement.take().is_some());
    }

    #[test]
    fn failed_export_capture_retires_every_prepared_endpoint() {
        let mut engine = engine();
        let (command, _, mut live_retirement) = install(48_000.0);
        process_install(&mut engine, command);
        let (second, mut second_retirement) = Box::new(HostedProcessor::new(
            Box::new(DigidawDelay::build()),
            HostInstanceId(2),
        ))
        .prepare_transfer()
        .unwrap();
        engine
            .plugin_state
            .master_effects
            .push(AudioEffectInstance {
                id: EffectId::from(12),
                registry_id: 124,
                plugin: second.install().unwrap(),
            });
        let mut snapshot = engine.export_snapshot();
        let mut retired = None;
        let result = snapshot.prepare_hosted(|id| {
            if id == HostInstanceId(2) {
                return Err(karbeat_host::HostError::InvalidState(
                    "capture failed".into(),
                ));
            }
            let (prepared, retirement) = Box::new(HostedProcessor::new(
                Box::new(DigidawDelay::build()),
                HostInstanceId(10),
            ))
            .prepare_transfer()?;
            retired = Some(retirement);
            Ok(prepared)
        });
        assert!(result.is_err());
        assert!(retired.as_mut().unwrap().take().is_some());
        assert!(offline(snapshot).is_err());
        drop(engine);
        assert!(live_retirement.take().is_some());
        assert!(second_retirement.take().is_some());
    }

    #[test]
    fn partial_export_reconstruction_releases_native_ownership_to_the_ui_reaper() {
        let mut engine = engine();
        let (command, _, mut live_retirement) = install(48_000.0);
        process_install(&mut engine, command);
        engine
            .plugin_state
            .master_effects
            .push(AudioEffectInstance {
                id: EffectId::from(12),
                registry_id: u32::MAX,
                plugin: Box::new(DigidawDelay::build()),
            });
        let mut snapshot = engine.export_snapshot();
        let mut retired = None;
        snapshot
            .prepare_hosted(|_| {
                let (prepared, retirement) = Box::new(HostedProcessor::new(
                    Box::new(DigidawDelay::build()),
                    HostInstanceId(10),
                ))
                .prepare_transfer()?;
                retired = Some(retirement);
                Ok(prepared)
            })
            .unwrap();
        assert!(matches!(
            offline(snapshot),
            Err(crate::audio::engine::AudioExportSnapshotError::PluginNotFound { .. })
        ));
        assert!(retired.as_ref().unwrap().is_abandoned());
        drop(engine);
        assert!(live_retirement.take().is_some());
    }

    #[test]
    fn native_processing_failures_remain_visible_until_acknowledged() {
        use std::sync::{
            Arc,
            atomic::{AtomicI32, Ordering},
        };
        let mut engine = engine();
        let status = Arc::new(AtomicI32::new(0));
        let mut endpoint =
            HostedProcessor::new(Box::new(DigidawDelay::build()), HostInstanceId(10));
        endpoint.set_processing_status(status.clone());
        engine
            .plugin_state
            .master_effects
            .push(AudioEffectInstance {
                id: EffectId::from(1),
                registry_id: 123,
                plugin: Box::new(endpoint),
            });
        assert!(engine.validate_hosted_processing().is_ok());
        status.store(-1, Ordering::Release);
        for _ in 0..2 {
            assert!(matches!(
                engine.validate_hosted_processing(),
                Err(
                    crate::audio::engine::AudioExportSnapshotError::HostedPlugin {
                        instance: HostInstanceId(10),
                        source: karbeat_host::HostError::PluginCall { code: -1, .. }
                    }
                )
            ));
        }
        status.store(0, Ordering::Release);
        assert!(engine.validate_hosted_processing().is_ok());
    }
}
