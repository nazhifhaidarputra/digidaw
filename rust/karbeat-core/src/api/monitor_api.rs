pub use sysinfo::{CpuRefreshKind, MemoryRefreshKind, System};

use crate::audio::engine::get_current_dsp_load;
#[derive(Clone, Debug)]
/// Point-in-time operating-system and audio callback load reported to the UI monitor.
pub struct PerformanceMetrics {
    /// Global operating-system CPU usage percentage.
    pub os_cpu_usage: f32, // 0.0 to 100.0
    /// Used physical memory converted to mebibytes.
    pub ram_usage_mb: f32,
    /// Total physical memory converted to mebibytes.
    pub total_ram_mb: f32,
    /// Audio callback load percentage maintained by the engine.
    pub dsp_headroom: f32, // The "FL Studio" meter (0.0 to 100.0)
}

/// Creates a `sysinfo` monitor configured to refresh CPU and physical-memory counters.
pub fn init_sys() -> System {
    System::new_with_specifics(
        sysinfo::RefreshKind::everything()
            .with_memory(MemoryRefreshKind::everything().without_swap()),
    )
}

/// Refreshes CPU and memory state and combines it with the engine's current DSP load.
pub fn fetch_metrics(sys: &mut System) -> PerformanceMetrics {
    sys.refresh_cpu_specifics(CpuRefreshKind::everything());
    sys.refresh_memory_specifics(MemoryRefreshKind::everything().without_swap());

    PerformanceMetrics {
        os_cpu_usage: sys.global_cpu_usage(),
        ram_usage_mb: (sys.used_memory() as f32) / 1_048_576.0,
        total_ram_mb: (sys.total_memory() as f32) / 1_048_576.0,
        dsp_headroom: get_current_dsp_load(),
    }
}
