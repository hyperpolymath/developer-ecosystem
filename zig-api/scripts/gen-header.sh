#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
# (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
#
# gen-header.sh — regenerate generated/abi/zig_api.h from the Idris2 ABI modules.
#
# Usage: scripts/gen-header.sh [repo-root]
#   repo-root defaults to the parent of the directory containing this script.
#
# Design notes
# ============
# Case-(c) custom extractor: no Idris2 built-in C backend emits C headers.
# This script parses two things from the Idris2 ABI modules:
#
#   1. %foreign declarations in Foreign.idr — gives C function names +
#      Idris2 type signatures → translated to C declarations.
#
#   2. *Tag pattern-match functions in Types/Http/Connector.idr — gives enum
#      constructor → integer tag mappings → emitted as #define constants.
#
# Idris2 → C type mapping
# -----------------------
#   Bits8              → uint8_t
#   Bits16             → uint16_t
#   Bits32             → uint32_t
#   Bits64             → uint64_t
#   String             → const char *  (inputs) / uint8_t * (out_buf only)
#   PrimIO ()          → void return
#   PrimIO BitsN       → uintN_t return
#
# CamelCase → UPPER_SNAKE_CASE for #define names:
#   InvalidParam → INVALID_PARAM
#   OutOfMemory  → OUT_OF_MEMORY
#   GrooveBridge → GROOVE_BRIDGE  (etc.)
#
# Output is fully deterministic: sections appear in a fixed coded order,
# enum entries appear in tag-numeric order (derived from source order in .idr),
# no timestamps or randomised ordering.

set -euo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
ABI_DIR="$REPO_ROOT/src/ZigApi/ABI"
OUT_FILE="$REPO_ROOT/generated/abi/zig_api.h"

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
die() { printf 'gen-header: error: %s\n' "$*" >&2; exit 1; }

for idr in Types.idr Http.idr Process.idr Connector.idr Foreign.idr; do
    [[ -f "$ABI_DIR/$idr" ]] || die "missing $ABI_DIR/$idr"
done
mkdir -p "$(dirname "$OUT_FILE")"

# ---------------------------------------------------------------------------
# camel_to_upper_snake WORD
# Converts CamelCase constructor names to UPPER_SNAKE_CASE for #define macros.
# Examples:
#   Ok           → OK
#   Err          → ERR
#   InvalidParam → INVALID_PARAM
#   OutOfMemory  → OUT_OF_MEMORY
#   GrooveBridge → GROOVE_BRIDGE
#   NotServing   → NOT_SERVING
#   IDApTIK      → ID_AP_TIK  (edge case — acceptable)
# ---------------------------------------------------------------------------
camel_to_upper_snake() {
    # Handle known abbreviations that confuse generic CamelCase splitting:
    #   BoJ        → BOJ            (not BO_J)
    #   IDApTIK    → IDAPTIK        (not ID_AP_TIK)
    #   VeriSimDB  → VERISIMDB      (not VERI_SIM_DB)
    #   GrooveBridge → GROOVE_BRIDGE
    #   AmbientOps → AMBIENT_OPS
    case "$1" in
        BoJ)        printf 'BOJ';      return ;;
        IDApTIK)    printf 'IDAPTIK';  return ;;
        VeriSimDB)  printf 'VERISIMDB';return ;;
    esac
    # Generic: insert underscore before a capital letter that follows a lowercase
    # letter, or before a capital sequence that precedes a mixed case.
    # Then uppercase the whole thing.
    printf '%s' "$1" \
        | sed -E 's/([a-z])([A-Z])/\1_\2/g' \
        | sed -E 's/([A-Z]+)([A-Z][a-z])/\1_\2/g' \
        | tr '[:lower:]' '[:upper:]'
}

# ---------------------------------------------------------------------------
# idr_type_to_c TYPE ARGNAME
# Translates a single Idris2 type token to a C type string.
# ARGNAME is used only to distinguish the out_buf special case.
# ---------------------------------------------------------------------------
idr_type_to_c() {
    local t="$1" name="${2:-}"
    case "$t" in
        Bits8)   printf 'uint8_t' ;;
        Bits16)  printf 'uint16_t' ;;
        Bits32)  printf 'uint32_t' ;;
        Bits64)  printf 'uint64_t' ;;
        String)
            if [[ "$name" == "out_buf" ]]; then
                printf 'uint8_t *'
            else
                printf 'const char *'
            fi
            ;;
        "()")    printf 'void' ;;
        *)       printf 'uint8_t' ;;
    esac
}

# ---------------------------------------------------------------------------
# extract_tags FILEPATH FUNCNAME MACRO_PREFIX
#
# Parses lines of the form:
#   funcname Constructor     = 0
#   funcname AnotherCtor     = 1
# from FILEPATH and emits:
#   MACRO_PREFIX_UPPER_SNAKE  VALUE
# one entry per line, in source order (which matches tag-numeric order).
# ---------------------------------------------------------------------------
extract_tags() {
    local file="$1" funcname="$2" macro_prefix="$3"
    # Use grep + awk: find lines that start with the function name followed
    # by a capital-letter word (the constructor) and end with = <number>.
    grep -E "^${funcname} [A-Z]" "$file" | while IFS= read -r line; do
        # Strip the function name prefix
        local rest
        rest="${line#"$funcname" }"
        # Constructor name = everything before " = "
        local ctor="${rest%% = *}"
        # Trim any trailing whitespace from ctor
        ctor="${ctor%"${ctor##*[! ]}"}"
        # Value = everything after " = "
        local val="${rest##* = }"
        # Trim whitespace and comments from val
        val="${val%% *}"
        # Convert ctor to UPPER_SNAKE
        local upper
        upper="$(camel_to_upper_snake "$ctor")"
        printf '%s_%s %s\n' "$macro_prefix" "$upper" "$val"
    done
}

# ---------------------------------------------------------------------------
# parse_foreign_functions FILEPATH
#
# Parses %foreign + prim__ declarations from FILEPATH.
# Output: one line per function:  CFUNCNAME|RET_C_TYPE|ARG1_CTYPE ARG1_NAME,...
#
# Handles multi-line type signatures (Idris2 allows line continuations with
# indentation).  The function section ends at the next blank line or next
# %foreign declaration.
# ---------------------------------------------------------------------------
parse_foreign_functions() {
    python3 - "$1" <<'PYEOF'
import re, sys

lines = open(sys.argv[1]).read().splitlines()

IDR_TO_C = {
    'Bits8':  'uint8_t',
    'Bits16': 'uint16_t',
    'Bits32': 'uint32_t',
    'Bits64': 'uint64_t',
    'String': 'const char *',
    '()':     'void',
}

def idr2c(t, name=''):
    if t == 'String' and name == 'out_buf':
        return 'uint8_t *'
    return IDR_TO_C.get(t, 'uint8_t')

results = []
i = 0
while i < len(lines):
    line = lines[i]
    # Match: %foreign "C:funcname, libzig_api"
    m = re.match(r'%foreign "C:(\w+),', line)
    if m:
        cfunc = m.group(1)
        # Collect the prim__ type signature (may span multiple lines)
        sig_lines = []
        j = i + 1
        while j < len(lines):
            l = lines[j]
            if re.match(r'^prim__', l) or (sig_lines and re.match(r'^  ', l)):
                sig_lines.append(l.strip())
                if 'PrimIO' in l:
                    break
            elif l.strip() == '' and sig_lines:
                break
            elif re.match(r'^%foreign', l):
                break
            elif not sig_lines:
                pass  # skip lines before prim__ found
            j += 1

        if sig_lines:
            sig = ' '.join(sig_lines)
            # Remove prim__name :
            sig = re.sub(r'^prim__\w+ *: *', '', sig).strip()

            # Extract return type (before removing the PrimIO suffix)
            if re.search(r'PrimIO \(\)', sig):
                ret_c = 'void'
            else:
                ret_match = re.search(r'PrimIO (Bits\d+|String)', sig)
                ret_c = idr2c(ret_match.group(1)) if ret_match else 'uint8_t'

            # If sig starts directly with PrimIO (no args before it), there
            # are no arguments: e.g. "PrimIO Bits8" or "PrimIO ()"
            if re.match(r'^PrimIO\b', sig):
                args = []
            else:
                # Remove the "-> PrimIO ..." suffix
                sig = re.sub(r' *-> *PrimIO.*', '', sig).strip()
                # Split on " -> " to get individual arg types
                parts = re.split(r' *-> *', sig)
                args = []
                for p in parts:
                    p = p.strip()
                    if not p:
                        continue
                    # Parse "(name : Type)" or just "Type"
                    m2 = re.match(r'\((\w+) *: *(\w+)\)', p)
                    if m2:
                        aname, atype = m2.group(1), m2.group(2)
                    else:
                        aname, atype = '', p.strip('()')
                    c_type = idr2c(atype, aname)
                    if aname:
                        args.append(f'{c_type} {aname}')
                    else:
                        args.append(c_type)

            argstr = ', '.join(args) if args else 'void'
            # Normalise pointer spacing: "const char * name" → "const char *name"
            argstr = re.sub(r'\* ', '*', argstr)
            results.append(f'{cfunc}|{ret_c}|{argstr}')
        i = j
    i += 1

for r in results:
    print(r)
PYEOF
}

# ---------------------------------------------------------------------------
# Main: build lookup table from parsed foreign declarations
# ---------------------------------------------------------------------------
declare -A F_RET F_ARGS
while IFS='|' read -r cfunc ret arglist; do
    F_RET["$cfunc"]="$ret"
    F_ARGS["$cfunc"]="$arglist"
done < <(parse_foreign_functions "$ABI_DIR/Foreign.idr")

# ---------------------------------------------------------------------------
# Render a C function declaration.
# If the single-line form exceeds 79 chars, use multi-line format.
# ---------------------------------------------------------------------------
render_decl() {
    local cfunc="$1"
    local ret="${F_RET[$cfunc]:-void}"
    local args="${F_ARGS[$cfunc]:-void}"

    local oneline="${ret} ${cfunc}(${args})"
    if [[ ${#oneline} -le 79 ]]; then
        printf '%s;\n' "$oneline"
    else
        printf '%s %s(\n' "$ret" "$cfunc"
        # Split args on ", " and indent each
        local IFS=','
        local first=1
        printf '%s' "$args" | awk -F', ' '{
            for(i=1;i<=NF;i++){
                gsub(/^ +/,"",$i)
                printf "    %s", $i
                if(i<NF) printf ","
                printf "\n"
            }
        }'
        printf ');\n'
    fi
}

# ---------------------------------------------------------------------------
# Emit the header
# ---------------------------------------------------------------------------
{
printf '/* SPDX-License-Identifier: MPL-2.0                              */\n'
printf '/* Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)                  */\n'
printf '/*   <j.d.a.jewell@open.ac.uk>                                              */\n'
printf '/*                                                                            */\n'
printf '/* zig_api.h \xe2\x80\x94 C header for libzig_api (unified-zig-api)                    */\n'
printf '/*                                                                            */\n'
printf '/* AUTO-GENERATED \xe2\x80\x94 do not edit by hand.                                     */\n'
printf '/* Source of truth: developer-ecosystem/zig-api/src/abi/ (*.idr)            */\n'
printf '/* Implementation:  developer-ecosystem/zig-api/ffi/zig/src/                */\n'
printf '/*                                                                            */\n'
printf '/* This header is ABI-stable across patch versions.                          */\n'
printf '/* Minor version bumps may add symbols; major bumps may remove them.         */\n'
printf '\n'
printf '#ifndef ZIG_API_H\n'
printf '#define ZIG_API_H\n'
printf '\n'
printf '#include <stdint.h>\n'
printf '\n'
printf '#ifdef __cplusplus\n'
printf 'extern "C" {\n'
printf '#endif\n'
printf '\n'

# -- Version --
printf '/* ============================================================================\n'
printf ' * Version\n'
printf ' * ========================================================================== */\n'
printf '\n'
printf '/** Null-terminated version string, e.g. "0.1.0". */\n'
printf 'const char *uapi_version(void);\n'
printf '\n'

# -- Lifecycle --
printf '/* ============================================================================\n'
printf ' * Library lifecycle\n'
printf ' * ========================================================================== */\n'
printf '\n'
printf '/**\n'
printf ' * One-time library initialisation.\n'
printf ' * Must be called before any uapi_* function.\n'
printf ' * Returns 0 (ok) on success, non-zero Result tag on failure.\n'
printf ' * Idempotent: safe to call multiple times.\n'
printf ' */\n'
render_decl "uapi_init"
printf '\n'
printf '/**\n'
printf ' * Tear down all active servers and connectors and free library-level memory.\n'
printf ' * After this call the library is uninitialised; call uapi_init again before\n'
printf ' * using any uapi_* functions.\n'
printf ' */\n'
render_decl "uapi_teardown"
printf '\n'

# -- Result codes --
printf '/* ============================================================================\n'
printf ' * Result codes  (ZigApi.ABI.Types.resultTag)\n'
printf ' * ========================================================================== */\n'
printf '\n'
while IFS=' ' read -r macro val; do
    printf '#define %-28s %s\n' "$macro" "$val"
done < <(extract_tags "$ABI_DIR/Types.idr" "resultTag" "UAPI")
printf '\n'

# -- ServerState tags --
printf '/* ============================================================================\n'
printf ' * ServerState tags  (ZigApi.ABI.Http.serverStateTag)\n'
printf ' * ========================================================================== */\n'
printf '\n'
while IFS=' ' read -r macro val; do
    printf '#define %-28s %s\n' "$macro" "$val"
done < <(extract_tags "$ABI_DIR/Http.idr" "serverStateTag" "UAPI_SERVER")
printf '\n'

# -- HealthStatus tags --
printf '/* ============================================================================\n'
printf ' * HealthStatus tags  (ZigApi.ABI.Http.healthStatusTag)\n'
printf ' * ========================================================================== */\n'
printf '\n'
while IFS=' ' read -r macro val; do
    printf '#define %-28s %s\n' "$macro" "$val"
done < <(extract_tags "$ABI_DIR/Http.idr" "healthStatusTag" "UAPI_HEALTH")
printf '\n'

# -- ConnectorState tags --
printf '/* ============================================================================\n'
printf ' * ConnectorState tags  (ZigApi.ABI.Connector.connectorStateTag)\n'
printf ' * ========================================================================== */\n'
printf '\n'
while IFS=' ' read -r macro val; do
    printf '#define %-28s %s\n' "$macro" "$val"
done < <(extract_tags "$ABI_DIR/Connector.idr" "connectorStateTag" "UAPI_CONNECTOR")
printf '\n'

# -- ServiceId tags --
printf '/* ============================================================================\n'
printf ' * ServiceId tags  (ZigApi.ABI.Connector.serviceIdTag)\n'
printf ' * ========================================================================== */\n'
printf '\n'
while IFS=' ' read -r macro val; do
    printf '#define %-28s %s\n' "$macro" "$val"
done < <(extract_tags "$ABI_DIR/Connector.idr" "serviceIdTag" "UAPI_SERVICE")
printf '\n'

# -- HTTP Method tags --
printf '/* ============================================================================\n'
printf ' * HTTP Method tags  (ZigApi.ABI.Http.methodTag)\n'
printf ' * ========================================================================== */\n'
printf '\n'
while IFS=' ' read -r macro val; do
    printf '#define %-28s %s\n' "$macro" "$val"
done < <(extract_tags "$ABI_DIR/Http.idr" "methodTag" "UAPI_METHOD")
printf '\n'

# -- Gnosis server --
printf '/* ============================================================================\n'
printf ' * Gnosis API server  (ffi/zig/src/gnosis.zig)\n'
printf ' * ========================================================================== */\n'
printf '\n'
printf '/**\n'
printf ' * Create a gnosis server bound to `port`.\n'
printf ' * Returns an opaque handle (non-zero on success, 0 on failure).\n'
printf ' * The server starts in Idle state; call uapi_gnosis_start to begin serving.\n'
printf ' */\n'
render_decl "uapi_gnosis_create"
printf '\n'
printf '/**\n'
printf ' * Start serving on the port provided at creation time.\n'
printf ' * Spawns a background thread that owns the HTTP listener.\n'
printf ' * Returns UAPI_OK on success, non-zero on failure.\n'
printf ' * Idempotent if the server is already listening.\n'
printf ' */\n'
render_decl "uapi_gnosis_start"
printf '\n'
printf '/**\n'
printf ' * Signal the server to stop accepting new requests and drain in-flight ones.\n'
printf ' * Blocks until the background thread exits.\n'
printf ' */\n'
render_decl "uapi_gnosis_stop"
printf '\n'
printf '/**\n'
printf ' * Destroy the server handle and free its resources.\n'
printf ' * Calls uapi_gnosis_stop internally if still listening.\n'
printf ' */\n'
render_decl "uapi_gnosis_destroy"
printf '\n'
printf '/**\n'
printf ' * Query current server state.\n'
printf ' * Returns a ServerState tag: UAPI_SERVER_{IDLE,LISTENING,DRAINING,STOPPED}.\n'
printf ' */\n'
render_decl "uapi_gnosis_state"
printf '\n'
printf '/**\n'
printf ' * Synchronous health probe.\n'
printf ' * Returns UAPI_HEALTH_SERVING (0) if the gnosis binary responds,\n'
printf ' * UAPI_HEALTH_NOT_SERVING (1) otherwise.\n'
printf ' */\n'
render_decl "uapi_gnosis_health"
printf '\n'
printf '/**\n'
printf ' * Request context passed to edge handler hooks.\n'
printf ' * All pointer fields are valid only for the duration of the handler call.\n'
printf ' */\n'
printf 'typedef struct {\n'
printf '    const char    *method;    /**< HTTP method, e.g. "GET" (null-terminated). */\n'
printf '    const char    *path;      /**< Request path, query-stripped (null-terminated). */\n'
printf '    const uint8_t *body_ptr;  /**< Request body bytes; NULL when empty. */\n'
printf '    uint32_t       body_len;  /**< Byte length of body_ptr; 0 when empty. */\n'
printf '} GnosisRequest;\n'
printf '\n'
printf '/**\n'
printf ' * Response written by an edge handler hook.\n'
printf ' * `body_ptr` must remain valid until uapi_gnosis_write_response returns.\n'
printf ' */\n'
printf 'typedef struct {\n'
printf '    uint16_t       status;        /**< HTTP status code, e.g. 200, 404. */\n'
printf '    uint16_t       _pad;          /**< Reserved; set to 0. */\n'
printf '    const char    *content_type;  /**< MIME type string (null-terminated). */\n'
printf '    const uint8_t *body_ptr;      /**< Response body; NULL for zero-length body. */\n'
printf '    uint32_t       body_len;      /**< Byte length of body_ptr. */\n'
printf '} GnosisResponse;\n'
printf '\n'
printf '/**\n'
printf ' * Register an edge handler hook for the server identified by `handle`.\n'
printf ' *\n'
printf ' * Must be called after uapi_gnosis_create and BEFORE uapi_gnosis_start.\n'
printf ' * Calling after start returns UAPI_ERR — no hot-swap.\n'
printf ' * When set, uapi_gnosis_start dispatches every request to `handler_fn`\n'
printf ' * instead of the built-in gnosis routes.  Pass NULL to revert to built-in.\n'
printf ' *\n'
printf ' * Returns UAPI_OK on success, non-zero on failure.\n'
printf ' */\n'
printf 'uint8_t uapi_gnosis_set_handler(\n'
printf '    uint64_t      handle,\n'
printf '    void        (*handler_fn)(const GnosisRequest *req, GnosisResponse *resp)\n'
printf ');\n'
printf '\n'
printf '/**\n'
printf ' * Convenience helper: fill all fields of a GnosisResponse in one call.\n'
printf ' * Edge handlers may call this or fill the struct directly.\n'
printf ' */\n'
printf 'void uapi_gnosis_write_response(\n'
printf '    GnosisResponse *resp,\n'
printf '    uint16_t        status,\n'
printf '    const char     *content_type,\n'
printf '    const uint8_t  *body_ptr,\n'
printf '    uint32_t        body_len\n'
printf ');\n'
printf '\n'

# -- Connector pool --
printf '/* ============================================================================\n'
printf ' * Service connector pool  (ffi/zig/src/connector.zig)\n'
printf ' * ========================================================================== */\n'
printf '\n'
printf '/**\n'
printf ' * Allocate a connector for service `service_id` pointing at `base_url`.\n'
printf ' * `service_id` is a UAPI_SERVICE_* tag (0-10).\n'
printf ' * `base_url` is a null-terminated string, e.g. "http://127.0.0.1:8080".\n'
printf ' * Returns slot index (0-63), or 255 on failure (pool exhausted / invalid arg).\n'
printf ' */\n'
render_decl "uapi_connector_create"
printf '\n'
printf '/**\n'
printf ' * Health-check the connector at `slot`.\n'
printf ' * Performs a GET /health probe and updates internal state.\n'
printf ' * Returns a ConnectorState tag: UAPI_CONNECTOR_*.\n'
printf ' */\n'
render_decl "uapi_connector_health"
printf '\n'
printf '/**\n'
printf ' * Send a request to the service connector at `slot`.\n'
printf ' * `method_tag`  \xe2\x80\x94 UAPI_METHOD_* tag.\n'
printf ' * `path`        \xe2\x80\x94 null-terminated sub-path, e.g. "/api/v1/render".\n'
printf ' * `body`        \xe2\x80\x94 null-terminated JSON body (empty string for GET).\n'
printf ' * `out_buf`     \xe2\x80\x94 caller-allocated response buffer.\n'
printf ' * `out_len`     \xe2\x80\x94 size of `out_buf` in bytes.\n'
printf ' * Returns a Result tag: UAPI_OK on success, non-zero on failure.\n'
printf ' */\n'
# uapi_connector_call is always multi-line (5 args + output buffer)
printf 'uint8_t uapi_connector_call(\n'
printf '    uint8_t      slot,\n'
printf '    uint8_t      method_tag,\n'
printf '    const char  *path,\n'
printf '    const char  *body,\n'
printf '    uint8_t     *out_buf,\n'
printf '    uint32_t     out_len\n'
printf ');\n'
printf '\n'
printf '/**\n'
printf ' * Release the connector at `slot` and return it to the pool.\n'
printf ' */\n'
render_decl "uapi_connector_destroy"
printf '\n'
printf '/**\n'
printf ' * Get the current ConnectorState tag for `slot`.\n'
printf ' * Returns UAPI_CONNECTOR_DISCONNECTED if the slot is empty.\n'
printf ' */\n'
render_decl "uapi_connector_state"
printf '\n'

printf '#ifdef __cplusplus\n'
printf '}\n'
printf '#endif\n'
printf '\n'
printf '#endif /* ZIG_API_H */\n'

} > "$OUT_FILE"

printf 'gen-header: wrote %s\n' "$OUT_FILE" >&2
