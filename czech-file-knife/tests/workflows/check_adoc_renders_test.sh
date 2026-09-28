#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

# Self-test for scripts/check-adoc-renders.sh.
#
# Four of the six fixtures below are defect classes found in this very repo.
# EVERY ONE OF THEM EXITS 0 UNDER BARE asciidoctor, because --failure-level
# defaults to FATAL. That is why each defective fixture is asserted twice:
# once to prove bare asciidoctor is blind to it, and once to prove the checker
# catches it. If the first assertion ever fails, the --failure-level flag has
# stopped being the load-bearing part and this gate needs rereading.

set -euo pipefail

CHECKER="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/check-adoc-renders.sh"
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT

git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.name "RSR fixture"
git -C "$FIXTURE" config user.email "fixture@example.invalid"

# A defective fixture must be invisible to bare asciidoctor, or it is measuring
# something other than the flag.
assert_bare_asciidoctor_is_blind() {
    local f="$1"
    if ! asciidoctor --backend=html5 -o /dev/null "$FIXTURE/$f" >/dev/null 2>&1; then
        echo "FAIL: bare asciidoctor already rejects $f; fixture no longer proves the flag" >&2
        exit 1
    fi
}

# Replace the single defective file under test, so each case is isolated.
stage_only() {
    local f="$1"
    rm -f "$FIXTURE"/defect-*.adoc
    git -C "$FIXTURE" rm -q --cached --ignore-unmatch 'defect-*.adoc' >/dev/null
    cat > "$FIXTURE/$f"
    git -C "$FIXTURE" add "$f"
}

expect_rejected() {
    local f="$1" label="$2"
    assert_bare_asciidoctor_is_blind "$f"
    if "$CHECKER" "$FIXTURE" > "$FIXTURE/out" 2>&1; then
        echo "FAIL: checker accepted $label ($f)" >&2
        exit 1
    fi
    grep -q "$f" "$FIXTURE/out"
}

# 1. An empty repository is a PASS, not a failure. A stripped mint of this
#    template may legitimately carry no .adoc at all.
"$CHECKER" "$FIXTURE" | grep -q '^PASS: no tracked .adoc'

# 2. A well-formed document passes.
cat > "$FIXTURE/README.adoc" <<'EOF'
= Well Formed Fixture

A paragraph of prose.

* one
* two
EOF
git -C "$FIXTURE" add README.adoc
"$CHECKER" "$FIXTURE" | grep -q '^PASS:'

# 3. A stray cell separator shifts the row width. The blank line after the
#    title is load-bearing: without it, [cols=] is swallowed into the document
#    header and the fixture measures the swallowed-attribute defect instead.
stage_only defect-table.adoc <<'EOF'
= Table Fixture

[cols="2*"]
|===
| one | two
| three | four | five
|===
EOF
expect_rejected defect-table.adoc "a table dropping cells"

# 4. A Markdown body inside a .adoc: '# H' parses as a level 0 section, which
#    collides with the '= Title' the file already has.
stage_only defect-markdown.adoc <<'EOF'
= Markdown Body Fixture

# Heading One

## Sub Heading

Some prose.
EOF
expect_rejected defect-markdown.adoc "a Markdown body carried inside a .adoc"

# 5. An attribute line flush against '= Title' is read as the author line and
#    the FIRST '----' as the revision line, so the SECOND '----' opens a block
#    nothing closes. The closing delimiter is what makes this fixture bite:
#    without it the file renders clean and the case is vacuous.
stage_only defect-swallowed.adoc <<'EOF'
= Swallowed Attribute Fixture
[source,bash]
----
echo hello
----

Prose after the block.
EOF
expect_rejected defect-swallowed.adoc "a listing block swallowed into the header"

# 6. [[word]] in prose is an inline anchor, processed even inside backticks,
#    so the second occurrence redefines an id that is already in use.
stage_only defect-anchor.adoc <<'EOF'
= Anchor Fixture

The token [[widget]] is used here.

The token [[widget]] is used again here.
EOF
expect_rejected defect-anchor.adoc "a repeated prose anchor"

# The repository is clean again once the defective file is withdrawn.
rm -f "$FIXTURE"/defect-*.adoc
git -C "$FIXTURE" rm -q --cached --ignore-unmatch 'defect-*.adoc' >/dev/null
"$CHECKER" "$FIXTURE" | grep -q '^PASS:'

echo "PASS: clean and empty repos accepted; four defect classes rejected that bare asciidoctor exits 0 on"
