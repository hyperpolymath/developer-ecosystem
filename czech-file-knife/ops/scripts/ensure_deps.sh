#!/usr/bin/env bash
# Checks for all required dependencies (Haskell, Elixir, Bun, Podman, Nickel)

set -e
echo "[deps] Checking core tools: Bun, Elixir, mix, Stack, Nickel, Podman..."

# Function to check if a command exists
need() {
    command -v "$1" >/dev/null 2>&1 || { 
        echo "Missing required dependency: $1" >&2
        return 1
    }
}

MISSING=0

# 1. Check core development tools (Bun, Stack, Nickel)
# We check for Bun to manage Svelte/Vite dependencies
for c in bun stack nickel; do
    need $c || MISSING=1
done

# 2. Check Elixir/Mix (Already installed, but confirms availability)
for c in elixir mix; do
    need $c || MISSING=1
done

# 3. Check Container Runtime (Flexible: Docker OR Podman)
if (command -v docker >/dev/null 2>&1 && command -v docker-compose >/dev/null 2>&1) || \
   (command -v podman >/dev/null 2>&1 && command -v podman-compose >/dev/null 2>&1); then
    echo "[deps] Container runtime (Podman/Docker) OK."
else
    echo "Missing container runtime (Docker or Podman) and compose tool." >&2
    MISSING=1
fi

if [ $MISSING -eq 1 ]; then
    echo ""
    echo "--- INSTALLATION GUIDANCE (Remaining) ---"
    echo "1. Install **Bun** (for Svelte UI): https://bun.sh/docs/installation (Required instead of Node/NPM)."
    echo "2. Install **Haskell Stack** (for the validator): e.g., 'sudo dnf install haskell-stack'."
    echo "3. Install **Nickel** (Policy Language): Check official documentation if 'dnf install nickel' failed."
    echo "-----------------------------------------"
    exit 1
fi

echo "[deps] All core tools present. Ready to proceed."
