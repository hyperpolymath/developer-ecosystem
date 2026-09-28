#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# verify.sh — the Yard-tier drift gate for the coaptation receipt (the runnable
# side of coapt.k9.ncl). Regenerates the receipt from the contractiles +
# descriptiles and byte-compares it to the committed receipts/latest.a2ml.
# Non-zero exit on drift or hand-edit. Wire into CI/pre-commit.
#
# The receipt is a drift-checked PROJECTION: if the normative set-point or the
# descriptive self-model changed without re-running `just coapt`, this fails —
# the reading on record no longer matches reality.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
CO="$ROOT/.machine_readable/coaptation"
TARGET="$CO/receipts/latest.a2ml"

[ -f "$TARGET" ] || { echo "DRIFT: coaptation receipt missing — run \`just coapt\`"; exit 1; }

bash "$CO/extract-clauses.sh" "$ROOT/.machine_readable/contractiles" > "$CO/clauses.json"
bash "$CO/extract-facts.sh"   "$ROOT/.machine_readable/descriptiles"           > "$CO/facts.json"

fresh="$(nickel export --format raw "$CO/coapt.ncl")"
committed="$(cat "$TARGET")"

if [ "$fresh" = "$committed" ]; then
  echo "OK: coaptation receipt is in sync with the contractiles + descriptiles."
else
  echo "DRIFT: coaptation receipt is stale (contractiles/descriptiles changed, or receipt hand-edited)."
  echo "       Run \`just coapt\` to regenerate. Diff (committed → fresh):"
  diff <(printf '%s\n' "$committed") <(printf '%s\n' "$fresh") || true
  exit 1
fi
