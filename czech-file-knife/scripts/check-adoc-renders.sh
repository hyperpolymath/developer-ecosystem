#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Every tracked .adoc file must parse. Asciidoctor's --failure-level DEFAULTS TO
# FATAL, so a document that emits WARNING or ERROR to stderr still exits 0 --
# which is why every gate in this estate that shelled out to asciidoctor was
# unfailable. The cure is the FLAG, not a wrapper, plus a three-way verdict:
#
#   exit 0 + empty stderr  -> the document rendered clean
#   exit 0 + stderr output -> a finding (this is the case bare asciidoctor hides)
#   non-zero               -> a finding, or the run did not complete
#
# This is the same contract empty-linter ships. The two are complementary halves
# of document integrity: empty-linter's remit is invisible bytes, this gate's
# remit is whether the document parses at all.
#
# Exit codes:
#   0  all tracked .adoc rendered clean (or there are none)
#   1  at least one file emitted a diagnostic or failed to render
#   2  the check could not run (bad path, asciidoctor not installed)

set -euo pipefail

REPO_ROOT="${1:-.}"
if [ ! -d "$REPO_ROOT" ]; then
    echo "ERROR: repository path does not exist: $REPO_ROOT" >&2
    exit 2
fi

if ! command -v asciidoctor >/dev/null 2>&1; then
    echo "ERROR: asciidoctor is not installed; cannot verify .adoc rendering." >&2
    echo "  Install it with: gem install asciidoctor -v 2.0.26 --no-document" >&2
    echo "  Failing closed: 'did not complete' is not 'clean'." >&2
    exit 2
fi

# Subject list read NUL-delimited so a path containing a space cannot split.
FILES=()
if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r -d '' f; do
        FILES+=("$REPO_ROOT/$f")
    done < <(git -C "$REPO_ROOT" ls-files -z -- '*.adoc' 2>/dev/null || true)
else
    while IFS= read -r -d '' f; do
        FILES+=("$f")
    done < <(find "$REPO_ROOT" -type f -name '*.adoc' \
        -not -path '*/.git/*' -not -path '*/node_modules/*' -print0 2>/dev/null || true)
fi

# An empty subject list is a PASS, not a failure. This is a TEMPLATE: a stripped
# mint may legitimately carry no .adoc yet, and the house idiom for an absent
# subject is check-no-md-in-docs.sh's "no docs/ directory (nothing to check)".
if [ "${#FILES[@]}" -eq 0 ]; then
    echo "PASS: no tracked .adoc (nothing to check)"
    exit 0
fi

FAILED=0
FINDINGS=""
for f in "${FILES[@]}"; do
    set +e
    err="$(asciidoctor --failure-level=WARN --backend=html5 -o /dev/null "$f" 2>&1 >/dev/null)"
    rc=$?
    set -e
    if [ "$rc" -ne 0 ] || [ -n "$err" ]; then
        FAILED=$((FAILED + 1))
        first="$(printf '%s\n' "$err" | sed -n '1p')"
        [ -n "$first" ] || first="(no diagnostic; exit $rc)"
        FINDINGS="${FINDINGS}  ${f#"$REPO_ROOT"/}: ${first}"$'\n'
    fi
done

if [ "$FAILED" -eq 0 ]; then
    echo "PASS: all ${#FILES[@]} tracked .adoc file(s) render clean"
    exit 0
fi

echo "FAIL: $FAILED of ${#FILES[@]} tracked .adoc file(s) did not render clean:" >&2
printf '%s' "$FINDINGS" >&2
echo >&2
echo "Repair the document so asciidoctor emits nothing on stderr. Common causes:" >&2
echo "  * a Markdown body inside a .adoc: '# H' parses as a level-0 section" >&2
echo "  * an attribute line flush against '= Title', swallowed into the header" >&2
echo "  * a repeated [[anchor]] in prose, processed even inside backticks" >&2
echo "  * a stray '|' inside a table, shifting the cell count" >&2
echo "Reproduce one file with:" >&2
echo "  asciidoctor --failure-level=WARN --backend=html5 -o /dev/null <file>" >&2
exit 1
