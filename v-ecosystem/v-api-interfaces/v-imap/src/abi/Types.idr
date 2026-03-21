-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-imap protocol.
-- IMAP4rev1 mailbox states, message flags, fetch items,
-- and envelope structures for remote mail access (RFC 3501).

module Types

import Data.List

||| IMAP connection state machine.
public export
data ConnectionState : Type where
  NotAuthenticated : ConnectionState
  Authenticated    : ConnectionState
  Selected         : ConnectionState
  Logout           : ConnectionState

||| Standard IMAP message flags.
public export
data MessageFlag : Type where
  Seen     : MessageFlag
  Answered : MessageFlag
  Flagged  : MessageFlag
  Deleted  : MessageFlag
  Draft    : MessageFlag
  Recent   : MessageFlag

||| Mailbox access mode.
public export
data MailboxAccess : Type where
  ReadWrite : MailboxAccess
  ReadOnly  : MailboxAccess

||| Mailbox metadata.
public export
record MailboxInfo where
  constructor MkMailboxInfo
  name        : String
  exists      : Nat
  recent      : Nat
  uidValidity : Bits32
  flags       : List MessageFlag

||| Message envelope (RFC 2822 headers).
public export
record Envelope where
  constructor MkEnvelope
  date      : String
  subject   : String
  msgFrom   : String
  msgTo     : String
  messageId : String
