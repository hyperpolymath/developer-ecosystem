#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# extract.sh — the thin a2ml *reader* for the arrival-pack compiler.
#
# Projects the scalar/array fields the CLAUDE.md arrival pack needs out of this
# repo's descriptive a2ml (the "descriptiles" family: CLADE/ECOSYSTEM/AGENTIC/STATE +
# anchors/ANCHOR) into a single deterministic JSON document on stdout.
#
# This is a READER only — it authors nothing. The a2ml files remain the single
# source of truth; arrival-pack.ncl renders this JSON into the CLAUDE.md region.
# Determinism (no timestamps) is required so the k9 drift check can byte-compare.
set -euo pipefail

DIR6A2="${1:-.machine_readable/descriptiles}"
CLADE="$DIR6A2/CLADE.a2ml"
ECO="$DIR6A2/ECOSYSTEM.a2ml"
AGENTIC="$DIR6A2/AGENTIC.a2ml"
STATE="$DIR6A2/STATE.a2ml"
ANCHOR="$DIR6A2/anchors/ANCHOR.a2ml"

for f in "$CLADE" "$ECO" "$AGENTIC" "$STATE" "$ANCHOR"; do
  [ -f "$f" ] || { echo "extract.sh: missing required a2ml: $f" >&2; exit 2; }
done

# scalar KEY FILE -> first `KEY = "value"` or unquoted `KEY = value` (anchored)
scalar() {
  local v
  v="$(grep -oP "^$1 = \"\K[^\"]+" "$2" | head -1 || true)"
  if [ -z "$v" ]; then
    v="$(grep -oP "^$1 = \K[^\"#]+" "$2" | head -1 | sed 's/[[:space:]]*$//' || true)"
  fi
  printf '%s' "$v"
}

# arr KEY FILE SEP -> join all quoted strings in the `KEY = [ ... ]` block
# (inline `k = ["a","b"]` or multiline). SEP is a literal multi-char string.
arr() {
  local key="$1" file="$2" sep="${3:-, }" out="" i
  local -a items
  mapfile -t items < <(
    awk -v k="$key" '
      index($0, k" = [")==1 {grab=1}
      grab {print}
      grab && /\]/ {exit}
    ' "$file" | grep -oP '"[^"]*"' | sed 's/^"//; s/"$//' || true
  )
  for i in "${!items[@]}"; do
    if [ "$i" -eq 0 ]; then out="${items[$i]}"; else out="$out$sep${items[$i]}"; fi
  done
  printf '%s' "$out"
}

# short content hash (drift provenance)
sh() { sha256sum "$1" | cut -c1-12; }

# --- IS-NOT: present only if ECOSYSTEM declares `what-this-is-not` ------------
isnot="$(arr 'what-this-is-not' "$ECO" ' · ')"
[ -n "$isnot" ] || isnot="(not yet declared — add ECOSYSTEM.what-this-is-not)"

golden_smoke="$(arr 'smoke-test-command' "$ANCHOR" ' && ')"
golden_crit="$(arr 'success-criteria' "$ANCHOR" '; ')"

jq -n \
  --arg canonical_name "$(scalar 'canonical-name' "$CLADE")" \
  --arg prefixed_name  "$(scalar 'prefixed-name' "$CLADE")" \
  --arg uuid           "$(scalar 'uuid' "$CLADE")" \
  --arg clade_primary  "$(scalar 'primary' "$CLADE")" \
  --arg clade_secondary "$(arr 'secondary' "$CLADE" ', ')" \
  --arg born           "$(scalar 'born' "$CLADE")" \
  --arg forge_gh       "$(scalar 'github' "$CLADE")" \
  --arg purpose        "$(scalar 'purpose' "$ECO")" \
  --arg isnot          "$isnot" \
  --arg pipeline_pos   "$(scalar 'position' "$ECO")" \
  --arg chain          "$(scalar 'chain' "$ECO")" \
  --arg coordination   "$(scalar 'coordination' "$ECO")" \
  --arg phase          "$(scalar 'phase' "$STATE")" \
  --arg maturity       "$(scalar 'maturity' "$STATE")" \
  --arg completion     "$(scalar 'completion-percentage' "$STATE")" \
  --arg status         "$(scalar 'status' "$STATE")" \
  --arg golden_smoke   "$golden_smoke" \
  --arg golden_crit    "$golden_crit" \
  --arg h_clade        "$(sh "$CLADE")" \
  --arg h_eco          "$(sh "$ECO")" \
  --arg h_agentic      "$(sh "$AGENTIC")" \
  --arg h_state        "$(sh "$STATE")" \
  --arg h_anchor       "$(sh "$ANCHOR")" \
  '$ARGS.named'
