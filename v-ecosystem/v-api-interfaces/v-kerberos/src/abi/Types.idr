-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-kerberos protocol.
-- Kerberos 5 (RFC 4120) principal types, encryption types,
-- ticket flags, and credential structures.

module Types

import Data.List

||| Kerberos encryption type identifiers.
public export
data EncType : Type where
  AES256CtsHmacSha1 : EncType  -- AES-256 with CTS and HMAC-SHA1 (etype 18)
  AES128CtsHmacSha1 : EncType  -- AES-128 with CTS and HMAC-SHA1 (etype 17)
  DES3CbcSha1       : EncType  -- Triple DES with CBC and SHA1 (etype 16, legacy)

||| Kerberos message type (AS-REQ, TGS-REQ, etc.).
public export
data MsgType : Type where
  AsReq  : MsgType  -- Authentication Service Request (initial TGT)
  AsRep  : MsgType  -- Authentication Service Reply
  TgsReq : MsgType  -- Ticket-Granting Service Request
  TgsRep : MsgType  -- Ticket-Granting Service Reply
  ApReq  : MsgType  -- Application Request (service ticket presentation)
  ApRep  : MsgType  -- Application Reply

||| Kerberos principal (user or service identity).
public export
record Principal where
  constructor MkPrincipal
  name     : String   -- Primary component (e.g. "user" or "HTTP")
  instance : String   -- Instance (e.g. "admin" or hostname)
  realm    : String   -- Kerberos realm

||| Boolean flags embedded in a Kerberos ticket.
public export
record TicketFlags where
  constructor MkTicketFlags
  forwardable : Bool
  forwarded   : Bool
  proxiable   : Bool
  renewable   : Bool
  preAuthent  : Bool

||| A Kerberos ticket with metadata.
public export
record Ticket where
  constructor MkTicket
  client    : Principal
  server    : Principal
  flags     : TicketFlags
  encType   : EncType
  startTime : Nat       -- Unix timestamp
  endTime   : Nat       -- Unix timestamp
  renewTill : Nat       -- Unix timestamp
