#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Idempotently wire every K9 member as a git submodule.
# Safe to re-run: skips members already present.
# Run from the k9-ecosystem repository root (post-extraction — see BOOTSTRAP.md).

set -euo pipefail

GH="git@github.com:hyperpolymath"

# path                               repo
members=(
  "members/implementations/k9-rs       k9-rs"
  "members/implementations/k9_ex       k9_ex"
  "members/implementations/k9_gleam    k9_gleam"
  "members/implementations/k9-deno     k9-deno"
  "members/implementations/k9-haskell  k9-haskell"
  "members/tooling/tree-sitter-k9      tree-sitter-k9"
  "members/tooling/vscode-k9           vscode-k9"
  "members/tooling/pandoc-k9           pandoc-k9"
  "members/ci/k9-validate-action       k9-validate-action"
  "members/ci/k9-pre-commit            k9-pre-commit"
  "members/examples/k9-showcase        k9-showcase"
)

if [ ! -f .gitmodules ] || [ ! -d .git ]; then
  echo "error: run from the k9-ecosystem repository root" >&2
  exit 1
fi

for entry in "${members[@]}"; do
  # shellcheck disable=SC2086
  set -- $entry
  path="$1"; repo="$2"
  if [ -e "$path/.git" ] || git config --file .gitmodules --get "submodule.$path.url" >/dev/null 2>&1; then
    echo "skip  $path (already configured)"
    continue
  fi
  echo "add   $path -> $GH/$repo.git"
  git submodule add "$GH/$repo.git" "$path"
done

git submodule update --init --recursive
echo "done: $(git submodule status --recursive | wc -l) members wired"
