use std::sync::{Arc, mpsc::Receiver};

use arc_swap::{ArcSwap, ArcSwapOption};
use hashbrown::HashMap;
use parking_lot::Mutex;
use triple_buffer::Output;

use crate::{
    commands::TelemetryRegistration,
    engine::{MixerTelemetrySnapshot, PluginTelemetrySnapshot},
    event::PluginTarget,
};

/// Legacy direct response payload emitted by audio-engine command execution.
pub enum AudioEngineResponse {
    /// Structured response returned by a plugin-defined command.
    PluginCommandResponse {
        /// Correlation identifier supplied with the request.
        request_id: u32,
        /// Plugin-defined JSON response.
        response: serde_json::Value,
    },
}

/// Owned contiguous floating-point telemetry buffer transferred to consumers.
pub type TelemetryBlob = Box<[f32]>;

/// One plugin's telemetry consumer. `Output::read` needs `&mut`, so each consumer has its own
/// leaf lock; only telemetry readers of that one plugin ever contend on it.
type PluginConsumer = Arc<Mutex<Output<PluginTelemetrySnapshot>>>;

/// Plugin consumers by target. Replaced as a whole on every change, so readers never lock it.
type PluginConsumers = HashMap<PluginTarget, PluginConsumer>;

/// Read side of the telemetry triple buffers, shared outside the core context.
///
/// Telemetry is polled by synchronous FFI calls on the UI thread every frame. Reading it must
/// therefore never wait for the core lock, which project operations can hold for a long time.
/// The hub is created with the context and never replaced, so a session clones the `Arc` once
/// and reads it without the core lock.
///
/// Locks: every lock here is a leaf, held only to update and clone one snapshot or to apply
/// pending registrations. None of them is ever held while taking the core lock, and the audio
/// thread takes none of them.
#[derive(Default)]
pub struct TelemetryHub {
    /// Consumers of the running engine. Swapped when the engine starts or restarts.
    channels: ArcSwapOption<TelemetryChannels>,
}

/// Consumers belonging to one engine instance.
struct TelemetryChannels {
    /// Consumer for the full mixer snapshot.
    mixer: Mutex<Output<MixerTelemetrySnapshot>>,
    /// Per-plugin parameter telemetry consumers, copied on write.
    plugins: ArcSwap<PluginConsumers>,
    /// Consumers the audio thread hands over as plugins are added or removed.
    registrations: Mutex<Receiver<TelemetryRegistration>>,
}

impl TelemetryChannels {
    /// Applies every pending registration. The receiver stays locked until the map changes are
    /// published, so once a blocking drain returns, everything sent before it is visible.
    fn apply_registrations(&self, receiver: &Receiver<TelemetryRegistration>) {
        while let Ok(registration) = receiver.try_recv() {
            match registration {
                TelemetryRegistration::Registered { target, consumer } => {
                    self.insert(target, Arc::new(Mutex::new(*consumer)));
                }
                TelemetryRegistration::Removed { target } => {
                    self.remove(&[target]);
                }
                TelemetryRegistration::BatchRegistered { consumers } => {
                    let consumers = consumers
                        .into_iter()
                        .map(|(target, consumer)| (target, Arc::new(Mutex::new(*consumer))))
                        .collect();
                    self.plugins.store(Arc::new(consumers));
                }
            }
        }
    }

    fn insert(&self, target: PluginTarget, consumer: PluginConsumer) {
        self.plugins.rcu(|current| {
            let mut next = PluginConsumers::clone(current);
            next.insert(target, Arc::clone(&consumer));
            next
        });
    }

    fn remove(&self, targets: &[PluginTarget]) {
        self.plugins.rcu(|current| {
            let mut next = PluginConsumers::clone(current);
            for target in targets {
                next.remove(target);
            }
            next
        });
    }

    /// Applies pending registrations unless another reader is already applying them; that
    /// reader publishes them, so this frame reads at most one registration batch late.
    fn try_drain(&self) {
        if let Some(receiver) = self.registrations.try_lock() {
            self.apply_registrations(&receiver);
        }
    }
}

impl TelemetryHub {
    /// Creates a hub with no engine attached.
    pub fn new() -> Self {
        Self::default()
    }

    /// Attaches the consumers of a newly started engine, replacing those of any previous one.
    pub fn attach(
        &self,
        mixer: Output<MixerTelemetrySnapshot>,
        registrations: Receiver<TelemetryRegistration>,
    ) {
        self.channels.store(Some(Arc::new(TelemetryChannels {
            mixer: Mutex::new(mixer),
            plugins: ArcSwap::from_pointee(PluginConsumers::new()),
            registrations: Mutex::new(registrations),
        })));
    }

    /// Whether an engine's consumers are attached.
    pub fn is_attached(&self) -> bool {
        self.channels.load().is_some()
    }

    /// Latest mixer snapshot, or an empty one when no engine is attached.
    ///
    /// Pending plugin registrations are applied first, so plugin consumers are current when a
    /// plugin screen reads next.
    pub fn mixer_snapshot(&self) -> MixerTelemetrySnapshot {
        let Some(channels) = self.channels.load_full() else {
            return MixerTelemetrySnapshot::default();
        };
        channels.try_drain();
        let mut mixer = channels.mixer.lock();
        mixer.update();
        mixer.read().clone()
    }

    /// Latest snapshot of one plugin, or `None` when it has no consumer yet.
    pub fn plugin_snapshot(&self, target: PluginTarget) -> Option<PluginTelemetrySnapshot> {
        let channels = self.channels.load_full()?;
        channels.try_drain();
        let consumer = channels.plugins.load().get(&target).map(Arc::clone)?;
        let mut consumer = consumer.lock();
        consumer.update();
        Some(consumer.read().clone())
    }

    /// Registers or replaces the consumer for a plugin target.
    pub fn insert_plugin_consumer(
        &self,
        target: PluginTarget,
        consumer: Output<PluginTelemetrySnapshot>,
    ) {
        if let Some(channels) = self.channels.load_full() {
            channels.insert(target, Arc::new(Mutex::new(consumer)));
        }
    }

    /// Drops the consumers of removed plugin targets.
    pub fn remove_plugin_consumers(&self, targets: &[PluginTarget]) {
        if let Some(channels) = self.channels.load_full() {
            channels.remove(targets);
        }
    }

    /// Applies every registration the audio thread sent so far, waiting for a reader that is
    /// applying them concurrently. Call it before inserting consumers that a pending
    /// `BatchRegistered` would otherwise wipe out.
    pub fn drain_registrations(&self) {
        if let Some(channels) = self.channels.load_full() {
            let receiver = channels.registrations.lock();
            channels.apply_registrations(&receiver);
        }
    }
}

#[cfg(test)]
mod tests {
    use std::sync::mpsc::sync_channel;

    use hashbrown::HashMap;
    use karbeat_core::shared::EffectId;
    use triple_buffer::{Input, triple_buffer};

    use super::TelemetryHub;
    use crate::{
        commands::TelemetryRegistration,
        engine::{MixerTelemetrySnapshot, PluginTelemetrySnapshot},
        event::PluginTarget,
    };

    fn plugin(
        value: f32,
    ) -> (
        Input<PluginTelemetrySnapshot>,
        Box<triple_buffer::Output<PluginTelemetrySnapshot>>,
    ) {
        let (mut input, output) = triple_buffer(&PluginTelemetrySnapshot::default());
        input.write(PluginTelemetrySnapshot {
            parameters: vec![(0, value)],
            buffers: HashMap::new(),
        });
        (input, Box::new(output))
    }

    fn parameter(hub: &TelemetryHub, target: PluginTarget) -> Option<f32> {
        hub.plugin_snapshot(target)
            .map(|snapshot| snapshot.parameters[0].1)
    }

    #[test]
    fn reads_are_empty_until_an_engine_attaches() {
        let hub = TelemetryHub::new();
        let target = PluginTarget::MasterEffect(EffectId::from(1));
        assert!(!hub.is_attached());
        assert!(hub.mixer_snapshot().master.is_none());
        assert!(hub.plugin_snapshot(target).is_none());
        // Without an engine there is nothing to register into.
        hub.insert_plugin_consumer(target, *plugin(1.0).1);
        assert!(hub.plugin_snapshot(target).is_none());
    }

    #[test]
    fn registrations_from_the_audio_thread_are_applied_on_read() {
        let hub = TelemetryHub::new();
        let (sender, receiver) = sync_channel(8);
        let (_mixer_input, mixer) = triple_buffer(&MixerTelemetrySnapshot::default());
        hub.attach(mixer, receiver);
        let first = PluginTarget::MasterEffect(EffectId::from(1));
        let second = PluginTarget::MasterEffect(EffectId::from(2));

        let (_first_input, consumer) = plugin(0.25);
        sender
            .send(TelemetryRegistration::Registered {
                target: first,
                consumer,
            })
            .unwrap();
        assert_eq!(parameter(&hub, first), Some(0.25));

        // A batch replaces every consumer, including ones registered one by one.
        let (_second_input, consumer) = plugin(0.5);
        sender
            .send(TelemetryRegistration::BatchRegistered {
                consumers: HashMap::from([(second, consumer)]),
            })
            .unwrap();
        hub.drain_registrations();
        assert_eq!(parameter(&hub, first), None);
        assert_eq!(parameter(&hub, second), Some(0.5));

        sender
            .send(TelemetryRegistration::Removed { target: second })
            .unwrap();
        assert!(hub.mixer_snapshot().master.is_none());
        assert_eq!(parameter(&hub, second), None);
    }

    #[test]
    fn consumers_inserted_after_a_drain_survive_the_batch() {
        let hub = TelemetryHub::new();
        let (sender, receiver) = sync_channel(8);
        let (_mixer_input, mixer) = triple_buffer(&MixerTelemetrySnapshot::default());
        hub.attach(mixer, receiver);
        let built_in = PluginTarget::MasterEffect(EffectId::from(1));
        let hosted = PluginTarget::MasterEffect(EffectId::from(2));

        let (_built_in_input, consumer) = plugin(0.25);
        sender
            .send(TelemetryRegistration::BatchRegistered {
                consumers: HashMap::from([(built_in, consumer)]),
            })
            .unwrap();
        hub.drain_registrations();
        let (_hosted_input, consumer) = plugin(0.75);
        hub.insert_plugin_consumer(hosted, *consumer);

        assert_eq!(parameter(&hub, built_in), Some(0.25));
        assert_eq!(parameter(&hub, hosted), Some(0.75));
        hub.remove_plugin_consumers(&[built_in, hosted]);
        assert_eq!(parameter(&hub, built_in), None);
        assert_eq!(parameter(&hub, hosted), None);
    }

    #[test]
    fn attaching_a_new_engine_drops_the_old_consumers() {
        let hub = TelemetryHub::new();
        let (_old_sender, receiver) = sync_channel(8);
        let (_mixer_input, mixer) = triple_buffer(&MixerTelemetrySnapshot::default());
        hub.attach(mixer, receiver);
        let target = PluginTarget::MasterEffect(EffectId::from(1));
        let (_input, consumer) = plugin(0.25);
        hub.insert_plugin_consumer(target, *consumer);

        let (_new_sender, receiver) = sync_channel(8);
        let (_mixer_input, mixer) = triple_buffer(&MixerTelemetrySnapshot::default());
        hub.attach(mixer, receiver);
        assert_eq!(parameter(&hub, target), None);
    }
}
