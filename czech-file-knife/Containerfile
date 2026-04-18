# SPDX-License-Identifier: AGPL-3.0-or-later
# Build stage
FROM docker.io/library/rust:1.83-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libfuse3-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy source
COPY . .

# Build release binary
RUN cargo build --release -p cfk-cli

# Runtime stage
FROM cgr.dev/chainguard/wolfi-base:latest

LABEL org.opencontainers.image.source="https://github.com/hyperpolymath/czech-file-knife"
LABEL org.opencontainers.image.description="Czech File Knife - Universal file management tool"
LABEL org.opencontainers.image.licenses="AGPL-3.0-or-later"

# Install runtime dependencies
RUN apk add --no-cache fuse3 fuse3-libs ca-certificates

# Copy binary from builder
COPY --from=builder /build/target/release/cfk /usr/local/bin/cfk

# Create non-root user
RUN adduser -D -u 1000 cfk
USER cfk

WORKDIR /home/cfk

ENTRYPOINT ["/usr/local/bin/cfk"]
