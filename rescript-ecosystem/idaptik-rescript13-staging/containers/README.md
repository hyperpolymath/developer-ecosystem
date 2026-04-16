# IDApTIK Container Setup

Stapeln-style containerisation for IDApTIK. Two services:

| Service | Image | Port | Description |
|---------|-------|------|-------------|
| `game` | Chainguard nginx | 8080 | Static ReScript/PixiJS web app |
| `sync` | Chainguard wolfi (OTP release) | 4000 | Elixir/Phoenix WebSocket server |

## Quick Start

```bash
# Generate a secret for Phoenix (one-time)
export SECRET_KEY_BASE=$(cd sync-server && mix phx.gen.secret)

# Build and run both services
podman-compose up --build

# Game:        http://localhost:8080
# Sync server: http://localhost:4000
```

## Individual Builds

```bash
# Game only
podman build -f containers/game.Containerfile -t idaptik-game .
podman run --rm -p 8080:8080 idaptik-game

# Sync server only
podman build -f containers/sync-server.Containerfile -t idaptik-sync .
podman run --rm -p 4000:4000 -e SECRET_KEY_BASE="$(mix phx.gen.secret)" idaptik-sync
```

## Environment Variables

### Sync server

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SECRET_KEY_BASE` | Yes | — | Phoenix secret (64+ bytes, `mix phx.gen.secret`) |
| `PHX_HOST` | No | `localhost` | Public hostname for URL generation |
| `PORT` | No | `4000` | HTTP listen port |

## Architecture

Both containers use read-only root filesystems with tmpfs mounts for runtime
writable paths (nginx cache, OTP temp files). Base images are from Chainguard
for minimal attack surface.

All builds use the repo root as build context. The `.containerignore` file
excludes heavy directories (node_modules, .git, target/, etc.) to keep
context transfers fast.
