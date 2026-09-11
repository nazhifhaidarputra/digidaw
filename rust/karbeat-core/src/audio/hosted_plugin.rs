use std::sync::{
    Arc,
    atomic::{AtomicU8, Ordering},
};

use karbeat_host::{PreparedProcessor, ProcessingConfig};

use crate::{audio::event::PluginTarget, shared::TrackId};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum HostedInstallStatus {
    Pending,
    Applying,
    Installed,
    Cancelled,
    InvalidConfiguration,
    MissingTarget,
    OccupiedTarget,
}

/// Acknowledgement remains outside the telemetry channel and never blocks processing.
pub struct HostedInstallReceipt {
    status: Arc<AtomicU8>,
    telemetry: Option<triple_buffer::Output<crate::audio::engine::PluginTelemetrySnapshot>>,
}
impl HostedInstallReceipt {
    pub fn take_telemetry(
        &mut self,
    ) -> Option<triple_buffer::Output<crate::audio::engine::PluginTelemetrySnapshot>> {
        self.telemetry.take()
    }
    pub fn status(&self) -> HostedInstallStatus {
        match self.status.load(Ordering::Acquire) {
            0 => HostedInstallStatus::Pending,
            1 => HostedInstallStatus::Applying,
            2 => HostedInstallStatus::Installed,
            3 => HostedInstallStatus::Cancelled,
            4 => HostedInstallStatus::InvalidConfiguration,
            5 => HostedInstallStatus::MissingTarget,
            _ => HostedInstallStatus::OccupiedTarget,
        }
    }

    /// A successful cancellation guarantees the engine will not install this endpoint.
    pub fn cancel(&self) -> bool {
        self.status
            .compare_exchange(
                HostedInstallStatus::Pending as u8,
                HostedInstallStatus::Cancelled as u8,
                Ordering::AcqRel,
                Ordering::Acquire,
            )
            .is_ok()
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
    status: Arc<AtomicU8>,
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
        let status = Arc::new(AtomicU8::new(HostedInstallStatus::Pending as u8));
        let (input, output) =
            triple_buffer::triple_buffer(&crate::audio::engine::PluginTelemetrySnapshot {
                parameters: endpoint.parameter_values(),
                ..Default::default()
            });
        let receipt = HostedInstallReceipt {
            status: status.clone(),
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
                status,
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

    pub(crate) fn begin(&self) -> bool {
        self.status
            .compare_exchange(
                HostedInstallStatus::Pending as u8,
                HostedInstallStatus::Applying as u8,
                Ordering::AcqRel,
                Ordering::Acquire,
            )
            .is_ok()
    }

    pub(crate) fn complete(&self, status: HostedInstallStatus) {
        self.status.store(status as u8, Ordering::Release);
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
impl Drop for HostedPluginInstall {
    fn drop(&mut self) {
        let _ = self.status.compare_exchange(
            HostedInstallStatus::Pending as u8,
            HostedInstallStatus::Cancelled as u8,
            Ordering::AcqRel,
            Ordering::Acquire,
        );
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum HostedRemovalStatus {
    Pending,
    Applying,
    Removed,
    Cancelled,
    StaleTarget,
}

pub struct HostedRemovalReceipt(Arc<AtomicU8>);
impl HostedRemovalReceipt {
    pub fn status(&self) -> HostedRemovalStatus {
        match self.0.load(Ordering::Acquire) {
            0 => HostedRemovalStatus::Pending,
            1 => HostedRemovalStatus::Applying,
            2 => HostedRemovalStatus::Removed,
            3 => HostedRemovalStatus::Cancelled,
            _ => HostedRemovalStatus::StaleTarget,
        }
    }

    pub fn cancel(&self) -> bool {
        self.0
            .compare_exchange(0, 3, Ordering::AcqRel, Ordering::Acquire)
            .is_ok()
    }
}

/// All targets are validated before any processor or graph is removed.
pub struct HostedPluginRemoval {
    pub(crate) bus: Option<crate::shared::BusId>,
    pub(crate) targets: Box<[(PluginTarget, Option<karbeat_host::HostInstanceId>)]>,
    pub(crate) graph: Option<HostedTrackGraph>,
    pub(crate) telemetry: Vec<triple_buffer::Input<crate::audio::engine::PluginTelemetrySnapshot>>,
    status: Arc<AtomicU8>,
}
impl HostedPluginRemoval {
    pub fn new(
        targets: Vec<(PluginTarget, Option<karbeat_host::HostInstanceId>)>,
        graph: Option<HostedTrackGraph>,
    ) -> (Self, HostedRemovalReceipt) {
        let status = Arc::new(AtomicU8::new(0));
        let receipt = HostedRemovalReceipt(status.clone());
        let telemetry = Vec::with_capacity(targets.len());
        (
            Self {
                bus: None,
                targets: targets.into_boxed_slice(),
                graph,
                telemetry,
                status,
            },
            receipt,
        )
    }

    pub(crate) fn with_bus(mut self, bus: Option<crate::shared::BusId>) -> Self {
        self.bus = bus;
        self
    }

    pub(crate) fn begin(&self) -> bool {
        self.status
            .compare_exchange(0, 1, Ordering::AcqRel, Ordering::Acquire)
            .is_ok()
    }

    pub(crate) fn complete(&self, status: HostedRemovalStatus) {
        self.status.store(status as u8, Ordering::Release);
    }
}
impl Drop for HostedPluginRemoval {
    fn drop(&mut self) {
        let _ = self
            .status
            .compare_exchange(0, 3, Ordering::AcqRel, Ordering::Acquire);
    }
}

/// Project replacement is accepted as one command after every native instance is prepared.
pub struct HostedProjectInstall {
    pub(crate) commands: Vec<Option<crate::commands::AudioCommand>>,
    pub(crate) sample_rate: u32,
    status: Arc<AtomicU8>,
}
impl HostedProjectInstall {
    pub fn new(
        commands: Vec<crate::commands::AudioCommand>,
        sample_rate: u32,
    ) -> (Self, HostedInstallReceipt) {
        let status = Arc::new(AtomicU8::new(0));
        let receipt = HostedInstallReceipt {
            status: status.clone(),
            telemetry: None,
        };
        (
            Self {
                commands: commands.into_iter().map(Some).collect(),
                sample_rate,
                status,
            },
            receipt,
        )
    }
    pub(crate) fn begin(&self) -> bool {
        self.status
            .compare_exchange(0, 1, Ordering::AcqRel, Ordering::Acquire)
            .is_ok()
    }
    pub(crate) fn complete(&self, status: HostedInstallStatus) {
        self.status.store(status as u8, Ordering::Release);
    }
}
impl Drop for HostedProjectInstall {
    fn drop(&mut self) {
        let _ = self
            .status
            .compare_exchange(0, 3, Ordering::AcqRel, Ordering::Acquire);
    }
}
