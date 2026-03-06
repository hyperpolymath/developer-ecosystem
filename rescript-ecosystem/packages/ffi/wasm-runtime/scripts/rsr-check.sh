#!/usr/bin/env bash
# RSR (Rhodium Standard Repository) Compliance Checker
# Verifies compliance with RSR framework standards

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0
TOTAL=0

# Helper functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
    ((TOTAL++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
    ((TOTAL++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
    ((TOTAL++))
}

check_file() {
    local file=$1
    local name=$2
    if [ -f "$file" ]; then
        check_pass "$name exists"
        return 0
    else
        check_fail "$name missing"
        return 1
    fi
}

check_dir() {
    local dir=$1
    local name=$2
    if [ -d "$dir" ]; then
        check_pass "$name directory exists"
        return 0
    else
        check_fail "$name directory missing"
        return 1
    fi
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}RSR Compliance Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Category 1: Documentation
echo -e "${BLUE}1. Documentation${NC}"
check_file "README.md" "README.md"
check_file "LICENSE" "LICENSE"
check_file "CHANGELOG.md" "CHANGELOG.md"
check_file "CONTRIBUTING.md" "CONTRIBUTING.md"
check_file "CODE_OF_CONDUCT.md" "CODE_OF_CONDUCT.md"
check_file "MAINTAINERS.md" "MAINTAINERS.md"
check_file "SECURITY.md" "SECURITY.md"
check_file "TPCF.md" "TPCF.md (Tri-Perimeter Contribution Framework)"
echo ""

# Category 2: .well-known/ Directory
echo -e "${BLUE}2. .well-known/ Directory (RFC 9116 + Extensions)${NC}"
check_dir ".well-known" ".well-known"
check_file ".well-known/security.txt" "security.txt (RFC 9116)"
check_file ".well-known/ai.txt" "ai.txt (AI training policies)"
check_file ".well-known/humans.txt" "humans.txt (attribution)"
echo ""

# Category 3: Build System
echo -e "${BLUE}3. Build System${NC}"
check_file "justfile" "justfile"
check_file "package.json" "package.json"
check_file "rescript.json" "rescript.json"
if check_file "flake.nix" "flake.nix (Nix reproducible builds)"; then
    check_pass "Nix support available"
fi
echo ""

# Category 4: CI/CD
echo -e "${BLUE}4. CI/CD Pipeline${NC}"
if [ -f ".gitlab-ci.yml" ]; then
    check_pass "GitLab CI/CD configured"
elif [ -f ".github/workflows" ]; then
    check_pass "GitHub Actions configured"
else
    check_fail "No CI/CD configuration found"
fi
echo ""

# Category 5: Testing
echo -e "${BLUE}5. Testing Infrastructure${NC}"
check_dir "tests" "tests"
if [ -d "tests/unit" ]; then
    check_pass "Unit tests directory exists"
fi
if [ -d "tests/integration" ]; then
    check_pass "Integration tests directory exists"
fi

# Check for test files
TEST_COUNT=$(find tests -name "*.ts" -o -name "*.res" 2>/dev/null | wc -l)
if [ "$TEST_COUNT" -gt 0 ]; then
    check_pass "Test files present ($TEST_COUNT files)"
else
    check_fail "No test files found"
fi
echo ""

# Category 6: Source Code
echo -e "${BLUE}6. Source Code Quality${NC}"
check_dir "src" "src"

# Count ReScript source files
RESCRIPT_COUNT=$(find src -name "*.res" 2>/dev/null | wc -l)
if [ "$RESCRIPT_COUNT" -gt 0 ]; then
    check_pass "ReScript source files present ($RESCRIPT_COUNT files)"

    # Check for 100+ lines requirement
    TOTAL_LINES=$(find src -name "*.res" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
    if [ "$TOTAL_LINES" -ge 100 ]; then
        check_pass "Minimum 100 lines of code ($TOTAL_LINES lines)"
    else
        check_fail "Less than 100 lines of code ($TOTAL_LINES lines)"
    fi
else
    check_fail "No ReScript source files found"
fi
echo ""

# Category 7: Examples
echo -e "${BLUE}7. Examples and Documentation${NC}"
check_dir "examples" "examples"

EXAMPLE_COUNT=$(find examples -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
if [ "$EXAMPLE_COUNT" -gt 0 ]; then
    check_pass "Example applications present ($EXAMPLE_COUNT examples)"
else
    check_warn "No example applications found"
fi

check_dir "docs" "docs"
echo ""

# Category 8: Type Safety
echo -e "${BLUE}8. Type Safety${NC}"
if [ -f "rescript.json" ]; then
    # Check for warnings configuration
    if grep -q "\"warnings\"" rescript.json; then
        check_pass "Compiler warnings configured"
    else
        check_warn "No compiler warnings configuration"
    fi

    # Check for proper module format
    if grep -q "\"esmodule\"" rescript.json; then
        check_pass "ES module format configured"
    else
        check_warn "Non-ESM module format"
    fi
fi
echo ""

# Category 9: Offline-First
echo -e "${BLUE}9. Offline-First Architecture${NC}"
# Check for network calls in core source (basic check)
NETWORK_CALLS=$(grep -r "fetch\|http\|websocket" src/*.res 2>/dev/null | grep -v "^src/Deno.res" | grep -v "^src/Bun.res" | wc -l || echo "0")
if [ "$NETWORK_CALLS" -eq 0 ]; then
    check_pass "No network calls in core modules (offline-capable)"
else
    check_warn "Network calls found in core modules ($NETWORK_CALLS occurrences)"
fi
echo ""

# Category 10: TPCF Compliance
echo -e "${BLUE}10. TPCF (Tri-Perimeter Contribution Framework)${NC}"
if check_file "TPCF.md" "TPCF.md documentation"; then
    if grep -q "Perimeter 3" TPCF.md; then
        check_pass "TPCF perimeters documented"
    fi
fi

if [ -f "CONTRIBUTING.md" ]; then
    if grep -q "Code of Conduct" CONTRIBUTING.md || [ -f "CODE_OF_CONDUCT.md" ]; then
        check_pass "Community guidelines present"
    fi
fi
echo ""

# Category 11: Security
echo -e "${BLUE}11. Security Standards${NC}"
if [ -f "SECURITY.md" ]; then
    if grep -q "Reporting a Vulnerability" SECURITY.md; then
        check_pass "Vulnerability reporting process documented"
    fi
fi

if [ -f ".well-known/security.txt" ]; then
    # Check for RFC 9116 compliance
    if grep -q "Contact:" .well-known/security.txt && grep -q "Expires:" .well-known/security.txt; then
        check_pass "security.txt is RFC 9116 compliant"
    else
        check_warn "security.txt may not be fully RFC 9116 compliant"
    fi
fi

# Check for .gitignore to prevent secret leaks
if check_file ".gitignore" ".gitignore"; then
    if grep -q ".env" .gitignore; then
        check_pass "Environment files ignored"
    else
        check_warn "No .env in .gitignore"
    fi
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}RSR Compliance Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Total Checks: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo ""

# Calculate compliance percentage
COMPLIANCE=$(( (PASSED * 100) / TOTAL ))
echo -e "Compliance Score: ${COMPLIANCE}%"
echo ""

# Determine tier
if [ "$FAILED" -eq 0 ] && [ "$COMPLIANCE" -ge 95 ]; then
    TIER="Gold"
    COLOR=$YELLOW
elif [ "$FAILED" -le 2 ] && [ "$COMPLIANCE" -ge 85 ]; then
    TIER="Silver"
    COLOR=$NC
elif [ "$COMPLIANCE" -ge 70 ]; then
    TIER="Bronze"
    COLOR=$YELLOW
else
    TIER="Non-Compliant"
    COLOR=$RED
fi

echo -e "${COLOR}RSR Tier: $TIER${NC}"
echo ""

# Recommendations
if [ "$FAILED" -gt 0 ] || [ "$WARNINGS" -gt 0 ]; then
    echo -e "${BLUE}Recommendations:${NC}"

    if [ ! -f "SECURITY.md" ]; then
        echo "- Add SECURITY.md with vulnerability reporting process"
    fi

    if [ ! -f "CODE_OF_CONDUCT.md" ]; then
        echo "- Add CODE_OF_CONDUCT.md for community guidelines"
    fi

    if [ ! -f "MAINTAINERS.md" ]; then
        echo "- Add MAINTAINERS.md listing project maintainers"
    fi

    if [ ! -d ".well-known" ]; then
        echo "- Create .well-known/ directory with security.txt, ai.txt, humans.txt"
    fi

    if [ ! -f "flake.nix" ]; then
        echo "- Add flake.nix for Nix reproducible builds"
    fi

    if [ "$TEST_COUNT" -eq 0 ]; then
        echo "- Add unit and integration tests"
    fi

    echo ""
fi

# Exit with appropriate code
if [ "$COMPLIANCE" -ge 70 ]; then
    echo -e "${GREEN}✓ RSR compliance check passed${NC}"
    exit 0
else
    echo -e "${RED}✗ RSR compliance check failed${NC}"
    exit 1
fi
