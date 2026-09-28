#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# check-profiles.sh — explicit-composition proof (issue #53 acceptance:
# "Profiles compose explicitly and can be enabled/disabled independently";
# "Consent-aware profile defaults to declaration/observe-only and cannot
# silently enable 430").
#
# Any profile that STATES an enforcement/auto-start flag must state it as
# false; the consent and DNS profiles (and full-expert) MUST state them —
# absence is as much a violation as `true`, so a flag can never be
# smuggled in by deletion.

set -uo pipefail
WWW="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$WWW/.." && pwd)"
FAIL=0
bad() { echo "PROFILE FAIL: $*" >&2; FAIL=1; }
ok()  { echo "ok: $*"; }

assert_profile() { # $1 = profile toml; returns 1 on any violation
    local f="$1" v=0 prof c
    grep -Eq '^profile = "' "$f" || { echo "  missing 'profile' key" >&2; v=1; }
    grep -Eq '^version = "' "$f" || { echo "  missing 'version' key" >&2; v=1; }
    grep -Eq '^status = "'  "$f" || { echo "  missing 'status' key" >&2; v=1; }
    prof="$(sed -nE 's/^profile = "([^"]+)".*/\1/p' "$f" | head -1)"

    # Flags: stated -> must be false; required by role -> must be present.
    if grep -q '^enforcement_http_430' "$f"; then
        grep -Eq '^enforcement_http_430 = false$' "$f" \
            || { echo "  enforcement_http_430 stated but not false — 430 cannot be silently enabled" >&2; v=1; }
    fi
    if grep -q '^auto_start_daemon' "$f"; then
        grep -Eq '^auto_start_daemon = false$' "$f" \
            || { echo "  auto_start_daemon stated but not false — no daemon may auto-start" >&2; v=1; }
    fi
    case "$prof" in
        consent-aware-web|full-expert)
            grep -Eq '^enforcement_http_430 = false$' "$f" \
                || { echo "  $prof must carry enforcement_http_430 = false explicitly" >&2; v=1; } ;;
    esac
    case "$prof" in
        authoritative-dns|full-expert)
            grep -Eq '^auto_start_daemon = false$' "$f" \
                || { echo "  $prof must carry auto_start_daemon = false explicitly" >&2; v=1; } ;;
    esac
    case "$prof" in
        *rogue*|*control*) : ;;  # planted controls need not satisfy role rules beyond the flags
    esac

    # full-expert composes EXACTLY the four, explicitly.
    if [ "$prof" = "full-expert" ]; then
        local inc; inc="$(sed -nE 's/^includes = \[(.*)\].*/\1/p' "$f")"
        for want in baseline-site consent-aware-web authoritative-dns privacy-enhanced; do
            case "$inc" in *"$want"*) : ;; *) echo "  full-expert.includes omits $want" >&2; v=1 ;; esac
        done
    fi

    # Every component path must exist in the bundle.
    # Process substitution (not a pipe) so violations set v in THIS shell;
    # `|| true` around grep so an empty array is not a pipefail "failure".
    while IFS= read -r c; do
        [ -n "$c" ] || continue
        [ -e "$REPO/$c" ] || { echo "  component path does not exist: $c" >&2; v=1; }
    done < <(sed -nE 's/^components = \[(.*)\].*/\1/p' "$f" | { grep -o '"[^"]*"' || true; } | tr -d '"')

    # requires/includes must resolve to sibling profile files.
    for key in requires includes; do
        while IFS= read -r c; do
            [ -n "$c" ] || continue
            [ -f "$WWW/profiles/$c.toml" ] || { echo "  $key references missing profile: $c" >&2; v=1; }
        done < <(sed -nE "s/^$key = \[(.*)\].*/\1/p" "$f" | { grep -o '"[^"]*"' || true; } | tr -d '"')
    done
    return "$v"
}

shopt -s nullglob
for p in "$WWW"/profiles/*.toml; do
    if assert_profile "$p" 2>/dev/null; then
        ok "profile valid: profiles/$(basename "$p")"
    else
        bad "profile invalid: profiles/$(basename "$p")"
        assert_profile "$p" 2>&1 | sed 's/^/    /' >&2 || true
    fi
done
for c in "$WWW"/tests/controls/profile-*.control.toml; do
    if assert_profile "$c" 2>/dev/null; then
        bad "planted control was NOT rejected: tests/controls/$(basename "$c")"
    else
        ok "planted control rejected: tests/controls/$(basename "$c")"
    fi
done

exit "$FAIL"
