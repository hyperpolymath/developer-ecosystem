# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Joshua B. Jewell and Jonathan D.A. Jewell
#
# IDApTIK Sync Server — Elixir/Phoenix WebSocket server (OTP release)
# Build context: repository root (run from repo root, not containers/)
#
# Usage:
#   podman build -f containers/sync-server.Containerfile -t idaptik-sync .

# ── Stage 1: Build OTP release ──────────────────────────────────────────────
FROM cgr.dev/chainguard/wolfi-base:latest AS builder

RUN apk add --no-cache elixir erlang-dev

WORKDIR /build

# Copy mix manifests for dependency caching
COPY sync-server/mix.exs sync-server/mix.lock ./

ENV MIX_ENV=prod

# Install hex + rebar, then fetch & compile deps (cached layer)
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod && \
    mix deps.compile

# Copy application source
COPY sync-server/lib/ lib/
COPY sync-server/config/ config/

# Compile and build the OTP release
RUN mix compile && \
    mix release

# ── Stage 2: Runtime ────────────────────────────────────────────────────────
FROM cgr.dev/chainguard/wolfi-base:latest

RUN apk add --no-cache libstdc++ ncurses-libs

WORKDIR /app

# Copy the built release from the builder
COPY --from=builder /build/_build/prod/rel/idaptik_sync_server/ ./

# Create a non-root user for runtime
RUN adduser -D -u 1001 appuser
USER appuser

ENV PORT=4000
ENV PHX_HOST=localhost

EXPOSE 4000

# Health check — Phoenix endpoint responds on /
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:4000/ || exit 1

CMD ["bin/idaptik_sync_server", "start"]
