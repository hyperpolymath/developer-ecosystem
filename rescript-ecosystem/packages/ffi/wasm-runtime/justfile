# ReScript WASM Runtime - Build System
# Requires: just, deno, rescript, wasm-pack

# Default recipe - show available commands
default:
    @just --list

# RSR Compliance commands
# =======================

# Check RSR (Rhodium Standard Repository) compliance
rsr-check:
    @echo "Running RSR compliance check..."
    ./scripts/rsr-check.sh

# Validate RSR compliance (alias)
rsr-validate: rsr-check

# Show RSR compliance status
rsr-status:
    @echo "RSR Compliance Status"
    @echo "====================="
    @./scripts/rsr-check.sh | grep -E "(Compliance Score|RSR Tier|Passed|Failed|Warnings)"

# Build commands
# ==============

# Build all ReScript sources
build:
    @echo "Building ReScript sources..."
    npx rescript build

# Clean build artifacts
clean:
    @echo "Cleaning build artifacts..."
    npx rescript clean
    rm -rf lib/
    find . -name "*.mjs" -type f -delete
    find . -name "*.d.ts" -type f -delete

# Clean and rebuild
rebuild: clean build

# Watch mode for development
watch:
    @echo "Watching for changes..."
    npx rescript build -w

# Compile to WebAssembly
wasm:
    @echo "Compiling to WebAssembly..."
    @echo "WASM compilation pipeline not yet implemented"
    @echo "This will use wasm-pack or similar tooling"

# Development commands
# ====================

# Run hello-world example
dev-hello:
    just build
    deno run --allow-net examples/hello-world/main.mjs

# Run API server example
dev-api:
    just build
    deno run --allow-net examples/api-server/main.mjs

# Run WebSocket example
dev-ws:
    just build
    deno run --allow-net examples/websocket/main.mjs

# Run static file server
dev-static:
    just build
    deno run --allow-net --allow-read examples/static-files/main.mjs

# Run microservices example
dev-micro:
    just build
    deno run --allow-net examples/microservices/auth-service.mjs

# Test commands
# =============

# Run all tests
test:
    @echo "Running tests..."
    deno test --allow-net --allow-read tests/

# Run unit tests only
test-unit:
    deno test --allow-net tests/unit/

# Run integration tests
test-integration:
    deno test --allow-net tests/integration/

# Run tests with coverage
test-coverage:
    deno test --coverage=coverage --allow-net --allow-read tests/
    deno coverage coverage

# Run tests in watch mode
test-watch:
    deno test --watch --allow-net --allow-read tests/

# Benchmark commands
# ==================

# Run all benchmarks
bench:
    @echo "Running benchmarks..."
    ./benchmark/run-benchmarks.sh

# Run startup benchmark
bench-startup:
    deno run --allow-run --allow-read benchmark/startup.ts

# Run memory benchmark
bench-memory:
    deno run --allow-run --allow-read benchmark/memory.ts

# Run throughput benchmark
bench-throughput:
    deno run --allow-run --allow-read benchmark/throughput.ts

# Compare with Node.js
bench-compare:
    ./benchmark/compare-with-node.sh

# Container commands
# ==================

# Build container image
container-build:
    podman build -t rescript-wasm-runtime:latest -f Containerfile .

# Run container
container-run:
    podman run -p 8000:8000 rescript-wasm-runtime:latest

# Push container to registry
container-push REGISTRY:
    podman tag rescript-wasm-runtime:latest {{REGISTRY}}/rescript-wasm-runtime:latest
    podman push {{REGISTRY}}/rescript-wasm-runtime:latest

# Quality commands
# ================

# Format code
fmt:
    @echo "Formatting ReScript code..."
    npx rescript format -all

# Type check
check:
    npx rescript build -with-deps

# Lint (using ReScript's built-in warnings)
lint:
    npx rescript build

# Documentation commands
# ======================

# Generate API documentation
docs:
    @echo "Generating documentation..."
    @echo "ReScript documentation generation"
    npx rescript doc

# Serve documentation locally
docs-serve:
    cd docs && python3 -m http.server 8080

# Deployment commands
# ===================

# Deploy to Deno Deploy
deploy-deno:
    @echo "Deploying to Deno Deploy..."
    deployctl deploy --project=rescript-wasm-runtime examples/api-server/main.mjs

# Deploy using Docker
deploy-docker:
    docker-compose up -d

# Utility commands
# ================

# Install dependencies
install:
    npm install
    @echo "Checking Deno installation..."
    deno --version

# Update dependencies
update:
    npm update
    deno upgrade

# Create new example
new-example NAME:
    mkdir -p examples/{{NAME}}
    echo '// {{NAME}} example\n\nlet handler = async (_req: Deno.request): promise<Deno.response> => {\n  Deno.Response.text("{{NAME}}", ())\n}\n\nServer.simple(~port=8000, handler)' > examples/{{NAME}}/main.res
    @echo "Created new example: examples/{{NAME}}"

# Bundle size analysis
analyze:
    @echo "Analyzing bundle sizes..."
    @for example in examples/*/main.mjs; do \
        if [ -f "$$example" ]; then \
            size=$$(wc -c < "$$example"); \
            echo "$$(dirname $$example): $${size} bytes"; \
        fi \
    done

# Performance profiling
profile EXAMPLE:
    deno run --inspect --allow-net examples/{{EXAMPLE}}/main.mjs

# Generate bundle report
bundle-report:
    @echo "Bundle Report"
    @echo "============="
    @just analyze
    @echo ""
    @echo "Compared to typical Node.js stack:"
    @echo "  Node.js + Express: ~5MB"
    @echo "  This runtime: <10KB per example"

# CI/CD commands
# ==============

# Run CI pipeline locally
ci: lint test build

# Pre-commit hook
pre-commit: fmt lint test

# Release preparation
release VERSION:
    @echo "Preparing release {{VERSION}}..."
    @echo "Updating version in package.json..."
    @echo "Running tests..."
    just test
    @echo "Building..."
    just build
    @echo "Ready to tag release {{VERSION}}"

# Git commands
# ============

# Commit all changes
commit MESSAGE:
    git add .
    git commit -m "{{MESSAGE}}"

# Push changes
push:
    git push origin HEAD

# Create and push tag
tag VERSION:
    git tag v{{VERSION}}
    git push origin v{{VERSION}}

# ============================================================================
# Superintendent Audit Recipes
# ============================================================================

# Full superintendent audit
audit:
    @echo "╔══════════════════════════════════════════════════════════════════╗"
    @echo "║          Superintendent Audit: rescript-wasm-runtime             ║"
    @echo "╚══════════════════════════════════════════════════════════════════╝"
    @just audit-sharedmemory
    @just audit-dag
    @echo ""
    @echo "Audit complete."

# Audit SharedArrayBuffer zero-copy support
audit-sharedmemory:
    @echo ""
    @echo "── Zero-Copy SharedMemory ────────────────────────────────────────────"
    @test -f src/SharedMemory.res && echo "✓ SharedMemory module exists" || echo "✗ MISSING: SharedMemory module"
    @grep -q "SharedArrayBuffer" src/SharedMemory.res 2>/dev/null && echo "✓ SharedArrayBuffer bindings" || echo "✗ MISSING: SharedArrayBuffer"
    @grep -q "Atomics" src/SharedMemory.res 2>/dev/null && echo "✓ Atomics for thread safety" || echo "✗ MISSING: Atomics"
    @grep -q "memoryPool" src/SharedMemory.res 2>/dev/null && echo "✓ Memory pool management" || echo "✗ MISSING: Memory pool"
    @grep -q "writeCommitHistory" src/SharedMemory.res 2>/dev/null && echo "✓ Commit history serialization" || echo "✗ MISSING: Commit history support"

# Audit DAG builder for dependency analysis
audit-dag:
    @echo ""
    @echo "── DAG Dependency Analysis ───────────────────────────────────────────"
    @test -f src/DependencyGraph.res && echo "✓ DependencyGraph module exists" || echo "✗ MISSING: DependencyGraph module"
    @grep -q "findCycles" src/DependencyGraph.res 2>/dev/null && echo "✓ Cycle detection" || echo "✗ MISSING: Cycle detection"
    @grep -q "topologicalSort" src/DependencyGraph.res 2>/dev/null && echo "✓ Topological sort" || echo "✗ MISSING: Topological sort"
    @grep -q "suggestedRoot" src/DependencyGraph.res 2>/dev/null && echo "✓ Root preservation logic" || echo "✗ MISSING: Root preservation"
    @grep -q "eliminationCandidates" src/DependencyGraph.res 2>/dev/null && echo "✓ Elimination scoring" || echo "✗ MISSING: Elimination scoring"
    @grep -q "criticalPath" src/DependencyGraph.res 2>/dev/null && echo "✓ Critical path analysis" || echo "✗ MISSING: Critical path"

# Verify superintendent environment
super-check:
    @echo "Checking Superintendent Environment..."
    @command -v rescript >/dev/null 2>&1 && echo "✓ ReScript available" || echo "✗ ReScript missing"
    @command -v deno >/dev/null 2>&1 && echo "✓ Deno available" || echo "✗ Deno missing"
    @command -v wasm-pack >/dev/null 2>&1 && echo "○ wasm-pack available" || echo "○ wasm-pack optional (for WASM builds)"
    @echo "Environment check complete."
