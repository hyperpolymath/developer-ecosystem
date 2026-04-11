-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Foreign.idr — %foreign declarations for unified-zig-api
--
-- Every declaration here corresponds to an `export fn uapi_*` in the Zig FFI.
-- Grouped by subsystem: gnosis server, connector pool.

module ZigApi.ABI.Foreign

import ZigApi.ABI.Types
import ZigApi.ABI.Http
import ZigApi.ABI.Process
import ZigApi.ABI.Connector

%default total

-- ============================================================================
-- Gnosis API server  (ffi/zig/src/gnosis.zig)
-- ============================================================================

||| Create a gnosis server bound to `port`.
||| Returns an opaque handle (non-zero on success, 0 on failure).
%foreign "C:uapi_gnosis_create, libzig_api"
prim__gnosisCreate : (port : Bits16) -> PrimIO Bits64

||| Start serving — blocks in a Zig thread until uapi_gnosis_stop is called.
||| Returns 0 on clean start, non-zero Result tag on failure.
%foreign "C:uapi_gnosis_start, libzig_api"
prim__gnosisStart : (handle : Bits64) -> PrimIO Bits8

||| Signal the server to stop accepting new requests and drain in-flight ones.
%foreign "C:uapi_gnosis_stop, libzig_api"
prim__gnosisStop : (handle : Bits64) -> PrimIO ()

||| Destroy the server handle and free its resources.
||| Caller must have called uapi_gnosis_stop first.
%foreign "C:uapi_gnosis_destroy, libzig_api"
prim__gnosisDestroy : (handle : Bits64) -> PrimIO ()

||| Query current server state.  Returns a ServerState tag (Bits8).
%foreign "C:uapi_gnosis_state, libzig_api"
prim__gnosisState : (handle : Bits64) -> PrimIO Bits8

||| Synchronous health probe — returns HealthStatus tag (0=serving, 1=not_serving).
%foreign "C:uapi_gnosis_health, libzig_api"
prim__gnosisHealth : (handle : Bits64) -> PrimIO Bits8

-- ============================================================================
-- Connector pool  (ffi/zig/src/connector.zig)
-- ============================================================================

||| Allocate a connector for `service_id` pointing at `base_url`.
||| Returns slot index (0..63), or 255 on failure (SlotExhausted / InvalidParam).
%foreign "C:uapi_connector_create, libzig_api"
prim__connectorCreate : (service_id : Bits8) -> (base_url : String) -> PrimIO Bits8

||| Health check the connector at `slot`. Returns ConnectorState tag.
%foreign "C:uapi_connector_health, libzig_api"
prim__connectorHealth : (slot : Bits8) -> PrimIO Bits8

||| Send a JSON-body request to the connector's service.
||| `method_tag` is an Http.Method tag. `path` is the endpoint sub-path.
||| `body` is a JSON string (empty string for GET requests).
||| Writes response JSON into `out_buf` (max `out_len` bytes).
||| Returns Result tag.
%foreign "C:uapi_connector_call, libzig_api"
prim__connectorCall :
  (slot      : Bits8) ->
  (method_tag : Bits8) ->
  (path      : String) ->
  (body      : String) ->
  (out_buf   : Bits64) ->  -- pointer to caller-allocated buffer
  (out_len   : Bits32) ->
  PrimIO Bits8

||| Release the connector at `slot` and return it to the pool.
%foreign "C:uapi_connector_destroy, libzig_api"
prim__connectorDestroy : (slot : Bits8) -> PrimIO ()

||| Get the current state of the connector at `slot`.
%foreign "C:uapi_connector_state, libzig_api"
prim__connectorState : (slot : Bits8) -> PrimIO Bits8

-- ============================================================================
-- Library lifecycle
-- ============================================================================

||| One-time library initialisation. Must be called before any uapi_* functions.
%foreign "C:uapi_init, libzig_api"
prim__uapiInit : PrimIO Bits8

||| Tear down all active servers and connectors and free library-level memory.
%foreign "C:uapi_teardown, libzig_api"
prim__uapiTeardown : PrimIO ()

||| Null-terminated version string, e.g. "0.1.0".
%foreign "C:uapi_version, libzig_api"
prim__uapiVersion : PrimIO String

-- ============================================================================
-- Idris2 wrappers (IO, not PrimIO)
-- ============================================================================

public export
uapiInit : IO Result
uapiInit = do
  tag <- primIO prim__uapiInit
  pure $ case ZigApi.ABI.Types.resultFromTag tag of
    Just r  => r
    Nothing => Err

public export
uapiTeardown : IO ()
uapiTeardown = primIO prim__uapiTeardown

public export
gnosisCreate : Bits16 -> IO Handle
gnosisCreate port = do
  ptr <- primIO (prim__gnosisCreate port)
  pure (MkHandle ptr)

public export
gnosisStart : Handle -> IO Result
gnosisStart (MkHandle ptr) = do
  tag <- primIO (prim__gnosisStart ptr)
  pure $ case ZigApi.ABI.Types.resultFromTag tag of
    Just r  => r
    Nothing => Err

public export
gnosisStop : Handle -> IO ()
gnosisStop (MkHandle ptr) = primIO (prim__gnosisStop ptr)

public export
gnosisDestroy : Handle -> IO ()
gnosisDestroy (MkHandle ptr) = primIO (prim__gnosisDestroy ptr)

public export
gnosisHealth : Handle -> IO HealthStatus
gnosisHealth (MkHandle ptr) = do
  tag <- primIO (prim__gnosisHealth ptr)
  pure $ if tag == 0 then Serving else NotServing

public export
connectorCreate : ServiceId -> String -> IO (Maybe Slot)
connectorCreate sid url = do
  idx <- primIO (prim__connectorCreate (serviceIdTag sid) url)
  if idx == 255
    then pure Nothing
    else pure (Just (MkSlot idx))

public export
connectorHealth : Slot -> IO ConnectorState
connectorHealth (MkSlot idx) = do
  tag <- primIO (prim__connectorHealth idx)
  pure $ case connectorStateFromTag tag of
    Just s  => s
    Nothing => Failed

public export
connectorDestroy : Slot -> IO ()
connectorDestroy (MkSlot idx) = primIO (prim__connectorDestroy idx)
