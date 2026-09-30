use karbeat_core::core::mitigation::UserDevice;
use sysinfo::{MemoryRefreshKind, RefreshKind, System};

/// CPU and memory figures used to size background work for the current machine.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct DeviceBudget {
    /// Physical CPU cores, or logical CPUs when the OS does not report cores.
    pub physical_cores: usize,
    /// Logical CPUs.
    pub logical_cpus: usize,
    /// Total physical memory in mebibytes.
    pub total_ram_mb: u64,
}

impl DeviceBudget {
    /// Probes the current machine. Reads OS information, so call it outside real-time paths.
    pub fn detect() -> Self {
        let device = UserDevice::detect();
        let logical_cpus = device.logical_cpus.max(1);
        Self {
            physical_cores: device.cpu_cores.unwrap_or(logical_cpus).max(1),
            logical_cpus,
            total_ram_mb: device.total_ram_mb,
        }
    }

    /// Currently available physical memory in mebibytes.
    ///
    /// Re-read before each heavy step: it changes while the app runs.
    pub fn available_ram_mb() -> u64 {
        let system = System::new_with_specifics(
            RefreshKind::nothing().with_memory(MemoryRefreshKind::nothing().with_ram()),
        );
        system.available_memory() / 1_048_576
    }
}

/// Concurrency limits for the job classes that share a semaphore.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct JobLimits {
    /// Renders, exports and imports running at once.
    pub heavy: usize,
    /// Model inference jobs running at once.
    pub inference: usize,
    /// Plugin scans running at once.
    pub io: usize,
}

impl JobLimits {
    /// Leaves at least half of the physical cores free for the audio and UI threads.
    pub fn for_device(budget: &DeviceBudget) -> Self {
        Self {
            heavy: (budget.physical_cores / 2).clamp(1, 3),
            inference: 1,
            io: 1,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{DeviceBudget, JobLimits};

    fn budget(physical_cores: usize) -> DeviceBudget {
        DeviceBudget {
            physical_cores,
            logical_cpus: physical_cores * 2,
            total_ram_mb: 8_192,
        }
    }

    #[test]
    fn heavy_limit_keeps_half_the_cores_and_stays_between_one_and_three() {
        assert_eq!(JobLimits::for_device(&budget(1)).heavy, 1);
        assert_eq!(JobLimits::for_device(&budget(4)).heavy, 2);
        assert_eq!(JobLimits::for_device(&budget(16)).heavy, 3);
    }
}
