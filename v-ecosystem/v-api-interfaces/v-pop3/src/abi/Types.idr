-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-pop3 protocol.
-- POP3 session states, command types, and maildrop structures
-- for post office mail retrieval (RFC 1939).

module Types

import Data.List

||| POP3 session state machine.
public export
data SessionState : Type where
  Authorization : SessionState  -- Before authentication
  Transaction   : SessionState  -- Authenticated, commands available
  Update        : SessionState  -- After QUIT, applying changes

||| POP3 command types.
public export
data Command : Type where
  User : Command
  Pass : Command
  Stat : Command
  List : Command
  Retr : Command
  Dele : Command
  Noop : Command
  Rset : Command
  Top  : Command
  Uidl : Command
  Quit : Command

||| Maildrop statistics.
public export
record MaildropStats where
  constructor MkMaildropStats
  count : Nat
  size  : Nat

||| Single message info from LIST.
public export
record MessageInfo where
  constructor MkMessageInfo
  number : Nat
  size   : Nat
