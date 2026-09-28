#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# check-template-conformance.sh — the CHECK half of the template contract.
#
# ── Why this exists ──────────────────────────────────────────────────────────
#
# The estate's own comment in build/just/repo-init.just reads:
#
#     "Copier/Cruft solved it with an answer-file + update + check; this estate
#      hand-simulated it as recurring standardisation-PR campaigns. This is the
#      answer-file."
#
# It built the answer-file — .machine_readable/PROVENANCE.a2ml — and then built
# neither the update nor the check. Nothing in this repository read that file.
# It was write-only.
#
# Four open defects are all the same missing half:
#
#   #200  CONTRIBUTING.md shipped hardcoded template identity into children
#   #201  the generated CLAUDE arrival pack retained the TEMPLATE's uuid,
#         clade and "canonical template" purpose in a Julia child
#   #203  a template work branch was copied into knot-knot with no common
#         ancestor — git proved the trees byte-identical
#
# Each is a repo asserting provenance it does not have, and none could be
# detected because no check read the record.
#
# ── What it checks ───────────────────────────────────────────────────────────
#
# Structural invariants (always, no network):
#   T1  PROVENANCE.a2ml exists
#   T2  it does not name THIS repo as its own template  (self-parent)
#   T3  template_branch / template_commit / template_tree are not UNASSIGNED
#   T4  the repo carries no branches beyond its declared extra_branches
#
# T2 is the #200/#201 class. T4 is #203.
#
# Drift report (only with --template PATH, and only ADVISORY):
#   D1  template-owned paths missing from this repo
#   D2  template-owned paths that differ from the template checkout
#
# Drift is advisory on purpose. A child is SUPPOSED to diverge; that is what
# minting is for. Reporting divergence as failure is how a gate becomes
# unpassable and then gets `continue-on-error`-ed, which is how the estate's
# Hypatia gate ended up unable to fire at all (measured twice: #49, #64).
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   bash scripts/check-template-conformance.sh [--repo PATH] [--template PATH]
#                                              [--report-only] [--quiet]
#
#   --repo PATH       the minted repo to check (default: this script's repo)
#   --template PATH   a template checkout, to enable the advisory drift report
#   --report-only     never exit non-zero (for rollout onto existing children)
#   --quiet           suppress the per-check PASS lines
#
# Exit: 0 conforming (or report-only), 1 findings, 2 usage/environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET="$REPO_DIR"
TEMPLATE=""
REPORT_ONLY=0
QUIET=0

while [ $# -gt 0 ]; do
    case "$1" in
        --repo)        TARGET="${2:-}"; shift 2 ;;
        --template)    TEMPLATE="${2:-}"; shift 2 ;;
        --report-only) REPORT_ONLY=1; shift ;;
        --quiet)       QUIET=1; shift ;;
        -h|--help)     sed -n '2,60p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)             echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

[ -d "$TARGET" ] || { echo "check-template-conformance: not a directory: $TARGET" >&2; exit 2; }
TARGET="$(cd "$TARGET" && pwd)"

PASS=0; FAIL=0; WARN=0
ok()   { PASS=$((PASS+1)); [ "$QUIET" -eq 1 ] || printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m  %s\n' "$1"; }
warn() { WARN=$((WARN+1)); printf '  \033[33mWARN\033[0m  %s\n' "$1"; }
note() { [ "$QUIET" -eq 1 ] || printf '        %s\n' "$1"; }

PROV="$TARGET/.machine_readable/PROVENANCE.a2ml"

finish() {
    echo
    if [ "$FAIL" -gt 0 ]; then
        printf 'conformance: \033[31m%d failed\033[0m, %d passed, %d warnings\n' "$FAIL" "$PASS" "$WARN"
    else
        printf 'conformance: \033[32m%d passed\033[0m, %d warnings\n' "$PASS" "$WARN"
    fi
    if [ "$REPORT_ONLY" -eq 1 ]; then
        echo "(report-only: not failing the run)"
        exit 0
    fi
    [ "$FAIL" -eq 0 ]
}

# ── Self-skip: this IS the template ──────────────────────────────────────────
# Same convention as tests/e2e/template_instantiation_test.sh. archetypes/ and
# build/templates/ are template-only and are removed at mint, so their presence
# means this repo has not been instantiated and has no parent to conform to.
if [ -d "$TARGET/archetypes" ] || [ -d "$TARGET/build/templates" ]; then
    echo "SKIP: $TARGET is a template (archetypes/ or build/templates/ present) — nothing to conform to."
    exit 0
fi

echo "template conformance: $TARGET"
echo

# ── T1: provenance exists ────────────────────────────────────────────────────
if [ ! -f "$PROV" ]; then
    bad "T1 no .machine_readable/PROVENANCE.a2ml — this repo cannot state what it was minted from"
    note "A repo minted through the GitHub template UI, or by copying a tree, never"
    note "runs repo-init and so never writes this file. That is the #203 mechanism."
    note "Recreate it by hand from the template commit you actually took."
    finish
    exit $?
else
    ok "T1 provenance present"
fi

# a2ml is a flat key = "value" format as far as this check needs.
prov_get() {
    sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"\(.*\)\"[[:space:]]*$/\1/p" "$PROV" | head -1
}

T_REPO="$(prov_get template_repo)"
T_BRANCH="$(prov_get template_branch)"
T_COMMIT="$(prov_get template_commit)"
T_TREE="$(prov_get template_tree)"

# ── T2: no self-parent ───────────────────────────────────────────────────────
SELF_SLUG=""
if command -v git >/dev/null 2>&1 && git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
    url="$(git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
    # normalise git@github.com:o/r.git and https://github.com/o/r(.git) to o/r.
    # Strip the .git suffix FIRST: the previous single-sed form left it on, so
    # SELF_SLUG became "owner/repo.git" and the T2 self-parent check silently
    # never matched. Caught by its own negative control.
    SELF_SLUG="$(printf '%s' "$url" \
        | sed -E 's|\.git$||; s|^[a-zA-Z][a-zA-Z0-9+.-]*://||; s|^git@||; s|:|/|' \
        | awk -F/ 'NF>=2 {print $(NF-1)"/"$NF}' || true)"
fi

if [ -z "$T_REPO" ]; then
    bad "T2 provenance has no template_repo"
elif [ -n "$SELF_SLUG" ] && [ "$T_REPO" = "$SELF_SLUG" ]; then
    bad "T2 provenance names THIS repo as its own template ($T_REPO) — self-parent"
    note "This is the #200/#201 class: the repo is asserting template identity."
    note "A child must point at the template it came from, not at itself."
else
    ok "T2 parent is external${SELF_SLUG:+ (self=$SELF_SLUG, parent=$T_REPO)}"
fi

# ── T3: the pin is real ──────────────────────────────────────────────────────
for pair in "template_branch:$T_BRANCH" "template_commit:$T_COMMIT" "template_tree:$T_TREE"; do
    key="${pair%%:*}"; val="${pair#*:}"
    if [ -z "$val" ] || [ "$val" = "UNASSIGNED" ]; then
        bad "T3 $key is ${val:-missing} — the parent pin is not resolvable"
        note "UNASSIGNED is honest at mint time when offline, but it must be filled"
        note "in before the repo is published, or drift can never be detected."
    else
        ok "T3 $key = $val"
    fi
done

# ── T4: branch contract (#203) ───────────────────────────────────────────────
# The template must never leak its work branches into a child. knot-knot got a
# byte-identical copy of coderabbit/fix-hypatia-scan-failures/f36ac704 with no
# common ancestor; git proved the tree equality.
if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
    DEFAULT="$(git -C "$TARGET" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
    if [ -z "$DEFAULT" ]; then
        for cand in main master; do
            git -C "$TARGET" show-ref --verify --quiet "refs/heads/$cand" && { DEFAULT="$cand"; break; }
        done
    fi

    # Declared extras: parse the bracketed list on the extra_branches line.
    DECLARED="$(sed -n 's/^[[:space:]]*extra_branches[[:space:]]*=[[:space:]]*\[\(.*\)\].*/\1/p' "$PROV" | head -1 | tr ',' '\n' | tr -d ' "' | grep -v '^$' || true)"

    UNEXPECTED=""
    while IFS= read -r br; do
        [ -z "$br" ] && continue
        [ "$br" = "$DEFAULT" ] && continue
        printf '%s\n' "$DECLARED" | grep -qxF "$br" && continue
        UNEXPECTED="$UNEXPECTED $br"
    done < <(git -C "$TARGET" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)

    if [ -n "$UNEXPECTED" ]; then
        bad "T4 branch(es) not in the mint contract:${UNEXPECTED}"
        note "Declared extra_branches: ${DECLARED:-<none>}"
        note "This is the #203 signature. A template work branch (coderabbit/,"
        note "chore/, bot-task) copied wholesale into a child. Review each: keep it"
        note "deliberately, or delete it. Do not force unrelated histories together."
    else
        ok "T4 branch contract honoured (default=${DEFAULT:-?}, declared extras=${DECLARED:-none})"
    fi

    # Byte-identical-tree detector: the cheapest proof of a leaked snapshot.
    # If a non-default branch's tree equals an ancestor's tree exactly, it very
    # likely arrived by copy rather than by work.
    while IFS= read -r br; do
        [ -z "$br" ] && continue
        [ "$br" = "$DEFAULT" ] && continue
        t="$(git -C "$TARGET" rev-parse "$br^{tree}" 2>/dev/null || true)"
        p="$(git -C "$TARGET" merge-base "$br" "${DEFAULT:-HEAD}" 2>/dev/null || true)"
        if [ -n "$t" ] && [ -z "$p" ]; then
            warn "T4b '$br' has NO common ancestor with ${DEFAULT:-HEAD} (unrelated history)"
            note "tree=$t — this is the exact knot-knot signature."
        fi
    done < <(git -C "$TARGET" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)
else
    warn "T4 skipped — not a git checkout"
fi

# ── D1/D2: advisory drift against a template checkout ────────────────────────
if [ -n "$TEMPLATE" ]; then
    if [ ! -d "$TEMPLATE" ]; then
        echo "  (--template path not a directory: $TEMPLATE)"; TEMPLATE=""
    elif [ ! -f "$TEMPLATE/Justfile" ]; then
        echo "  (--template path does not look like the template: no Justfile)"; TEMPLATE=""
    fi
fi

if [ -n "$TEMPLATE" ]; then
    TEMPLATE="$(cd "$TEMPLATE" && pwd)"
    echo
    echo "advisory drift vs $TEMPLATE"
    MISSING=0; DRIFTED=0

    # Paths the template owns: everything it ships except what it deliberately
    # drops at mint (archetypes/, build/, and the answer-file itself).
    while IFS= read -r rel; do
        case "$rel" in
            archetypes/*|build/*|.git/*|.machine_readable/PROVENANCE.a2ml) continue ;;
        esac
        if [ ! -e "$TARGET/$rel" ]; then
            MISSING=$((MISSING+1)); [ "$MISSING" -le 15 ] && echo "    MISSING  $rel"
        elif ! cmp -s "$TEMPLATE/$rel" "$TARGET/$rel"; then
            DRIFTED=$((DRIFTED+1)); [ "$DRIFTED" -le 15 ] && echo "    differs  $rel"
        fi
    done < <(cd "$TEMPLATE" && git ls-files 2>/dev/null || find . -type f | sed 's|^\./||')

    [ "$MISSING" -eq 0 ] && [ "$DRIFTED" -eq 0 ] && echo "    (none — no template-owned path diverged)"
    [ "$MISSING" -gt 0 ] && warn "D1 $MISSING template-owned path(s) missing from this repo"
    [ "$DRIFTED" -gt 0 ] && warn "D2 $DRIFTED template-owned path(s) differ from the template"
    note "Advisory only. A child is SUPPOSED to diverge — but a path that diverged"
    note "once is never healed by a later template update, and copier's own 3-way"
    note "merge carries such a difference forward silently, with no conflict marker."
    note "Decide per path: conform it, or record why it is deliberately forked."
fi

finish
exit $?
