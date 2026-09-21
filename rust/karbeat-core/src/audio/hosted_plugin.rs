use karbeat_host::{PreparedProcessor, ProcessingConfig};

use crate::{audio::event::PluginTarget, shared::TrackId};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum HostedInstallResult {
    Installed,
    InvalidConfiguration,
    MissingTarget,
    OccupiedTarget,
}

/// Control-side completion for one committed hosted installation.
pub struct HostedInstallReceipt {
    result: rtrb::Consumer<HostedInstallResult>,
    telemetry: Option<triple_buffer::Output<crate::audio::engine::PluginTelemetrySnapshot>>,
}
impl HostedInstallReceipt {
    pub fn take_telemetry(
        &mut self,
    ) -> Option<triple_buffer::Output<crate::audio::engine::PluginTelemetrySnapshot>> {
        self.telemetry.take()
    }
    /// Awaits the single terminal result published through the lock-free audio feedback path.
    pub async fn wait(&mut self) -> Result<HostedInstallResult, karbeat_host::HostError> {
        loop {
            match self.result.pop() {
                Ok(result) => return Ok(result),
                Err(rtrb::PopError::Empty) if self.result.is_abandoned() => {
                    return Err(karbeat_host::HostError::RuntimeUnavailable);
                }
                Err(rtrb::PopError::Empty) => futures_lite::future::yield_now().await,
            }
        }
    }
}

pub struct HostedPluginInstall {
    pub(crate) target: PluginTarget,
    pub(crate) generator_track: Option<TrackId>,
    pub(crate) registry_id: u32,
    pub(crate) config: ProcessingConfig,
    pub(crate) endpoint: Option<PreparedProcessor>,
    pub(crate) graph: Option<HostedTrackGraph>,
    pub(crate) telemetry:
        Option<triple_buffer::Input<crate::audio::engine::PluginTelemetrySnapshot>>,
    pub(crate) bypass: bool,
    pub(crate) replace_missing: bool,
    result: Option<rtrb::Producer<HostedInstallResult>>,
}
impl HostedPluginInstall {
    /// Construct on a control worker after native preparation and retirement reservation.
    pub fn new(
        target: PluginTarget,
        generator_track: Option<TrackId>,
        registry_id: u32,
        config: ProcessingConfig,
        endpoint: PreparedProcessor,
    ) -> (Self, HostedInstallReceipt) {
        let (result_tx, result) = rtrb::RingBuffer::new(1);
        let (input, output) =
            triple_buffer::triple_buffer(&crate::audio::engine::PluginTelemetrySnapshot {
                parameters: endpoint.parameter_values(),
                ..Default::default()
            });
        let receipt = HostedInstallReceipt {
            result,
            telemetry: Some(output),
        };
        (
            Self {
                target,
                generator_track,
                registry_id,
                config,
                endpoint: Some(endpoint),
                bypass: false,
                replace_missing: false,
                graph: None,
                telemetry: Some(input),
                result: Some(result_tx),
            },
            receipt,
        )
    }

    pub(crate) fn replacing_missing(mut self) -> Self {
        self.replace_missing = true;
        self
    }

    pub fn with_bypass(mut self, bypass: bool) -> Self {
        self.bypass = bypass;
        self
    }

    pub fn with_track_graph(mut self, graph: HostedTrackGraph) -> Self {
        self.graph = Some(graph);
        self
    }

    pub(crate) fn complete(&mut self, result: HostedInstallResult) {
        if let Some(mut sender) = self.result.take() {
            let published = sender.push(result);
            debug_assert!(published.is_ok());
        }
    }
}

/// Track publication prepared alongside an external instrument, before DSP can accept either.
pub struct HostedTrackGraph {
    pub(crate) tracks: Box<[crate::core::project::AudioTrack]>,
    pub(crate) clips: hashbrown::HashMap<crate::shared::ClipId, crate::core::project::Clip>,
    pub(crate) patterns:
        hashbrown::HashMap<crate::shared::PatternId, crate::core::project::Pattern>,
    pub(crate) routing: Box<[crate::core::project::RoutingConnection]>,
}

impl From<&crate::core::project::ApplicationState> for HostedTrackGraph {
    fn from(app: &crate::core::project::ApplicationState) -> Self {
        let mut tracks: Vec<_> = app.tracks.values().cloned().collect();
        tracks.sort_by_key(|track| track.id);
        Self {
            tracks: tracks.into_boxed_slice(),
            clips: app
                .clips_pool
                .iter()
                .map(|(id, clip)| (id, clip.clone()))
                .collect(),
            patterns: app
                .pattern_pool
                .iter()
                .map(|(id, pattern)| (id, pattern.clone()))
                .collect(),
            routing: app.mixer.routing.clone().into_boxed_slice(),
        }
    }
}
pub struct HostedPluginReplacement {
    pub(crate) target: PluginTarget,
    pub(crate) expected: karbeat_host::HostInstanceId,
    pub(crate) config: ProcessingConfig,
    pub(crate) endpoint: Option<PreparedProcessor>,
    pub(crate) bypass: bool,
}

impl HostedPluginReplacement {
    pub fn new(
        target: PluginTarget,
        expected: karbeat_host::HostInstanceId,
        config: ProcessingConfig,
        endpoint: PreparedProcessor,
        bypass: bool,
    ) -> Self {
        Self {
            target,
            expected,
            config,
            endpoint: Some(endpoint),
            bypass,
        }
    }
}

pub struct HostedPluginReconfiguration {
    pub(crate) replacements: Box<[HostedPluginReplacement]>,
    pub(crate) sample_rate: u32,
    pub(crate) block_size: usize,
    result: Option<rtrb::Producer<HostedInstallResult>>,
}

impl HostedPluginReconfiguration {
    pub fn new(
        replacements: Vec<HostedPluginReplacement>,
        sample_rate: u32,
        block_size: usize,
    ) -> (Self, HostedInstallReceipt) {
        let (result_tx, result) = rtrb::RingBuffer::new(1);
        let receipt = HostedInstallReceipt {
            result,
            telemetry: None,
        };
        (
            Self {
                replacements: replacements.into_boxed_slice(),
                sample_rate,
                block_size,
                result: Some(result_tx),
            },
            receipt,
        )
    }

    pub(crate) fn complete(&mut self, result: HostedInstallResult) {
        if let Some(mut sender) = self.result.take() {
            let published = sender.push(result);
            debug_assert!(published.is_ok());
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum HostedRemovalResult {
    Removed,
    StaleTarget,
}

pub struct HostedRemovalReceipt(rtrb::Consumer<HostedRemovalResult>);
impl HostedRemovalReceipt {
    /// Awaits the single terminal removal result from the audio engine.
    pub async fn wait(&mut self) -> Result<HostedRemovalResult, karbeat_host::HostError> {
        loop {
            match self.0.pop() {
                Ok(result) => return Ok(result),
                Err(rtrb::PopError::Empty) if self.0.is_abandoned() => {
                    return Err(karbeat_host::HostError::RuntimeUnavailable);
                }
                Err(rtrb::PopError::Empty) => futures_lite::future::yield_now().await,
            }
        }
    }
}

/// All targets are validated before any processor or graph is removed.
pub struct HostedPluginRemoval {
    pub(crate) bus: Option<crate::shared::BusId>,
    pub(crate) targets: Box<[(PluginTarget, Option<karbeat_host::HostInstanceId>)]>,
    pub(crate) graph: Option<HostedTrackGraph>,
    pub(crate) telemetry: Vec<triple_buffer::Input<crate::audio::engine::PluginTelemetrySnapshot>>,
    result: Option<rtrb::Producer<HostedRemovalResult>>,
}
impl HostedPluginRemoval {
    pub fn new(
        targets: Vec<(PluginTarget, Option<karbeat_host::HostInstanceId>)>,
        graph: Option<HostedTrackGraph>,
    ) -> (Self, HostedRemovalReceipt) {
        let (result_tx, result) = rtrb::RingBuffer::new(1);
        let receipt = HostedRemovalReceipt(result);
        let telemetry = Vec::with_capacity(targets.len());
        (
            Self {
                bus: None,
                targets: targets.into_boxed_slice(),
                graph,
                telemetry,
                result: Some(result_tx),
            },
            receipt,
        )
    }

    pub(crate) fn with_bus(mut self, bus: Option<crate::shared::BusId>) -> Self {
        self.bus = bus;
        self
    }

    pub(crate) fn complete(&mut self, result: HostedRemovalResult) {
        if let Some(mut sender) = self.result.take() {
            let published = sender.push(result);
            debug_assert!(published.is_ok());
        }
    }
}

/// Project replacement is accepted as one command after every native instance is prepared.
pub struct HostedProjectInstall {
    pub(crate) commands: Vec<Option<crate::commands::AudioCommand>>,
    pub(crate) sample_rate: u32,
    result: Option<rtrb::Producer<HostedInstallResult>>,
}
impl HostedProjectInstall {
    pub fn new(
        commands: Vec<crate::commands::AudioCommand>,
        sample_rate: u32,
    ) -> (Self, HostedInstallReceipt) {
        let (result_tx, result) = rtrb::RingBuffer::new(1);
        let receipt = HostedInstallReceipt {
            result,
            telemetry: None,
        };
        (
            Self {
                commands: commands.into_iter().map(Some).collect(),
                sample_rate,
                result: Some(result_tx),
            },
            receipt,
        )
    }
    pub(crate) fn complete(&mut self, result: HostedInstallResult) {
        if let Some(mut sender) = self.result.take() {
            let published = sender.push(result);
            debug_assert!(published.is_ok());
        }
    }
}
