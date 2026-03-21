-- SPDX-License-Identifier: PMPL-1.0-or-later
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
