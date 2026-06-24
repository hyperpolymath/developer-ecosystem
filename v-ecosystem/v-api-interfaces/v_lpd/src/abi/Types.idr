-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-lpd protocol.
-- LPD types: print job states, queues.

module Types

||| Print job lifecycle state.
public export
data PrintJobState : Type where
  Queued    : PrintJobState
  Printing  : PrintJobState
  Completed : PrintJobState
  Cancelled : PrintJobState
  Error     : PrintJobState

||| Print queue.
public export
record PrintQueue where
  constructor MkPrintQueue
  name    : String
  device  : String
  enabled : Bool

||| Print job.
public export
record PrintJob where
  constructor MkPrintJob
  jobId     : Nat
  queueName : String
  filename  : String
  state     : PrintJobState
  copies    : Nat
