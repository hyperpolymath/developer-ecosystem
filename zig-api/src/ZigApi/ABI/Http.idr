-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Http.idr — HTTP-layer types for unified-zig-api
--
-- Tags must match the Zig enums in ffi/zig/src/http.zig exactly.

module ZigApi.ABI.Http

import Data.Bits
import ZigApi.ABI.Types

%default total

-- ============================================================================
-- HTTP Method  (Zig: pub const Method = enum(u8))
-- ============================================================================

public export
data Method = GET | POST | PUT | DELETE | HEAD | OPTIONS | PATCH

public export
methodTag : Method -> Bits8
methodTag GET     = 0
methodTag POST    = 1
methodTag PUT     = 2
methodTag DELETE  = 3
methodTag HEAD    = 4
methodTag OPTIONS = 5
methodTag PATCH   = 6

public export
methodFromTag : Bits8 -> Maybe Method
methodFromTag 0 = Just GET
methodFromTag 1 = Just POST
methodFromTag 2 = Just PUT
methodFromTag 3 = Just DELETE
methodFromTag 4 = Just HEAD
methodFromTag 5 = Just OPTIONS
methodFromTag 6 = Just PATCH
methodFromTag _ = Nothing

public export
methodRoundtrip : (m : Method) -> methodFromTag (methodTag m) = Just m
methodRoundtrip GET     = Refl
methodRoundtrip POST    = Refl
methodRoundtrip PUT     = Refl
methodRoundtrip DELETE  = Refl
methodRoundtrip HEAD    = Refl
methodRoundtrip OPTIONS = Refl
methodRoundtrip PATCH   = Refl

-- ============================================================================
-- HTTP Status class  (Zig: pub const StatusClass = enum(u8))
-- ============================================================================

||| Coarse HTTP status classification.
public export
data StatusClass = Info | Success | Redirect | ClientErr | ServerErr

public export
statusClassTag : StatusClass -> Bits8
statusClassTag Info      = 1
statusClassTag Success   = 2
statusClassTag Redirect  = 3
statusClassTag ClientErr = 4
statusClassTag ServerErr = 5

||| Canonical base status code for each class.
public export
baseStatus : StatusClass -> Bits16
baseStatus Info      = 100
baseStatus Success   = 200
baseStatus Redirect  = 300
baseStatus ClientErr = 400
baseStatus ServerErr = 500

-- ============================================================================
-- Content type  (Zig: pub const ContentType = enum(u8))
-- ============================================================================

public export
data ContentType = JSON | PlainText | HTML | OctetStream | EventStream

public export
contentTypeTag : ContentType -> Bits8
contentTypeTag JSON        = 0
contentTypeTag PlainText   = 1
contentTypeTag HTML        = 2
contentTypeTag OctetStream = 3
contentTypeTag EventStream = 4

public export
contentTypeMime : ContentType -> String
contentTypeMime JSON        = "application/json"
contentTypeMime PlainText   = "text/plain; charset=utf-8"
contentTypeMime HTML        = "text/html; charset=utf-8"
contentTypeMime OctetStream = "application/octet-stream"
contentTypeMime EventStream = "text/event-stream"

-- ============================================================================
-- Route registration  (passed to uapi_http_register_route)
-- ============================================================================

||| A route descriptor passed over the C ABI.
||| method_tag: encoded as Bits8.  path: null-terminated C string.
public export
record RouteDescriptor where
  constructor MkRoute
  methodTag  : Bits8
  path       : String
  handlerTag : Bits8   -- caller-defined handler identifier

||| Proof that a RouteDescriptor has a known method.
public export
data ValidRoute : RouteDescriptor -> Type where
  RouteOk : (r : RouteDescriptor) -> IsJust (methodFromTag r.methodTag) -> ValidRoute r

-- ============================================================================
-- Server state  (Zig: pub const ServerState = enum(u8))
-- ============================================================================

public export
data ServerState = Idle | Listening | Draining | Stopped

public export
serverStateTag : ServerState -> Bits8
serverStateTag Idle      = 0
serverStateTag Listening = 1
serverStateTag Draining  = 2
serverStateTag Stopped   = 3

public export
serverStateFromTag : Bits8 -> Maybe ServerState
serverStateFromTag 0 = Just Idle
serverStateFromTag 1 = Just Listening
serverStateFromTag 2 = Just Draining
serverStateFromTag 3 = Just Stopped
serverStateFromTag _ = Nothing

public export
serverStateRoundtrip : (s : ServerState) -> serverStateFromTag (serverStateTag s) = Just s
serverStateRoundtrip Idle      = Refl
serverStateRoundtrip Listening = Refl
serverStateRoundtrip Draining  = Refl
serverStateRoundtrip Stopped   = Refl

-- ============================================================================
-- Health status  (Zig: pub const HealthStatus = enum(u8))
-- Used for the /health endpoint — 0 = serving, 1 = not_serving.
-- Load balancers use this to decide whether to route traffic.
-- ============================================================================

public export
data HealthStatus = Serving | NotServing

public export
healthStatusTag : HealthStatus -> Bits8
healthStatusTag Serving    = 0
healthStatusTag NotServing = 1

||| HTTP status code to return for each health status.
||| Load balancers MUST see 200 for Serving and 503 for NotServing.
public export
healthHttpStatus : HealthStatus -> Bits16
healthHttpStatus Serving    = 200
healthHttpStatus NotServing = 503
