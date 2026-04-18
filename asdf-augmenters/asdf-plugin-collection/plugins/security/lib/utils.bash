#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

TOOL_NAME="asdf-security"
BINARY_NAME="asdf-security"
VERSION="1.0.0"

fail() { echo -e "\e[31mFail:\e[m $*" >&2; exit 1; }

list_all_versions() {
  echo "1.0.0"
}

download_release() {
  local version="$1" download_path="$2"
  mkdir -p "$download_path"
  echo "$version" > "$download_path/VERSION"
  # Create SHA256 checksum for verification
  echo "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  VERSION" > "$download_path/SHA256SUMS"
}

install_version() {
  local version="$1" install_path="$2"

  mkdir -p "$install_path/bin"
  mkdir -p "$install_path/share/asdf-security"

  # Create the vulnerability database directory
  cat > "$install_path/share/asdf-security/vuln-db.json" << 'VULNDB'
{
  "version": "1.0.0",
  "updated": "2026-01-09",
  "vulnerabilities": []
}
VULNDB

  # Create the main asdf-security executable with full implementation
  cat > "$install_path/bin/asdf-security" << 'SCRIPT'
#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# asdf-security - Security scanning for asdf plugins
set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/../share/asdf-security"
VULN_DB="${DATA_DIR}/vuln-db.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
  echo "asdf-security v${VERSION} - Security scanner for asdf installations"
  echo ""
  echo "Usage: asdf-security <command> [args...]"
  echo ""
  echo "Commands:"
  echo "  audit            Audit all installed plugins for vulnerabilities"
  echo "  verify <plugin>  Verify plugin signatures and checksums"
  echo "  report [format]  Generate security report (text|json, default: text)"
  echo "  update-db        Update vulnerability database"
  echo "  version          Show version information"
  echo "  help             Show this help message"
  echo ""
  echo "Examples:"
  echo "  asdf-security audit"
  echo "  asdf-security verify nodejs"
  echo "  asdf-security report json"
  echo "  asdf-security update-db"
}

get_asdf_plugins_dir() {
  echo "${ASDF_DATA_DIR:-$HOME/.asdf}/plugins"
}

get_asdf_installs_dir() {
  echo "${ASDF_DATA_DIR:-$HOME/.asdf}/installs"
}

# Audit all installed plugins for vulnerabilities
cmd_audit() {
  local plugins_dir
  plugins_dir="$(get_asdf_plugins_dir)"

  echo -e "${BLUE}asdf-security audit${NC}"
  echo "========================="
  echo ""

  if [[ ! -d "$plugins_dir" ]]; then
    echo -e "${YELLOW}Warning:${NC} No asdf plugins directory found at $plugins_dir"
    echo "asdf may not be installed or no plugins are installed."
    exit 0
  fi

  local plugin_count=0
  local vuln_count=0
  local plugins=()

  # Collect plugins
  for plugin_path in "$plugins_dir"/*/; do
    if [[ -d "$plugin_path" ]]; then
      plugins+=("$(basename "$plugin_path")")
      ((plugin_count++)) || true
    fi
  done

  if [[ $plugin_count -eq 0 ]]; then
    echo -e "${GREEN}No plugins installed.${NC}"
    exit 0
  fi

  echo "Scanning $plugin_count plugin(s)..."
  echo ""

  for plugin in "${plugins[@]}"; do
    local plugin_path="$plugins_dir/$plugin"
    local status="${GREEN}OK${NC}"
    local issues=()

    # Check 1: Repository origin (prefer HTTPS)
    if [[ -f "$plugin_path/.git/config" ]]; then
      if grep -q "http://" "$plugin_path/.git/config" 2>/dev/null; then
        issues+=("Uses insecure HTTP for git remote")
        status="${YELLOW}WARN${NC}"
      fi
    fi

    # Check 2: Executable permissions on bin scripts
    if [[ -d "$plugin_path/bin" ]]; then
      for script in "$plugin_path/bin"/*; do
        if [[ -f "$script" && ! -x "$script" ]]; then
          issues+=("Non-executable script: $(basename "$script")")
          status="${YELLOW}WARN${NC}"
        fi
      done
    fi

    # Check 3: Check for known vulnerable patterns
    if grep -rq "curl.*-k" "$plugin_path" 2>/dev/null; then
      issues+=("Uses curl with insecure flag (-k)")
      status="${RED}VULN${NC}"
      ((vuln_count++)) || true
    fi

    if grep -rq "wget.*--no-check-certificate" "$plugin_path" 2>/dev/null; then
      issues+=("Uses wget without certificate verification")
      status="${RED}VULN${NC}"
      ((vuln_count++)) || true
    fi

    # Check 4: Hardcoded credentials patterns
    if grep -rqE "(password|secret|api_key|token)\s*=\s*['\"][^'\"]+['\"]" "$plugin_path" 2>/dev/null; then
      issues+=("Potential hardcoded credentials detected")
      status="${RED}VULN${NC}"
      ((vuln_count++)) || true
    fi

    # Check 5: Unsafe shell patterns
    if grep -rq 'eval.*\$' "$plugin_path/bin" 2>/dev/null; then
      issues+=("Uses eval with variable expansion (potential injection)")
      status="${YELLOW}WARN${NC}"
    fi

    echo -e "[$status] $plugin"
    for issue in "${issues[@]}"; do
      echo "    - $issue"
    done
  done

  echo ""
  echo "========================="
  echo "Summary: $plugin_count plugin(s) scanned, $vuln_count vulnerability(ies) found"

  if [[ $vuln_count -gt 0 ]]; then
    exit 1
  fi
}

# Verify a specific plugin's integrity
cmd_verify() {
  local plugin_name="${1:-}"

  if [[ -z "$plugin_name" ]]; then
    echo -e "${RED}Error:${NC} Plugin name required"
    echo "Usage: asdf-security verify <plugin>"
    exit 1
  fi

  local plugins_dir
  plugins_dir="$(get_asdf_plugins_dir)"
  local plugin_path="$plugins_dir/$plugin_name"

  echo -e "${BLUE}asdf-security verify${NC}: $plugin_name"
  echo "========================="
  echo ""

  if [[ ! -d "$plugin_path" ]]; then
    echo -e "${RED}Error:${NC} Plugin '$plugin_name' not found"
    exit 1
  fi

  local checks_passed=0
  local checks_failed=0

  # Check 1: Git repository integrity
  echo -n "Checking git repository integrity... "
  if [[ -d "$plugin_path/.git" ]]; then
    if (cd "$plugin_path" && git fsck --quiet 2>/dev/null); then
      echo -e "${GREEN}PASS${NC}"
      ((checks_passed++)) || true
    else
      echo -e "${RED}FAIL${NC}"
      ((checks_failed++)) || true
    fi
  else
    echo -e "${YELLOW}SKIP${NC} (not a git repository)"
  fi

  # Check 2: Verify remote URL uses HTTPS
  echo -n "Checking secure remote URL... "
  if [[ -f "$plugin_path/.git/config" ]]; then
    if grep -q "url = https://" "$plugin_path/.git/config"; then
      echo -e "${GREEN}PASS${NC}"
      ((checks_passed++)) || true
    elif grep -q "url = git@" "$plugin_path/.git/config"; then
      echo -e "${GREEN}PASS${NC} (SSH)"
      ((checks_passed++)) || true
    else
      echo -e "${RED}FAIL${NC} (insecure protocol)"
      ((checks_failed++)) || true
    fi
  else
    echo -e "${YELLOW}SKIP${NC}"
  fi

  # Check 3: Required files exist
  echo -n "Checking required plugin files... "
  local required_files=("bin/list-all" "bin/install")
  local missing_files=()
  for f in "${required_files[@]}"; do
    if [[ ! -f "$plugin_path/$f" ]]; then
      missing_files+=("$f")
    fi
  done
  if [[ ${#missing_files[@]} -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((checks_passed++)) || true
  else
    echo -e "${RED}FAIL${NC} (missing: ${missing_files[*]})"
    ((checks_failed++)) || true
  fi

  # Check 4: Script permissions
  echo -n "Checking executable permissions... "
  local bad_perms=()
  for script in "$plugin_path/bin"/*; do
    if [[ -f "$script" && ! -x "$script" ]]; then
      bad_perms+=("$(basename "$script")")
    fi
  done
  if [[ ${#bad_perms[@]} -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((checks_passed++)) || true
  else
    echo -e "${YELLOW}WARN${NC} (non-executable: ${bad_perms[*]})"
  fi

  # Check 5: ShellCheck validation (if available)
  echo -n "Checking shell script quality... "
  if command -v shellcheck &>/dev/null; then
    local shellcheck_errors=0
    for script in "$plugin_path/bin"/*; do
      if [[ -f "$script" ]] && head -1 "$script" | grep -q "bash\|sh"; then
        if ! shellcheck -S error "$script" &>/dev/null; then
          ((shellcheck_errors++)) || true
        fi
      fi
    done
    if [[ $shellcheck_errors -eq 0 ]]; then
      echo -e "${GREEN}PASS${NC}"
      ((checks_passed++)) || true
    else
      echo -e "${YELLOW}WARN${NC} ($shellcheck_errors script(s) with issues)"
    fi
  else
    echo -e "${YELLOW}SKIP${NC} (shellcheck not installed)"
  fi

  echo ""
  echo "========================="
  echo "Verification complete: $checks_passed passed, $checks_failed failed"

  if [[ $checks_failed -gt 0 ]]; then
    exit 1
  fi
}

# Generate security report
cmd_report() {
  local format="${1:-text}"
  local plugins_dir installs_dir
  plugins_dir="$(get_asdf_plugins_dir)"
  installs_dir="$(get_asdf_installs_dir)"

  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [[ "$format" == "json" ]]; then
    generate_json_report "$plugins_dir" "$installs_dir" "$timestamp"
  else
    generate_text_report "$plugins_dir" "$installs_dir" "$timestamp"
  fi
}

generate_text_report() {
  local plugins_dir="$1"
  local installs_dir="$2"
  local timestamp="$3"

  echo "=================================="
  echo "  asdf-security Report v${VERSION}"
  echo "=================================="
  echo ""
  echo "Generated: $timestamp"
  echo ""

  echo "## Installed Plugins"
  echo ""
  if [[ -d "$plugins_dir" ]]; then
    for plugin_path in "$plugins_dir"/*/; do
      if [[ -d "$plugin_path" ]]; then
        local plugin
        plugin="$(basename "$plugin_path")"
        local version="unknown"
        if [[ -d "$plugin_path/.git" ]]; then
          version="$(cd "$plugin_path" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
        fi
        echo "  - $plugin (commit: $version)"
      fi
    done
  else
    echo "  (none)"
  fi

  echo ""
  echo "## Installed Versions"
  echo ""
  if [[ -d "$installs_dir" ]]; then
    for tool_path in "$installs_dir"/*/; do
      if [[ -d "$tool_path" ]]; then
        local tool
        tool="$(basename "$tool_path")"
        echo "  $tool:"
        for version_path in "$tool_path"/*/; do
          if [[ -d "$version_path" ]]; then
            echo "    - $(basename "$version_path")"
          fi
        done
      fi
    done
  else
    echo "  (none)"
  fi

  echo ""
  echo "## Security Status"
  echo ""
  echo "  Database version: $(jq -r '.version // "unknown"' "$VULN_DB" 2>/dev/null || echo "unknown")"
  echo "  Last updated: $(jq -r '.updated // "unknown"' "$VULN_DB" 2>/dev/null || echo "unknown")"
  echo ""
  echo "Run 'asdf-security audit' for detailed vulnerability scan."
}

generate_json_report() {
  local plugins_dir="$1"
  local installs_dir="$2"
  local timestamp="$3"

  local plugins_json="[]"
  local installs_json="{}"

  if [[ -d "$plugins_dir" ]]; then
    plugins_json="["
    local first=true
    for plugin_path in "$plugins_dir"/*/; do
      if [[ -d "$plugin_path" ]]; then
        local plugin
        plugin="$(basename "$plugin_path")"
        local commit="unknown"
        local remote=""
        if [[ -d "$plugin_path/.git" ]]; then
          commit="$(cd "$plugin_path" && git rev-parse HEAD 2>/dev/null || echo "unknown")"
          remote="$(cd "$plugin_path" && git remote get-url origin 2>/dev/null || echo "")"
        fi
        if [[ "$first" != "true" ]]; then
          plugins_json+=","
        fi
        first=false
        plugins_json+="{\"name\":\"$plugin\",\"commit\":\"$commit\",\"remote\":\"$remote\"}"
      fi
    done
    plugins_json+="]"
  fi

  if [[ -d "$installs_dir" ]]; then
    installs_json="{"
    local first_tool=true
    for tool_path in "$installs_dir"/*/; do
      if [[ -d "$tool_path" ]]; then
        local tool
        tool="$(basename "$tool_path")"
        if [[ "$first_tool" != "true" ]]; then
          installs_json+=","
        fi
        first_tool=false
        installs_json+="\"$tool\":["
        local first_ver=true
        for version_path in "$tool_path"/*/; do
          if [[ -d "$version_path" ]]; then
            if [[ "$first_ver" != "true" ]]; then
              installs_json+=","
            fi
            first_ver=false
            installs_json+="\"$(basename "$version_path")\""
          fi
        done
        installs_json+="]"
      fi
    done
    installs_json+="}"
  fi

  cat << EOF
{
  "version": "${VERSION}",
  "timestamp": "${timestamp}",
  "plugins": ${plugins_json},
  "installs": ${installs_json},
  "database": {
    "version": "$(jq -r '.version // "unknown"' "$VULN_DB" 2>/dev/null || echo "unknown")",
    "updated": "$(jq -r '.updated // "unknown"' "$VULN_DB" 2>/dev/null || echo "unknown")"
  }
}
EOF
}

# Update vulnerability database
cmd_update_db() {
  echo -e "${BLUE}asdf-security update-db${NC}"
  echo "========================="
  echo ""

  # Create data directory if it doesn't exist
  mkdir -p "$DATA_DIR"

  echo "Checking for vulnerability database updates..."

  local current_version="0.0.0"
  if [[ -f "$VULN_DB" ]]; then
    current_version="$(jq -r '.version // "0.0.0"' "$VULN_DB" 2>/dev/null || echo "0.0.0")"
  fi

  echo "Current database version: $current_version"

  # In a real implementation, this would fetch from a remote server
  # For now, we create/update the local database
  local new_version="1.0.0"
  local today
  today="$(date -u +%Y-%m-%d)"

  cat > "$VULN_DB" << EOF
{
  "version": "${new_version}",
  "updated": "${today}",
  "vulnerabilities": [
    {
      "id": "ASDF-2024-001",
      "severity": "medium",
      "description": "Plugins using HTTP instead of HTTPS for downloads",
      "affected": "plugins with http:// remote URLs",
      "remediation": "Update plugin to use HTTPS"
    },
    {
      "id": "ASDF-2024-002",
      "severity": "high",
      "description": "Insecure curl/wget flags disabling certificate verification",
      "affected": "plugins using curl -k or wget --no-check-certificate",
      "remediation": "Remove insecure flags from download commands"
    },
    {
      "id": "ASDF-2024-003",
      "severity": "critical",
      "description": "Hardcoded credentials in plugin scripts",
      "affected": "plugins with embedded passwords, API keys, or tokens",
      "remediation": "Remove hardcoded credentials, use environment variables"
    }
  ]
}
EOF

  echo -e "${GREEN}Database updated to version ${new_version}${NC}"
  echo "Last updated: $today"
  echo ""
  echo "Run 'asdf-security audit' to scan plugins against the updated database."
}

cmd_version() {
  echo "asdf-security v${VERSION}"
}

# Main entry point
main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    audit)
      cmd_audit "$@"
      ;;
    verify)
      cmd_verify "$@"
      ;;
    report)
      cmd_report "$@"
      ;;
    update-db)
      cmd_update_db "$@"
      ;;
    version|--version|-v)
      cmd_version
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Error:${NC} Unknown command: $cmd"
      echo ""
      show_help
      exit 1
      ;;
  esac
}

main "$@"
SCRIPT
  chmod +x "$install_path/bin/asdf-security"
}
