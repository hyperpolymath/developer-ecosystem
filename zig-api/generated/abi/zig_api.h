/* SPDX-License-Identifier: PMPL-1.0-or-later                              */
/* Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)                  */
/*   <j.d.a.jewell@open.ac.uk>                                              */
/*                                                                            */
/* zig_api.h — C header for libzig_api (unified-zig-api)                    */
/*                                                                            */
/* AUTO-GENERATED — do not edit by hand.                                     */
/* Source of truth: developer-ecosystem/zig-api/src/abi/ (*.idr)            */
/* Implementation:  developer-ecosystem/zig-api/ffi/zig/src/                */
/*                                                                            */
/* This header is ABI-stable across patch versions.                          */
/* Minor version bumps may add symbols; major bumps may remove them.         */

#ifndef ZIG_API_H
#define ZIG_API_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Version
 * ========================================================================== */

/** Null-terminated version string, e.g. "0.1.0". */
const char *uapi_version(void);

/* ============================================================================
 * Library lifecycle
 * ========================================================================== */

/**
 * One-time library initialisation.
 * Must be called before any uapi_* function.
 * Returns 0 (ok) on success, non-zero Result tag on failure.
 * Idempotent: safe to call multiple times.
 */
uint8_t uapi_init(void);

/**
 * Tear down all active servers and connectors and free library-level memory.
 * After this call the library is uninitialised; call uapi_init again before
 * using any uapi_* functions.
 */
void uapi_teardown(void);

/* ============================================================================
 * Result codes  (ZigApi.ABI.Types.resultTag)
 * ========================================================================== */

#define UAPI_OK                      0
#define UAPI_ERR                     1
#define UAPI_INVALID_PARAM           2
#define UAPI_OUT_OF_MEMORY           3
#define UAPI_NULL_POINTER            4
#define UAPI_PATH_DENIED             5
#define UAPI_PROCESS_FAILED          6
#define UAPI_TIMEOUT                 7
#define UAPI_NOT_FOUND               8
#define UAPI_ALREADY_EXISTS          9
#define UAPI_SLOT_EXHAUSTED          10

/* ============================================================================
 * ServerState tags  (ZigApi.ABI.Http.serverStateTag)
 * ========================================================================== */

#define UAPI_SERVER_IDLE             0
#define UAPI_SERVER_LISTENING        1
#define UAPI_SERVER_DRAINING         2
#define UAPI_SERVER_STOPPED          3

/* ============================================================================
 * HealthStatus tags  (ZigApi.ABI.Http.healthStatusTag)
 * ========================================================================== */

#define UAPI_HEALTH_SERVING          0
#define UAPI_HEALTH_NOT_SERVING      1

/* ============================================================================
 * ConnectorState tags  (ZigApi.ABI.Connector.connectorStateTag)
 * ========================================================================== */

#define UAPI_CONNECTOR_DISCONNECTED  0
#define UAPI_CONNECTOR_CONNECTING    1
#define UAPI_CONNECTOR_CONNECTED     2
#define UAPI_CONNECTOR_DEGRADED      3
#define UAPI_CONNECTOR_FAILED        4
#define UAPI_CONNECTOR_DRAINING      5

/* ============================================================================
 * ServiceId tags  (ZigApi.ABI.Connector.serviceIdTag)
 * ========================================================================== */

#define UAPI_SERVICE_AMBIENT_OPS     0
#define UAPI_SERVICE_BOJ             1
#define UAPI_SERVICE_BURBLE          2
#define UAPI_SERVICE_ECHIDNA         3
#define UAPI_SERVICE_GOSSAMER        4
#define UAPI_SERVICE_GROOVE_BRIDGE   5
#define UAPI_SERVICE_HYPATIA         6
#define UAPI_SERVICE_IDAPTIK         7
#define UAPI_SERVICE_REPOSYSTEM      8
#define UAPI_SERVICE_STAPELN         9
#define UAPI_SERVICE_VERISIMDB       10

/* ============================================================================
 * HTTP Method tags  (ZigApi.ABI.Http.methodTag)
 * ========================================================================== */

#define UAPI_METHOD_GET              0
#define UAPI_METHOD_POST             1
#define UAPI_METHOD_PUT              2
#define UAPI_METHOD_DELETE           3
#define UAPI_METHOD_HEAD             4
#define UAPI_METHOD_OPTIONS          5
#define UAPI_METHOD_PATCH            6

/* ============================================================================
 * Gnosis API server  (ffi/zig/src/gnosis.zig)
 * ========================================================================== */

/**
 * Create a gnosis server bound to `port`.
 * Returns an opaque handle (non-zero on success, 0 on failure).
 * The server starts in Idle state; call uapi_gnosis_start to begin serving.
 */
uint64_t uapi_gnosis_create(uint16_t port);

/**
 * Start serving on the port provided at creation time.
 * Spawns a background thread that owns the HTTP listener.
 * Returns UAPI_OK on success, non-zero on failure.
 * Idempotent if the server is already listening.
 */
uint8_t uapi_gnosis_start(uint64_t handle);

/**
 * Signal the server to stop accepting new requests and drain in-flight ones.
 * Blocks until the background thread exits.
 */
void uapi_gnosis_stop(uint64_t handle);

/**
 * Destroy the server handle and free its resources.
 * Calls uapi_gnosis_stop internally if still listening.
 */
void uapi_gnosis_destroy(uint64_t handle);

/**
 * Query current server state.
 * Returns a ServerState tag: UAPI_SERVER_{IDLE,LISTENING,DRAINING,STOPPED}.
 */
uint8_t uapi_gnosis_state(uint64_t handle);

/**
 * Synchronous health probe.
 * Returns UAPI_HEALTH_SERVING (0) if the gnosis binary responds,
 * UAPI_HEALTH_NOT_SERVING (1) otherwise.
 */
uint8_t uapi_gnosis_health(uint64_t handle);

/* ============================================================================
 * Service connector pool  (ffi/zig/src/connector.zig)
 * ========================================================================== */

/**
 * Allocate a connector for service `service_id` pointing at `base_url`.
 * `service_id` is a UAPI_SERVICE_* tag (0-10).
 * `base_url` is a null-terminated string, e.g. "http://127.0.0.1:8080".
 * Returns slot index (0-63), or 255 on failure (pool exhausted / invalid arg).
 */
uint8_t uapi_connector_create(uint8_t service_id, const char *base_url);

/**
 * Health-check the connector at `slot`.
 * Performs a GET /health probe and updates internal state.
 * Returns a ConnectorState tag: UAPI_CONNECTOR_*.
 */
uint8_t uapi_connector_health(uint8_t slot);

/**
 * Send a request to the service connector at `slot`.
 * `method_tag`  — UAPI_METHOD_* tag.
 * `path`        — null-terminated sub-path, e.g. "/api/v1/render".
 * `body`        — null-terminated JSON body (empty string for GET).
 * `out_buf`     — caller-allocated response buffer.
 * `out_len`     — size of `out_buf` in bytes.
 * Returns a Result tag: UAPI_OK on success, non-zero on failure.
 */
uint8_t uapi_connector_call(
    uint8_t      slot,
    uint8_t      method_tag,
    const char  *path,
    const char  *body,
    uint8_t     *out_buf,
    uint32_t     out_len
);

/**
 * Release the connector at `slot` and return it to the pool.
 */
void uapi_connector_destroy(uint8_t slot);

/**
 * Get the current ConnectorState tag for `slot`.
 * Returns UAPI_CONNECTOR_DISCONNECTED if the slot is empty.
 */
uint8_t uapi_connector_state(uint8_t slot);

#ifdef __cplusplus
}
#endif

#endif /* ZIG_API_H */
