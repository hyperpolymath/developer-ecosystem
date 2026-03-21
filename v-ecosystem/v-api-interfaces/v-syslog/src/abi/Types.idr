-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-syslog protocol.
-- Syslog severity levels, facility codes, structured data,
-- and message format for RFC 5424 system logging.

module Types

import Data.List

||| Syslog severity level (0-7).
public export
data Severity : Type where
  Emergency     : Severity  -- 0: System unusable
  Alert         : Severity  -- 1: Immediate action needed
  Critical      : Severity  -- 2: Critical conditions
  Error         : Severity  -- 3: Error conditions
  Warning       : Severity  -- 4: Warning conditions
  Notice        : Severity  -- 5: Normal but significant
  Informational : Severity  -- 6: Informational
  Debug         : Severity  -- 7: Debug-level

||| Syslog facility code.
public export
data Facility : Type where
  Kern     : Facility  -- 0
  User     : Facility  -- 1
  Mail     : Facility  -- 2
  Daemon   : Facility  -- 3
  Auth     : Facility  -- 4
  Local0   : Facility  -- 16
  Local7   : Facility  -- 23

||| Structured data element (SD-ELEMENT).
public export
record SDElement where
  constructor MkSDElement
  sdId   : String
  params : List (String, String)

||| RFC 5424 syslog message.
public export
record SyslogMessage where
  constructor MkSyslogMessage
  facility  : Facility
  severity  : Severity
  timestamp : String
  hostname  : String
  appName   : String
  procId    : String
  msgId     : String
  sdElems   : List SDElement
  message   : String
