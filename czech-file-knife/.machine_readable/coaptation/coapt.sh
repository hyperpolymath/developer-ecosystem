#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# coapt.sh — the Coaptation RUNNER (the controller of the cybernetic loop).
#
# Pipeline: extract-clauses.sh + extract-facts.sh (Kennel: sense) -> coapt.ncl
# (Yard: compare, pure) -> write receipts/latest.a2ml (Hunt: actuate, leashed).
#
# Modes (runner-invocation grammar):
#   --report   (default) SITREP — emit the coaptation receipt; decide nothing.
#   --reanchor           If the band is red, assemble the BASIS for an anchor-drop
#                        (the "carnage"). The DROP ITSELF is a human authority act —
#                        coapt never drops an anchor. ANCHOR.a2ml has no drift/ledger
#                        schema yet, so the drop cannot be recorded mechanically.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
CO="$ROOT/.machine_readable/coaptation"
MODE="${1:---report}"

# Kennel (sense) -> deterministic atomised inputs.
bash "$CO/extract-clauses.sh" "$ROOT/.machine_readable/contractiles" > "$CO/clauses.json"
bash "$CO/extract-facts.sh"   "$ROOT/.machine_readable/descriptiles"           > "$CO/facts.json"

# Yard (compare, pure) -> receipt text.
receipt="$(nickel export --format raw "$CO/coapt.ncl")"

# Hunt (actuate, leashed) -> persist the receipt.
mkdir -p "$CO/receipts"
printf '%s\n' "$receipt" > "$CO/receipts/latest.a2ml"

band="$(printf '%s\n' "$receipt"   | grep -oP '^band = "\K[^"]+' | head -1)"
action="$(printf '%s\n' "$receipt" | grep -oP '^proposed-action = "\K[^"]+' | head -1)"

echo "coapt: receipt written to .machine_readable/coaptation/receipts/latest.a2ml"
echo "coapt: band = ${band}"
echo "coapt: ${action}"

case "$MODE" in
  --report)
    : # SITREP only — decides nothing.
    ;;
  --reanchor)
    if [ "$band" = "red" ]; then
      basis="$CO/receipts/reanchor-basis.a2ml"
      # repo name from the CLADE descriptile, not a hardcoded literal — this
      # script is shared verbatim by every repo instantiated from
      # czech-file-knife, so a literal "czech-file-knife" here would
      # misreport every one of them.
      repo_name="$(grep -oP '^canonical-name = "\K[^"]+' "$ROOT/.machine_readable/descriptiles/CLADE.a2ml" | head -1)"
      {
        echo "# SPDX-License-Identifier: MPL-2.0"
        echo "# reanchor-basis — assembled by \`coapt --reanchor\`. This is the BASIS (the"
        echo "# \"carnage\") for an anchor-drop, NOT the drop. The drop is a human authority"
        echo "# act: a dated, named, hashed event authored by someone with the right and the"
        echo "# responsibility. ANCHOR.a2ml has no drift/ledger schema yet — wire that first."
        echo ""
        echo "[reanchor-basis]"
        echo "schema = \"hyperpolymath.reanchor-basis/0\""
        echo "repo = \"$repo_name\""
        echo "occasioned-by = \"band=red in the coaptation receipt\""
        echo ""
        echo "[carnage]"
        echo "# hard obligations refuted / unmeasured / breaks active (from the receipt):"
        printf '%s\n' "$receipt" | grep -E ' = (refuted|gap|unmeasured|alarm)$' | sed 's/^/clause = /'
        echo ""
        echo "[basis-for-the-human]"
        echo "decision = \"<author records the design decision here>\""
        echo "realignment = \"<author records the realignment here>\""
        echo "authority = \"<name of the person with the right + responsibility>\""
        echo ""
        echo "[provenance]"
        printf '%s\n' "$receipt" | sed -n '/^\[provenance\]/,$p' | tail -n +2
      } > "$basis"
      echo "coapt: re-anchor BASIS assembled at .machine_readable/coaptation/receipts/reanchor-basis.a2ml"
      echo "coapt: the anchor DROP is a HUMAN AUTHORITY ACT — coapt never drops an anchor."
      echo "coapt: NOTE — ANCHOR.a2ml lacks a drift/ledger schema; the drop cannot yet be recorded mechanically."
    else
      echo "coapt: band is '${band}' (not red) — no re-anchor basis needed."
    fi
    ;;
  *)
    echo "usage: coapt.sh [--report|--reanchor]" >&2
    exit 64
    ;;
esac
