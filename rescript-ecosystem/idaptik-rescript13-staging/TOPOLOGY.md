<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# TOPOLOGY.md — idaptik-rescript13-staging

## Purpose

Staging repository for IDApixiTIK (hacking/network simulator game) migration to ReScript 13 with zero deprecated APIs. Browser-based game with combat, companion systems, training scenarios, network simulation, and Phoenix WebSocket multiplayer infrastructure.

## Module Map

```
idaptik-rescript13-staging/
├── src/
│   ├── Game.res               # Game core (ReScript 13)
│   ├── Combat.res             # Guard encounters, collision
│   ├── Companion.res          # Moletaire companion system
│   ├── Training.res           # 8 training scenarios
│   ├── Network.res            # SSH, terminals, topology
│   └── ... (additional systems)
├── backend/
│   └── phoenix/               # Elixir/Phoenix WebSocket
├── test/
│   └── ... (test suites)
├── deno.json, deno.lock       # Deno package config
├── containers/
│   └── ... (Containerfile specifications)
└── README.md                  # ReScript 13 migration notes
```

## Data Flow

```
[Game State] ◄──► [ReScript Engine] ──► [PixiJS Renderer] ──► [Browser]
     ↓                                                              ↓
[Phoenix WebSocket] ◄────────────────────────────────────────── [Multiplayer]
```

## Key Invariants

- AGPL-3.0-or-later license (co-developed game)
- Zero deprecated ReScript APIs (migration target)
- Multiplayer via Phoenix Channels (Elixir backend)
- Combat, companions, training, and network simulation subsystems
