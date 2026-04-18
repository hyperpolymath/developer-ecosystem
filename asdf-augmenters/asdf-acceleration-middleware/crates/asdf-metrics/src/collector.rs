//! Metrics collector

use serde::{Deserialize, Serialize};
use std::time::{Duration, Instant};
use sysinfo::System;

/// Metrics data
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Metrics {
    /// Total number of operations
    pub operations_total: usize,

    /// Number of succeeded operations
    pub operations_succeeded: usize,

    /// Number of failed operations
    pub operations_failed: usize,

    /// Total duration
    pub total_duration: Duration,

    /// Average duration per operation
    pub average_duration: Duration,
}

impl Default for Metrics {
    fn default() -> Self {
        Self {
            operations_total: 0,
            operations_succeeded: 0,
            operations_failed: 0,
            total_duration: Duration::ZERO,
            average_duration: Duration::ZERO,
        }
    }
}

impl Metrics {
    /// Calculate success rate as percentage
    pub fn success_rate(&self) -> f64 {
        if self.operations_total == 0 {
            0.0
        } else {
            (self.operations_succeeded as f64 / self.operations_total as f64) * 100.0
        }
    }

    /// Calculate failure rate as percentage
    pub fn failure_rate(&self) -> f64 {
        100.0 - self.success_rate()
    }
}

/// Metrics collector
pub struct MetricsCollector {
    metrics: Metrics,
    start_time: Option<Instant>,
}

impl MetricsCollector {
    /// Create a new metrics collector
    pub fn new() -> Self {
        Self {
            metrics: Metrics::default(),
            start_time: None,
        }
    }

    /// Start timing
    pub fn start(&mut self) {
        self.start_time = Some(Instant::now());
    }

    /// Record a successful operation
    pub fn record_success(&mut self) {
        self.metrics.operations_total += 1;
        self.metrics.operations_succeeded += 1;
        self.update_timing();
    }

    /// Record a failed operation
    pub fn record_failure(&mut self) {
        self.metrics.operations_total += 1;
        self.metrics.operations_failed += 1;
        self.update_timing();
    }

    /// Update timing metrics
    fn update_timing(&mut self) {
        if let Some(start) = self.start_time {
            let elapsed = start.elapsed();
            self.metrics.total_duration += elapsed;

            if self.metrics.operations_total > 0 {
                self.metrics.average_duration =
                    self.metrics.total_duration / self.metrics.operations_total as u32;
            }

            self.start_time = Some(Instant::now()); // Reset for next operation
        }
    }

    /// Get current metrics
    pub fn metrics(&self) -> &Metrics {
        &self.metrics
    }

    /// Get system information
    pub fn system_info() -> SystemInfo {
        let mut sys = System::new_all();
        sys.refresh_all();

        SystemInfo {
            cpu_count: sys.cpus().len(),
            total_memory_kb: sys.total_memory(),
            used_memory_kb: sys.used_memory(),
            total_swap_kb: sys.total_swap(),
            used_swap_kb: sys.used_swap(),
        }
    }
}

impl Default for MetricsCollector {
    fn default() -> Self {
        Self::new()
    }
}

/// System information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemInfo {
    /// Number of CPU cores
    pub cpu_count: usize,

    /// Total memory in KB
    pub total_memory_kb: u64,

    /// Used memory in KB
    pub used_memory_kb: u64,

    /// Total swap in KB
    pub total_swap_kb: u64,

    /// Used swap in KB
    pub used_swap_kb: u64,
}

impl SystemInfo {
    /// Get memory usage percentage
    pub fn memory_usage_percent(&self) -> f64 {
        if self.total_memory_kb == 0 {
            0.0
        } else {
            (self.used_memory_kb as f64 / self.total_memory_kb as f64) * 100.0
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_metrics_collector() {
        let mut collector = MetricsCollector::new();
        collector.start();

        collector.record_success();
        collector.record_success();
        collector.record_failure();

        let metrics = collector.metrics();
        assert_eq!(metrics.operations_total, 3);
        assert_eq!(metrics.operations_succeeded, 2);
        assert_eq!(metrics.operations_failed, 1);
    }

    #[test]
    fn test_success_rate() {
        let metrics = Metrics {
            operations_total: 10,
            operations_succeeded: 8,
            operations_failed: 2,
            total_duration: Duration::ZERO,
            average_duration: Duration::ZERO,
        };

        assert_eq!(metrics.success_rate(), 80.0);
        assert_eq!(metrics.failure_rate(), 20.0);
    }

    #[test]
    fn test_system_info() {
        let info = MetricsCollector::system_info();
        assert!(info.cpu_count > 0);
    }
}
