#!/usr/bin/env bash

set -euo pipefail

# RSR Framework Compliance Verification Script
# Checks asdf-ghjk against RSR standards

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Check result
check() {
  local name="$1"
  local condition="$2"

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  if eval "$condition"; then
    echo -e "  ${GREEN}✓${NC} $name"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  else
    echo -e "  ${RED}✗${NC} $name"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    return 1
  fi
}

# Section header
section() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   RSR Framework Compliance Verification          ║${NC}"
echo -e "${BLUE}║   asdf-ghjk Plugin                                ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
# Category 1: Documentation
# =============================================================================
section "Category 1: Documentation"

check "README exists" "[[ -f README.md ]] || [[ -f README.adoc ]]"
check "README is comprehensive (>100 lines)" "[[ -f README.md ]] && [[ \$(wc -l < README.md) -gt 100 ]] || [[ -f README.adoc ]] && [[ \$(wc -l < README.adoc) -gt 100 ]]"
check "CONTRIBUTING exists" "[[ -f CONTRIBUTING.md ]] || [[ -f CONTRIBUTING.adoc ]]"
check "CODE_OF_CONDUCT.md exists" "[[ -f CODE_OF_CONDUCT.md ]]"
check "MAINTAINERS exists" "[[ -f MAINTAINERS.md ]] || [[ -f MAINTAINERS.adoc ]]"
check "SECURITY.md exists" "[[ -f SECURITY.md ]]"
check "CHANGELOG exists" "[[ -f CHANGELOG.md ]] || [[ -f CHANGELOG.adoc ]]"
check "ARCHITECTURE.md exists" "[[ -f docs/ARCHITECTURE.md ]]"
check "API_REFERENCE.md exists" "[[ -f docs/API_REFERENCE.md ]]"
check "FAQ.md exists" "[[ -f docs/FAQ.md ]]"
check "QUICKSTART.md exists" "[[ -f docs/QUICKSTART.md ]]"
check "TROUBLESHOOTING.md exists" "[[ -f docs/TROUBLESHOOTING.md ]]"
check "EXAMPLES.md exists" "[[ -f docs/EXAMPLES.md ]]"
check "MIGRATION.md exists" "[[ -f docs/MIGRATION.md ]]"

# =============================================================================
# Category 2: Licensing
# =============================================================================
section "Category 2: Licensing"

check "LICENSE.txt exists" "[[ -f LICENSE.txt ]]"
check "LICENSE contains MIT" "grep -q 'MIT License' LICENSE.txt"
check "LICENSE contains Palimpsest" "grep -q 'Palimpsest' LICENSE.txt"
check "Dual licensing explained" "grep -q 'Dual License' LICENSE.txt"
check "SPDX identifier present" "grep -q 'SPDX-License-Identifier' LICENSE.txt"

# =============================================================================
# Category 3: Security
# =============================================================================
section "Category 3: Security"

check "SECURITY.md exists" "[[ -f SECURITY.md ]]"
check "security.txt exists" "[[ -f .well-known/security.txt ]]"
check "security.txt is RFC 9116 compliant" "grep -q 'Contact:' .well-known/security.txt"
check "Checksum verification in download script" "grep -q 'verify_checksum' bin/download"
check "HTTPS-only downloads" "grep -q 'https://' bin/download && ! grep -q 'http://' bin/download || true"
check "Input validation present" "grep -q 'ASDF_INSTALL_VERSION' bin/download"

# =============================================================================
# Category 4: Contributing
# =============================================================================
section "Category 4: Contributing"

check "CONTRIBUTING comprehensive (>50 lines)" "[[ -f CONTRIBUTING.md ]] && [[ \$(wc -l < CONTRIBUTING.md) -gt 50 ]] || [[ -f CONTRIBUTING.adoc ]] && [[ \$(wc -l < CONTRIBUTING.adoc) -gt 5 ]]"
check "CODE_OF_CONDUCT follows Contributor Covenant" "grep -q 'Contributor Covenant' CODE_OF_CONDUCT.md"
check "Issue templates exist" "[[ -d .github/ISSUE_TEMPLATE ]]"
check "Bug report template exists" "[[ -f .github/ISSUE_TEMPLATE/bug_report.md ]]"
check "Feature request template exists" "[[ -f .github/ISSUE_TEMPLATE/feature_request.md ]]"
check "PR template exists" "[[ -f .github/pull_request_template.md ]]"

# =============================================================================
# Category 5: Governance
# =============================================================================
section "Category 5: Governance"

check "MAINTAINERS exists" "[[ -f MAINTAINERS.md ]] || [[ -f MAINTAINERS.adoc ]]"
check "CODEOWNERS exists" "[[ -f .github/CODEOWNERS ]]"
check "Maintainer responsibilities documented" "grep -q 'Responsibilities' MAINTAINERS.md 2>/dev/null || grep -qi 'responsibilities' MAINTAINERS.adoc 2>/dev/null"
check "Decision-making process documented" "grep -q 'Decision Making' MAINTAINERS.md 2>/dev/null || grep -qi 'decision' MAINTAINERS.adoc 2>/dev/null || grep -q 'decision' MAINTAINERS.md 2>/dev/null"
check "RSR.md with TPCF declaration exists" "[[ -f RSR.md ]]"
check "TPCF perimeter declared" "grep -q 'Perimeter 3' RSR.md"

# =============================================================================
# Category 6: Testing
# =============================================================================
section "Category 6: Testing"

check "Test directory exists" "[[ -d test ]]"
check "Unit tests exist" "[[ -f test/utils.bats ]]"
check "Integration tests exist" "[[ -f test/list-all.bats ]] && [[ -f test/download.bats ]]"
check "Test helpers exist" "[[ -f test/test_helpers.bash ]]"
check "CI/CD workflow exists" "[[ -f .github/workflows/ci.yml ]]"
check "CI tests multiple platforms" "grep -q 'ubuntu-latest' .github/workflows/ci.yml && grep -q 'macos-latest' .github/workflows/ci.yml"

# =============================================================================
# Category 7: Build System
# =============================================================================
section "Category 7: Build System"

check "Build system exists" "[[ -f Makefile ]] || [[ -f Justfile ]] || [[ -f justfile ]]"
check "Justfile exists" "[[ -f Justfile ]] || [[ -f justfile ]]"
check "Nix/Guix package definition exists" "[[ -f flake.nix ]] || [[ -f guix.scm ]] || [[ -f default.nix ]]"
check "Build system has test target" "grep -qi 'test' Makefile 2>/dev/null || grep -qi 'test' Justfile 2>/dev/null || grep -qi 'test' justfile 2>/dev/null"
check "Build system has lint target" "grep -qi 'lint' Makefile 2>/dev/null || grep -qi 'lint' Justfile 2>/dev/null || grep -qi 'lint' justfile 2>/dev/null"
check "Dev setup script exists" "[[ -f scripts/setup-dev.sh ]]"
check "Setup script is executable" "[[ -x scripts/setup-dev.sh ]]"

# =============================================================================
# Category 8: Versioning
# =============================================================================
section "Category 8: Versioning"

check "CHANGELOG follows Keep a Changelog" "grep -qi 'Changelog' CHANGELOG.md 2>/dev/null || grep -qi 'Changelog' CHANGELOG.adoc 2>/dev/null"
check "CHANGELOG has Unreleased section" "grep -qi 'Unreleased' CHANGELOG.md 2>/dev/null || grep -qi 'Unreleased' CHANGELOG.adoc 2>/dev/null"
check "Semantic versioning mentioned" "grep -qi 'Semantic Versioning' CHANGELOG.md 2>/dev/null || grep -qi 'semver' CHANGELOG.adoc 2>/dev/null || grep -qi 'Semantic' CHANGELOG.adoc 2>/dev/null"

# =============================================================================
# Category 9: .well-known
# =============================================================================
section "Category 9: .well-known Directory"

check ".well-known directory exists" "[[ -d .well-known ]]"
check "security.txt exists and valid" "[[ -f .well-known/security.txt ]] && grep -q 'RFC 9116' .well-known/security.txt"
check "ai.txt exists" "[[ -f .well-known/ai.txt ]]"
check "ai.txt has training policy" "grep -q 'TRAINING PERMISSIONS' .well-known/ai.txt"
check "humans.txt exists" "[[ -f .well-known/humans.txt ]]"
check "humans.txt has team info" "grep -q 'TEAM' .well-known/humans.txt"

# =============================================================================
# Category 10: Community
# =============================================================================
section "Category 10: Community"

check "Issue templates directory exists" "[[ -d .github/ISSUE_TEMPLATE ]]"
check "Multiple issue templates" "[[ \$(ls -1 .github/ISSUE_TEMPLATE/*.md 2>/dev/null | wc -l) -ge 2 ]]"
check "PR template exists" "[[ -f .github/pull_request_template.md ]]"
check "CODE_OF_CONDUCT references enforcement" "grep -q 'Enforcement' CODE_OF_CONDUCT.md"

# =============================================================================
# Category 11: Automation
# =============================================================================
section "Category 11: Automation"

check "CI workflow exists" "[[ -f .github/workflows/ci.yml ]]"
check "Release workflow exists" "[[ -f .github/workflows/release.yml ]]"
check "Pre-commit config exists" "[[ -f .pre-commit-config.yaml ]]"
check "ShellCheck in CI" "grep -q 'shellcheck' .github/workflows/ci.yml"
check "Automated tests in CI" "grep -q 'test' .github/workflows/ci.yml"

# =============================================================================
# Bonus: Additional Quality Markers
# =============================================================================
section "Bonus: Excellence Markers"

check "Shell completions exist" "[[ -d completions ]]"
check "Container examples exist" "[[ -d examples ]] && { [[ -f examples/Dockerfile ]] || [[ -f examples/Containerfile ]]; }"
check "Benchmark script exists" "[[ -f scripts/benchmark.sh ]]"
check "Doctor diagnostic script exists" "[[ -f scripts/doctor.sh ]]"
check "Cleanup utility exists" "[[ -f scripts/cleanup.sh ]]"

# =============================================================================
# Summary
# =============================================================================
section "Summary"

PERCENTAGE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

echo ""
echo "  Total Checks: $TOTAL_CHECKS"
echo -e "  ${GREEN}Passed: $PASSED_CHECKS${NC}"
if [[ $FAILED_CHECKS -gt 0 ]]; then
  echo -e "  ${RED}Failed: $FAILED_CHECKS${NC}"
fi
echo "  Score: $PERCENTAGE%"
echo ""

# Determine RSR level
if [[ $PERCENTAGE -eq 100 ]]; then
  LEVEL="Platinum"
  COLOR=$GREEN
elif [[ $PERCENTAGE -ge 90 ]]; then
  LEVEL="Gold"
  COLOR=$GREEN
elif [[ $PERCENTAGE -ge 70 ]]; then
  LEVEL="Silver"
  COLOR=$BLUE
elif [[ $PERCENTAGE -ge 50 ]]; then
  LEVEL="Bronze"
  COLOR=$YELLOW
else
  LEVEL="Not Compliant"
  COLOR=$RED
fi

echo -e "${COLOR}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${COLOR}║   RSR Level: ${LEVEL}${NC}$(printf "%$((48 - ${#LEVEL}))s")${COLOR}║${NC}"
echo -e "${COLOR}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Exit code
if [[ $PERCENTAGE -lt 70 ]]; then
  echo -e "${YELLOW}⚠️  Recommendation: Aim for Silver level (70%) or higher${NC}"
  exit 1
fi

if [[ $FAILED_CHECKS -gt 0 ]]; then
  echo -e "${YELLOW}⚠️  Some checks failed. See above for details.${NC}"
  exit 1
fi

echo -e "${GREEN}✅ RSR compliance verification passed!${NC}"
exit 0
