# Multi-stage Containerfile for ReScript WASM Runtime
# Optimized for minimal image size

# Stage 1: Build
FROM docker.io/denoland/deno:alpine AS builder

WORKDIR /app

# Install Node.js and npm for ReScript compiler
RUN apk add --no-cache nodejs npm

# Copy package files
COPY package.json package-lock.json* ./

# Install dependencies
RUN npm install

# Copy source code
COPY rescript.json ./
COPY src/ ./src/
COPY examples/ ./examples/

# Build ReScript code
RUN npm run build

# Stage 2: Runtime
FROM docker.io/denoland/deno:alpine

WORKDIR /app

# Copy only compiled outputs
COPY --from=builder /app/src/*.mjs ./src/
COPY --from=builder /app/examples/ ./examples/

# Set permissions
RUN chmod -R 755 /app

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD deno eval "fetch('http://localhost:8000').then(() => Deno.exit(0)).catch(() => Deno.exit(1))"

# Default command - run API server example
CMD ["deno", "run", "--allow-net", "examples/api-server/main.mjs"]

# Alternative commands:
# CMD ["deno", "run", "--allow-net", "examples/hello-world/main.mjs"]
# CMD ["deno", "run", "--allow-net", "examples/websocket/main.mjs"]

# Build with: podman build -t rescript-wasm-runtime:latest -f Containerfile .
# Run with: podman run -p 8000:8000 rescript-wasm-runtime:latest

# Size optimization notes:
# - Alpine base image (~5MB)
# - No npm/node in runtime image
# - Only compiled .mjs files copied
# - Expected final image size: <50MB vs typical Node.js images (>100MB)
