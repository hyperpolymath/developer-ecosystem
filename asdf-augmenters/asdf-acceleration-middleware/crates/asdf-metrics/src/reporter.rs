//! Metrics reporter

use crate::{Metrics, SystemInfo};
use crate::error::Result;

/// Metrics reporter
pub struct MetricsReporter;

impl MetricsReporter {
    /// Generate a human-readable report
    pub fn format_report(metrics: &Metrics, system_info: &SystemInfo) -> String {
        format!(
            r#"
📊 Performance Metrics
═══════════════════════

Operations:
  Total:     {}
  Succeeded: {} ({}%)
  Failed:    {} ({}%)

Timing:
  Total:     {:.2}s
  Average:   {:.2}s

System:
  CPUs:      {}
  Memory:    {:.1}% ({} MB / {} MB)

"#,
            metrics.operations_total,
            metrics.operations_succeeded,
            metrics.success_rate(),
            metrics.operations_failed,
            metrics.failure_rate(),
            metrics.total_duration.as_secs_f64(),
            metrics.average_duration.as_secs_f64(),
            system_info.cpu_count,
            system_info.memory_usage_percent(),
            system_info.used_memory_kb / 1024,
            system_info.total_memory_kb / 1024,
        )
    }

    /// Generate a colored console report
    pub fn format_colored_report(metrics: &Metrics, system_info: &SystemInfo) -> String {
        // Simplified version without color formatting
        Self::format_report(metrics, system_info)
    }

    /// Export as JSON
    pub fn to_json(metrics: &Metrics, system_info: &SystemInfo) -> Result<String> {
        let data = serde_json::json!({
            "metrics": metrics,
            "system": system_info,
        });

        serde_json::to_string_pretty(&data).map_err(|e| e.into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    #[test]
    fn test_format_report() {
        let metrics = Metrics {
            operations_total: 10,
            operations_succeeded: 8,
            operations_failed: 2,
            total_duration: Duration::from_secs(100),
            average_duration: Duration::from_secs(10),
        };

        let system_info = SystemInfo {
            cpu_count: 8,
            total_memory_kb: 16_000_000,
            used_memory_kb: 8_000_000,
            total_swap_kb: 4_000_000,
            used_swap_kb: 1_000_000,
        };

        let report = MetricsReporter::format_report(&metrics, &system_info);
        assert!(report.contains("10"));
        assert!(report.contains("8"));
    }

    #[test]
    fn test_to_json() {
        let metrics = Metrics::default();
        let system_info = SystemInfo {
            cpu_count: 4,
            total_memory_kb: 8_000_000,
            used_memory_kb: 4_000_000,
            total_swap_kb: 2_000_000,
            used_swap_kb: 500_000,
        };

        let json = MetricsReporter::to_json(&metrics, &system_info).unwrap();
        assert!(json.contains("metrics"));
        assert!(json.contains("system"));
    }
}
