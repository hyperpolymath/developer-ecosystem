-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-bfd protocol.
-- BFD session types: states, discriminators, timers.

module Types

||| BFD session state machine.
public export
data BfdState : Type where
  AdminDown : BfdState
  Down      : BfdState
  Init      : BfdState
  Up        : BfdState

||| BFD session.
public export
record BfdSession where
  constructor MkBfdSession
  localDiscr    : Bits32
  remoteDiscr   : Bits32
  localAddr     : String
  remoteAddr    : String
  state         : BfdState
  desiredMinTx  : Bits32
  requiredMinRx : Bits32
  detectMult    : Bits8
