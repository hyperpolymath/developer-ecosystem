# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# GROOVE PROTOCOL
#
# Imported by ../../Justfile via `import? "build/just/groove.just"`.
# Recipes here configure and validate the Groove protocol manifest at
# .machine_readable/integrations/groove.a2ml — port assignment, API surface
# flags (REST/gRPC/GraphQL/WebSocket/SSE), and template-placeholder hygiene.
# The manifest itself is consumed by the Groove bridge / zig-unified-api-adapter.

# Configure Groove protocol manifest (port assignment, API surfaces)
groove-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    MANIFEST=".machine_readable/integrations/groove.a2ml"
    if [ ! -f "$MANIFEST" ]; then
        echo "Error: $MANIFEST not found. Run 'just repo-init' first."
        exit 1
    fi

    echo "═══════════════════════════════════════════════════"
    echo "  Groove Protocol Setup"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "Check PORT-REGISTRY.md before assigning a port:"
    echo "  https://github.com/hyperpolymath/standards/blob/main/PORT-REGISTRY.md"
    echo ""

    read -rp "Primary port for this service: " PORT
    [ -z "$PORT" ] && echo "Error: port required" && exit 1

    echo ""
    echo "Which API surfaces does this project expose?"
    read -rp "  REST API? [Y/n]: " REST
    read -rp "  gRPC? [y/N]: " GRPC
    read -rp "  GraphQL? [y/N]: " GRAPHQL
    read -rp "  WebSocket? [y/N]: " WS
    read -rp "  SSE (Server-Sent Events)? [y/N]: " SSE

    # Update port in manifest
    sed -i "s/(port 0)/(port ${PORT})/" "$MANIFEST"

    # Update API surface flags
    [[ "${GRPC,,}" == "y" ]] && sed -i 's/(grpc.*enabled false)/(grpc    (enabled true)/' "$MANIFEST"
    [[ "${GRAPHQL,,}" == "y" ]] && sed -i 's/(graphql.*enabled false)/(graphql (enabled true)/' "$MANIFEST"
    [[ "${WS,,}" == "y" ]] && sed -i 's/(websocket.*enabled false)/(websocket (enabled true)/' "$MANIFEST"
    [[ "${SSE,,}" == "y" ]] && sed -i 's/(sse.*enabled false)/(sse     (enabled true)/' "$MANIFEST"

    echo ""
    echo "Groove manifest updated: $MANIFEST"
    echo "Port ${PORT} assigned. Add to PORT-REGISTRY.md if not already there."

# Check for template placeholders that haven't been replaced
verify-template:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking for unreplaced template placeholders..."
    FOUND=0

    # Check for double-brace placeholder patterns
    HITS=$(grep -rn '{{'{{'}}[A-Z_]*{{'}}'}}' --include="*.adoc" --include="*.md" --include="*.a2ml" \
           --include="*.scm" --include="*.toml" --include="*.yml" --include="*.yaml" \
           . 2>/dev/null | grep -v 'node_modules\|\.git/' | grep -v 'PLACEHOLDERS.adoc' || true)
    if [ -n "$HITS" ]; then
        echo ""
        echo "⚠ Unreplaced placeholders found:"
        echo "$HITS" | head -20
        FOUND=1
    fi

    # Check for template defaults still present
    if grep -q 'czech-file-knife' Justfile 2>/dev/null; then
        echo "⚠ Justfile still references 'czech-file-knife' — update project name"
        FOUND=1
    fi

    # Check for port 0 in Groove manifest
    if grep -q '(port 0)' .machine_readable/integrations/groove.a2ml 2>/dev/null; then
        echo "⚠ Groove manifest has port 0 — run 'just groove-setup' to assign a port"
        FOUND=1
    fi

    # Check for empty SCM files
    for f in .machine_readable/descriptiles/STATE.a2ml .machine_readable/descriptiles/META.a2ml .machine_readable/descriptiles/ECOSYSTEM.a2ml; do
        if [ -f "$f" ] && grep -q '{{'{{'}}' "$f" 2>/dev/null; then
            echo "⚠ $f still has template placeholders"
            FOUND=1
        fi
    done

    if [ $FOUND -eq 0 ]; then
        echo "✓ No template placeholders found — project is properly customised."
    else
        echo ""
        echo "Run 'just repo-init' to replace placeholders, or edit files manually."
        exit 1
    fi
