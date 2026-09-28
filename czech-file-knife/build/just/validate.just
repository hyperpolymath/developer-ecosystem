# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# VALIDATION & COMPLIANCE
#
# Imported by ../../Justfile via `import? "build/just/validate.just"`.
# Recipes here check that this repo conforms to the RSR (Rhodium Standard
# Repository) skeleton: required files, METAdata, AI install guide
# completeness, etc. Run via `just validate`.

# Validate RSR compliance
validate-rsr:
    #!/usr/bin/env bash
    cd "{{justfile_directory()}}"
    echo "=== RSR Compliance Check ==="
    MISSING=""
    for f in .editorconfig .gitignore Justfile README.adoc LICENSE; do
        [ -f "$f" ] || MISSING="$MISSING $f"
    done
    # The repo deed's filename carries the repo slug (<stem>_chora.deed), so
    # this is a glob; the folded replacement of the old 0-AI-MANIFEST.a2ml.
    ls *_chora.deed >/dev/null 2>&1 || MISSING="$MISSING repo-deed (*_chora.deed)"
    for f in .machine_readable/descriptiles/STATE.a2ml .machine_readable/descriptiles/META.a2ml .machine_readable/descriptiles/ECOSYSTEM.a2ml .machine_readable/descriptiles/anchors/ANCHOR.a2ml .machine_readable/policies/MAINTENANCE-AXES.a2ml .machine_readable/policies/MAINTENANCE-CHECKLIST.a2ml .machine_readable/policies/SOFTWARE-DEVELOPMENT-APPROACH.a2ml; do
        [ -f "$f" ] || MISSING="$MISSING $f"
    done
    for f in docs/legal/EXHIBIT-A-ETHICAL-USE.txt docs/legal/EXHIBIT-B-QUANTUM-SAFE.txt LICENSES/MPL-2.0.txt; do
        [ -f "$f" ] || MISSING="$MISSING $f"
    done
    if [ ! -d "src/interface/abi" ] && [ ! -d "src/interface/Abi" ]; then
        MISSING="$MISSING src/interface/abi"
    fi
    for f in src/interface/ffi src/interface/generated; do
        [ -d "$f" ] || MISSING="$MISSING $f"
    done
    for f in docs/governance/MAINTENANCE-CHECKLIST.adoc docs/governance/SOFTWARE-DEVELOPMENT-APPROACH.adoc; do
        [ -f "$f" ] || MISSING="$MISSING $f"
    done
    if [ -f ".machine_readable/descriptiles/META.a2ml" ]; then
        grep -q 'axis-1 = "must > intend > like"' .machine_readable/descriptiles/META.a2ml || MISSING="$MISSING META.a2ml:axis-1"
        grep -q 'axis-2 = "corrective > adaptive > perfective"' .machine_readable/descriptiles/META.a2ml || MISSING="$MISSING META.a2ml:axis-2"
        grep -q 'axis-3 = "systems > compliance > effects"' .machine_readable/descriptiles/META.a2ml || MISSING="$MISSING META.a2ml:axis-3"
        grep -q 'scoping-first = true' .machine_readable/descriptiles/META.a2ml || MISSING="$MISSING META.a2ml:scoping-first"
        grep -q 'idris-unsound-scan = "believe_me/assert_total"' .machine_readable/descriptiles/META.a2ml || MISSING="$MISSING META.a2ml:idris-unsound-scan"
        grep -q 'audit-focus = "systems in place, documentation explains actual state, safety/security accounted for, observed effects reviewed"' .machine_readable/descriptiles/META.a2ml || MISSING="$MISSING META.a2ml:audit-focus"
        grep -q 'compliance-focus = "seams/compromises/exception register, bounded exceptions, anti-drift checks"' .machine_readable/descriptiles/META.a2ml || MISSING="$MISSING META.a2ml:compliance-focus"
        grep -q 'effects-evidence = "benchmark execution/results and maintainer status dialogue/review"' .machine_readable/descriptiles/META.a2ml || MISSING="$MISSING META.a2ml:effects-evidence"
        grep -q 'compliance-tooling = "panic-attack"' .machine_readable/policies/MAINTENANCE-AXES.a2ml || MISSING="$MISSING MAINTENANCE-AXES.a2ml:compliance-tooling"
        grep -q 'effects-tooling = "ecological checking with sustainabot guidance"' .machine_readable/policies/MAINTENANCE-AXES.a2ml || MISSING="$MISSING MAINTENANCE-AXES.a2ml:effects-tooling"
        grep -q 'source-human = "docs/governance/MAINTENANCE-CHECKLIST.adoc"' .machine_readable/policies/MAINTENANCE-CHECKLIST.a2ml || MISSING="$MISSING MAINTENANCE-CHECKLIST.a2ml:source-human"
        grep -q 'source-human = "docs/governance/SOFTWARE-DEVELOPMENT-APPROACH.adoc"' .machine_readable/policies/SOFTWARE-DEVELOPMENT-APPROACH.a2ml || MISSING="$MISSING SOFTWARE-DEVELOPMENT-APPROACH.a2ml:source-human"
    fi
    if [ -n "$MISSING" ]; then
        echo "MISSING:$MISSING"
        exit 1
    fi
    echo "RSR compliance: PASS"

# Validate STATE.a2ml syntax
validate-state:
    @cd "{{justfile_directory()}}" && if [ -f ".machine_readable/descriptiles/STATE.a2ml" ]; then \
        grep -q '^\[metadata\]' .machine_readable/descriptiles/STATE.a2ml && \
        grep -q 'project\s*=' .machine_readable/descriptiles/STATE.a2ml && \
        echo "STATE.a2ml: valid" || echo "STATE.a2ml: INVALID (missing required sections)"; \
    else \
        echo "No .machine_readable/descriptiles/STATE.a2ml found"; \
    fi

# Validate AI installation guide completeness (finishbot pre-release check)
validate-ai-install:
    #!/usr/bin/env bash
    cd "{{justfile_directory()}}"
    echo "=== AI Installation Guide Check ==="
    GUIDE="docs/AI_INSTALLATION_GUIDE.adoc"
    README="README.adoc"
    ERRORS=0

    # Check guide exists
    if [ ! -f "$GUIDE" ]; then
        echo "MISSING: $GUIDE (create from template: docs/AI_INSTALLATION_GUIDE.adoc)"
        ERRORS=$((ERRORS + 1))
    else
        # Check for unfilled TODO markers
        TODOS=$(grep -c '\[TODO-AI-INSTALL' "$GUIDE" 2>/dev/null || true)
        if [ "$TODOS" -gt 0 ]; then
            echo "INCOMPLETE: $GUIDE has $TODOS unfilled [TODO-AI-INSTALL] markers:"
            grep -n '\[TODO-AI-INSTALL' "$GUIDE" | head -10
            ERRORS=$((ERRORS + 1))
        else
            echo "$GUIDE: complete (no TODO markers)"
        fi

        # Check AI implementation section exists
        if ! grep -q 'ai-implementation' "$GUIDE" 2>/dev/null; then
            echo "MISSING: [[ai-implementation]] anchor in $GUIDE"
            ERRORS=$((ERRORS + 1))
        fi

        # Check privacy notice exists
        if ! grep -qi 'privacy' "$GUIDE" 2>/dev/null; then
            echo "MISSING: Privacy notice in $GUIDE"
            ERRORS=$((ERRORS + 1))
        fi

        # Check install commands exist (not just placeholders)
        if ! grep -q 'git clone' "$GUIDE" 2>/dev/null; then
            echo "WARNING: No git clone command found in $GUIDE -- install commands may be incomplete"
        fi
    fi

    # Check README has AI install section
    if [ -f "$README" ]; then
        if ! grep -qi 'AI-Assisted Installation' "$README" 2>/dev/null; then
            echo "MISSING: AI-Assisted Installation section in $README"
            echo "  Copy from docs/AI-INSTALL-README-SECTION.adoc"
            ERRORS=$((ERRORS + 1))
        fi

        # Check README for unfilled TODO markers
        README_TODOS=$(grep -c '\[TODO-AI-INSTALL' "$README" 2>/dev/null || true)
        if [ "$README_TODOS" -gt 0 ]; then
            echo "INCOMPLETE: $README has $README_TODOS unfilled [TODO-AI-INSTALL] markers"
            ERRORS=$((ERRORS + 1))
        fi
    fi

    if [ "$ERRORS" -gt 0 ]; then
        echo ""
        echo "AI install guide: FAIL ($ERRORS issues)"
        exit 1
    fi
    echo "AI install guide: PASS"

# Full validation suite
validate: validate-rsr validate-state validate-ai-install
    @echo "All validations passed!"
