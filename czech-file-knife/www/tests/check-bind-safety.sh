#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# check-bind-safety.sh — authoritative-only posture proof (issue #53,
# acceptance: "BIND example passes syntax validation and a planted
# open-recursion control is rejected").
#
# Asserts, for every named.conf* under www/dns/ (examples AND controls are
# scanned by posture_assert; controls must FAIL it):
#   * recursion no; present, and no 'recursion yes'
#   * no unrestricted allow-recursion
#   * no allow-transfer { any; }
#   * no listen-on ... { any; }
#   * no inline key/secret blocks (TSIG or otherwise)
#   * zone names restricted to reserved/documentation names
#   * no key/journal/secret FILES anywhere under www/dns/
# When bind9utils is available: real named-checkconf via a temp jail
# (directory/pid-file rewritten into it, zones copied in) and
# named-checkzone on every *.zone.

set -uo pipefail
WWW="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DNS="$WWW/dns"
FAIL=0
bad() { echo "BIND SAFETY FAIL: $*" >&2; FAIL=1; }
ok()  { echo "ok: $*"; }

posture_assert() { # $1 = named.conf file; returns 1 on any violation
    local f="$1" v=0 z
    grep -Eq '^[[:space:]]*recursion[[:space:]]+no[[:space:]]*;' "$f" \
        || { echo "  no 'recursion no;' — resolver posture forbidden" >&2; v=1; }
    grep -Eq '^[[:space:]]*recursion[[:space:]]+yes' "$f" \
        && { echo "  'recursion yes' present — OPEN RESOLVER" >&2; v=1; }
    if grep -Eq '^[[:space:]]*allow-recursion' "$f"; then
        grep -Eq '^[[:space:]]*allow-recursion[[:space:]]*\{[[:space:]]*none[[:space:]]*;' "$f" \
            || { echo "  unrestricted allow-recursion" >&2; v=1; }
    fi
    grep -Eq 'allow-transfer[[:space:]]*\{[[:space:]]*any' "$f" \
        && { echo "  allow-transfer { any; } — zone walk exposure" >&2; v=1; }
    grep -Eq 'listen-on(-v6)?[[:space:]]*(port[[:space:]]+[0-9]+[[:space:]]*)?\{[[:space:]]*any' "$f" \
        && { echo "  listen-on any — bind explicit addresses" >&2; v=1; }
    grep -Eq '^[[:space:]]*key[[:space:]]+"' "$f" \
        && { echo "  inline key block — secrets never live in the bundle" >&2; v=1; }
    grep -Eoq 'secret[[:space:]]+"' "$f" \
        && { echo "  inline secret material" >&2; v=1; }
    # Zone names must be reserved/documentation names only.
    while IFS= read -r z; do
        case "$z" in
            example.invalid|example.com|example.net|example.org|*.example.invalid|*.example|localhost|2.0.192.in-addr.arpa|*.2.0.192.in-addr.arpa|0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa) : ;;
            *) echo "  non-reserved zone name in template: $z" >&2; v=1 ;;
        esac
    done < <(sed -nE 's/^[[:space:]]*zone[[:space:]]+"([^"]+)".*$/\1/p' "$f")
    return "$v"
}

secret_file_scan() { # no key/journal/runtime material under www/dns/
    local f found=0
    while IFS= read -r f; do
        case "${f##*/}" in
            *.key|*.private|*.jnl|*.journal|*.rndc|*.jbk|tsig*|K*+*+*.key|K*+*+*.private)
                echo "  secret/runtime file under dns/: $f" >&2; found=1 ;;
        esac
    done < <(find "$DNS" -type f)
    return "$found"
}

# ── shipped examples must pass posture + real validators when available ─────
shopt -s nullglob
for conf in "$DNS"/bind9/named.conf*; do
    case "${conf##*/}" in *.control) continue ;; esac
    if posture_assert "$conf" 2>/dev/null; then
        ok "posture: ${conf#"$WWW"/}"
    else
        bad "posture violated: ${conf#"$WWW"/}"
        posture_assert "$conf" 2>&1 | sed 's/^/    /' >&2 || true
    fi
done

if secret_file_scan 2>/dev/null; then
    ok "no key/journal/secret files under www/dns/"
else
    bad "secret/runtime material found under www/dns/"
fi

if command -v named-checkconf >/dev/null 2>&1; then
    for conf in "$DNS"/bind9/named.conf*; do
        case "${conf##*/}" in *.control) continue ;; esac
        jail="$(mktemp -d)"; mkdir -p "$jail/zones" "$jail/run"
        sed -e "s|directory  \"/var/cache/bind\";|directory \"$jail\";|" \
            -e "s|pid-file   \"/run/named/named.pid\";|pid-file \"$jail/run/named.pid\";|" \
            "$conf" > "$jail/named.conf"
        cp "$DNS"/records/*.zone "$jail/zones/" 2>/dev/null || true
        if named-checkconf "$jail/named.conf" >/dev/null 2>&1; then
            ok "named-checkconf: ${conf#"$WWW"/}"
        else
            bad "named-checkconf rejected ${conf#"$WWW"/}"
        fi
        rm -rf "$jail"
    done
else
    echo "note: named-checkconf unavailable — posture grep checks only"
fi

if command -v named-checkzone >/dev/null 2>&1; then
    for zone in "$DNS"/records/*.zone; do
        origin="$(basename "$zone" .zone)"
        [ "$origin" = "2.0.192.in-addr.arpa" ] || origin="${origin%.zone}"
        if named-checkzone "$origin" "$zone" >/dev/null 2>&1; then
            ok "named-checkzone: records/$(basename "$zone")"
        else
            bad "named-checkzone rejected records/$(basename "$zone")"
        fi
    done
else
    echo "note: named-checkzone unavailable — skipped"
fi

# ── planted controls MUST be rejected ────────────────────────────────────────
for ctl in "$WWW"/tests/controls/named.conf*.control; do
    [ -f "$ctl" ] || continue
    if posture_assert "$ctl" 2>/dev/null; then
        bad "planted open-recursion control was NOT rejected: ${ctl#"$WWW"/}"
    else
        ok "planted control rejected: tests/controls/$(basename "$ctl")"
    fi
done

exit "$FAIL"
