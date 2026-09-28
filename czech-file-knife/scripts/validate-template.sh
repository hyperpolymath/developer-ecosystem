#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# RSR Template Validation Script
# Verifies that a repository follows the RSR template structure and contains all required files
#
# Exit codes:
#   0 = validation passed
#   1 = validation failed with errors
#   2 = validation failed with warnings (but can proceed)

set -euo pipefail

REPO_ROOT="${1:-.}"
VERBOSE="${2:-0}"
ERRORS=0
WARNINGS=0

# ANSI colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_error() {
    echo -e "${RED}ERROR${NC}: $*" >&2
    ERRORS=$((ERRORS + 1))
}

log_warning() {
    echo -e "${YELLOW}WARN${NC}: $*" >&2
    WARNINGS=$((WARNINGS + 1))
}

log_info() {
    echo -e "${BLUE}INFO${NC}: $*" >&2
}

log_pass() {
    echo -e "${GREEN}PASS${NC}: $*" >&2
}

check_file_exists() {
    local file="$1"
    local description="${2:-}"
    if [ -f "$REPO_ROOT/$file" ]; then
        [ "$VERBOSE" = "1" ] && log_pass "File exists: $file"
        return 0
    else
        log_error "Required file missing: $file ${description:+(${description})}"
        return 1
    fi
}

# The repo deed's FILENAME carries the repository name (filename dispatch:
# <stem>_chora.deed, stem = repo slug — deed.abnf v1.0.0), so the check is a
# glob, not a literal. Pre-deed era this slot was 0-AI-MANIFEST.a2ml; the
# family-7 allocation manifest and the ply tree folded into the deed
# (standards#837 pilot).
check_deed_exists() {
    local description="${1:-}"
    local f
    for f in "$REPO_ROOT"/*_chora.deed; do
        if [ -f "$f" ]; then
            [ "$VERBOSE" = "1" ] && log_pass "Repo deed exists: ${f#"$REPO_ROOT"/}"
            return 0
        fi
    done
    log_error "Required repo deed missing: no <reponame>_chora.deed at root ${description:+(${description})}"
    return 1
}

check_file_either() {
    local first="$1"
    local second="$2"
    local description="${3:-}"
    if [ -f "$REPO_ROOT/$first" ] || [ -f "$REPO_ROOT/$second" ]; then
        [ "$VERBOSE" = "1" ] && log_pass "File exists: $first or $second"
        return 0
    fi
    log_error "Required file missing: $first or $second ${description:+($description)}"
    return 1
}

check_dir_exists() {
    local dir="$1"
    local description="${2:-}"
    if [ -d "$REPO_ROOT/$dir" ]; then
        [ "$VERBOSE" = "1" ] && log_pass "Directory exists: $dir"
        return 0
    else
        log_error "Required directory missing: $dir ${description:+(${description})}"
        return 1
    fi
}

# The machine tree has two estate spellings: `.machine_readable/` is canonical,
# `machine-readable/` is the minority form ~9 repositories still carry. This
# file already had check_file_either for exactly this reason; directories had no
# such helper, and the gap let the matrix check below name the hyphenated form
# while its own message said `.machine_readable/`. Naming only one spelling
# fails whichever half of the estate has not migrated.
check_dir_either() {
    local first="$1"
    local second="$2"
    local description="${3:-}"
    if [ -d "$REPO_ROOT/$first" ] || [ -d "$REPO_ROOT/$second" ]; then
        [ "$VERBOSE" = "1" ] && log_pass "Directory exists: $first or $second"
        return 0
    fi
    log_error "Required directory missing: $first or $second ${description:+(${description})}"
    return 1
}

# Case-tolerant ABI seam checks: accept the canonical case-consistent
# src/interface/Abi/ (matches `module Abi.*`) OR a lowercase src/interface/abi/
# that some downstream repos ship. Never require BOTH (that would be a case-fold
# collision on case-insensitive filesystems).
check_abi_dir_exists() {
    local description="${1:-}"
    if [ -d "$REPO_ROOT/src/interface/Abi" ] || [ -d "$REPO_ROOT/src/interface/abi" ]; then
        [ "$VERBOSE" = "1" ] && log_pass "Directory exists: src/interface/{Abi,abi}"
        return 0
    fi
    log_error "Required directory missing: src/interface/Abi ${description:+(${description})}"
    return 1
}
check_abi_file_exists() {
    local fname="$1"
    local description="${2:-}"
    if [ -f "$REPO_ROOT/src/interface/Abi/$fname" ] || [ -f "$REPO_ROOT/src/interface/abi/$fname" ]; then
        [ "$VERBOSE" = "1" ] && log_pass "File exists: src/interface/{Abi,abi}/$fname"
        return 0
    fi
    log_error "Required file missing: src/interface/Abi/$fname ${description:+(${description})}"
    return 1
}

has_spdx_header() {
    local file="$1"
    if head -10 "$file" | grep -q "SPDX-License-Identifier"; then
        return 0
    fi
    return 1
}

has_placeholder() {
    local file="$1"
    if grep -q "{{REPO\|{{OWNER\|{{FORGE\|{{PROJECT\|{{project\|{{AUTHOR" "$file" 2>/dev/null; then
        return 0
    fi
    return 1
}

#==============================================================================
# VALIDATION PHASE 1: CORE STRUCTURE
#==============================================================================

echo ""
log_info "Phase 1: Core repository structure"
echo ""

# Root files
check_deed_exists "repo deed (universal AI entry point)"
check_file_exists "README.adoc" "High-level pitch"
check_file_either "EXPLAINME.adoc" "docs/EXPLAINME.adoc" "Developer deep-dive"
check_file_exists "LICENSE" "License file"
check_file_exists "Justfile" "Task runner"
check_file_either "AUDIT.adoc" "docs/AUDIT.adoc" "Release audit gate"

# Directories
check_dir_either ".machine_readable" "machine-readable" "Machine-readable metadata"
check_dir_exists ".github" "GitHub community metadata"
check_abi_dir_exists "Idris2 ABI definitions"
check_dir_exists "src/interface/ffi" "Zig FFI implementation"
check_dir_exists "src/interface/generated/abi" "Generated C headers"
check_dir_exists "docs" "Documentation"

#==============================================================================
# VALIDATION PHASE 2: MACHINE-READABLE METADATA
#==============================================================================

echo ""
log_info "Phase 2: Machine-readable metadata (.machine_readable/)"
echo ""

check_file_exists ".machine_readable/descriptiles/STATE.a2ml" "Project state"
check_file_exists ".machine_readable/descriptiles/META.a2ml" "Architecture decisions"
check_file_exists ".machine_readable/descriptiles/ECOSYSTEM.a2ml" "Ecosystem position"
check_file_exists ".machine_readable/descriptiles/anchors/ANCHOR.a2ml" "Semantic boundary anchor"
check_file_exists ".machine_readable/policies/MAINTENANCE-AXES.a2ml" "Maintenance axes"

#==============================================================================
# VALIDATION PHASE 3: REQUIRED WORKFLOWS (17 minimum)
#==============================================================================

echo ""
log_info "Phase 3: GitHub Actions workflows"
echo ""

REQUIRED_WORKFLOWS=(
    "hypatia-scan.yml"
    "codeql.yml"
    "scorecard.yml"
    "quality.yml"
    "mirror.yml"
    "guix-policy.yml"
    "security-policy.yml"
    "wellknown-enforcement.yml"
    "workflow-linter.yml"
    # npm-bun-blocker.yml and ts-blocker.yml were retired in #14 and replaced by
    # runtime-policy.yml: the old gate failed any build carrying bun.lockb with
    # "Use Deno instead", which blocked the estate's new first-choice runtime, so
    # none of the 55 repos carrying it ever adopted Bun. This list was not
    # updated, so it has required two files the template deliberately no longer
    # ships — which is why validate-template.sh has been red since that merge.
    "runtime-policy.yml"
    "secret-scanner.yml"
)

# A workflow renamed upstream must not read as a missing workflow here. #106
# moved wellknown-enforcement.yml to dot-wellknown-enforcement.yml to match the
# .well-known/ URL convention and left this list requiring the old name, so this
# gate failed on main — the same way it failed when the two retired files above
# stayed listed. Resolve EITHER spelling and let the alias be dropped once the
# rename has propagated, exactly as check-root-shape.sh resolves both root
# spellings instead of assuming the migration is finished everywhere.
WORKFLOW_ALIASES=(
    "wellknown-enforcement.yml:dot-wellknown-enforcement.yml"
)

resolve_required_workflow() {
    local want="$1" pair alt
    if [ -f "$REPO_ROOT/.github/workflows/$want" ]; then
        printf '%s\n' "$want"
        return 0
    fi
    for pair in "${WORKFLOW_ALIASES[@]}"; do
        [ "${pair%%:*}" = "$want" ] || continue
        alt="${pair#*:}"
        if [ -f "$REPO_ROOT/.github/workflows/$alt" ]; then
            printf '%s\n' "$alt"
            return 0
        fi
    done
    return 1
}

# Check required workflows
for workflow in "${REQUIRED_WORKFLOWS[@]}"; do
    if found="$(resolve_required_workflow "$workflow")"; then
        [ "$VERBOSE" = "1" ] && log_pass "Workflow found: $found"
    else
        log_error "Required workflow missing: $workflow"
    fi
done

# Verify all workflows have SPDX headers and proper structure
WORKFLOW_FILES=$(find "$REPO_ROOT/.github/workflows" -name "*.yml" -type f 2>/dev/null || true)
WORKFLOW_COUNT=$(echo "$WORKFLOW_FILES" | grep -c "." || true)

if [ "$WORKFLOW_COUNT" -ge 15 ]; then
    log_pass "Found $WORKFLOW_COUNT workflows (>= 15 expected)"
else
    log_warning "Found only $WORKFLOW_COUNT workflows (expected >= 15)"
fi

# Spot-check workflow files for issues
while IFS= read -r workflow_file; do
    if [ -z "$workflow_file" ]; then continue; fi

    # Check for SPDX header (optional in YAML workflows, but best practice)
    if ! head -5 "$workflow_file" | grep -q "SPDX-License-Identifier"; then
        log_warning "Workflow missing SPDX header: $(basename "$workflow_file")"
    fi

    # Check for proper YAML structure
    if ! grep -q "^name:" "$workflow_file"; then
        log_error "Workflow missing 'name' field: $(basename "$workflow_file")"
    fi
done <<< "$WORKFLOW_FILES"

#==============================================================================
# VALIDATION PHASE 4: ABI/FFI SOURCE FILES
#==============================================================================

echo ""
log_info "Phase 4: Idris2 ABI and Zig FFI source files"
echo ""

# Idris2 ABI files
check_abi_file_exists "Types.idr" "Core type definitions"
check_abi_file_exists "Layout.idr" "Memory layout specifications"
check_abi_file_exists "Foreign.idr" "FFI foreign declarations"

# Zig FFI files
check_file_exists "src/interface/ffi/build.zig" "Zig build configuration"
check_file_exists "src/interface/ffi/src/main.zig" "Zig implementation"
check_file_exists "src/interface/ffi/test/integration_test.zig" "Integration tests"

#==============================================================================
# VALIDATION PHASE 5: PLACEHOLDER TOKENS
#==============================================================================

echo ""
# The heading is unconditional; the skip below is not. It previously read
# "(skipped in template repo)" on every run, so in an instantiated repo — where
# the check DOES run — the log said it had been skipped. A live check that
# reports itself as skipped is worse than a silent one: it invites people to
# stop reading the phase. The skip announces itself on the line that performs it.
log_info "Phase 5: Placeholder token replacement"
echo ""

# Note: Template repo is allowed to have placeholders
# For derived repos, we'd check that placeholders are replaced
if [ "$(basename "$REPO_ROOT")" = "czech-file-knife" ]; then
    log_pass "Skipping placeholder check for template repo"
else
    # Check that key files don't have unresolved placeholders
    for file in "$REPO_ROOT/README.adoc" "$REPO_ROOT/Justfile" "$REPO_ROOT/.machine_readable/descriptiles/STATE.a2ml"; do
        if [ -f "$file" ]; then
            if has_placeholder "$file"; then
                log_warning "File contains unresolved placeholders: $(basename "$file")"
            fi
        fi
    done
fi

#==============================================================================
# VALIDATION PHASE 6: SPDX LICENSE HEADERS
#==============================================================================

echo ""
log_info "Phase 6: SPDX License Headers"
echo ""

# Check source files for SPDX headers (excluding build artifacts).
#
# Scans the whole repository, not just src/, and every estate source language —
# not just Idris2 and Zig.
#
# This used to be `find "$REPO_ROOT/src" ... \( -name "*.idr" -o -name "*.zig" \)`.
# That is fine for the template, whose only sources are src/interface/{abi,ffi},
# but wrong for the repos instantiated from it: a multi-language project keeps
# code in core-zig/, beam/, clients/, normalizer/ and so on, so the scan saw a
# handful of files and printed "SPDX headers: 10/10 (100%)". Measured across all
# languages the same repo was at 172/188 (91%) — the number was not wrong, it was
# answering a much narrower question than it appeared to.
#
# Uses `git ls-files` so it follows .gitignore and never descends into vendored
# or build directories; falls back to `find` outside a work tree.
SPDX_EXTS='idr|zig|rs|ex|exs|res|resi|factor|fs|lean|jl|gleam|ml|mli|hs|sh|nix|scm'
if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    SOURCE_FILES=$(git -C "$REPO_ROOT" ls-files \
        | grep -E "\.($SPDX_EXTS)$" \
        | sed "s|^|$REPO_ROOT/|" || true)
else
    SOURCE_FILES=$(find "$REPO_ROOT" -type f \
        ! -path "*/.git/*" ! -path "*/.zig-cache/*" ! -path "*/zig-cache/*" \
        ! -path "*/node_modules/*" ! -path "*/target/*" ! -path "*/_build/*" \
        ! -path "*/.lake/*" ! -path "*/deps/*" \
        2>/dev/null | grep -E "\.($SPDX_EXTS)$" || true)
fi
SOURCE_COUNT=$(echo "$SOURCE_FILES" | grep -c "." || true)
SPDX_COUNT=0

while IFS= read -r src_file; do
    if [ -z "$src_file" ]; then continue; fi
    if has_spdx_header "$src_file"; then
        SPDX_COUNT=$((SPDX_COUNT + 1))
    else
        log_warning "Source file missing SPDX header: $(basename "$src_file")"
    fi
done <<< "$SOURCE_FILES"

if [ "$SOURCE_COUNT" -gt 0 ]; then
    PERCENT=$((SPDX_COUNT * 100 / SOURCE_COUNT))
    log_pass "SPDX headers: $SPDX_COUNT/$SOURCE_COUNT ($PERCENT%)"
    if [ "$PERCENT" -lt 100 ]; then
        log_warning "Not all source files have SPDX headers"
    fi
fi

#==============================================================================
# VALIDATION PHASE 7: BUILD VERIFICATION
#==============================================================================

echo ""
log_info "Phase 7: Build system verification"
echo ""

# Check Zig build
if [ -f "$REPO_ROOT/src/interface/ffi/build.zig" ]; then
    if command -v zig &> /dev/null; then
        cd "$REPO_ROOT/src/interface/ffi"
        if zig build 2>&1 | grep -q "error"; then
            log_error "Zig build failed"
        else
            log_pass "Zig build successful"
        fi
        cd - > /dev/null
    else
        log_warning "Zig compiler not found - skipping Zig build check"
    fi
else
    log_error "Zig build.zig not found"
fi

# Check Idris2. Prefer a REAL typecheck via the package (abi.ipkg sets the
# sourcedir so the `module Abi.*` namespace resolves); this catches namespace /
# path / import breakage that a bare per-file `idris2 --check` masks as a
# tolerated "module name does not match file name" warning.
if command -v idris2 &> /dev/null; then
    if [ -f "$REPO_ROOT/src/interface/abi.ipkg" ]; then
        if (cd "$REPO_ROOT" && idris2 --typecheck src/interface/abi.ipkg) > /dev/null 2>&1; then
            log_pass "Idris2 ABI typechecks (abi.ipkg)"
        else
            log_error "Idris2 ABI does NOT typecheck (abi.ipkg)"
        fi
    else
        # No package: fall back to a best-effort per-file syntax check (warns on
        # the expected namespace/path mismatch). Look in either case of the dir.
        IDS_FILES=$(find "$REPO_ROOT/src/interface/Abi" "$REPO_ROOT/src/interface/abi" -name "*.idr" -type f 2>/dev/null || true)
        while IFS= read -r ids_file; do
            if [ -z "$ids_file" ]; then continue; fi
            if ! idris2 --check "$ids_file" 2>&1 | grep -q "Error"; then
                log_pass "Idris2 syntax OK: $(basename "$ids_file")"
            else
                log_warning "Idris2 syntax issue: $(basename "$ids_file")"
            fi
        done <<< "$IDS_FILES"
    fi
else
    log_warning "Idris2 compiler not found - skipping Idris2 syntax checks"
fi

#==============================================================================
# VALIDATION PHASE 8: DOCUMENTATION
#==============================================================================

echo ""
log_info "Phase 8: Documentation requirements"
echo ""

check_file_exists "docs/developer/ABI-FFI-README.adoc" "ABI/FFI documentation"
# TOPOLOGY may live at root or under docs/architecture/, .md or .adoc
if [ -f "$REPO_ROOT/TOPOLOGY.adoc" ] || [ -f "$REPO_ROOT/TOPOLOGY.md" ] || \
   [ -f "$REPO_ROOT/docs/architecture/TOPOLOGY.adoc" ] || [ -f "$REPO_ROOT/docs/architecture/TOPOLOGY.md" ]; then
    [ "$VERBOSE" = "1" ] && log_pass "Architecture topology found"
else
    log_error "Required file missing: TOPOLOGY (root or docs/architecture/, .adoc or .md)"
fi
# CONTRIBUTING.md may live at root or in .github/ (GitHub auto-discovers either)
if [ -f "$REPO_ROOT/CONTRIBUTING.md" ] || [ -f "$REPO_ROOT/.github/CONTRIBUTING.md" ]; then
    [ "$VERBOSE" = "1" ] && log_pass "Contribution guide found"
else
    log_error "Required file missing: CONTRIBUTING.md (root or .github/)"
fi

# Governance can be at root or in docs/governance/
if [ -f "$REPO_ROOT/GOVERNANCE.adoc" ] || [ -f "$REPO_ROOT/GOVERNANCE.md" ] || [ -d "$REPO_ROOT/docs/governance" ]; then
    [ "$VERBOSE" = "1" ] && log_pass "Governance files found"
else
    log_warning "Governance documentation not found"
fi

#==============================================================================
# VALIDATION SUMMARY
#==============================================================================

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "VALIDATION SUMMARY"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo -e "Errors:   ${RED}${ERRORS}${NC}"
echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"
echo ""

if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}✓ Validation PASSED${NC}"
    [ "$WARNINGS" -gt 0 ] && echo -e "  (with $WARNINGS warnings)"
    exit 0
else
    echo -e "${RED}✗ Validation FAILED${NC}"
    echo "  Please fix the errors above."
    exit 1
fi
