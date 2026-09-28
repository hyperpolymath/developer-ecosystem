#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# generate.sh — compile the repo's CLAUDE.md arrival pack.
#   extract.sh (a2ml -> JSON)  ->  arrival-pack.ncl (Nickel projection)  ->  splice.
#
# The generated region lives between the ARRIVAL-PACK:BEGIN/END markers. Anything
# OUTSIDE the markers in CLAUDE.md is hand-authorable and is preserved verbatim.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
AP="$ROOT/.machine_readable/arrival-pack"
TARGET="$ROOT/CLAUDE.md"

bash "$AP/extract.sh" "$ROOT/.machine_readable/descriptiles" > "$AP/claude-md-data.json"
nickel export --format raw "$AP/arrival-pack.ncl" > "$AP/.region.tmp"

if [ -f "$TARGET" ] && grep -q 'ARRIVAL-PACK:BEGIN' "$TARGET"; then
  # Replace the marked block in place, keeping human content around it.
  awk '
    FNR==NR { region = region $0 ORS; next }
    /<!-- ARRIVAL-PACK:BEGIN/ { printf "%s", region; skip=1; next }
    /ARRIVAL-PACK:END/        { skip=0; next }
    !skip { print }
  ' "$AP/.region.tmp" "$TARGET" > "$TARGET.tmp"
  mv "$TARGET.tmp" "$TARGET"
else
  # Fresh file: SPDX header + a short hand-authorable preamble above the region.
  # Both live OUTSIDE the markers, so regeneration preserves them.
  {
    echo "<!--"
    echo "SPDX-License-Identifier: MPL-2.0"
    echo "SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>"
    echo "-->"
    echo "<!-- Hand-authored notes may go ABOVE or BELOW the generated region. -->"
    echo "<!-- The region between the ARRIVAL-PACK markers is generated from this"
    echo "     repo's a2ml by \`just claude-md\` — do not hand-edit it. -->"
    echo
    cat "$AP/.region.tmp"
  } > "$TARGET"
fi

rm -f "$AP/.region.tmp"
echo "claude-md: wrote $TARGET"
