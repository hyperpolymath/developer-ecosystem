-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-metrics protocol.
-- Metrics types: metric types, dimensional labels.

module Types

||| Metric classification.
public export
data MetricType : Type where
  Counter   : MetricType
  Gauge     : MetricType
  Histogram : MetricType
  Summary   : MetricType

||| Metric definition.
public export
record Metric where
  constructor MkMetric
  name       : String
  metricType : MetricType
  help       : String
  value      : Double
