#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# extract-facts.sh — the DESCRIPTIVE-side atomiser for Coaptation.
#
# Step 1 of the build path (descriptile half): give each descriptile a fact-list
# with STABLE IDs. Reads this repo's descriptive a2ml (the "descriptiles" family:
# CLADE/STATE/ECOSYSTEM/AGENTIC + anchors/ANCHOR) and projects the fields that can
# bear witness to contractile obligations into one deterministic JSON document.
#
# The scalar/arr/sh helpers are the same ones proven in arrival-pack/extract.sh.
# READER only — authors nothing; the a2ml files remain the single source of truth.
#
# Output (stdout): { "facts": [ {id,family,key,value,present} ... ],
#                   "provenance": { <family>: <hash> } }
set -euo pipefail

DIR6A2="${1:-.machine_readable/descriptiles}"
CLADE="$DIR6A2/CLADE.a2ml"
STATE="$DIR6A2/STATE.a2ml"
ECO="$DIR6A2/ECOSYSTEM.a2ml"
AGENTIC="$DIR6A2/AGENTIC.a2ml"
ANCHOR="$DIR6A2/anchors/ANCHOR.a2ml"

for f in "$CLADE" "$STATE" "$ECO" "$AGENTIC" "$ANCHOR"; do
  [ -f "$f" ] || { echo "extract-facts.sh: missing required a2ml: $f" >&2; exit 2; }
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

# id <TAB> value rows. Empty value => present:false in jq below.
emit() { printf '%s\t%s\n' "$1" "$2"; }

rows="$(
  # --- CLADE: identity / lineage ---
  emit 'clade.uuid'             "$(scalar 'uuid' "$CLADE")"
  emit 'clade.canonical-name'   "$(scalar 'canonical-name' "$CLADE")"
  emit 'clade.prefixed-name'    "$(scalar 'prefixed-name' "$CLADE")"
  emit 'clade.primary'          "$(scalar 'primary' "$CLADE")"
  emit 'clade.born'             "$(scalar 'born' "$CLADE")"
  emit 'clade.forge-github'     "$(scalar 'github' "$CLADE")"
  # --- STATE: where things are now ---
  emit 'state.status'                 "$(scalar 'status' "$STATE")"
  emit 'state.phase'                  "$(scalar 'phase' "$STATE")"
  emit 'state.maturity'               "$(scalar 'maturity' "$STATE")"
  emit 'state.completion-percentage'  "$(scalar 'completion-percentage' "$STATE")"
  emit 'state.open-warnings'          "$(scalar 'open-warnings' "$STATE")"
  emit 'state.open-failures'          "$(scalar 'open-failures' "$STATE")"
  emit 'state.last-result'            "$(scalar 'last-result' "$STATE")"
  # --- ECOSYSTEM: where it sits + IS-NOT boundary ---
  emit 'ecosystem.type'             "$(scalar 'type' "$ECO")"
  emit 'ecosystem.position'         "$(scalar 'position' "$ECO")"
  emit 'ecosystem.coordination'     "$(scalar 'coordination' "$ECO")"
  emit 'ecosystem.what-this-is-not' "$(arr 'what-this-is-not' "$ECO" ' · ')"
  # --- AGENTIC: may I act / integrity posture ---
  emit 'agentic.fail-closed'                       "$(scalar 'fail-closed' "$AGENTIC")"
  emit 'agentic.allow-silent-skip'                 "$(scalar 'allow-silent-skip' "$AGENTIC")"
  emit 'agentic.require-evidence-per-step'         "$(scalar 'require-evidence-per-step' "$AGENTIC")"
  emit 'agentic.release-claim-requires-hard-pass'  "$(scalar 'release-claim-requires-hard-pass' "$AGENTIC")"
  emit 'agentic.default-mode'                      "$(scalar 'default-mode' "$AGENTIC")"
  # --- ANCHOR: semantic authority + golden path ---
  emit 'anchor.authority'            "$(scalar 'authority' "$ANCHOR")"
  emit 'anchor.policy'               "$(scalar 'policy' "$ANCHOR")"
  emit 'anchor.project'              "$(scalar 'project' "$ANCHOR")"
  emit 'anchor.golden-path'          "$(arr 'smoke-test-command' "$ANCHOR" ' && ')"
  emit 'anchor.success-criteria'     "$(arr 'success-criteria' "$ANCHOR" '; ')"
  emit 'anchor.must-have-anchor'     "$(scalar 'must-have-anchor' "$ANCHOR")"
  emit 'anchor.must-have-golden-path' "$(scalar 'must-have-golden-path' "$ANCHOR")"
)"

printf '%s\n' "$rows" | jq -R -s \
  --arg clade     "$(sh "$CLADE")" \
  --arg state     "$(sh "$STATE")" \
  --arg ecosystem "$(sh "$ECO")" \
  --arg agentic   "$(sh "$AGENTIC")" \
  --arg anchor    "$(sh "$ANCHOR")" \
  '
  {
    facts: (
      split("\n") | map(select(length > 0)) | map(split("\t")) | map({
        id:      .[0],
        family:  (.[0] | split(".")[0]),
        key:     (.[0] | split(".") | .[1:] | join(".")),
        value:   (.[1] // ""),
        present: ((.[1] // "") | length > 0)
      })
    ),
    provenance: {
      clade: $clade, state: $state, ecosystem: $ecosystem,
      agentic: $agentic, anchor: $anchor
    }
  }
'
