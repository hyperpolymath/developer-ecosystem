-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-rtsp protocol.
-- RTSP methods, status codes, transport parameters, and
-- SDP media descriptions for stream control (RFC 7826).

module Types

import Data.List

||| RTSP request method.
public export
data Method : Type where
  Options      : Method
  Describe     : Method
  Setup        : Method
  Play         : Method
  Pause        : Method
  Teardown     : Method
  GetParameter : Method
  SetParameter : Method

||| RTSP response status category.
public export
data StatusCategory : Type where
  Informational : StatusCategory  -- 1xx
  Success       : StatusCategory  -- 2xx
  Redirection   : StatusCategory  -- 3xx
  ClientError   : StatusCategory  -- 4xx
  ServerError   : StatusCategory  -- 5xx

||| SDP media description.
public export
record MediaDescription where
  constructor MkMediaDescription
  mediaType : String
  port      : Nat
  protocol  : String
  control   : String

||| RTSP response.
public export
record Response where
  constructor MkResponse
  statusCode : Nat
  cseq       : Nat
  sessionId  : Maybe String
  body       : String
