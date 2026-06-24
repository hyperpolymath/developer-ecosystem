-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-coap protocol.
-- CoAP (RFC 7252) message types, method codes, option numbers,
-- and content format identifiers for constrained IoT devices.

module Types

import Data.List

||| CoAP message type (2-bit field).
public export
data MsgType : Type where
  Confirmable    : MsgType  -- Reliable delivery with ACK
  NonConfirmable : MsgType  -- Fire-and-forget
  Acknowledgement : MsgType -- Response to CON
  Reset          : MsgType  -- Rejection signal

||| CoAP request method code.
public export
data Method : Type where
  Get    : Method
  Post   : Method
  Put    : Method
  Delete : Method

||| CoAP response code (class.detail format).
public export
record ResponseCode where
  constructor MkResponseCode
  codeClass : Nat    -- 2=success, 4=client error, 5=server error
  detail    : Nat    -- Detail within class

||| CoAP content format identifier.
public export
data ContentFormat : Type where
  TextPlain    : ContentFormat   -- 0
  LinkFormat   : ContentFormat   -- 40
  Xml          : ContentFormat   -- 41
  OctetStream  : ContentFormat   -- 42
  Json         : ContentFormat   -- 50
  Cbor         : ContentFormat   -- 60

||| A CoAP option (number + opaque value).
public export
record CoapOption where
  constructor MkCoapOption
  number : Nat
  value  : List Bits8

||| A CoAP message with header, options, and payload.
public export
record Message where
  constructor MkMessage
  msgType   : MsgType
  code      : Bits8
  messageId : Bits16
  token     : List Bits8
  options   : List CoapOption
  payload   : List Bits8
