# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Joshua B. Jewell and Jonathan D.A. Jewell
#
# IDApTIK Game — Static web app (ReScript/PixiJS compiled to JS, served by nginx)
# Build context: repository root (run from repo root, not containers/)
#
# Usage:
#   podman build -f containers/game.Containerfile -t idaptik-game .

# ── Stage 1: Build ───────────────────────────────────────────────────────────
FROM cgr.dev/chainguard/wolfi-base:latest AS builder

# Install Deno
RUN apk add --no-cache deno

WORKDIR /build

# Copy dependency manifests first for layer caching
COPY deno.json deno.lock package.json rescript.json ./

# Install dependencies (creates node_modules via Deno's npm compat)
RUN deno install --node-modules-dir=auto --allow-scripts

# Copy source files needed for the build
COPY src/ src/
COPY public/ public/
COPY index.html style.css vite.config.js ./
COPY shared/ shared/

# Build: ReScript compile + Vite bundle
RUN deno task build

# ── Stage 2: Serve ───────────────────────────────────────────────────────────
FROM cgr.dev/chainguard/nginx:latest

# Copy built assets from builder stage
COPY --from=builder /build/dist/ /usr/share/nginx/html/

# Custom nginx config for SPA routing
COPY containers/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
