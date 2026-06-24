-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-soap protocol.
-- SOAP envelope, header, body, and fault types for 1.1 and 1.2.

module Types

import Data.List

||| SOAP protocol version, selecting namespace and content type.
public export
data SoapVersion : Type where
  V11 : SoapVersion  -- schemas.xmlsoap.org/soap/envelope/
  V12 : SoapVersion  -- www.w3.org/2003/05/soap-envelope

||| A single SOAP header block carrying metadata.
public export
record Header where
  constructor MkHeader
  namespace : String  -- XML namespace URI (may be empty)
  name      : String  -- Local element name
  value     : String  -- Text content

||| The SOAP Body element wrapping application payload as raw XML.
public export
record Body where
  constructor MkBody
  content : String

||| SOAP Fault (1.1 section 4.4 / 1.2 section 5.4).
public export
record Fault where
  constructor MkFault
  faultCode   : String        -- e.g. "soap:Server"
  faultString : String        -- Human-readable description
  detail      : Maybe String  -- Optional detail XML

||| Complete SOAP envelope: version, headers, body, and action.
public export
record Envelope where
  constructor MkEnvelope
  version : SoapVersion
  headers : List Header
  body    : Body
  action  : String  -- SOAPAction header / Content-Type param

||| Parsed SOAP response: either body content or a fault.
public export
data ParsedResponse : Type where
  ResponseOk    : (statusCode : Nat) -> (body : Body) -> ParsedResponse
  ResponseFault : (statusCode : Nat) -> (fault : Fault) -> ParsedResponse

||| SOAP actor/role for the mustUnderstand processing model.
public export
data Actor : Type where
  UltimateReceiver : Actor
  Intermediary     : (uri : String) -> Actor
  Next             : Actor  -- SOAP 1.2 only
