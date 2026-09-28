#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Point this clone's git hooks at .github/hooks/ so the local Dogfood Gate runs
# on push. Idempotent; safe to re-run.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath .github/hooks
git config commit.template .gitmessage
chmod +x .github/hooks/pre-push .github/hooks/validate-deed.sh .github/hooks/validate-k9.sh 2>/dev/null || true
echo "Installed: core.hooksPath -> .github/hooks (pre-push DEED+K9 gate active), commit.template -> .gitmessage."
