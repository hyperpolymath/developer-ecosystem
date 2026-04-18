#!/usr/bin/env bash

set -euo pipefail

# Performance benchmarking script for asdf-ghjk

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "🔬 asdf-ghjk Performance Benchmark"
echo "=================================="
echo ""

# Helper function to measure time
benchmark() {
  local name="$1"
  local command="$2"
  local iterations="${3:-3}"

  echo "📊 Benchmarking: $name"

  local total_time=0
  local times=()

  for i in $(seq 1 "$iterations"); do
    local start
    local end
    local duration

    start=$(date +%s%N)
    eval "$command" > /dev/null 2>&1
    end=$(date +%s%N)

    duration=$(( (end - start) / 1000000 )) # Convert to milliseconds
    times+=("$duration")
    total_time=$((total_time + duration))

    echo "  Run $i: ${duration}ms"
  done

  local avg=$((total_time / iterations))
  echo "  Average: ${avg}ms"
  echo ""
}

# Benchmark list-all
echo "## List All Versions"
echo ""
benchmark "bin/list-all (no cache)" \
  "rm -rf ~/.asdf/cache/ghjk/* 2>/dev/null; ./bin/list-all"

benchmark "bin/list-all (with cache)" \
  "./bin/list-all"

# Benchmark platform detection
echo "## Platform Detection"
echo ""
benchmark "Platform detection" \
  "source lib/utils.sh && get_platform"

# Benchmark version sorting
echo "## Version Sorting"
echo ""
cat > /tmp/test-versions.txt << 'EOF'
v0.3.0
v0.1.0
v0.3.2
v0.2.0
v0.3.1
v0.1.5
v0.2.3
EOF

benchmark "Version sorting" \
  "source lib/utils.sh && cat /tmp/test-versions.txt | sort_versions"

rm -f /tmp/test-versions.txt

# Benchmark download URL generation
echo "## URL Generation"
echo ""
benchmark "Download URL generation" \
  "source lib/utils.sh && get_download_url '0.3.2' 'x86_64-unknown-linux-gnu'"

# Benchmark checksum verification
echo "## Checksum Verification"
echo ""

# Create test file
dd if=/dev/urandom of=/tmp/test-file bs=1M count=10 2>/dev/null
TEST_CHECKSUM=$(sha256sum /tmp/test-file | awk '{print $1}')

benchmark "SHA256 verification" \
  "source lib/utils.sh && verify_checksum /tmp/test-file $TEST_CHECKSUM"

rm -f /tmp/test-file

# Cache performance
echo "## Cache Performance"
echo ""

# Clear cache first
rm -rf ~/.asdf/cache/ghjk/* 2>/dev/null || true

TEST_URL="https://api.github.com/repos/metatypedev/ghjk/releases?per_page=10"

benchmark "First request (no cache)" \
  "source lib/cache.sh && source lib/utils.sh && github_api_fetch '$TEST_URL'" \
  1

benchmark "Subsequent request (cached)" \
  "source lib/cache.sh && source lib/utils.sh && github_api_fetch '$TEST_URL'" \
  5

# Summary
echo "=================================="
echo "Benchmark complete!"
echo ""
echo "Note: Results may vary based on:"
echo "  - Network speed (for API calls)"
echo "  - CPU performance"
echo "  - Disk I/O speed"
echo "  - System load"
echo ""
echo "Run with: ./scripts/benchmark.sh"
