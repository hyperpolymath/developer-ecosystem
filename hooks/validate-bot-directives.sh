#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

readonly DEFAULT_TARGETS=(
    "affinescript-ecosystem/affinescript-vite"
    "affinescript-ecosystem/affinescriptiser"
    "affinescript-ecosystem/rattlescript"
)

validate_targets() {
    local failed=0
    local target
    local machine_readable

    for target in "$@"; do
        machine_readable="${target}/.machine_readable"

        if [[ -d "${machine_readable}/agent_instructions" ]]; then
            printf 'ERROR: legacy directive directory remains: %s\n' \
                "${machine_readable}/agent_instructions" >&2
            failed=1
        fi

        if [[ ! -d "${machine_readable}/bot_directives" ]]; then
            printf 'ERROR: canonical directive directory is missing: %s\n' \
                "${machine_readable}/bot_directives" >&2
            failed=1
        fi

        if rg --hidden --glob '!**/.git/**' --quiet 'agent_instructions' "$target"; then
            printf 'ERROR: legacy agent_instructions reference remains under %s\n' \
                "$target" >&2
            rg --hidden --glob '!**/.git/**' --line-number \
                'agent_instructions' "$target" >&2
            failed=1
        fi
    done

    return "$failed"
}

self_test() {
    local fixture
    fixture="$(mktemp -d /tmp/validate-bot-directives.XXXXXX)"
    trap 'rm -rf -- "$fixture"' RETURN

    mkdir -p "${fixture}/.machine_readable/agent_instructions"
    if validate_targets "$fixture" >/dev/null 2>&1; then
        echo "ERROR: validator accepted a planted legacy directory" >&2
        return 1
    fi

    mv "${fixture}/.machine_readable/agent_instructions" \
        "${fixture}/.machine_readable/bot_directives"
    validate_targets "$fixture"
    echo "Bot-directives validator self-test passed."
}

if [[ "${1:-}" == "--self-test" ]]; then
    self_test
    exit
fi

if (( $# > 0 )); then
    validate_targets "$@"
else
    validate_targets "${DEFAULT_TARGETS[@]}"
fi

echo "Bot-directives migration validation passed."
