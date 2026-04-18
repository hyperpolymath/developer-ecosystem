//! Metrics and monitoring for asdf operations

pub mod collector;
pub mod error;
pub mod reporter;

pub use collector::{Metrics, MetricsCollector, SystemInfo};
pub use error::{Error, Result};
pub use reporter::MetricsReporter;

/// Export metrics in Prometheus format
pub fn export_prometheus(metrics: &Metrics) -> Result<String> {
    // This is a simplified version - in production you'd register
    // the metrics with the global registry
    let output = format!(
        "# asdf_operations_total {}\n# asdf_operation_duration_seconds {}\n",
        metrics.operations_total, metrics.total_duration.as_secs_f64()
    );

    Ok(output)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_export_prometheus() {
        let metrics = Metrics {
            operations_total: 10,
            operations_succeeded: 8,
            operations_failed: 2,
            total_duration: Duration::from_secs(100),
            average_duration: Duration::from_secs(10),
        };

        let output = export_prometheus(&metrics).unwrap();
        assert!(output.contains("10"));
    }
}
