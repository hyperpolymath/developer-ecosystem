#!/usr/bin/env bash
#
# check-boundaries.sh
#
# Ensures cadre-tea-router stays in its lane and doesn't implement
# functionality that belongs in cadre-router (the core library).
#
# Exit codes:
#   0 - No boundary violations
#   1 - Boundary violations detected
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

VIOLATIONS=0
SRC_DIR="src"

echo "=================================="
echo "Checking module boundaries..."
echo "=================================="
echo ""

# Helper to check for forbidden patterns
check_pattern() {
  local pattern="$1"
  local description="$2"
  local belongs_in="$3"

  if grep -rn --include="*.res" --include="*.resi" -E "$pattern" "$SRC_DIR" 2>/dev/null; then
    echo -e "${RED}✗ VIOLATION:${NC} $description"
    echo -e "  ${YELLOW}→ This belongs in:${NC} $belongs_in"
    echo ""
    VIOLATIONS=$((VIOLATIONS + 1))
    return 1
  fi
  return 0
}

echo "Checking for URL parsing combinators (belong in cadre-router)..."
echo "----------------------------------------------------------------"

# Path segment combinators like: s("users") / int / string
check_pattern '\bs\s*\(\s*"[^"]+"\s*\)\s*/' \
  "Path segment combinator pattern (s(\"...\") / ...)" \
  "cadre-router" || true

# Parser combinator definitions
check_pattern 'type\s+(parser|route)\s*(<|\=)' \
  "Parser/Route type definitions" \
  "cadre-router" || true

# oneOf, map, custom combinators
check_pattern '\b(oneOf|map2|map3|map4|andThen)\s*\(' \
  "Parser combinator functions (oneOf, map2, etc.)" \
  "cadre-router" || true

# Query parameter parsing combinators
check_pattern '\b(query|queryInt|queryString|queryBool|queryFlag)\s*\(' \
  "Query parameter combinators" \
  "cadre-router" || true

echo ""
echo "Checking for route formatting (belong in cadre-router)..."
echo "----------------------------------------------------------"

# Route-to-string formatting
check_pattern 'let\s+format\w*Route' \
  "Route formatting functions" \
  "cadre-router" || true

# Path builder patterns
check_pattern 'type\s+pathBuilder' \
  "Path builder types" \
  "cadre-router" || true

echo ""
echo "Checking for framework-agnostic primitives (belong in cadre-router)..."
echo "-----------------------------------------------------------------------"

# Matchers module (should import from cadre-router, not define)
check_pattern 'module\s+Matchers\s*=' \
  "Matchers module definition (should import from CadreRouter)" \
  "cadre-router" || true

# Segment type definitions
check_pattern 'type\s+segment\s*=' \
  "Segment type definitions" \
  "cadre-router" || true

# Custom URL parser implementations
check_pattern 'let\s+(parseSegments?|parsePath)\s*[=:]' \
  "Low-level URL segment parsing" \
  "cadre-router" || true

echo ""
echo "=================================="

if [ $VIOLATIONS -gt 0 ]; then
  echo -e "${RED}✗ Found $VIOLATIONS boundary violation(s)${NC}"
  echo ""
  echo "These patterns belong in cadre-router, not cadre-tea-router."
  echo "cadre-tea-router should only contain TEA-specific wiring:"
  echo "  • Subscriptions for URL changes"
  echo "  • Navigation Cmds (push/replace/back/forward)"
  echo "  • init-from-URL helpers"
  echo "  • Route → Msg patterns"
  echo ""
  echo "Import core routing from @anthropics/cadre-router instead."
  exit 1
else
  echo -e "${GREEN}✓ No boundary violations detected${NC}"
  echo ""
  echo "cadre-tea-router correctly delegates to cadre-router for:"
  echo "  • URL parsing/formatting combinators"
  echo "  • Route definitions"
  echo "  • Framework-agnostic primitives"
  exit 0
fi
