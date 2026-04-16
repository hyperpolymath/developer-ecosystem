#!/bin/bash
# IDApixiTIK Game-Only Launcher (without sync server)
# Use this for single-player development

set -e

echo "🎮 Starting IDApixiTIK Game (single-player mode)..."

# Check if Deno is installed
if ! command -v deno &> /dev/null; then
    echo "❌ Deno is not installed. Please install Deno first:"
    echo "   https://deno.land/manual/getting_started/installation"
    exit 1
fi

# Start Vite dev server
deno task dev
