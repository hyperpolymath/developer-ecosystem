#!/usr/bin/env bash

set -euo pipefail

# Cleanup script for asdf-ghjk
# Removes caches, old downloads, and temporary files

echo "🧹 asdf-ghjk Cleanup Utility"
echo "============================"
echo ""

CACHE_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}/cache/ghjk"
DOWNLOAD_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}/downloads/ghjk"
INSTALL_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}/installs/ghjk"

# Calculate directory sizes
get_size() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    du -sh "$dir" 2>/dev/null | awk '{print $1}'
  else
    echo "0B"
  fi
}

# Show current usage
echo "📊 Current Disk Usage:"
echo ""
echo "  Cache:     $(get_size "$CACHE_DIR")"
echo "  Downloads: $(get_size "$DOWNLOAD_DIR")"
echo "  Installs:  $(get_size "$INSTALL_DIR")"
echo ""

# Parse command line arguments
CLEAN_CACHE=false
CLEAN_DOWNLOADS=false
CLEAN_OLD_VERSIONS=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --cache)
      CLEAN_CACHE=true
      shift
      ;;
    --downloads)
      CLEAN_DOWNLOADS=true
      shift
      ;;
    --old-versions)
      CLEAN_OLD_VERSIONS=true
      shift
      ;;
    --all)
      CLEAN_CACHE=true
      CLEAN_DOWNLOADS=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      cat << 'EOF'
Usage: cleanup.sh [OPTIONS]

Options:
  --cache          Clean API cache
  --downloads      Clean downloaded archives
  --old-versions   Remove old installed versions (keeps 3 most recent)
  --all            Clean cache and downloads
  --dry-run        Show what would be deleted without deleting
  --help           Show this help

Examples:
  # Clean cache only
  ./scripts/cleanup.sh --cache

  # Clean everything
  ./scripts/cleanup.sh --all

  # Preview what would be deleted
  ./scripts/cleanup.sh --all --dry-run
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# If no options specified, show usage
if ! $CLEAN_CACHE && ! $CLEAN_DOWNLOADS && ! $CLEAN_OLD_VERSIONS; then
  echo "No cleanup options specified. Use --help for usage."
  echo ""
  echo "Quick options:"
  echo "  --cache           Clean API cache"
  echo "  --downloads       Clean downloaded archives"
  echo "  --old-versions    Remove old versions"
  echo "  --all             Clean cache and downloads"
  exit 0
fi

echo "🗑️  Cleanup Actions:"
echo ""

# Clean cache
if $CLEAN_CACHE; then
  if [[ -d "$CACHE_DIR" ]]; then
    echo "  - Cleaning API cache..."
    if $DRY_RUN; then
      echo "    [DRY RUN] Would remove: $CACHE_DIR"
      find "$CACHE_DIR" -type f 2>/dev/null | head -5
      count=$(find "$CACHE_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
      echo "    [DRY RUN] Would delete $count files"
    else
      rm -rf "${CACHE_DIR:?}"/*
      echo "    ✅ Cache cleaned"
    fi
  else
    echo "  - Cache directory doesn't exist (nothing to clean)"
  fi
  echo ""
fi

# Clean downloads
if $CLEAN_DOWNLOADS; then
  if [[ -d "$DOWNLOAD_DIR" ]]; then
    echo "  - Cleaning downloaded archives..."
    if $DRY_RUN; then
      echo "    [DRY RUN] Would remove: $DOWNLOAD_DIR"
      find "$DOWNLOAD_DIR" -name "*.tar.gz" 2>/dev/null | head -5
      count=$(find "$DOWNLOAD_DIR" -name "*.tar.gz" 2>/dev/null | wc -l | tr -d ' ')
      echo "    [DRY RUN] Would delete $count archives"
    else
      rm -rf "${DOWNLOAD_DIR:?}"/*
      echo "    ✅ Downloads cleaned"
    fi
  else
    echo "  - Download directory doesn't exist (nothing to clean)"
  fi
  echo ""
fi

# Clean old versions
if $CLEAN_OLD_VERSIONS; then
  if [[ -d "$INSTALL_DIR" ]]; then
    echo "  - Cleaning old installed versions (keeping 3 most recent)..."

    # Get list of installed versions sorted by modification time
    versions=()
    while IFS= read -r version; do
      versions+=("$version")
    done < <(ls -t "$INSTALL_DIR" 2>/dev/null || true)

    total=${#versions[@]}

    if [[ $total -gt 3 ]]; then
      echo "    Found $total versions, will keep 3 newest"
      to_remove=("${versions[@]:3}")

      for version in "${to_remove[@]}"; do
        if $DRY_RUN; then
          echo "    [DRY RUN] Would remove: $version"
        else
          echo "    Removing: $version"
          rm -rf "${INSTALL_DIR:?}/${version}"
        fi
      done

      if ! $DRY_RUN; then
        echo "    ✅ Removed $((total - 3)) old version(s)"
      fi
    else
      echo "    Only $total version(s) installed, nothing to remove"
    fi
  else
    echo "  - No installed versions found"
  fi
  echo ""
fi

# Show final usage
if ! $DRY_RUN; then
  echo "📊 Final Disk Usage:"
  echo ""
  echo "  Cache:     $(get_size "$CACHE_DIR")"
  echo "  Downloads: $(get_size "$DOWNLOAD_DIR")"
  echo "  Installs:  $(get_size "$INSTALL_DIR")"
  echo ""
  echo "✨ Cleanup complete!"
else
  echo "💡 This was a dry run. Run without --dry-run to actually delete files."
fi
