#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# check-variant-drift.sh — verify the shared RSR spine of this variant
# template stays convergent with its parent at the pinned commit.
#
# Reads the contract at .machine_readable/descriptiles/VARIANT.a2ml:
#   - every tracked file NOT declared added/removed/diverged/pending/operational
#     must be identical to the parent's copy at parent-pin, modulo the
#     [normalise] rules (action-pin SHAs, self-name substitution);
#   - declared additions must exist here and not in the parent;
#   - declared removals must exist in the parent and not here.
#
# Usage: check-variant-drift.sh <parent-checkout-dir> [self-dir]
# Exit:  0 = spine convergent; 1 = undeclared drift (listed on stdout).

set -euo pipefail

PARENT_DIR="${1:?usage: check-variant-drift.sh <parent-checkout-dir> [self-dir]}"
SELF_DIR="${2:-.}"
CONTRACT="$SELF_DIR/.machine_readable/descriptiles/VARIANT.a2ml"

[ -f "$CONTRACT" ] || { echo "FAIL: contract not found: $CONTRACT"; exit 1; }

SELF_NAME=$(sed -n 's/^project = "\(.*\)"/\1/p' "$CONTRACT" | head -1)
PARENT_SLUG=$(sed -n 's/^parent = "\(.*\)"/\1/p' "$CONTRACT" | head -1)
PARENT_NAME="${PARENT_SLUG##*/}"
PIN=$(sed -n 's/^parent-pin = "\([0-9a-f]*\)".*/\1/p' "$CONTRACT" | head -1)

# Extract the paths array of one [paths.<section>] block.
section_paths() {
  awk -v sec="[paths.$1]" '
    $0 == sec { insec = 1; next }
    insec && /^\[/ { insec = 0 }
    insec && /^ *"/ {
      line = $0
      sub(/^ *"/, "", line); sub(/".*$/, "", line)
      print line
    }
  ' "$CONTRACT"
}

ADDED=$(section_paths added)
REMOVED=$(section_paths removed)
SKIP=$(printf '%s\n' "$(section_paths diverged)" \
                     "$(section_paths diverged-pending-upstream)" \
                     "$(section_paths operational-state)")

in_list() { # $1 = path, $2 = newline list (entries ending in / are prefixes)
  local p="$1" e
  while IFS= read -r e; do
    [ -z "$e" ] && continue
    case "$e" in
      */) case "$p" in "$e"*) return 0;; esac ;;
      *)  [ "$p" = "$e" ] && return 0 ;;
    esac
  done <<< "$2"
  return 1
}

# Fold operational state out of a file before comparison: action-pin SHAs,
# then BOTH repo names → SELF (variant name first — it does not contain the
# parent name as a substring, so order is safe). Folding both names on both
# sides keeps inherited files that legitimately mention the parent by name
# convergent, while still matching self-identity substitutions.
normalise() { # $1 = file
  sed -E -e 's/@[0-9a-f]{40}[^ ]*( # v[^ ]*)?/@PIN/g' \
         -e "s/$SELF_NAME/SELF/g" -e "s/$PARENT_NAME/SELF/g" "$1"
}

DRIFT=0
report() { DRIFT=1; echo "DRIFT: $*"; }

if [ -n "$PIN" ] && [ -d "$PARENT_DIR/.git" ]; then
  ACTUAL=$(git -C "$PARENT_DIR" rev-parse HEAD)
  [ "$ACTUAL" = "$PIN" ] || echo "WARN: parent checkout is $ACTUAL, contract pins $PIN"
fi

# 1. Spine files must match, modulo normalisation.
while IFS= read -r f; do
  in_list "$f" "$ADDED" && continue
  in_list "$f" "$SKIP" && continue
  if [ ! -f "$PARENT_DIR/$f" ]; then
    report "$f exists here but not in parent (declare in paths.added or remove)"
    continue
  fi
  if ! diff -q <(normalise "$PARENT_DIR/$f") \
               <(normalise "$SELF_DIR/$f") >/dev/null 2>&1; then
    report "$f differs from parent (declare in paths.diverged or re-converge)"
  fi
done < <(git -C "$SELF_DIR" ls-files)

# 2. Parent files absent here must be declared removed.
while IFS= read -r f; do
  [ -f "$SELF_DIR/$f" ] && continue
  in_list "$f" "$REMOVED" && continue
  in_list "$f" "$SKIP" && continue
  report "parent has $f but it is absent here (declare in paths.removed)"
done < <(git -C "$PARENT_DIR" ls-files)

# 3. Declared additions must exist (and not silently exist in parent).
while IFS= read -r e; do
  [ -z "$e" ] && continue
  case "$e" in
    */) [ -d "$SELF_DIR/$e" ] || report "declared-added directory $e is missing" ;;
    *)  [ -f "$SELF_DIR/$e" ] || report "declared-added file $e is missing"
        [ -e "$PARENT_DIR/$e" ] && report "declared-added $e also exists in parent (not an addition)" ;;
  esac
done <<< "$ADDED"

# 4. Declared removals must still exist in the parent.
while IFS= read -r e; do
  [ -z "$e" ] && continue
  [ -e "$PARENT_DIR/$e" ] || report "declared-removed $e no longer exists in parent (stale entry)"
done <<< "$REMOVED"

if [ "$DRIFT" -eq 0 ]; then
  echo "PASS: spine convergent with $PARENT_SLUG@${PIN:0:12} (modulo declared variant paths)"
else
  echo "FAIL: undeclared drift against $PARENT_SLUG@${PIN:0:12} — update VARIANT.a2ml or re-converge"
  exit 1
fi
