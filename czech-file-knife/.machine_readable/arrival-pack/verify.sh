#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# verify.sh — drift check for the CLAUDE.md arrival pack (the runnable side of
# claude-md.k9.ncl). Regenerates the region from a2ml and byte-compares it to the
# committed region. Non-zero exit on drift or hand-edit. Wire into CI/pre-commit.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
AP="$ROOT/.machine_readable/arrival-pack"
TARGET="$ROOT/CLAUDE.md"

[ -f "$TARGET" ] || { echo "DRIFT: CLAUDE.md missing — run \`just claude-md\`"; exit 1; }

bash "$AP/extract.sh" "$ROOT/.machine_readable/descriptiles" > "$AP/claude-md-data.json"
fresh="$(nickel export --format raw "$AP/arrival-pack.ncl")"
committed="$(awk '/<!-- ARRIVAL-PACK:BEGIN/{f=1} f{print} /ARRIVAL-PACK:END/{f=0}' "$TARGET")"

if [ "$fresh" = "$committed" ]; then
  echo "OK: CLAUDE.md arrival pack is in sync with a2ml."
else
  echo "DRIFT: CLAUDE.md arrival-pack region is stale or hand-edited."
  echo "       Run \`just claude-md\` to regenerate. Diff (committed → fresh):"
  diff <(printf '%s\n' "$committed") <(printf '%s\n' "$fresh") || true
  exit 1
fi
