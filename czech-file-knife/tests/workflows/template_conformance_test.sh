#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# template_conformance_test.sh — prove check-template-conformance.sh can fail.
#
# The estate has twice shipped a gate that could never fire (#49: the
# invisible-character gate matched nothing; #64: the Hypatia gate was
# unconditionally vacuous). A gate whose only evidence is that it passes is not
# evidence. Every check below therefore has a NEGATIVE control: a fixture that
# MUST be rejected. If a negative control passes, this test fails.
#
# Usage: bash tests/workflows/template_conformance_test.sh [--keep]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECK="$REPO_DIR/scripts/check-template-conformance.sh"
KEEP="${1:-}"

SCRATCH="$(mktemp -d /tmp/tmpl-conformance.XXXXXX)"
[ "$KEEP" = "--keep" ] || trap 'rm -rf "$SCRATCH"' EXIT

PASS=0; FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

command -v git >/dev/null 2>&1 || { echo "SKIP: no git"; exit 0; }
[ -x "$CHECK" ] || [ -f "$CHECK" ] || { echo "FAIL: checker not found at $CHECK"; exit 1; }

# ── fixture: a template and a minted child ───────────────────────────────────
make_template() {
    local d="$1"
    mkdir -p "$d/.github" "$d/scripts"
    printf 'name: demo\n' > "$d/Justfile"
    printf 'body\n'       > "$d/README.adoc"
    printf 'ci: []\n'     > "$d/.github/workflows.yml"
    git -C "$d" init -q -b main
    git -C "$d" -c user.email=t@t -c user.name=t add -A
    git -C "$d" -c user.email=t@t -c user.name=t commit -qm "template"
}

make_child() {
    local d="$1" parent_slug="$2" branch="$3" commit="$4" tree="$5"
    mkdir -p "$d/.machine_readable" "$d/.github" "$d/scripts"
    cp "$2_README" /dev/null 2>/dev/null || true
    printf 'name: demo\n' > "$d/Justfile"
    printf 'body\n'       > "$d/README.adoc"
    printf 'ci: []\n'     > "$d/.github/workflows.yml"
    cp "$CHECK" "$d/scripts/check-template-conformance.sh"
    cat > "$d/.machine_readable/PROVENANCE.a2ml" <<EOF
[provenance]
template_repo      = "$parent_slug"
template_branch    = "$branch"
template_commit    = "$commit"
template_tree      = "$tree"
extra_branches     = []
minted_by          = "repo-init"
EOF
    git -C "$d" init -q -b main
    git -C "$d" remote add origin "https://github.com/metadatastician/knot-knot.git"
    git -C "$d" -c user.email=t@t -c user.name=t add -A
    git -C "$d" -c user.email=t@t -c user.name=t commit -qm "mint"
}

run_check() { # $1=repo dir, $2=optional template dir
    local repo="$1" tmpl="${2:-}"
    if [ -n "$tmpl" ]; then
        bash "$CHECK" --repo "$repo" --template "$tmpl" --quiet >"$SCRATCH/out" 2>&1
    else
        bash "$CHECK" --repo "$repo" --quiet >"$SCRATCH/out" 2>&1
    fi
    echo $?
}

say() { echo; echo "── $1 ──"; }

TMPL="$SCRATCH/template"; make_template "$TMPL"
T_COMMIT="$(git -C "$TMPL" rev-parse HEAD)"
T_TREE="$(git -C "$TMPL" rev-parse 'HEAD^{tree}')"

# ─────────────────────────────────────────────────────────────────────────────
say "control: a conforming child must PASS"
CHILD="$SCRATCH/child-good"
make_child "$CHILD" "hyperpolymath/czech-file-knife" "main" "$T_COMMIT" "$T_TREE"
rc=$(run_check "$CHILD")
if [ "$rc" -eq 0 ]; then ok "conforming child accepted (positive control)"; else bad "conforming child was rejected (rc=$rc)"; cat "$SCRATCH/out"; fi

# ─────────────────────────────────────────────────────────────────────────────
say "negative control 1: missing provenance must FAIL (#203)"
CHILD="$SCRATCH/child-noprov"
make_child "$CHILD" "hyperpolymath/czech-file-knife" "main" "$T_COMMIT" "$T_TREE"
rm "$CHILD/.machine_readable/PROVENANCE.a2ml"
rc=$(run_check "$CHILD")
if [ "$rc" -ne 0 ]; then ok "child with no provenance rejected (T1)"; else bad "child with no provenance ACCEPTED — T1 is vacuous"; fi

# ─────────────────────────────────────────────────────────────────────────────
say "negative control 2: self-parent must FAIL (#200/#201 class)"
CHILD="$SCRATCH/child-self"
make_child "$CHILD" "metadatastician/knot-knot" "main" "$T_COMMIT" "$T_TREE"
rc=$(run_check "$CHILD")
if [ "$rc" -ne 0 ]; then ok "self-parenting repo rejected (T2)"; else bad "self-parenting repo ACCEPTED — T2 is vacuous"; fi

# ─────────────────────────────────────────────────────────────────────────────
say "negative control 3: UNASSIGNED pin must FAIL"
CHILD="$SCRATCH/child-unassigned"
make_child "$CHILD" "hyperpolymath/czech-file-knife" "UNASSIGNED" "UNASSIGNED" "UNASSIGNED"
rc=$(run_check "$CHILD")
if [ "$rc" -ne 0 ]; then ok "unresolved parent pin rejected (T3)"; else bad "unresolved parent pin ACCEPTED — T3 is vacuous"; fi

# ─────────────────────────────────────────────────────────────────────────────
say "negative control 4: a leaked work branch must FAIL (#203)"
CHILD="$SCRATCH/child-leak"
make_child "$CHILD" "hyperpolymath/czech-file-knife" "main" "$T_COMMIT" "$T_TREE"
# reproduce the knot-knot shape: a parentless branch whose tree is copied
git -C "$CHILD" checkout -q --orphan coderabbit/fix-hypatia-scan-failures/f36ac704
git -C "$CHILD" -c user.email=t@t -c user.name=t commit -qm "Initialize coderabbit/fix-hypatia-scan-failures/f36ac704"
git -C "$CHILD" checkout -q main
rc=$(run_check "$CHILD")
if [ "$rc" -ne 0 ]; then ok "leaked work branch rejected (T4)"; else bad "leaked work branch ACCEPTED — T4 is vacuous"; fi
if grep -qi "no common ancestor" "$SCRATCH/out"; then ok "unrelated-history signature reported (T4b)"; else bad "unrelated-history signature not reported"; fi

# ─────────────────────────────────────────────────────────────────────────────
say "negative control 5: drift must be REPORTED (advisory) and visibly found"
CHILD="$SCRATCH/child-drift"
make_child "$CHILD" "hyperpolymath/czech-file-knife" "main" "$T_COMMIT" "$T_TREE"
printf 'tampered\n' > "$CHILD/README.adoc"          # a template-owned file changed
rm "$CHILD/.github/workflows.yml"                   # a template-owned file deleted
rc=$(run_check "$CHILD" "$TMPL")
if grep -q "MISSING" "$SCRATCH/out" && grep -q "differs" "$SCRATCH/out"; then
    ok "drift report found both a missing and a changed template-owned path (D1/D2)"
else
    bad "drift report missed the injected divergence"; cat "$SCRATCH/out"
fi
[ "$rc" -eq 0 ] && ok "drift alone does not fail the gate (advisory, by design)" || bad "drift failed the gate — that is how a gate becomes unpassable, then continue-on-error'd"

# ─────────────────────────────────────────────────────────────────────────────
say "self-skip: the template itself must not be checked"
SKIPDIR="$SCRATCH/template-with-archetypes"
mkdir -p "$SKIPDIR/archetypes"
out=$(bash "$CHECK" --repo "$SKIPDIR" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "SKIP"; then ok "template self-skips"; else bad "template did not self-skip (rc=$rc): $out"; fi

echo
echo "template conformance test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
