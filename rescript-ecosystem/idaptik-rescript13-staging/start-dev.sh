#!/bin/bash
# IDApixiTIK Development Server Launcher
# Starts both the Elixir sync server and the Vite dev server

set -e

echo "🚀 Starting IDApixiTIK Development Environment..."

# Check if Elixir/Mix is installed
if ! command -v mix &> /dev/null; then
    echo "❌ Elixir/Mix is not installed. Please install Elixir first:"
    echo "   https://elixir-lang.org/install.html"
    exit 1
fi

# Check if Deno is installed
if ! command -v deno &> /dev/null; then
    echo "❌ Deno is not installed. Please install Deno first:"
    echo "   https://deno.land/manual/getting_started/installation"
    exit 1
fi

# Function to cleanup background processes on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down servers..."
    jobs -p | xargs -r kill 2>/dev/null
    exit 0
}
trap cleanup INT TERM

# Start Elixir sync server in background
echo "📡 Starting Elixir sync server on port 4000..."
cd sync-server
mix deps.get > /dev/null 2>&1 || true
mix phx.server &
SYNC_PID=$!
cd ..

# Wait a moment for sync server to start
sleep 2

# Start Vite dev server
echo "🎮 Starting game dev server on port 8080..."
deno task dev

# Wait for background processes
wait $SYNC_PID
