#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# check-publication-boundary.sh — prove the publication boundary (issue #53).
#
# Modes:
#   (no args)          bundle invariants + planted-control self-test:
#                      A. schemas/publishable-paths.txt declares exactly
#                         www/public/ and www/.well-known/;
#                      B. every webservers/ example keeps its document root
#                         OUTSIDE the bundle and denies all eight operational
#                         categories; every planted *.control config violates
#                         B and must be rejected;
#                      C. the planted good stage passes the stage scan and
#                         the planted bad stage is rejected.
#   --stage <dir>      scan a staged deployment directory (as produced by
#                      runbooks/deploy.adoc) and exit non-zero on any
#                      operational material. This is the check the runbook
#                      and CI invoke before anything reaches a docroot.
#
# Operational categories (never publishable): dns tls security_headers
# webservers profiles schemas tests runbooks. Secret/runtime patterns are
# rejected anywhere in a stage.

set -uo pipefail

WWW="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORBIDDEN_DIRS="dns tls security_headers webservers profiles schemas tests runbooks"
FAIL=0
bad() { echo "BOUNDARY FAIL: $*" >&2; FAIL=1; }
ok()  { echo "ok: $*"; }

# ── stage scanner ────────────────────────────────────────────────────────────
scan_stage() { # $1 = staged dir; returns 1 on any violation (messages to stderr)
    local root="$1" v f base found=0
    [ -d "$root" ] || { echo "stage scan: $root is not a directory" >&2; return 1; }
    for v in $FORBIDDEN_DIRS; do
        if [ -e "$root/$v" ]; then
            echo "stage scan: operational category present: $v/" >&2; found=1
        fi
    done
    while IFS= read -r f; do
        base="${f##*/}"
        case "$base" in
            *.key|*.pem|*.p12|*.pfx|*.jks|*.rndc|*.jbk|*.control|\
            named.conf*|rndc.conf*|tsig*|*.zone|*.journal|*.pid|*.log)
                echo "stage scan: operational/secret material present: ${f#"$root"/}" >&2
                found=1 ;;
        esac
    done < <(find "$root" -type f)
    return "$found"
}

# ── config scanner ───────────────────────────────────────────────────────────
scan_config() { # $1 = server config; returns 1 if it could publish the bundle
    local f="$1" r found=0 v
    # Document-root directives must not point at the bundle or into it.
    while IFS= read -r r; do
        [ -n "$r" ] || continue
        case "$r" in
            */www|*/www/|*/www/*|www|www/)
                echo "config scan: document root points into the www/ bundle: $r" >&2; found=1 ;;
            *dns*|*tls*|*security_headers*|*webservers*|*profiles*|*schemas*|*tests*|*runbooks*)
                echo "config scan: document root points at operational material: $r" >&2; found=1 ;;
        esac
    done < <(sed -nE 's/^[[:space:]]*root[[:space:]]+\*[[:space:]]*([^;[:space:]]+).*$/\1/p
                      s/^[[:space:]]*root[[:space:]]+([^;[:space:]]+).*$/\1/p
                      s/^[[:space:]]*DocumentRoot[[:space:]]+([^[:space:]]+).*$/\1/p' "$f")
    # Every operational category must be named in the config (deny coverage)…
    for v in $FORBIDDEN_DIRS; do
        grep -q "$v" "$f" || { echo "config scan: no deny coverage for category '$v'" >&2; found=1; }
    done
    # …and at least one explicit deny verb must be present.
    grep -qE 'respond @operational 404|return 404;|Require all denied' "$f" \
        || { echo "config scan: no explicit deny directive" >&2; found=1; }
    return "$found"
}

# ── --stage mode ─────────────────────────────────────────────────────────────
if [ "${1:-}" = "--stage" ]; then
    [ -n "${2:-}" ] || { echo "usage: $0 --stage <dir>" >&2; exit 2; }
    if scan_stage "$2"; then
        echo "publication boundary: stage $2 is clean"
        exit 0
    else
        echo "publication boundary: stage $2 REJECTED" >&2
        exit 1
    fi
fi

# The publication boundary only exists once a repository PUBLISHES something.
# The bundle's schemas/, webservers/, dns/ and tls/ trees are what a site is
# built from; a library that serves no document root has no boundary to police
# and no shipped config to audit. Sections A, B and C all test that tree, so
# the guard is one test for all three rather than a rewrite of each.
#
# This is the guard whose absence planted three failing checks into every
# swept repository measured on 2026-09-18. `--stage <dir>` mode above is
# unaffected: it is invoked by the deploy runbook against a real stage.
if [ ! -f "$WWW/schemas/publishable-paths.txt" ] && [ ! -d "$WWW/webservers" ]; then
    echo "SKIP: this repository publishes nothing (no www/schemas/ and no"
    echo "SKIP:   www/webservers/) — the publication boundary does not apply"
    exit 77
fi

# ── A. declaration ───────────────────────────────────────────────────────────
DECL="$WWW/schemas/publishable-paths.txt"
if [ ! -f "$DECL" ]; then
    bad "schemas/publishable-paths.txt missing"
else
    declared="$(grep -v '^#' "$DECL" | grep -v '^[[:space:]]*$' | sort)"
    expected="$(printf 'www/.well-known/\nwww/public/')"
    if [ "$declared" = "$expected" ]; then
        ok "publishable-paths.txt declares exactly www/public/ + www/.well-known/"
    else
        bad "publishable-paths.txt must declare exactly the two publishable categories; found: $(echo "$declared" | tr '\n' ' ')"
    fi
fi

# ── B. shipped configs pass; planted control configs fail ───────────────────
shopt -s nullglob
for cfg in "$WWW"/webservers/*/*.example; do
    if scan_config "$cfg" 2>/dev/null; then
        ok "config implements the boundary: ${cfg#"$WWW"/}"
    else
        bad "shipped config violates the boundary: ${cfg#"$WWW"/}"
        scan_config "$cfg" 2>&1 | sed 's/^/    /' >&2 || true
    fi
done
for ctl in "$WWW"/tests/controls/*.control; do
    if scan_config "$ctl" 2>/dev/null; then
        bad "planted control was NOT rejected (control is broken): ${ctl#"$WWW"/}"
    else
        ok "planted control rejected: ${ctl#"$WWW"/}"
    fi
done

# ── C. staged-tree controls ──────────────────────────────────────────────────
if scan_stage "$WWW/tests/controls/good-deploy" 2>/dev/null; then
    ok "planted good stage accepted"
else
    bad "planted good stage was rejected (control is broken)"
fi
if scan_stage "$WWW/tests/controls/bad-deploy" 2>/dev/null; then
    bad "planted bad stage was NOT rejected (boundary is unenforced)"
else
    ok "planted bad stage rejected"
fi

exit "$FAIL"
