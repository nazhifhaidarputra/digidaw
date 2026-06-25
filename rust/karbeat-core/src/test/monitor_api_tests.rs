//! Tests for `api::monitor_api`

#[cfg(test)]
mod tests {
    use crate::api::monitor_api;

    #[test]
    fn init_sys_returns_system_object() {
        // Should construct without panicking
        let _sys = monitor_api::init_sys();
    }

    #[test]
    fn fetch_metrics_fields_in_valid_range() {
        let mut sys = monitor_api::init_sys();
        let metrics = monitor_api::fetch_metrics(&mut sys);

        assert!(
            metrics.os_cpu_usage >= 0.0 && metrics.os_cpu_usage <= 100.0,
            "CPU usage should be 0–100, got {}",
            metrics.os_cpu_usage
        );
        assert!(
            metrics.ram_usage_mb >= 0.0,
            "RAM usage should be non-negative, got {}",
            metrics.ram_usage_mb
        );
        assert!(
            metrics.total_ram_mb > 0.0,
            "Total RAM should be positive, got {}",
            metrics.total_ram_mb
        );
        assert!(
            metrics.ram_usage_mb <= metrics.total_ram_mb,
            "Used RAM {} should not exceed total RAM {}",
            metrics.ram_usage_mb,
            metrics.total_ram_mb
        );
        assert!(
            metrics.dsp_headroom >= 0.0,
            "DSP headroom should be non-negative"
        );
    }
}
