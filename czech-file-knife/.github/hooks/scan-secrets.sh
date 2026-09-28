#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# scan-secrets.sh — local pre-push secret gate (TruffleHog).
#
# ── Why this is NOT duplicated work ─────────────────────────────────────────
# The estate runs a TWO-TIER secret defence:
#
#   CI     gitleaks, via the standards `secret-scanner-reusable.yml`
#          (gitleaks + rust-secrets + shell-secrets). Catches what reaches the
#          remote, on every pull_request and push to main.
#   LOCAL  TruffleHog — this script — before the push leaves the machine.
#
# Different detection engines at different checkpoints. The reusable's header
# retires TruffleHog "as redundant with gitleaks"; that judgement is scoped to
# CI, where running both cost twice over one population. It is not a reason to
# leave the local tier unguarded. DO NOT delete this script as duplication —
# see .github/workflows/README.adoc, "Secret scanning is single-sourced".
#
# ── Fail closed ─────────────────────────────────────────────────────────────
# A missing or non-functional scanner BLOCKS the push and prints an install
# hint. The sibling validators skip gracefully when their tooling is absent; a
# SECRET gate must not, because "skipped" and "clean" are indistinguishable in
# the output, and the machines least likely to carry the toolchain are exactly
# the ones whose pushes nobody has vetted.
# The escape hatch is unchanged and documented:   git push --no-verify
#
# ── Two measured instrument traps this script is written around ─────────────
#  1. TRUFFLEHOG EXITS 0 WHEN IT FINDS SECRETS. `--fail` is mandatory, and with
#     it the found-secrets status is 183 — NOT 1. Every test here is for
#     non-zero; never compare against 1.
#  2. PIPING A SCANNER DESTROYS ITS EXIT CODE — a pipeline reports the LAST
#     command's status. Measured: `gitleaks … | tail` returns rc=0 while
#     printing "leaks found: 1". Nothing here pipes the scanner; output is
#     captured to a file and printed after the status is read.
#
# Env overrides:
#   TRUFFLEHOG              explicit path to the binary (used by the tests)
#   K9_SECRETS_MAX_DEPTH    commits to scan for a brand-new branch (default 500)
#   K9_SECRETS_VERIFY=1     enable live credential verification (see below)

set -euo pipefail

REPO_ROOT="${INPUT_PATH:-$(git rev-parse --show-toplevel)}"
MAX_DEPTH="${K9_SECRETS_MAX_DEPTH:-500}"
ZERO="0000000000000000000000000000000000000000"

# Verification OFF by default. `--no-verification` keeps the hook offline and
# fast, and — the real reason — verification transmits candidate credentials to
# the issuing provider's API on every push. A detected-but-unverified secret
# must still block, so verification buys only false-positive reduction at the
# cost of egress. Opt in with K9_SECRETS_VERIFY=1.
VERIFY_ARGS=(--no-verification)
if [ "${K9_SECRETS_VERIFY:-0}" = "1" ]; then VERIFY_ARGS=(); fi

# ── The SonarCloud detector must be excluded, and why ───────────────────────
# TruffleHog's SonarCloud detector matches ANY bare 40-hex string. This estate
# SHA-pins every GitHub Action by doctrine, so every pin is a 40-hex string and
# every pin reads as a secret. MEASURED on a clean clone of this template:
#   24 findings, 0 verified, 100% SonarCloud, 12 distinct values, ALL exactly
#   40 hex, all in .github/workflows/ — and .github/workflows/actions.lock
#   carries one of them verbatim as `commit: 'sha1-ede1191ef…'`.
# Left in, the gate blocks every push on this repo and every inheritor of the
# template: a gate that always fires is uninstallable, and an uninstallable gate
# gets deleted. With the detector excluded the same history scans rc=0 (5,103
# chunks, 0 findings), and a planted AWS/Slack credential still returns 183.
#
# What this gives up, and what covers it: a genuine SonarCloud token is also
# 40-hex, so it is indistinguishable from a pin BY SHAPE — no path or context
# filter recovers it. CI's gitleaks tier catches it instead; measured, gitleaks
# under the estate baseline (`useDefault = true`) flags a SonarCloud token as
# `generic-api-key`, rc=1. The two tiers are complementary here by design.
DETECTOR_ARGS=(--exclude-detectors SonarCloud)

# ── Resolve the binary by INVOKING it ───────────────────────────────────────
# `command -v` is not enough: a mise shim with no pinned global version sits on
# PATH, answers `command -v` happily, and fails every actual invocation with
# "No version is set for shim". Installed is not invokable. Each candidate is
# therefore probed with `--version` and only accepted on exit 0.
probe() { [ -n "${1:-}" ] && [ -x "$1" ] && "$1" --version >/dev/null 2>&1; }

TH=""
if probe "${TRUFFLEHOG:-}"; then
  TH="$TRUFFLEHOG"
elif c="$(command -v trufflehog 2>/dev/null)" && probe "$c"; then
  TH="$c"
else
  # mise installs tree, newest version first. MISE_DATA_DIR when exported,
  # else mise's documented default. No machine-specific path is hardcoded.
  _md="${MISE_DATA_DIR:-$HOME/.local/share/mise}"
  while IFS= read -r c; do
    if probe "$c"; then TH="$c"; break; fi
  done < <(find "$_md/installs" -mindepth 3 -maxdepth 3 -type f -name trufflehog \
             -path '*trufflehog*' 2>/dev/null | sort -rV)
fi

if [ -z "$TH" ]; then
  cat >&2 <<'HINT'
[scan-secrets] BLOCKED: TruffleHog is not installed, or is a dead shim.

  This gate fails closed on purpose — a secret scanner that skips silently is
  indistinguishable from one that found nothing.

  Install (mise, as used by this estate):
      mise use -g aqua:trufflesecurity/trufflehog@3.96.0

  Or point the hook at an existing binary:
      TRUFFLEHOG=/path/to/trufflehog git push

  Emergency override (you are asserting the push carries no secrets):
      git push --no-verify
HINT
  exit 1
fi

# ── Build the scan ranges from the pre-push stdin lines ─────────────────────
# pre-push receives "<local ref> <local sha> <remote ref> <remote sha>" per ref
# and forwards them in K9_PUSH_RANGES. Scanning only the commits actually being
# pushed is both the correct population for this gate and far faster than the
# whole history (which CI already covers).
# ── Findings and scanner errors BOTH block, but are NOT the same thing ───────
# TruffleHog returns 183 for "secrets found" and other non-zero codes for "I
# could not scan" (a broken ref, an unreadable repo, a bad flag). Both must fail
# closed — an unscanned push is exactly as unvetted as an unchecked one — but
# they must be REPORTED apart. Measured here: a stale remote ref pointing at
# 0000…0 made every scan exit 1 with "upload-pack: not our ref", and a handler
# that said "Secrets detected" for any non-zero told the developer to go hunting
# for a credential that did not exist. A gate that misnames its own failure
# sends people looking in the wrong place, which is how gates get switched off.
status=0
scanned=0
found=0
errored=0
out="$(mktemp)"
trap 'rm -f "$out"' EXIT

# Run TruffleHog against a git ref/range with the configured verify/detector args.
# Takes a human-readable label ($1) and any extra trufflehog arguments, captures
# output to a file (not piped, to preserve the exit code), and sets the shared
# found/errored/status variables based on the result: 0 = clean, 183 = secrets
# found, anything else = scanner error.
scan() {
  local label="$1"; shift
  local rc=0
  # NOT piped — see trap 2 in the header.
  "$TH" git "file://$REPO_ROOT" "$@" "${VERIFY_ARGS[@]}" "${DETECTOR_ARGS[@]}" \
      --fail --no-update >"$out" 2>&1 || rc=$?
  scanned=$((scanned + 1))
  if [ "$rc" -eq 183 ]; then
    echo "[scan-secrets] FINDINGS while scanning $label:" >&2
    cat "$out" >&2
    found=1
    status=1
  elif [ "$rc" -ne 0 ]; then
    echo "[scan-secrets] SCANNER ERROR (exit $rc) while scanning $label —" >&2
    echo "[scan-secrets] this is a failure to scan, NOT a detected secret:" >&2
    cat "$out" >&2
    errored=1
    status=1
  fi
}

if [ -n "${K9_PUSH_RANGES:-}" ]; then
  while read -r local_ref local_sha remote_ref remote_sha; do
    [ -z "${local_sha:-}" ] && continue
    [ "$local_sha" = "$ZERO" ] && continue                 # branch deletion
    if [ "${remote_sha:-$ZERO}" = "$ZERO" ]; then
      scan "new branch ${local_ref:-HEAD} (last $MAX_DEPTH commits)" \
           --branch "$local_sha" --max-depth "$MAX_DEPTH"
    else
      scan "${local_ref:-HEAD} since ${remote_sha:0:12}" \
           --branch "$local_sha" --since-commit "$remote_sha"
    fi
  done <<< "$K9_PUSH_RANGES"
fi

# No ranges (hook invoked directly, or an empty push): scan the bounded tail of
# HEAD rather than reporting a pass over nothing. A gate that reports success
# having examined zero commits is the vacuity this estate keeps re-learning.
if [ "$scanned" -eq 0 ]; then
  scan "HEAD (no push ranges; last $MAX_DEPTH commits)" --max-depth "$MAX_DEPTH"
fi

if [ "$found" -ne 0 ]; then
  echo "[scan-secrets] Secrets detected in the commits being pushed." >&2
  echo "[scan-secrets] Remove them and rewrite the offending commits." >&2
  echo "[scan-secrets] Override (only if these are false positives): git push --no-verify" >&2
fi

if [ "$errored" -ne 0 ]; then
  echo "[scan-secrets] TruffleHog could not complete the scan (see above)." >&2
  echo "[scan-secrets] BLOCKED because an unscanned push is an unvetted push." >&2
  echo "[scan-secrets] Common cause: a broken local ref. Check with:  git fsck" >&2
  echo "[scan-secrets] Override (you are asserting this push carries no secrets):" >&2
  echo "[scan-secrets]     git push --no-verify" >&2
fi

if [ "$status" -ne 0 ]; then
  exit 1
fi

echo "[scan-secrets] TruffleHog clean ($scanned range(s) scanned, $("$TH" --version 2>&1 | head -1))."
exit 0
