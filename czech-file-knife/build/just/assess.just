# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# PROJECT SELF-ASSESSMENT + OPENSSF COMPLIANCE VERIFICATION
#
# Imported by ../../Justfile via `import? "build/just/assess.just"`.
# Recipes here advise on what to keep/remove (`self-assess`, read-only) and
# verify that OpenSSF Best Practices prerequisites are present (`verify`,
# called by `init` and CI).

# Analyse this project and advise what to keep, remove, or leave for later.
# Does NOT modify any files — only prints recommendations.
self-assess:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "═══════════════════════════════════════════════════"
    echo "  RSR Project Self-Assessment"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "Scanning project structure to identify what's"
    echo "relevant, removable, or worth keeping for later..."
    echo ""

    # Detect project characteristics
    HAS_RUST=false; [ -f "Cargo.toml" ] && HAS_RUST=true
    HAS_ELIXIR=false; [ -f "mix.exs" ] && HAS_ELIXIR=true
    HAS_RESCRIPT=false; [ -f "rescript.json" ] || [ -f "bsconfig.json" ] && HAS_RESCRIPT=true
    HAS_IDRIS=false; ls *.ipkg >/dev/null 2>&1 && HAS_IDRIS=true
    HAS_ZIG=false; [ -f "build.zig" ] || [ -d "ffi/zig" ] && HAS_ZIG=true
    HAS_GLEAM=false; [ -f "gleam.toml" ] && HAS_GLEAM=true
    HAS_CONTAINER=false; [ -f "Containerfile" ] || [ -f "build/container/Containerfile" ] && HAS_CONTAINER=true
    HAS_TESTS=false; [ -d "test" ] || [ -d "tests" ] || [ -d "__tests__" ] && HAS_TESTS=true
    HAS_API=false; grep -rq 'port\|listen\|endpoint' --include="*.exs" --include="*.rs" --include="*.toml" . 2>/dev/null && HAS_API=true
    IS_LIBRARY=false; [ -f "Cargo.toml" ] && grep -q '\[lib\]' Cargo.toml 2>/dev/null && IS_LIBRARY=true

    echo "Detected: Rust=$HAS_RUST Elixir=$HAS_ELIXIR ReScript=$HAS_RESCRIPT"
    echo "          Idris=$HAS_IDRIS Zig=$HAS_ZIG Gleam=$HAS_GLEAM"
    echo "          Container=$HAS_CONTAINER Tests=$HAS_TESTS API=$HAS_API"
    echo ""

    # ── ESSENTIAL (removing these breaks RSR compliance) ──────────
    echo "── ESSENTIAL (removing breaks Rhodium Standard) ──────────"
    echo ""

    for f in LICENSE .editorconfig .gitignore; do
        if [ -f "$f" ]; then
            echo "  ✓ $f — KEEP (RSR required)"
        else
            echo "  ✗ $f — MISSING (RSR violation!)"
        fi
    done

    # Community health files live at root OR .github/ (.github/ is the estate's
    # canonical location — see .machine_readable/root-allow.txt). Checking root
    # alone reported the template's own .github/ copies as "MISSING (RSR
    # violation!)", which is a false negative.
    for f in SECURITY CODE_OF_CONDUCT CONTRIBUTING; do
        found=""
        for cand in "$f.md" "$f.adoc" ".github/$f.md" ".github/$f.adoc"; do
            [ -f "$cand" ] && { found="$cand"; break; }
        done
        if [ -n "$found" ]; then
            echo "  ✓ $found — KEEP (RSR required)"
        else
            echo "  ✗ $f.md — MISSING at root and .github/ (RSR violation!)"
        fi
    done

    if [ -d ".machine_readable/descriptiles" ]; then
        echo "  ✓ .machine_readable/descriptiles/ — KEEP (SCM checkpoint files)"
    else
        echo "  ✗ .machine_readable/descriptiles/ — MISSING (RSR violation!)"
    fi

    if [ -d ".github/workflows" ]; then
        WF_COUNT=$(ls .github/workflows/*.yml 2>/dev/null | wc -l)
        echo "  ✓ .github/workflows/ — KEEP ($WF_COUNT workflows, RSR CI/CD)"
    fi
    echo ""

    # ── RELEVANT (useful for your project type) ───────────────────
    echo "── RELEVANT (matches your project) ───────────────────────"
    echo ""

    if $HAS_IDRIS && { [ -d "src/interface/abi" ] || [ -d "src/interface/Abi" ]; }; then
        echo "  ✓ src/interface/abi/ — KEEP (Idris2 ABI definitions)"
    elif ! $HAS_IDRIS && { [ -d "src/interface/abi" ] || [ -d "src/interface/Abi" ]; }; then
        echo "  ? src/interface/abi/ — No Idris2 detected."
        echo "    → KEEP if you plan to add formal verification later."
        echo "    → SAFE TO REMOVE if this project will never use Idris2."
        echo "    ⚠ Consequence: no formally verified interface definitions."
    fi

    if $HAS_ZIG && [ -d "src/interface/ffi" ]; then
        echo "  ✓ src/interface/ffi/ — KEEP (Zig FFI bridge)"
    elif ! $HAS_ZIG && [ -d "src/interface/ffi" ]; then
        echo "  ? src/interface/ffi/ — No Zig detected."
        echo "    → KEEP if you plan C ABI interop later."
        echo "    → SAFE TO REMOVE if this is a pure web/scripting project."
        echo "    ⚠ Consequence: no C-compatible FFI bridge."
    fi

    if $HAS_API && [ -f ".machine_readable/integrations/groove.a2ml" ]; then
        PORT=$(grep '(port ' .machine_readable/integrations/groove.a2ml 2>/dev/null | sed 's/.*(port \([0-9]*\)).*/\1/')
        if [ "$PORT" = "0" ]; then
            echo "  ⚠ groove.a2ml — Port not assigned. Run 'just groove-setup'."
        else
            echo "  ✓ groove.a2ml — KEEP (Groove discovery on port $PORT)"
        fi
    elif $HAS_API; then
        echo "  ✗ groove.a2ml — MISSING. Your project has an API but no Groove manifest."
        echo "    → Run 'just groove-setup' to enable snap-on/snap-off discovery."
    fi

    if $HAS_CONTAINER && [ -d "build/container" ]; then
        echo "  ✓ build/container/ — KEEP (Containerfile + compose)"
    elif ! $HAS_CONTAINER && [ -d "build/container" ]; then
        echo "  ? build/container/ — No Containerfile detected in use."
        echo "    → KEEP if you plan to containerise later."
        echo "    → SAFE TO REMOVE for libraries and CLI tools (run: just no-container)."
    fi

    echo ""

    # ── SAFE TO REMOVE (not relevant, no consequences) ────────────
    echo "── SAFE TO REMOVE (no RSR consequences) ──────────────────"
    echo ""

    if ! $HAS_RESCRIPT && [ -d "examples" ] && ls examples/*.res >/dev/null 2>&1; then
        echo "  ○ examples/*.res — Template ReScript examples. Not your code."
    fi

    if [ -f ".machine_readable/ai/PLACEHOLDERS.adoc" ]; then
        echo "  ○ .machine_readable/ai/PLACEHOLDERS.adoc — Template doc. Remove after init."
    fi

    if { [ -f "build/flake.nix" ] || [ -f "flake.nix" ]; } && ! command -v nix >/dev/null 2>&1; then
        echo "  ○ flake.nix — Nix flake. Safe to remove if you don't use Nix."
        echo "    → KEEP if others might build with Nix."
    fi

    if [ -f "build/guix.scm" ] && ! command -v guix >/dev/null 2>&1; then
        echo "  ○ build/guix.scm — Guix package. Safe to remove if you don't use Guix."
        echo "    → KEEP if others might build with Guix."
    fi

    echo ""

    # ── FUTURE VALUE (not needed now, worth keeping) ──────────────
    echo "── KEEP FOR FUTURE (not active, but valuable later) ──────"
    echo ""

    if [ -d ".machine_readable/contractiles" ]; then
        echo "  ◆ contractiles/ — Must/Trust/Dust/Lust contracts."
        echo "    Not enforced until you configure them, but ready when you need"
        echo "    automated compliance checking. Zero cost to keep."
    fi

    if [ -d ".machine_readable/bot_directives" ]; then
        echo "  ◆ bot_directives/ — Gitbot fleet configuration."
        echo "    Not active until gitbot-fleet is connected. Keeps your repo"
        echo "    ready for automated maintenance when the fleet arrives."
    fi

    if [ -d ".machine_readable/bot_directives" ]; then
        echo "  ◆ bot_directives/ — AI agent methodology config."
        echo "    Guides Claude/Gemini/etc on how to work in this repo."
        echo "    No cost to keep. Improves AI assistance quality."
    fi

    if [ -d "docs/governance" ]; then
        echo "  ◆ docs/governance/ — TSDM, CRG, maintenance checklists."
        echo "    Not needed for solo projects. Essential when you add contributors."
    fi

    if [ -d "verification" ]; then
        echo "  ◆ verification/ — Proofs, benchmarks, fuzzing, safety case."
        echo "    Empty scaffolds until you add formal verification."
        echo "    Worth keeping for any project that claims safety properties."
    fi

    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  Assessment complete. No files were modified."
    echo "═══════════════════════════════════════════════════"

# Verify OpenSSF Best Practices prerequisites — fails if any required file is missing
verify:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== OpenSSF Best Practices Verification ==="
    ERRORS=0

    check_file() {
        if [ ! -f "$1" ]; then
            echo "  FAIL: $1 missing"
            ERRORS=$((ERRORS + 1))
        else
            echo "  OK:   $1"
        fi
    }

    # Accept either .md or .adoc for documentation files
    check_either() {
        if [ ! -f "$1" ] && [ ! -f "$2" ]; then
            echo "  FAIL: $1 (or $2) missing"
            ERRORS=$((ERRORS + 1))
        else
            local found="$1"
            [ -f "$2" ] && found="$2"
            [ -f "$1" ] && found="$1"
            echo "  OK:   $found"
        fi
    }

    # Community health files: accept root OR .github/, .md OR .adoc.
    #
    # .github/ is the canonical estate location for these — see
    # .machine_readable/root-allow.txt, which says of CONTRIBUTING.md:
    #   "Accepted at root OR .github/ — CI (openssf/quality/rhodibot) now
    #    checks both; .github/ is the canonical estate location
    #    (org-inherited). Allow-listed if present at root."
    # and of SECURITY.md: "security-policy contractile now accepts the
    # .github/ copy."
    #
    # GitHub and the OpenSSF Best Practices criteria both treat .github/ as a
    # valid home for them. Checking root only made this recipe a FALSE
    # NEGATIVE: the files exist in .github/ and always have, so the template
    # failed its own `just verify` ("repo cannot ship"), and so did every repo
    # instantiated from it. This recipe was the last checker still looking at
    # root alone.
    check_community_file() {
        local base="$1"
        local cand
        for cand in "$base.md" "$base.adoc" ".github/$base.md" ".github/$base.adoc"; do
            if [ -f "$cand" ]; then
                echo "  OK:   $cand"
                return 0
            fi
        done
        echo "  FAIL: $base.md (or $base.adoc) missing at root or .github/"
        ERRORS=$((ERRORS + 1))
    }

    check_community_file "SECURITY"
    check_file "LICENSE"
    check_community_file "CONTRIBUTING"
    check_either "README.adoc" "README.md"
    check_file ".machine_readable/descriptiles/STATE.a2ml"
    check_file ".machine_readable/descriptiles/META.a2ml"
    check_file ".machine_readable/descriptiles/ECOSYSTEM.a2ml"
    check_either "CHANGELOG.md" "CHANGELOG.adoc"

    # Check at least 1 workflow exists
    WORKFLOW_COUNT=$(find .github/workflows -name '*.yml' -o -name '*.yaml' 2>/dev/null | wc -l)
    if [ "$WORKFLOW_COUNT" -eq 0 ]; then
        echo "  FAIL: No workflows in .github/workflows/"
        ERRORS=$((ERRORS + 1))
    else
        echo "  OK:   .github/workflows/ ($WORKFLOW_COUNT workflows)"
    fi

    echo ""
    if [ "$ERRORS" -gt 0 ]; then
        echo "FAIL: $ERRORS OpenSSF prerequisites missing — repo cannot ship."
        exit 1
    fi
    echo "PASS: All OpenSSF Best Practices prerequisites satisfied."
