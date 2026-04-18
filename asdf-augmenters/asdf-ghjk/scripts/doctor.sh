#!/usr/bin/env bash

set -euo pipefail

# Doctor script - diagnoses common issues with asdf-ghjk

echo "🏥 asdf-ghjk Doctor"
echo "==================="
echo ""
echo "Checking your asdf-ghjk installation..."
echo ""

ISSUES_FOUND=0

# Check asdf is installed
echo "1️⃣  Checking asdf installation..."
if command -v asdf &>/dev/null; then
  ASDF_VERSION=$(asdf --version 2>&1 | head -1 || echo "unknown")
  echo "   ✅ asdf is installed: $ASDF_VERSION"
else
  echo "   ❌ asdf is not installed or not in PATH"
  echo "      Install from: https://asdf-vm.com"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# Check plugin is installed
echo "2️⃣  Checking ghjk plugin..."
if asdf plugin list 2>/dev/null | grep -q ghjk; then
  echo "   ✅ ghjk plugin is installed"

  # Check plugin path
  PLUGIN_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}/plugins/ghjk"
  if [[ -d "$PLUGIN_DIR" ]]; then
    echo "   ✅ Plugin directory exists: $PLUGIN_DIR"

    # Check required scripts exist
    for script in list-all download install; do
      if [[ -x "$PLUGIN_DIR/bin/$script" ]]; then
        echo "   ✅ bin/$script is executable"
      else
        echo "   ❌ bin/$script is missing or not executable"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
      fi
    done
  else
    echo "   ❌ Plugin directory not found: $PLUGIN_DIR"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi
else
  echo "   ❌ ghjk plugin is not installed"
  echo "      Run: asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# Check required dependencies
echo "3️⃣  Checking required dependencies..."
DEPS=(bash curl tar grep sort)
for dep in "${DEPS[@]}"; do
  if command -v "$dep" &>/dev/null; then
    VERSION=$($dep --version 2>&1 | head -1 || echo "installed")
    echo "   ✅ $dep: $VERSION"
  else
    echo "   ❌ $dep is not installed"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi
done
echo ""

# Check ghjk runtime dependencies
echo "4️⃣  Checking ghjk runtime dependencies..."
RUNTIME_DEPS=(git curl tar unzip zstd)
MISSING_RUNTIME=()
for dep in "${RUNTIME_DEPS[@]}"; do
  if command -v "$dep" &>/dev/null; then
    echo "   ✅ $dep is installed"
  else
    echo "   ⚠️  $dep is not installed (needed for ghjk to run)"
    MISSING_RUNTIME+=("$dep")
  fi
done

if [[ ${#MISSING_RUNTIME[@]} -gt 0 ]]; then
  echo ""
  echo "   Install missing dependencies:"
  echo "   Ubuntu/Debian: sudo apt-get install ${MISSING_RUNTIME[*]}"
  echo "   macOS: brew install ${MISSING_RUNTIME[*]}"
fi
echo ""

# Check if any versions are installed
echo "5️⃣  Checking installed ghjk versions..."
if command -v asdf &>/dev/null && asdf plugin list 2>/dev/null | grep -q ghjk; then
  VERSIONS=$(asdf list ghjk 2>/dev/null || echo "")
  if [[ -n "$VERSIONS" ]]; then
    echo "   ✅ Found installed versions:"
    echo "$VERSIONS" | sed 's/^/      /'

    # Check current version
    CURRENT=$(asdf current ghjk 2>&1 || echo "")
    if [[ "$CURRENT" =~ "No version set" ]] || [[ "$CURRENT" =~ "not installed" ]]; then
      echo "   ⚠️  No version currently active"
      echo "      Run: asdf global ghjk <version>"
    else
      echo "   ✅ Current version: $CURRENT"
    fi
  else
    echo "   ⚠️  No versions installed"
    echo "      Run: asdf install ghjk latest"
  fi
else
  echo "   ⏭️  Skipping (plugin not installed)"
fi
echo ""

# Check GitHub API access
echo "6️⃣  Checking GitHub API access..."
if curl -s -f -I https://api.github.com/rate_limit >/dev/null 2>&1; then
  echo "   ✅ GitHub API is accessible"

  # Check rate limit
  if [[ -n "${GITHUB_API_TOKEN:-}" ]]; then
    RATE_LIMIT=$(curl -s -H "Authorization: token $GITHUB_API_TOKEN" \
      https://api.github.com/rate_limit | grep -o '"remaining":[0-9]*' | head -1 | cut -d: -f2 || echo "unknown")
    echo "   ✅ GITHUB_API_TOKEN is set"
    echo "      Remaining API calls: $RATE_LIMIT"
  else
    RATE_LIMIT=$(curl -s https://api.github.com/rate_limit | \
      grep -o '"remaining":[0-9]*' | head -1 | cut -d: -f2 || echo "unknown")
    echo "   ⚠️  GITHUB_API_TOKEN is not set"
    echo "      Remaining API calls: $RATE_LIMIT/60"
    echo "      Set token to avoid rate limits: export GITHUB_API_TOKEN=ghp_..."
  fi
else
  echo "   ❌ Cannot access GitHub API"
  echo "      Check your internet connection"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# Check shell configuration
echo "7️⃣  Checking shell configuration..."
if [[ -f "$HOME/.bashrc" ]] && grep -q "asdf.sh" "$HOME/.bashrc"; then
  echo "   ✅ asdf appears to be configured in ~/.bashrc"
elif [[ -f "$HOME/.zshrc" ]] && grep -q "asdf.sh" "$HOME/.zshrc"; then
  echo "   ✅ asdf appears to be configured in ~/.zshrc"
elif [[ -f "$HOME/.bash_profile" ]] && grep -q "asdf.sh" "$HOME/.bash_profile"; then
  echo "   ✅ asdf appears to be configured in ~/.bash_profile"
else
  echo "   ⚠️  asdf may not be configured in your shell"
  echo "      Add to your shell profile:"
  echo "      echo '. \$HOME/.asdf/asdf.sh' >> ~/.bashrc"
fi
echo ""

# Check platform support
echo "8️⃣  Checking platform compatibility..."
OS=$(uname -s)
ARCH=$(uname -m)
echo "   OS: $OS"
echo "   Architecture: $ARCH"

SUPPORTED=false
case "$OS-$ARCH" in
  Linux-x86_64|Linux-aarch64|Darwin-x86_64|Darwin-arm64)
    echo "   ✅ Platform is supported"
    SUPPORTED=true
    ;;
  *)
    echo "   ❌ Platform may not be supported"
    echo "      Supported: Linux (x86_64, aarch64), macOS (x86_64, arm64)"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    ;;
esac
echo ""

# Summary
echo "=========================================="
if [[ $ISSUES_FOUND -eq 0 ]]; then
  echo "✅ All checks passed! Everything looks good."
  echo ""
  echo "You're ready to use asdf-ghjk!"
  echo ""
  echo "Quick start:"
  echo "  asdf install ghjk latest"
  echo "  asdf global ghjk latest"
  echo "  ghjk --version"
else
  echo "⚠️  Found $ISSUES_FOUND issue(s)"
  echo ""
  echo "Please fix the issues above and run doctor again."
  echo ""
  echo "For more help:"
  echo "  - Troubleshooting: docs/TROUBLESHOOTING.md"
  echo "  - FAQ: docs/FAQ.md"
  echo "  - Issues: https://github.com/Hyperpolymath/asdf-ghjk/issues"
  exit 1
fi
