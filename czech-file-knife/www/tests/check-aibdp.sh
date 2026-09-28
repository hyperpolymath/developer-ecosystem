#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# check-aibdp.sh — validate www/.well-known/aibdp.json (issue #53:
# "experimental files are labelled as such"; declaration-only by default).
# Requires jq; skips with a note when absent.

set -uo pipefail
WWW="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
bad() { echo "AIBDP FAIL: $*" >&2; FAIL=1; }
ok()  { echo "ok: $*"; }

if ! command -v jq >/dev/null 2>&1; then
    echo "note: jq unavailable — AIBDP checks skipped"
    exit 0
fi

validate_aibdp() { # $1 = aibdp json; returns 1 on any violation
    local f="$1" v=0 st
    jq empty "$f" 2>/dev/null || { echo "  not valid JSON" >&2; return 1; }
    [ "$(jq -r '.aibdp_version // empty' "$f")" = "0.2" ] \
        || { echo "  aibdp_version must be 0.2" >&2; v=1; }
    jq -e '.contact | test("^(mailto:|https?:)")' "$f" >/dev/null \
        || { echo "  contact must be a mailto:/http(s) URI" >&2; v=1; }
    # Experimental labelling (declaration-only provenance must be visible).
    st="$(jq -r '.status // empty' "$f")"
    case "$st" in *experimental*declaration-only*) : ;;
        *) echo "  status must label the file experimental AND declaration-only" >&2; v=1 ;; esac
    # Policies vocabulary + rationale discipline.
    jq -e '.policies | type == "object" and length >= 1' "$f" >/dev/null \
        || { echo "  policies must be a non-empty object" >&2; v=1; }
    while IFS=$'\t' read -r name status; do
        case "$status" in allowed|conditional|disallowed) : ;;
            *) echo "  policies.$name.status not in {allowed,conditional,disallowed}: $status" >&2; v=1 ;; esac
        jq -e --arg n "$name" '.policies[$n].rationale | type == "string" and length > 0' "$f" >/dev/null \
            || { echo "  policies.$name missing rationale" >&2; v=1; }
        if [ "$status" = "conditional" ]; then
            jq -e --arg n "$name" '.policies[$n].conditions | type == "array" and length >= 1' "$f" >/dev/null \
                || { echo "  policies.$name is conditional without conditions" >&2; v=1; }
        fi
    done < <(jq -r '.policies | to_entries[] | [.key, (.value.status // "")] | @tsv' "$f")
    # Enforcement: absent or mechanism "none" — never http_430.
    if jq -e 'has("enforcement")' "$f" >/dev/null; then
        local mech; mech="$(jq -r '.enforcement.mechanism // "none"' "$f")"
        [ "$mech" = "none" ] \
            || { echo "  enforcement.mechanism is '$mech' — this bundle is declaration-only" >&2; v=1; }
    fi
    return "$v"
}

consistency_with_ai_txt() { # declaration must not contradict ai.txt
    local ai="$WWW/.well-known/ai.txt" f="$WWW/.well-known/aibdp.json" v=0
    [ -f "$ai" ] || return 0
    local want got
    for pair in "Disallow-Training:training" "Disallow-Summarization:summarization" "Disallow-Generation:generation"; do
        key="${pair%%:*}"; field="${pair##*:}"
        want="$(grep -m1 "^$key:" "$ai" | awk '{print $2}')"
        got="$(jq -r --arg n "$field" '.policies[$n].status // "absent"' "$f")"
        case "$want" in
            yes) [ "$got" = "disallowed" ] || { echo "  ai.txt $key yes but aibdp policies.$field.status=$got" >&2; v=1; } ;;
            no)  [ "$got" = "allowed" ]    || { echo "  ai.txt $key no but aibdp policies.$field.status=$got" >&2; v=1; } ;;
        esac
    done
    return "$v"
}

MAIN="$WWW/.well-known/aibdp.json"
AI_FILE="$WWW/.well-known/ai.txt"
# The AIBDP declaration is OPTIONAL (issue #53). A repository that does not
# make it has no AIBDP claims to validate, and demanding the file regardless is
# what made this check fail in every repository the .well-known/ stage-5
# migration reached: the migration moves ai.txt and security.txt, and aibdp.json
# was never part of it. Silence is not a violation — but ai.txt REFERRING to
# aibdp while the file is absent is a real contradiction, and still fails below.
if [ ! -f "$MAIN" ] && ! grep -qi 'aibdp' "$AI_FILE" 2>/dev/null; then
    echo "SKIP: no AIBDP declaration here (www/.well-known/aibdp.json absent and"
    echo "SKIP:   ai.txt makes no aibdp claim) — there is nothing to validate"
    exit 77
fi
if [ ! -f "$MAIN" ]; then
    bad "ai.txt references aibdp but www/.well-known/aibdp.json is missing"
elif validate_aibdp "$MAIN" 2>/dev/null; then
    ok "aibdp.json valid, experimental + declaration-only labelled"
else
    bad "aibdp.json invalid"
    validate_aibdp "$MAIN" 2>&1 | sed 's/^/    /' >&2 || true
fi

if consistency_with_ai_txt 2>/dev/null; then
    ok "aibdp.json consistent with ai.txt stances"
else
    bad "aibdp.json contradicts ai.txt"
    consistency_with_ai_txt 2>&1 | sed 's/^/    /' >&2 || true
fi

shopt -s nullglob
for c in "$WWW"/tests/controls/aibdp-*.control.json; do
    if validate_aibdp "$c" 2>/dev/null; then
        bad "planted control was NOT rejected: tests/controls/$(basename "$c")"
    else
        ok "planted control rejected: tests/controls/$(basename "$c")"
    fi
done

exit "$FAIL"
