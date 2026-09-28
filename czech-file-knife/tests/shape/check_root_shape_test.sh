#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# check_root_shape_test.sh — prove scripts/check-root-shape.sh can FAIL.
#
# The gate went one-directional for months and nobody noticed, because a gate
# that only ever passes looks identical to a gate that works. These cases pin
# both directions and the '?' optional marker.

set -euo pipefail

CHECKER="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/check-root-shape.sh"
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT

git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.name "RSR fixture"
git -C "$FIXTURE" config user.email "fixture@example.invalid"

mkdir -p "$FIXTURE/machine-readable"
cat > "$FIXTURE/machine-readable/root-allow.txt" <<'ALLOW'
# fixture allowlist
.git/
machine-readable/
README.adoc
?OPTIONAL-THING.adoc
ALLOW
printf 'fixture\n' > "$FIXTURE/README.adoc"

fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. A conforming root passes.
bash "$CHECKER" "$FIXTURE" | grep -q '^PASS:' || fail "conforming fixture did not pass"

# 2. An entry at root that is not allow-listed fails, and is named.
printf 'stray\n' > "$FIXTURE/STRAY.adoc"
if out=$(bash "$CHECKER" "$FIXTURE" 2>&1); then
    fail "stray root entry did not fail the gate"
fi
grep -q 'STRAY.adoc' <<<"$out" || fail "failure did not name the stray entry"
rm "$FIXTURE/STRAY.adoc"

# 3. A REQUIRED allowlist entry that is absent fails, and is named.
#    This is the direction that was missing, and the reason the allowlist rotted.
mv "$FIXTURE/README.adoc" "$FIXTURE/machine-readable/README.adoc.parked"
if out=$(bash "$CHECKER" "$FIXTURE" 2>&1); then
    fail "missing required entry did not fail the gate"
fi
grep -q 'README.adoc' <<<"$out" || fail "failure did not name the missing entry"
mv "$FIXTURE/machine-readable/README.adoc.parked" "$FIXTURE/README.adoc"

# 4. An OPTIONAL entry that is absent passes. Capability-gated and template-only
#    material is legitimately missing in a conforming repo.
bash "$CHECKER" "$FIXTURE" | grep -q '^PASS:' || fail "absent ?optional entry wrongly failed"

# 5. A git-ignored root entry is not drift: the allowlist governs tracked shape,
#    not build output. (A .tmp probe once made this gate look broken when it
#    was the probe that was wrong.)
printf '*.tmp\n' > "$FIXTURE/.gitignore"
printf 'x\n' > "$FIXTURE/build-output.tmp"
sed -i 's|^README.adoc$|README.adoc\n.gitignore|' "$FIXTURE/machine-readable/root-allow.txt"
bash "$CHECKER" "$FIXTURE" | grep -q '^PASS:' || fail "git-ignored root entry was wrongly treated as drift"


# ---------------------------------------------------------------------------
# Both-path resolution. The estate contract admits two spellings of the
# machine-readable directory, and the great majority of repos use the dotted
# one. A gate that reads only the hyphenated path exits 2 on those repos --
# indistinguishable, to a caller, from a broken setup.
# ---------------------------------------------------------------------------

DOTTED=$(mktemp -d)
trap 'rm -rf "$FIXTURE" "$DOTTED"' EXIT
git -C "$DOTTED" init -q
git -C "$DOTTED" config user.name "RSR fixture"
git -C "$DOTTED" config user.email "fixture@example.invalid"
mkdir -p "$DOTTED/.machine_readable"
cat > "$DOTTED/.machine_readable/root-allow.txt" <<'ALLOW'
# fixture allowlist, dotted spelling
.git/
.machine_readable/
README.adoc
ALLOW
printf 'fixture\n' > "$DOTTED/README.adoc"

# 6. The dotted spelling resolves and a conforming root passes.
bash "$CHECKER" "$DOTTED" | grep -q '^PASS:' || fail "dotted .machine_readable/ allowlist was not resolved"

# 7. The dotted spelling still FAILS on drift. Resolving the file is not the
#    same as enforcing against it; without this case, case 6 would also pass
#    for a gate that found the allowlist and then ignored it.
printf 'stray\n' > "$DOTTED/STRAY.adoc"
if out=$(bash "$CHECKER" "$DOTTED" 2>&1); then
    fail "dotted-spelling repo did not fail on a stray root entry"
fi
grep -q 'STRAY.adoc' <<<"$out" || fail "dotted-spelling failure did not name the stray entry"
rm "$DOTTED/STRAY.adoc"

# 8. BOTH spellings present is refused as setup error (2), not silently
#    resolved: two allowlists cannot both be canonical.
mkdir -p "$DOTTED/machine-readable"
cp "$DOTTED/.machine_readable/root-allow.txt" "$DOTTED/machine-readable/root-allow.txt"
set +e
bash "$CHECKER" "$DOTTED" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "two competing allowlists returned $rc, expected 2"
rm -rf "$DOTTED/machine-readable"

# 9. NEITHER spelling present is a setup error (2), and the message names both
#    paths so the operator knows which two were tried.
rm -rf "$DOTTED/.machine_readable"
set +e
out=$(bash "$CHECKER" "$DOTTED" 2>&1)
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "absent allowlist returned $rc, expected 2"
grep -q '.machine_readable/root-allow.txt' <<<"$out" || fail "error did not name the dotted path"
grep -q 'machine-readable/root-allow.txt'  <<<"$out" || fail "error did not name the hyphenated path"

echo "PASS: check-root-shape.sh fails in both directions, honours '?', and resolves both spellings"
