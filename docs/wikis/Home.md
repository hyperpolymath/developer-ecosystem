<!-- SPDX-License-Identifier: MPL-2.0 -->
# Developer Ecosystem

**The central hub for all hyperpolymath development-workflow tools** — git operations, repository management, scaffolding, code analysis, and developer experience.

This wiki is the *signpost* — canonical docs live in the repo at [`docs/`](https://github.com/hyperpolymath/developer-ecosystem/tree/main/docs). Edit [`docs/wikis/`](https://github.com/hyperpolymath/developer-ecosystem/tree/main/docs/wikis) in the code repo, not directly in the wiki UI.

---

## Start here

| If you want to… | Go to |
|---|---|
| Understand what's in the ecosystem | [README.adoc](https://github.com/hyperpolymath/developer-ecosystem/blob/main/README.adoc) |
| Find a specific tool | [satellite map below](#satellite-map) |
| See current project state | [.machine_readable/6a2/STATE.a2ml](https://github.com/hyperpolymath/developer-ecosystem/blob/main/.machine_readable/6a2/STATE.a2ml) |
| See governance / contractiles | [.machine_readable/contractiles/](https://github.com/hyperpolymath/developer-ecosystem/tree/main/.machine_readable/contractiles/) |

---

## What Developer Ecosystem is

Developer Ecosystem is a **meta-repository** — a coordination hub and scaffold for 30+ satellite projects that improve how developers work. Satellites are organized into four tracks:

- **Git Tools** — forge management, branch workflows, repo unification, multi-forge mirroring
- **Repo Management** — automation, health monitoring, audit-grade tooling
- **Scaffolding** — project template generation, boilerplate
- **Developer UX** — dashboards, doc reconciliation, language evangelism

Each satellite is a real project with its own repo and its own machine-readable governance; this parent repo provides the shared standards, CI templates, and estate-wide coordination.

## Satellite map

### Git Tools

| Satellite | Purpose |
|---|---|
| **git-hud** | Unified git platform dashboard — GitHub, GitLab, Gitea, Bitbucket in one UI |
| **gitloom** | Branch management and workflow weaving |
| **git-reunify** | Safe repo reunification and history merging |
| **git-seo** | Repo discoverability tooling |
| **polysafe-gitfixer** | Git backup merger |
| **vext** | IRC commit notifications |

### Repo Management

| Satellite | Purpose |
|---|---|
| **oikos** | Ecological code health and analysis metrics |
| **robot-repo-automaton** | Automated repo management |
| **grim-repo** | Audit-grade repo tooling |
| **robot-vacuum-cleaner** | Repo tidying bot |

### Scaffolding

| Satellite | Purpose |
|---|---|
| **scaffoldia** | Community-driven project scaffolding and templates |

### Developer UX

| Satellite | Purpose |
|---|---|
| **rescript-evangeliser** | AffineScript/ReScript migration assistant and IDE helpers |
| **recon-silly-ation** | Doc reconciliation system |
| **nickel-config-reporter** | Config auditing against Nickel schemas |

## Language policy

Tools in this ecosystem follow the **hyperpolymath standard** language policy:

- **Primary application code**: AffineScript (`.affine`) — compiles to typed-wasm or Deno-ESM
- **CLI tools / systems**: Rust
- **Scripts / automation**: Deno (Bash for simple cases)
- **Backend services**: Gleam or Elixir (BEAM ecosystem)
- **Data analysis**: Julia
- **Legacy**: ReScript/TypeScript exists in some satellites; no new `.res`/`.ts` files

See [`.claude/CLAUDE.md`](https://github.com/hyperpolymath/developer-ecosystem/blob/main/.claude/CLAUDE.md) for the full policy.

## Governance

- **Licence**: MPL-2.0 (or PMPL-1.0 where explicitly declared)
- **Machine-readable state**: [`.machine_readable/6a2/`](https://github.com/hyperpolymath/developer-ecosystem/tree/main/.machine_readable/6a2/)
- **Contractiles**: 6-verb governance (`must/trust/bust/adjust/dust/intend`) in [`.machine_readable/contractiles/`](https://github.com/hyperpolymath/developer-ecosystem/tree/main/.machine_readable/contractiles/)
- **Bot directives**: [`.machine_readable/bot_directives/`](https://github.com/hyperpolymath/developer-ecosystem/tree/main/.machine_readable/bot_directives/) — methodology + coverage + debt for AI agents
- **Security policy**: [SECURITY.md](https://github.com/hyperpolymath/developer-ecosystem/blob/main/SECURITY.md)
- **Open issues**: [github.com/hyperpolymath/developer-ecosystem/issues](https://github.com/hyperpolymath/developer-ecosystem/issues)
