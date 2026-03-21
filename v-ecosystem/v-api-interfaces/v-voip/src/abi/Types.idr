-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-voip protocol.
-- SIP methods, response classes, call states, SDP media types,
-- and RTP payload types.

module Types

import Data.List

||| SIP request method (RFC 3261 section 7.1).
public export
data SipMethod : Type where
  Register : SipMethod
  Invite   : SipMethod
  Ack      : SipMethod
  Bye      : SipMethod
  Cancel   : SipMethod
  Options  : SipMethod
  Refer    : SipMethod  -- RFC 3515
  Info     : SipMethod  -- RFC 6086
  Update   : SipMethod  -- RFC 3311

||| SIP response class (first digit of status code).
public export
data ResponseClass : Type where
  Provisional  : ResponseClass  -- 1xx: request received, continuing
  Success      : ResponseClass  -- 2xx: action completed
  Redirection  : ResponseClass  -- 3xx: further action needed
  ClientError  : ResponseClass  -- 4xx: request malformed
  ServerError  : ResponseClass  -- 5xx: server failure
  GlobalError  : ResponseClass  -- 6xx: request cannot be fulfilled

||| Call lifecycle state machine.
public export
data CallState : Type where
  Idle        : CallState  -- No active call
  Trying      : CallState  -- INVITE sent, awaiting response
  Ringing     : CallState  -- 180 Ringing received
  Established : CallState  -- 200 OK received, ACK sent
  Terminating : CallState  -- BYE sent
  Terminated  : CallState  -- Call ended

||| SDP media type for codec negotiation.
public export
data MediaType : Type where
  Audio       : MediaType
  Video       : MediaType
  Application : MediaType

||| RTP payload type (common codecs).
public export
data PayloadType : Type where
  PCMU : PayloadType  -- G.711 mu-law (PT 0)
  PCMA : PayloadType  -- G.711 A-law (PT 8)
  G722 : PayloadType  -- G.722 wideband (PT 9)
  Opus : PayloadType  -- Opus (dynamic PT)

||| A SIP URI with user, host, and optional port.
public export
record SipUri where
  constructor MkSipUri
  scheme : String  -- "sip" or "sips"
  user   : String
  host   : String
  port   : Nat

||| An RTP packet header (RFC 3550 section 5.1).
public export
record RtpHeader where
  constructor MkRtpHeader
  version     : Nat  -- Always 2
  payloadType : Nat
  seqNumber   : Nat
  timestamp   : Nat
  ssrc        : Nat
