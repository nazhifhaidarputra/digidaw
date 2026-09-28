use serde::{Deserialize, Serialize};
use sysinfo::{CpuRefreshKind, MemoryRefreshKind, RefreshKind, System};

/// Describes the machine a crash happened on: CPU, RAM, OS, and architecture.
///
/// GPU information is not collected yet because `sysinfo` does not report it; `gpu` stays `None`
/// until a platform-specific probe is added.
#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq)]
pub struct UserDevice {
    /// Operating system name, such as "Fedora Linux" or "Windows".
    pub os_name: Option<String>,
    /// Operating system version.
    pub os_version: Option<String>,
    /// Kernel version.
    pub kernel_version: Option<String>,
    /// CPU architecture reported by the operating system.
    pub arch: String,
    /// Marketing name of the first CPU.
    pub cpu_brand: Option<String>,
    /// Physical CPU core count.
    pub cpu_cores: Option<usize>,
    /// Logical CPU count.
    pub logical_cpus: usize,
    /// Total physical memory in mebibytes.
    pub total_ram_mb: u64,
    /// GPU description; not collected yet.
    pub gpu: Option<String>,
}

impl UserDevice {
    /// Probes the current machine. Call outside real-time paths; this reads OS information.
    pub fn detect() -> Self {
        let system = System::new_with_specifics(
            RefreshKind::nothing()
                .with_cpu(CpuRefreshKind::nothing())
                .with_memory(MemoryRefreshKind::nothing().with_ram()),
        );
        let cpu_brand = system
            .cpus()
            .first()
            .map(|cpu| cpu.brand().trim().to_owned())
            .filter(|brand| !brand.is_empty());

        Self {
            os_name: System::name(),
            os_version: System::os_version(),
            kernel_version: System::kernel_version(),
            arch: System::cpu_arch(),
            cpu_brand,
            cpu_cores: System::physical_core_count(),
            logical_cpus: system.cpus().len(),
            total_ram_mb: system.total_memory() / 1_048_576,
            gpu: None,
        }
    }
}
