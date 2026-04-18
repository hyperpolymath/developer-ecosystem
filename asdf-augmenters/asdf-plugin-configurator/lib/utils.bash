#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

TOOL_NAME="asdf-configurator"
BINARY_NAME="asdf-configurator"

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

  cat > "$install_path/bin/asdf-configurator" << 'SCRIPT'
#!/usr/bin/env bash
# asdf-configurator - Plugin configuration management
echo "asdf-configurator v1.0.0 - Configuration manager for asdf plugins"
echo ""
echo "Usage: asdf-configurator <command> [args...]"
echo ""
echo "Commands:"
echo "  list             List all configurable plugins"
echo "  show <plugin>    Show configuration for a plugin"
echo "  set <plugin> <key> <value>  Set configuration option"
echo "  export           Export all configurations"
echo ""
echo "This meta-plugin helps manage plugin-specific configurations."
SCRIPT
  chmod +x "$install_path/bin/asdf-configurator"
}
