#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# check-migration.sh — prove scripts/migrate-wellknown-to-www.sh honours the
# behaviours stage 5 (#119) depends on (czech-file-knife#53 acceptance:
# "Migration handles identical, missing and divergent root/www copies without
# data loss"). Each scenario runs in a throwaway git repository.
#
# Scenarios 1-3 are the original four-scenario contract from #106. Scenarios
# 4-8 cover the stage 5 additions: the sweep is unattended, so a divergent
# copy must be quarantined rather than left to halt the batch — loudly, and
# with the old in-place contract still available under --in-place.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATOR="$REPO_ROOT/scripts/migrate-wellknown-to-www.sh"
# This check tests the MIGRATOR, not the repository. The migrator performs the
# one-time root .well-known/ -> www/.well-known/ move (issue #119) and is
# template-side tooling: a repository that has already been migrated has
# nothing for it to do and no business carrying it. A repository without it has
# nothing to test, so this is a SKIP, not a failure. Shipping a check that
# fails in every repository it reaches is how a suite stops being read.
if [ ! -f "$MIGRATOR" ]; then
    echo "SKIP: scripts/migrate-wellknown-to-www.sh absent here — this check tests"
    echo "SKIP:   the template-side migrator, which this repository does not carry"
    exit 77
fi

fail=0
ok()   { echo "ok: $1"; }
bad()  { echo "FAIL: $1" >&2; fail=1; }

scenario() { # name -> fresh git repo path on stdout
    local dir; dir="$(mktemp -d)"
    git -C "$dir" init -q
    git -C "$dir" config user.email t@example.invalid
    git -C "$dir" config user.name t
    echo "$dir"
}
commit_all() { git -C "$1" add -A >/dev/null && git -C "$1" commit -qm fixture; }

# The quarantine directory is named for the UTC date, so a scenario must read
# the same clock the migrator will.
qdir() { echo "www/.legacy-well-known-$(date -u +%Y%m%d)"; }

# ── 1. identical copies: root removed, www kept, exit 0 ─────────────────────
d="$(scenario)"
mkdir -p "$d/.well-known" "$d/www/.well-known"
printf 'Contact: mailto:s@example.invalid\n' | tee "$d/.well-known/security.txt" > "$d/www/.well-known/security.txt"
commit_all "$d"
if (cd "$d" && bash "$MIGRATOR" >/dev/null); then
    if [ ! -e "$d/.well-known/security.txt" ] && [ -f "$d/www/.well-known/security.txt" ]; then
        ok "identical -> root removed, www kept"
    else
        bad "identical scenario left wrong tree"
    fi
else
    bad "identical scenario exited non-zero"
fi
rm -rf "$d"

# ── 2. root-only: moved into www, exit 0 ─────────────────────────────────────
d="$(scenario)"
mkdir -p "$d/.well-known/groove"
printf '{"service_id":"x"}\n' > "$d/.well-known/groove/manifest.json"
printf 'User-Agent: *\n' > "$d/.well-known/ai.txt"
commit_all "$d"
if (cd "$d" && bash "$MIGRATOR" >/dev/null); then
    if [ -f "$d/www/.well-known/groove/manifest.json" ] && [ -f "$d/www/.well-known/ai.txt" ] \
       && [ ! -d "$d/.well-known" ]; then
        ok "root-only -> moved (nested dirs too)"
    else
        bad "root-only move incomplete"
    fi
else
    bad "root-only scenario exited non-zero"
fi
rm -rf "$d"

# ── 3. www-only (no root): no-op, exit 0 ─────────────────────────────────────
d="$(scenario)"
mkdir -p "$d/www/.well-known"
printf 'Contact: mailto:s@example.invalid\n' > "$d/www/.well-known/security.txt"
commit_all "$d"
if (cd "$d" && bash "$MIGRATOR" >/dev/null) && [ -f "$d/www/.well-known/security.txt" ]; then
    ok "www-only -> no-op"
else
    bad "www-only scenario damaged tree or exited non-zero"
fi
rm -rf "$d"

# ── 4. divergent, default: root copy QUARANTINED, www untouched, exit 0 ──────
# The sweep is unattended, so this must not halt: the batch continues and the
# report names every quarantined file.
d="$(scenario)"
mkdir -p "$d/.well-known" "$d/www/.well-known"
printf 'Contact: mailto:old@example.invalid\n' > "$d/.well-known/security.txt"
printf 'Contact: mailto:new@example.invalid\n' > "$d/www/.well-known/security.txt"
commit_all "$d"
if (cd "$d" && bash "$MIGRATOR" >/dev/null 2>&1); then
    Q="$d/$(qdir)"
    if [ -f "$Q/security.txt" ] && grep -q old "$Q/security.txt" \
       && [ -f "$d/www/.well-known/security.txt" ] && grep -q new "$d/www/.well-known/security.txt" \
       && [ ! -e "$d/.well-known/security.txt" ]; then
        ok "divergent -> root copy quarantined, www copy untouched, exit 0"
    else
        bad "divergent scenario lost, overwrote or misplaced content"
    fi
else
    bad "divergent scenario must exit 0 by default (batch sweeps depend on it)"
fi
rm -rf "$d"

# ── 5. divergent, --in-place: BOTH preserved where they are, exit 1 ──────────
# The pre-stage-5 contract, kept for hand resolution.
d="$(scenario)"
mkdir -p "$d/.well-known" "$d/www/.well-known"
printf 'Contact: mailto:old@example.invalid\n' > "$d/.well-known/security.txt"
printf 'Contact: mailto:new@example.invalid\n' > "$d/www/.well-known/security.txt"
commit_all "$d"
if (cd "$d" && bash "$MIGRATOR" --in-place >/dev/null 2>&1); then
    bad "divergent --in-place must exit non-zero"
else
    if [ -f "$d/.well-known/security.txt" ] && [ -f "$d/www/.well-known/security.txt" ] \
       && grep -q old "$d/.well-known/security.txt" && grep -q new "$d/www/.well-known/security.txt"; then
        ok "divergent --in-place -> both preserved, non-zero exit"
    else
        bad "divergent --in-place lost or overwrote content"
    fi
fi
rm -rf "$d"

# ── 6. divergent, --strict: quarantined AND non-zero exit ────────────────────
d="$(scenario)"
mkdir -p "$d/.well-known" "$d/www/.well-known"
printf 'Contact: mailto:old@example.invalid\n' > "$d/.well-known/security.txt"
printf 'Contact: mailto:new@example.invalid\n' > "$d/www/.well-known/security.txt"
commit_all "$d"
if (cd "$d" && bash "$MIGRATOR" --strict >/dev/null 2>&1); then
    bad "divergent --strict must exit non-zero"
else
    if [ -f "$d/$(qdir)/security.txt" ] && [ ! -e "$d/.well-known/security.txt" ]; then
        ok "divergent --strict -> quarantined and non-zero exit"
    else
        bad "divergent --strict did not quarantine"
    fi
fi
rm -rf "$d"

# ── 7. --dry-run: reports, changes nothing, exit 0 ───────────────────────────
d="$(scenario)"
mkdir -p "$d/.well-known" "$d/www/.well-known"
printf 'Contact: mailto:old@example.invalid\n' > "$d/.well-known/security.txt"
printf 'Contact: mailto:new@example.invalid\n' > "$d/www/.well-known/security.txt"
commit_all "$d"
before="$(cd "$d" && git status --porcelain | sort)"
if (cd "$d" && bash "$MIGRATOR" --dry-run >/dev/null 2>&1); then
    after="$(cd "$d" && git status --porcelain | sort)"
    if [ "$before" = "$after" ] && [ -f "$d/.well-known/security.txt" ] \
       && [ ! -d "$d/$(qdir)" ]; then
        ok "--dry-run -> nothing written"
    else
        bad "--dry-run mutated the tree"
    fi
else
    bad "--dry-run must exit 0 even when content diverges"
fi
rm -rf "$d"

# ── 8. quarantine never overwrites: a taken name gets the next free suffix ───
d="$(scenario)"
mkdir -p "$d/.well-known" "$d/www/.well-known" "$d/$(qdir)"
printf 'Contact: mailto:old@example.invalid\n' > "$d/.well-known/security.txt"
printf 'Contact: mailto:new@example.invalid\n' > "$d/www/.well-known/security.txt"
printf 'PRIOR QUARANTINE — must survive\n' > "$d/$(qdir)/security.txt"
commit_all "$d"
if (cd "$d" && bash "$MIGRATOR" >/dev/null 2>&1); then
    if grep -q 'PRIOR QUARANTINE' "$d/$(qdir)/security.txt" \
       && [ -f "$d/$(qdir)/security.txt.1" ] && grep -q old "$d/$(qdir)/security.txt.1"; then
        ok "quarantine collision -> prior file preserved, new one suffixed .1"
    else
        bad "quarantine collision overwrote an existing file"
    fi
else
    bad "quarantine collision scenario exited non-zero"
fi
rm -rf "$d"

# ── 9. --report: machine-readable TSV for batch drivers ──────────────────────
d="$(scenario)"
mkdir -p "$d/.well-known" "$d/www/.well-known"
printf 'Contact: mailto:old@example.invalid\n' > "$d/.well-known/security.txt"      # divergent -> quarantined
printf 'Contact: mailto:new@example.invalid\n' > "$d/www/.well-known/security.txt"
printf 'User-Agent: *\n' > "$d/.well-known/ai.txt"                                   # root-only -> moved
printf 'User-Agent: *\n' > "$d/www/.well-known/humans.txt"                           # identical -> deduped
printf 'User-Agent: *\n' > "$d/.well-known/humans.txt"
commit_all "$d"
if (cd "$d" && bash "$MIGRATOR" --report migrate.tsv >/dev/null 2>&1); then
    if [ -f "$d/migrate.tsv" ] \
       && grep -qP '^quarantined\tsecurity.txt\t' "$d/migrate.tsv" \
       && grep -qP '^moved\tai.txt\t' "$d/migrate.tsv" \
       && grep -qP '^deduped\thumans.txt\t' "$d/migrate.tsv"; then
        ok "--report -> TSV records quarantined/moved/deduped per file"
    else
        bad "--report TSV missing or incomplete"
    fi
else
    bad "--report scenario exited non-zero"
fi
rm -rf "$d"

exit "$fail"
