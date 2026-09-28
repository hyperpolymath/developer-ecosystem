#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# extract-clauses.sh — the NORMATIVE-side atomiser for Coaptation.
#
# Step 1 of the build path: give each contractile verb a machine-checkable
# clause-list with STABLE IDs. The clauses already exist as `###`/`####` anchors
# inside the six Xfiles (Intentfile/Mustfile/Trustfile/Adjustfile/Dustfile/
# Bustfile); this reader lifts them — it invents no semantics. Each obligation
# becomes a stable id `verb.slug` with its description, gate-field and whether it
# carries a runnable probe.
#
# A header is treated as a CLAUSE (not a section/grouping header) iff its block
# contains at least one `- <field>:` line. This separates `### Secrets` (a Trust
# grouping header, no fields) from `#### no-secrets-committed` (a real clause).
#
# READER only — authors nothing. Deterministic (no timestamps) so the receipt the
# Yard comparator emits can be byte-compared by verify.sh.
#
# Output (stdout): { "clauses": [ {id,verb,slug,description,severity,status,
#                   tolerance,has_probe} ... ], "provenance": { <verb>: <hash> } }
set -euo pipefail

DIR="${1:-.machine_readable/contractiles}"

# verb -> Xfile (relative to $DIR)
declare -A XFILE=(
  [intend]="intend/Intentfile.a2ml"
  [must]="must/Mustfile.a2ml"
  [trust]="trust/Trustfile.a2ml"
  [adjust]="adjust/Adjustfile.a2ml"
  [dust]="dust/Dustfile.a2ml"
  [bust]="bust/Bustfile.a2ml"
)
ORDER=(intend must trust adjust dust bust)

for v in "${ORDER[@]}"; do
  f="$DIR/${XFILE[$v]}"
  [ -f "$f" ] || { echo "extract-clauses.sh: missing Xfile: $f" >&2; exit 2; }
done

# short content hash (drift provenance), matches arrival-pack extract.sh
sh() { sha256sum "$1" | cut -c1-12; }

# Emit TSV rows: verb \t slug \t description \t severity \t status \t tolerance \t has_probe
atomise() {
  local verb="$1" file="$2"
  awk -v verb="$verb" '
    function flush() {
      if (have_field && slug ~ /^[A-Za-z0-9_-]+$/) {
        gsub(/\t/, " ", desc)
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", verb, slug, desc, sev, status, tol, hasprobe, horizon
      }
      slug=""; desc=""; sev=""; status=""; tol=""; hasprobe="false"; horizon=""; have_field=0
    }
    /^#{3,4} / { flush(); line=$0; sub(/^#{3,4}[[:space:]]+/, "", line); slug=line; next }
    /^## /     { flush(); next }
    /^- description:/ { d=$0; sub(/^- description:[[:space:]]*/, "", d); desc=d; have_field=1; next }
    /^- severity:/    { d=$0; sub(/^- severity:[[:space:]]*/, "", d);    sev=d;  have_field=1; next }
    /^- status:/      { d=$0; sub(/^- status:[[:space:]]*/, "", d);      status=d; have_field=1; next }
    /^- tolerance:/   { d=$0; sub(/^- tolerance:[[:space:]]*/, "", d);   tol=d;  have_field=1; next }
    /^- horizon:/     { d=$0; sub(/^- horizon:[[:space:]]*/, "", d);     horizon=d; have_field=1; next }
    /^- run:/             { hasprobe="true"; have_field=1; next }
    /^- probe:/           { hasprobe="true"; have_field=1; next }
    /^- injection_probe:/ { hasprobe="true"; have_field=1; next }
    /^- recovery_probe:/  { hasprobe="true"; have_field=1; next }
    /^- class:/        { have_field=1; next }
    /^- verification:/ { have_field=1; next }
    /^- corrective:/   { have_field=1; next }
    END { flush() }
  ' "$file"
}

# Build the clause rows + the provenance object.
rows="$(for v in "${ORDER[@]}"; do atomise "$v" "$DIR/${XFILE[$v]}"; done)"

prov_args=()
for v in "${ORDER[@]}"; do
  prov_args+=(--arg "$v" "$(sh "$DIR/${XFILE[$v]}")")
done

printf '%s\n' "$rows" | jq -R -s "${prov_args[@]}" '
  {
    clauses: (
      split("\n") | map(select(length > 0)) | map(split("\t")) | map({
        id:          (.[0] + "." + .[1]),
        verb:        .[0],
        slug:        .[1],
        description: (.[2] // ""),
        severity:    (.[3] // ""),
        status:      (.[4] // ""),
        tolerance:   (.[5] // ""),
        has_probe:   ((.[6] // "false") == "true"),
        horizon:     (.[7] // ""),
        is_wish:     ((.[7] // "") | length > 0)
      })
    ),
    provenance: {
      intend: $intend, must: $must, trust: $trust,
      adjust: $adjust, dust: $dust, bust: $bust
    }
  }
'
