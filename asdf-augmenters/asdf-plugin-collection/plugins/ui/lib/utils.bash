#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

TOOL_NAME="asdf-ui"
BINARY_NAME="asdf-ui"

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

  cat > "$install_path/bin/asdf-ui" << 'SCRIPT'
#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# asdf-ui - Terminal UI for asdf version manager
set -euo pipefail

VERSION="1.0.0"

# Terminal colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly RESET='\033[0m'

# Box drawing characters
readonly BOX_TL='┌' BOX_TR='┐' BOX_BL='└' BOX_BR='┘'
readonly BOX_H='─' BOX_V='│'

show_help() {
  echo -e "${BOLD}asdf-ui v${VERSION}${RESET} - Terminal user interface for asdf"
  echo ""
  echo -e "${BOLD}Usage:${RESET} asdf-ui [command]"
  echo ""
  echo -e "${BOLD}Commands:${RESET}"
  echo "  (none)           Launch interactive TUI"
  echo "  dashboard        Show plugin dashboard"
  echo "  versions         Interactive version selector"
  echo "  help             Show this help message"
  echo ""
  echo -e "${DIM}This meta-plugin provides a terminal UI for asdf management.${RESET}"
}

draw_box() {
  local title="$1" width="${2:-60}"
  local padding=$((width - ${#title} - 4))
  echo -e "${CYAN}${BOX_TL}${BOX_H}${BOX_H} ${BOLD}${title}${RESET}${CYAN} $(printf "${BOX_H}%.0s" $(seq 1 $padding))${BOX_TR}${RESET}"
}

draw_box_end() {
  local width="${1:-60}"
  echo -e "${CYAN}${BOX_BL}$(printf "${BOX_H}%.0s" $(seq 1 $((width - 2))))${BOX_BR}${RESET}"
}

draw_row() {
  local content="$1" width="${2:-60}"
  local visible_len
  visible_len=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g' | wc -c)
  local padding=$((width - visible_len - 3))
  if [[ $padding -lt 0 ]]; then padding=0; fi
  echo -e "${CYAN}${BOX_V}${RESET} ${content}$(printf " %.0s" $(seq 1 $padding))${CYAN}${BOX_V}${RESET}"
}

get_plugins() {
  if command -v asdf &>/dev/null; then
    asdf plugin list 2>/dev/null || echo "(no plugins installed)"
  else
    echo "(asdf not found)"
  fi
}

get_plugin_versions() {
  local plugin="$1"
  if command -v asdf &>/dev/null; then
    asdf list "$plugin" 2>/dev/null | sed 's/^[* ]*//' || echo "(none)"
  else
    echo "(asdf not found)"
  fi
}

get_current_version() {
  local plugin="$1"
  if command -v asdf &>/dev/null; then
    asdf current "$plugin" 2>/dev/null | awk '{print $2}' || echo "-"
  else
    echo "-"
  fi
}

show_dashboard() {
  clear
  local width=60
  echo ""
  draw_box "asdf-ui Dashboard" "$width"
  draw_row "" "$width"

  if ! command -v asdf &>/dev/null; then
    draw_row "${RED}asdf is not installed or not in PATH${RESET}" "$width"
    draw_row "" "$width"
    draw_box_end "$width"
    return
  fi

  local plugins
  plugins=$(get_plugins)

  if [[ "$plugins" == "(no plugins installed)" ]]; then
    draw_row "${YELLOW}No plugins installed${RESET}" "$width"
    draw_row "" "$width"
    draw_row "Run: ${BOLD}asdf plugin add <name>${RESET}" "$width"
  else
    draw_row "${BOLD}Installed Plugins:${RESET}" "$width"
    draw_row "" "$width"

    while IFS= read -r plugin; do
      [[ -z "$plugin" ]] && continue
      local current
      current=$(get_current_version "$plugin")
      local versions
      versions=$(get_plugin_versions "$plugin" | wc -l)
      draw_row "  ${GREEN}${plugin}${RESET} ${DIM}(${versions} versions, current: ${current})${RESET}" "$width"
    done <<< "$plugins"
  fi

  draw_row "" "$width"
  draw_box_end "$width"
  echo ""
  echo -e "${DIM}Press Enter to refresh, 'q' to quit${RESET}"
}

show_versions() {
  clear
  local width=60
  echo ""
  draw_box "Version Selector" "$width"
  draw_row "" "$width"

  if ! command -v asdf &>/dev/null; then
    draw_row "${RED}asdf is not installed or not in PATH${RESET}" "$width"
    draw_row "" "$width"
    draw_box_end "$width"
    return
  fi

  local plugins
  plugins=$(get_plugins)

  if [[ "$plugins" == "(no plugins installed)" ]]; then
    draw_row "${YELLOW}No plugins installed${RESET}" "$width"
    draw_row "" "$width"
    draw_box_end "$width"
    return
  fi

  local plugin_array=()
  local i=1
  while IFS= read -r plugin; do
    [[ -z "$plugin" ]] && continue
    plugin_array+=("$plugin")
    local current
    current=$(get_current_version "$plugin")
    draw_row "  ${BOLD}[$i]${RESET} ${GREEN}${plugin}${RESET} ${DIM}(current: ${current})${RESET}" "$width"
    ((i++))
  done <<< "$plugins"

  draw_row "" "$width"
  draw_box_end "$width"
  echo ""
  echo -e "Select plugin number (1-$((i-1))), or 'q' to quit: "

  read -r choice
  [[ "$choice" == "q" ]] && return

  if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#plugin_array[@]}" ]]; then
    local selected_plugin="${plugin_array[$((choice-1))]}"
    show_plugin_versions "$selected_plugin"
  else
    echo -e "${RED}Invalid selection${RESET}"
    sleep 1
    show_versions
  fi
}

show_plugin_versions() {
  local plugin="$1"
  clear
  local width=60
  echo ""
  draw_box "Versions: $plugin" "$width"
  draw_row "" "$width"

  local current
  current=$(get_current_version "$plugin")
  draw_row "Current version: ${BOLD}${current}${RESET}" "$width"
  draw_row "" "$width"

  local versions
  versions=$(get_plugin_versions "$plugin")

  local version_array=()
  local i=1
  while IFS= read -r ver; do
    [[ -z "$ver" ]] && continue
    version_array+=("$ver")
    if [[ "$ver" == "$current" ]]; then
      draw_row "  ${BOLD}[$i]${RESET} ${GREEN}${ver}${RESET} ${YELLOW}(active)${RESET}" "$width"
    else
      draw_row "  ${BOLD}[$i]${RESET} ${ver}" "$width"
    fi
    ((i++))
  done <<< "$versions"

  draw_row "" "$width"
  draw_box_end "$width"
  echo ""
  echo -e "Select version to activate (1-$((i-1))), 'b' for back, 'q' to quit: "

  read -r choice
  [[ "$choice" == "q" ]] && return
  [[ "$choice" == "b" ]] && { show_versions; return; }

  if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#version_array[@]}" ]]; then
    local selected_version="${version_array[$((choice-1))]}"
    echo -e "Setting ${BOLD}${plugin}${RESET} to version ${BOLD}${selected_version}${RESET}..."
    if asdf global "$plugin" "$selected_version" 2>/dev/null; then
      echo -e "${GREEN}Done!${RESET}"
    else
      echo -e "${RED}Failed to set version${RESET}"
    fi
    sleep 1
    show_plugin_versions "$plugin"
  else
    echo -e "${RED}Invalid selection${RESET}"
    sleep 1
    show_plugin_versions "$plugin"
  fi
}

interactive_tui() {
  while true; do
    clear
    local width=60
    echo ""
    draw_box "asdf-ui v${VERSION}" "$width"
    draw_row "" "$width"
    draw_row "${BOLD}[1]${RESET} Dashboard     - View installed plugins" "$width"
    draw_row "${BOLD}[2]${RESET} Versions      - Select and switch versions" "$width"
    draw_row "${BOLD}[3]${RESET} Help          - Show help information" "$width"
    draw_row "${BOLD}[q]${RESET} Quit          - Exit asdf-ui" "$width"
    draw_row "" "$width"
    draw_box_end "$width"
    echo ""
    echo -e "Select option: "

    read -r -n1 choice
    echo ""

    case "$choice" in
      1) show_dashboard; read -r -n1 key; [[ "$key" == "q" ]] && break ;;
      2) show_versions ;;
      3) show_help; echo ""; echo -e "${DIM}Press any key to continue...${RESET}"; read -r -n1 ;;
      q|Q) break ;;
      *) ;;
    esac
  done
  clear
  echo -e "${GREEN}Goodbye!${RESET}"
}

# Main entry point
case "${1:-}" in
  help|--help|-h)
    show_help
    ;;
  dashboard)
    show_dashboard
    read -r -n1
    ;;
  versions)
    show_versions
    ;;
  "")
    interactive_tui
    ;;
  *)
    echo -e "${RED}Unknown command: $1${RESET}"
    echo ""
    show_help
    exit 1
    ;;
esac
SCRIPT
  chmod +x "$install_path/bin/asdf-ui"
}
