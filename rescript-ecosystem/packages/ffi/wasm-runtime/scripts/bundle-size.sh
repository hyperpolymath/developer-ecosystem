#!/usr/bin/env bash
# Analyze bundle sizes and compare with targets

set -euo pipefail

echo "📦 Bundle Size Analysis"
echo "======================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

total_size=0
target_exceeded=0

# Analyze each example
for example_dir in examples/*/; do
  if [ -d "$example_dir" ]; then
    example_name=$(basename "$example_dir")
    mjs_file="${example_dir}main.mjs"

    if [ -f "$mjs_file" ]; then
      size=$(wc -c < "$mjs_file")
      size_kb=$(echo "scale=2; $size / 1024" | bc)
      total_size=$((total_size + size))

      # Determine target
      case "$example_name" in
        "hello-world")
          target=2048
          ;;
        "api-server")
          target=5120
          ;;
        *)
          target=10240
          ;;
      esac

      target_kb=$(echo "scale=2; $target / 1024" | bc)

      # Check if over target
      if [ "$size" -gt "$target" ]; then
        echo -e "${RED}❌ ${example_name}${NC}"
        echo "   Size: ${size_kb}KB (target: ${target_kb}KB)"
        echo "   Over by: $(echo "scale=2; ($size - $target) / 1024" | bc)KB"
        target_exceeded=$((target_exceeded + 1))
      else
        echo -e "${GREEN}✅ ${example_name}${NC}"
        echo "   Size: ${size_kb}KB (target: ${target_kb}KB)"
        under_by=$(echo "scale=2; ($target - $size) / 1024" | bc)
        echo "   Under by: ${under_by}KB"
      fi
      echo ""
    fi
  fi
done

# Summary
echo "======================="
total_size_kb=$(echo "scale=2; $total_size / 1024" | bc)
echo "Total bundle size: ${total_size_kb}KB"

if [ "$target_exceeded" -eq 0 ]; then
  echo -e "${GREEN}✅ All examples meet size targets${NC}"
  exit 0
else
  echo -e "${RED}❌ ${target_exceeded} example(s) exceed size targets${NC}"
  exit 1
fi
