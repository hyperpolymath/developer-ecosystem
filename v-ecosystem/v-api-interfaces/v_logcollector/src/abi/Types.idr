-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-logcollector protocol.
-- Log collector types: formats, severities, sources.

module Types

||| Log encoding format.
public export
data LogFormat : Type where
  JSON           : LogFormat
  SyslogRFC5424  : LogFormat
  SyslogRFC3164  : LogFormat
  CEF            : LogFormat
  Plain          : LogFormat

||| Syslog severity.
public export
data LogSeverity : Type where
  Emergency : LogSeverity
  Alert     : LogSeverity
  Critical  : LogSeverity
  Err       : LogSeverity
  Warning   : LogSeverity
  Notice    : LogSeverity
  Info      : LogSeverity
  Debug     : LogSeverity

||| Log source.
public export
record LogSource where
  constructor MkLogSource
  name       : String
  sourceType : String
  path       : String
  format     : LogFormat
