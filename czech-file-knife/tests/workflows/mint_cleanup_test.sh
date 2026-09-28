#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
repo=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cat > "$fixture/dependabot.yml" <<'YAML'
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
  - package-ecosystem: nix
    directory: /
  - package-ecosystem: cargo
    directory: /
YAML
bash "$repo/scripts/rust-tool.sh" prune-dependabot-ecosystems "$fixture/dependabot.yml" github-actions
grep -q 'github-actions' "$fixture/dependabot.yml"
if grep -qE 'nix|cargo' "$fixture/dependabot.yml"; then exit 1; fi
cp "$fixture/dependabot.yml" "$fixture/before"
bash "$repo/scripts/rust-tool.sh" prune-dependabot-ecosystems "$fixture/dependabot.yml" nix
cmp "$fixture/dependabot.yml" "$fixture/before"
cat > "$fixture/policy.md" <<'DOC'
<!--
SPDX-License-Identifier: MPL-2.0
-->
# Policy
Prose mentions TEMPLATE INSTRUCTIONS and must survive.
Actual policy.
DOC
bash "$repo/scripts/rust-tool.sh" strip-instruction-blocks "$fixture"
grep -q SPDX "$fixture/policy.md"
grep -q '^# Policy' "$fixture/policy.md"
grep -q '^Prose mentions' "$fixture/policy.md"
if grep -q 'delete only this' "$fixture/policy.md"; then exit 1; fi
cp "$fixture/policy.md" "$fixture/before"
bash "$repo/scripts/rust-tool.sh" strip-instruction-blocks "$fixture"
cmp "$fixture/policy.md" "$fixture/before"
echo 'PASS: selected ecosystems, nonempty updates, comment boundaries, and idempotence'
