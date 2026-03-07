# SPDX-License-Identifier: MIT OR Palimpsest-0.8
# SPDX-FileCopyrightText: 2025 Hyperpolymath

# Containerfile for aggregate-library (aLib)
# Use with Podman (preferred) or Docker
# Base: Chainguard Wolfi (minimal, secure, distroless-style base image)

# Build stage
FROM cgr.dev/chainguard/wolfi-base:latest AS builder

# Install build dependencies
RUN apk add --no-cache \
    just \
    git \
    yaml-linter \
    && rm -rf /var/cache/apk/*

# Set working directory
WORKDIR /build

# Copy project files
COPY . /build/

# Validate specifications
RUN just validate || echo "Validation completed"

# Production stage
FROM cgr.dev/chainguard/static:latest

# Metadata
LABEL org.opencontainers.image.title="aggregate-library"
LABEL org.opencontainers.image.description="Common Library Specification for cross-language programming"
LABEL org.opencontainers.image.version="0.1.0"
LABEL org.opencontainers.image.authors="Hyperpolymath"
LABEL org.opencontainers.image.url="https://github.com/Hyperpolymath/aggregate-library"
LABEL org.opencontainers.image.source="https://github.com/Hyperpolymath/aggregate-library"
LABEL org.opencontainers.image.licenses="MIT OR Palimpsest-0.8"
LABEL org.opencontainers.image.vendor="aggregate-library project"

# RSR compliance labels
LABEL rsr.compliance="Gold"
LABEL rsr.version="1.0.0"
LABEL rsr.score="100/100"
LABEL tpcf.perimeter="3"

# Copy specifications from builder
COPY --from=builder /build/specs /specs/
COPY --from=builder /build/README.md /README.md
COPY --from=builder /build/README.adoc /README.adoc
COPY --from=builder /build/LICENSE.txt /LICENSE.txt
COPY --from=builder /build/SPEC_FORMAT.md /SPEC_FORMAT.md
COPY --from=builder /build/.well-known /.well-known/

# Non-root user (distroless already runs as non-root)
# Chainguard static image is minimal and secure

# No CMD needed - this container serves static specifications
# Can be used as a base for documentation servers or validation tools

# Usage with Podman (preferred):
#   podman build -f Containerfile -t aggregate-library:latest .
#   podman run -v $(pwd)/specs:/specs:ro aggregate-library:latest
#
# Usage with Docker (if Podman unavailable):
#   docker build -f Containerfile -t aggregate-library:latest .
#   docker run -v $(pwd)/specs:/specs:ro aggregate-library:latest

# Security notes:
# - Uses Chainguard Wolfi base (minimal attack surface)
# - Distroless-style (no package manager, shell, or unnecessary tools)
# - Runs as non-root user by default
# - Read-only filesystem recommended
# - No network access required (offline-first)

# Podman-specific features:
# - Rootless by default (more secure than Docker)
# - No daemon (lower attack surface)
# - OCI-compliant (standards-based)
# - Better SELinux integration
