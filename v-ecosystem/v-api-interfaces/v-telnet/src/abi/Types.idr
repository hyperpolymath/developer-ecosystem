-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-telnet protocol.
-- Telnet IAC commands, option codes, negotiation states,
-- and NVT data types for remote terminal access (RFC 854).

module Types

import Data.List

||| Telnet IAC command type.
public export
data IacCommand : Type where
  Will : IacCommand  -- Offer to perform option
  Wont : IacCommand  -- Refuse to perform option
  Do   : IacCommand  -- Request peer to perform option
  Dont : IacCommand  -- Demand peer stop option
  SB   : IacCommand  -- Begin subnegotiation
  SE   : IacCommand  -- End subnegotiation

||| Telnet option code.
public export
data OptionCode : Type where
  Echo       : OptionCode  -- 1
  SuppressGA : OptionCode  -- 3
  TermType   : OptionCode  -- 24
  WindowSize : OptionCode  -- 31
  LineMode   : OptionCode  -- 34

||| Option negotiation state.
public export
record OptionState where
  constructor MkOptionState
  code      : OptionCode
  localOn   : Bool
  remoteOn  : Bool
