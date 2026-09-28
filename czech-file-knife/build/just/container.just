# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# CONTAINERS — three-tier containerisation
#
# Imported by ../../Justfile via `import? "build/just/container.just"`.
# Variables (project, OWNER, ...) and `set shell` are inherited from the root.
#
# Tier A — OCI standard:   build/container/Containerfile, build/container/.containerignore
# Tier B — portable engine: build/container/compose.yaml      (podman | nerdctl | docker)
# Tier C — stapeln sovereign: build/container/stapeln/         (cerro-torre, svalinn,
#                                                         vordr, selur, rokur, k9)
#
# Engine is auto-selected: $CONTAINER_ENGINE, else the first of podman /
# nerdctl / docker found on PATH. Override with:  CONTAINER_ENGINE=docker just …
#
# Narrow the template to the tiers you want (see the Narrowing section below):
#   just container-keep oci portable   # keep image + portable compose, drop the rest
#   just no-stapeln | no-devcontainer | no-container   # convenience aliases

# ── Engine detection (shared snippet) ──────────────────────────────────────
# Resolves the OCI engine into $ENGINE. Sourced at the top of each recipe.
_engine := '''
    ENGINE="${CONTAINER_ENGINE:-}"
    if [ -z "$ENGINE" ]; then
        for e in podman nerdctl docker; do
            if command -v "$e" >/dev/null 2>&1; then ENGINE="$e"; break; fi
        done
    fi
    if [ -z "$ENGINE" ]; then
        echo "No container engine found (looked for podman, nerdctl, docker)." >&2
        echo "Install one or set CONTAINER_ENGINE." >&2
        exit 1
    fi
'''

# Initialise container templates — substitute placeholders with project values
container-init:
    #!/usr/bin/env bash
    set -euo pipefail

    if [ ! -d "build/container" ]; then
        echo "Error: build/container/ directory not found."
        echo "This repo may not have been created from rsr-template-repo,"
        echo "or containerisation was removed with 'just no-container'."
        exit 1
    fi

    echo "=== Container Template Initialisation ==="
    echo ""

    # Load RSR defaults if available
    DEFAULTS="${XDG_CONFIG_HOME:-$HOME/.config}/rsr/defaults"
    if [ -f "$DEFAULTS" ]; then
        echo "Loading defaults from $DEFAULTS"
        # shellcheck source=/dev/null
        source "$DEFAULTS"
        echo ""
    fi

    # Prompt for container-specific values
    read -rp "Service name (e.g. my-api) [czech_file_knife]: " _SERVICE_NAME
    SERVICE_NAME="${_SERVICE_NAME:-czech_file_knife}"

    read -rp "Primary port [8080]: " _PORT
    PORT="${_PORT:-8080}"

    read -rp "Container registry [ghcr.io/${OWNER:-hyperpolymath}]: " _REGISTRY
    REGISTRY="${_REGISTRY:-ghcr.io/${OWNER:-hyperpolymath}}"

    echo ""
    echo "  Service:  $SERVICE_NAME"
    echo "  Port:     $PORT"
    echo "  Registry: $REGISTRY"
    echo ""
    read -rp "Proceed? [Y/n] " CONFIRM
    [[ "${CONFIRM:-Y}" =~ ^[Nn] ]] && echo "Aborted." && exit 0

    echo ""
    echo "Replacing container placeholders..."

    # Brace tokens as variables (hex escapes avoid just interpolation)
    LB=$(printf '\x7b\x7b')
    RB=$(printf '\x7d\x7d')

    SED_ARGS=(
        -e "s|${LB}SERVICE_NAME${RB}|${SERVICE_NAME}|g"
        -e "s|${LB}PORT${RB}|${PORT}|g"
        -e "s|${LB}REGISTRY${RB}|${REGISTRY}|g"
    )

    # Recurses into build/container/stapeln/ as well.
    find build/container/ -type f | while read -r file; do
        if file --brief "$file" | grep -qi 'text\|ascii\|utf'; then
            sed -i "${SED_ARGS[@]}" "$file"
        fi
    done

    echo "Container templates initialised."
    echo ""
    echo "Next steps:"
    echo "  1. Edit build/container/Containerfile          — add your build commands (Tier A)"
    echo "  2. Edit build/container/entrypoint.sh          — set your application binary"
    echo "  3. Review build/container/compose.yaml         — portable stack (Tier B)"
    echo "  4. Review build/container/stapeln/             — sovereign stack (Tier C)"
    echo "  5. Build: just container-build"

# Build container image (cerro-torre pipeline if present, else plain OCI build)
container-build *args:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_engine}}
    if [ -f "build/container/stapeln/ct-build.sh" ]; then
        cd build/container/stapeln && CONTAINER_ENGINE="$ENGINE" ./ct-build.sh {{args}}
    elif [ -f "build/container/Containerfile" ]; then
        "$ENGINE" build -t czech_file_knife:latest -f build/container/Containerfile .
    elif [ -f "Containerfile" ]; then
        "$ENGINE" build -t czech_file_knife:latest -f Containerfile .
    else
        echo "No Containerfile found in build/container/ or project root"
        exit 1
    fi

# Pick the compose path: selur-compose (sovereign) if installed, else portable
_compose action *args:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_engine}}
    if command -v selur-compose >/dev/null 2>&1 && [ -f "build/container/stapeln/compose.toml" ]; then
        ( cd build/container/stapeln && selur-compose {{action}} {{args}} )
    elif [ -f "build/container/compose.yaml" ]; then
        "$ENGINE" compose -f build/container/compose.yaml {{action}} {{args}}
    else
        echo "No compose file found (build/container/stapeln/compose.toml or build/container/compose.yaml)"
        exit 1
    fi

# Verify compose configuration (selur-compose verify, else <engine> compose config)
container-verify:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_engine}}
    if command -v selur-compose >/dev/null 2>&1 && [ -f "build/container/stapeln/compose.toml" ]; then
        ( cd build/container/stapeln && selur-compose verify )
    elif [ -f "build/container/compose.yaml" ]; then
        "$ENGINE" compose -f build/container/compose.yaml config
    else
        echo "No compose file found (build/container/stapeln/compose.toml or build/container/compose.yaml)"
        exit 1
    fi

# Start the container stack (selur-compose if available, else $ENGINE compose)
container-up *args:
    @just _compose up {{args}}

# Stop the container stack
container-down *args:
    @just _compose down {{args}}

# Sign and verify the container bundle (cerro-torre: build + pack + sign + verify)
container-sign:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -f "build/container/stapeln/ct-build.sh" ]; then
        cd build/container/stapeln && ./ct-build.sh
    else
        echo "No build/container/stapeln/ct-build.sh found"
        exit 1
    fi

# Push the signed bundle (or plain image) to the registry
container-push:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_engine}}
    if [ -f "build/container/stapeln/ct-build.sh" ]; then
        cd build/container/stapeln && CONTAINER_ENGINE="$ENGINE" ./ct-build.sh --push
    else
        echo "No build/container/stapeln/ct-build.sh found — falling back to $ENGINE push"
        "$ENGINE" push czech_file_knife:latest
    fi

# Run the container interactively (for debugging)
container-run *args:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_engine}}
    "$ENGINE" run --rm -it czech_file_knife:latest {{args}}

# Container matrix: [build|run|push|shell|scan] x [registry] x [tag]
container-matrix action="build" registry="ghcr.io/hyperpolymath" tag="latest":
    @echo "Container matrix: action={{action}} registry={{registry}} tag={{tag}}"

# ── Narrowing / opt-out ──────────────────────────────────────────────────────
#
# `container-keep` is the workhorse: declare exactly which tiers to KEEP; the
# rest are removed. Tiers: oci (A) · portable (B) · stapeln (C) · devcontainer.
# Idempotent — safe to re-run. The aliases below are thin wrappers.
#
#   just container-keep oci                       # bare OCI image only
#   just container-keep oci portable              # image + portable compose
#   just container-keep oci portable stapeln      # full prod stack, no dev container
#   just container-keep all                       # no-op (keep everything)
#   just container-keep none                      # remove everything (= no-container)
#   DRY_RUN=1 just container-keep oci             # show what would change, do nothing
#   FORCE=1   just container-keep oci             # skip the confirm prompt
#
# Accepts space- or comma-separated tokens, and aliases: a/A, b/B/compose,
# c/C/sovereign, dev. 'portable'/'stapeln' require 'oci' (they build the image).
container-keep +tiers:
    #!/usr/bin/env bash
    set -euo pipefail

    sel="$(echo "$@" | tr ',' ' ')"
    keep_oci=false keep_port=false keep_stap=false keep_dev=false
    for t in $sel; do
        case "$t" in
            all)                      keep_oci=true; keep_port=true; keep_stap=true; keep_dev=true ;;
            none)                     : ;;
            oci|a|A)                  keep_oci=true ;;
            portable|compose|b|B)     keep_port=true ;;
            stapeln|sovereign|c|C)    keep_stap=true ;;
            devcontainer|dev)         keep_dev=true ;;
            *) echo "Unknown tier '$t'. Valid: oci portable stapeln devcontainer | all | none" >&2; exit 1 ;;
        esac
    done

    # Coherence: tiers B and C build the OCI image, so they need tier A.
    if { $keep_port || $keep_stap; } && ! $keep_oci; then
        echo "Incoherent selection: 'portable'/'stapeln' build the OCI image — add 'oci'." >&2
        exit 1
    fi

    # Build the removal plan.
    plan=()
    $keep_dev  || plan+=(".devcontainer/  (dev container)")
    if $keep_oci; then
        $keep_stap || plan+=("build/container/stapeln/  (cerro-torre, svalinn, vordr, selur, rokur, k9)")
        $keep_port || plan+=("build/container/compose.yaml + compose.example.yaml  (portable stack)")
    else
        plan+=("build/container/  (entire image + compose + stapeln)")
        plan+=("build/just/container.just  (this module) + its Justfile import")
        [ -f .github/workflows/container-build.yml ] && plan+=(".github/workflows/container-build.yml")
    fi

    echo "Keeping: oci=$keep_oci portable=$keep_port stapeln=$keep_stap devcontainer=$keep_dev"
    if [ ${#plan[@]} -eq 0 ]; then echo "Nothing to remove — selection already matches."; exit 0; fi
    echo "Will remove:"; printf '  - %s\n' "${plan[@]}"

    if [ "${DRY_RUN:-}" = "1" ]; then echo "(DRY_RUN — no changes made)"; exit 0; fi
    if [ "${FORCE:-}" != "1" ]; then
        read -rp "Proceed? [y/N] " c; [[ "${c:-N}" =~ ^[Yy] ]] || { echo "Aborted."; exit 0; }
    fi

    # Apply.
    $keep_dev || rm -rf .devcontainer
    if $keep_oci; then
        $keep_stap || rm -rf build/container/stapeln
        $keep_port || rm -f build/container/compose.yaml build/container/compose.example.yaml
    else
        rm -rf build/container
        rm -f .machine_readable/configs/selur-compose.toml
        rm -f .github/workflows/container-build.yml
        rm -f build/just/container.just
        [ -f Justfile ] && sed -i '/# >>> container-module/,/# <<< container-module/d' Justfile
        for jf in Justfile .machine_readable/contractiles/Justfile; do
            [ -f "$jf" ] && sed -i '\|import? "build/just/container.just"|d' "$jf"
        done
    fi

    echo ""
    echo "Done. Review .github/workflows/ for image build/publish jobs you no longer need."

# Remove ALL containerisation (image, compose, stapeln, dev container)
no-container:
    @just container-keep none

# Drop only the stapeln sovereign tier (keep OCI image + portable compose + dev container)
no-stapeln:
    @just container-keep oci portable devcontainer

# Drop only the dev container (keep the full image/compose/stapeln stack)
no-devcontainer:
    @just container-keep oci portable stapeln
