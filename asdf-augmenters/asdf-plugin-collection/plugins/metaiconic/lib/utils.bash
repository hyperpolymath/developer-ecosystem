#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

TOOL_NAME="asdf-metaiconic"
BINARY_NAME="asdf-metaiconic"

fail() { echo -e "\e[31mFail:\e[m $*" >&2; exit 1; }

list_all_versions() {
  echo "1.0.0"
}

download_release() {
  local version="$1" download_path="$2"
  mkdir -p "$download_path"
  echo "$version" > "$download_path/VERSION"
}

install_version() {
  local install_type="$1" version="$2" install_path="$3"

  mkdir -p "$install_path/bin"

  cat > "$install_path/bin/asdf-metaiconic" << 'SCRIPT'
#!/usr/bin/env bash
# asdf-metaiconic - Plugin metadata and discovery
echo "asdf-metaiconic v1.0.0 - Metadata registry for asdf plugins"
echo ""
echo "Usage: asdf-metaiconic <command> [args...]"
echo ""
echo "Commands:"
echo "  search <term>    Search plugins by name or category"
echo "  info <plugin>    Show detailed plugin information"
echo "  categories       List all plugin categories"
echo "  stats            Show ecosystem statistics"
echo ""
echo "This meta-plugin provides plugin discovery and metadata."
SCRIPT
  chmod +x "$install_path/bin/asdf-metaiconic"
}
