#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# ssg-bootstrap.sh — Universal SSG Initialisation Helper
#
# Provides a starting hand for creating a documentation site or blog.
# Options 1-2 are hyperpolymath-maintained SSGs; options 3-5 are popular
# third-party choices. Use whichever fits your project.

set -euo pipefail

DEST="${1:-docs/site}"

echo "═══════════════════════════════════════════════════"
echo "  SSG BOOTSTRAP HELPER"
echo "  Target directory: $DEST"
echo "═══════════════════════════════════════════════════"
echo ""
echo "Select an SSG to initialize in this project:"
echo "  [1] Casket-SSG (Haskell) — hyperpolymath, pretty-formal"
echo "  [2] Ddraig-SSG (Idris2)  — hyperpolymath, dependent-type proofed"
echo "  [3] Serum (Elixir)       — BEAM-based, concurrent"
echo "  [4] Zola (Rust)          — Fast, standalone, standard"
echo "  [5] Custom Git URL       — Any SSG from a git repository"
echo ""

read -rp "Enter choice [1-5]: " choice

case "$choice" in
    1)
        echo "Selected: Casket-SSG"
        echo "Run: git clone https://github.com/hyperpolymath/casket-ssg $DEST"
        ;;
    2)
        echo "Selected: Ddraig-SSG"
        echo "Run: git clone https://github.com/hyperpolymath/ddraig-ssg $DEST"
        ;;
    3)
        echo "Selected: Serum"
        echo "Run: mix serum.new $DEST"
        ;;
    4)
        echo "Selected: Zola"
        echo "Run: zola init $DEST"
        ;;
    5)
        read -rp "Git URL: " custom_url
        echo "Run: git clone $custom_url $DEST"
        ;;
    *)
        echo "Invalid selection. Aborting."
        exit 1
        ;;
esac

echo "═══════════════════════════════════════════════════"
echo "  SCAFFOLDING SECURITY & RESOURCE DIRECTORIES"
echo "═══════════════════════════════════════════════════"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
WWW="$REPO_ROOT/www"

mkdir -p "$DEST/security_headers"
mkdir -p "$DEST/.well-known"
mkdir -p "$DEST/resource_records"

# Canonical sources live in www/ (issue #53). Copy from there when present;
# the inline defaults below remain for repositories without the bundle.
if [ -d "$WWW/.well-known" ]; then
    cp -r "$WWW/.well-known/." "$DEST/.well-known/"
    echo "  .well-known: copied from canonical www/.well-known/"
fi
if [ -d "$WWW/dns/records" ]; then
    cp -r "$WWW/dns/records/." "$DEST/resource_records/"
    echo "  resource records: copied from www/dns/records/"
fi
if [ -f "$WWW/security_headers/csp.conf" ]; then
    cp "$WWW/security_headers/csp.conf" "$DEST/security_headers/csp.conf"
    echo "  security headers: copied from www/security_headers/csp.conf"
else
cat << 'EOF' > "$DEST/security_headers/csp.conf"
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; form-action 'self'; upgrade-insecure-requests;
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
EOF
fi

echo "Scaffolding complete. Please ensure these directories are copied to your site's output root."
