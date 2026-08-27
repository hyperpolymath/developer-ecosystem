## Machine-Readable Artefacts

The following files in `.machine_readable/` contain structured project metadata:

- `.machine_readable/6a2/STATE.a2ml` - Current project state and progress
- `.machine_readable/6a2/META.a2ml` - Architecture decisions and development practices
- `.machine_readable/6a2/ECOSYSTEM.a2ml` - Position in the ecosystem and related projects
- `.machine_readable/6a2/AGENTIC.a2ml` - AI agent interaction patterns
- `.machine_readable/6a2/NEUROSYM.a2ml` - Neurosymbolic integration config
- `.machine_readable/6a2/PLAYBOOK.a2ml` - Operational runbook

---

# CLAUDE.md - AI Assistant Instructions

## Language Policy (Hyperpolymath Standard)

### ALLOWED Languages & Tools

| Language/Tool | Use Case | Notes |
|---------------|----------|-------|
| **AffineScript** | Primary application code | Affine-typed, compiles to typed-wasm or ESM |
| **Bun** | JS runtime & package management (tier 1) | Default for all new work. Runs compiled ESM/JS directly — no bundler step. Uses an npm-compatible `package.json` plus `bun.lock` — both are expected, not anti-patterns. |
| **Rust** | Performance-critical, systems, WASM | Preferred for CLI tools |
| **Tauri 2.0+** | Mobile apps (iOS/Android) | Rust backend + web UI |
| **Dioxus** | Mobile apps (native UI) | Pure Rust, React-like |
| **Gleam** | Backend services | Runs on BEAM or compiles to JS |
| **Bash/POSIX Shell** | Scripts, automation | Keep minimal |
| **JavaScript** | Only where AffineScript cannot | MCP protocol glue, Bun APIs |
| **Nickel** | Configuration language | For complex configs |
| **Guile Scheme** | State/meta files | .machine_readable/6a2/STATE.a2ml, .machine_readable/6a2/META.a2ml, .machine_readable/6a2/ECOSYSTEM.a2ml |
| **Julia** | Batch scripts, data processing | Per RSR |
| **OCaml** | AffineScript compiler | Language-specific |
| **Ada** | Safety-critical systems | Where required |

### BANNED - Do Not Use

| Banned | Replacement |
|--------|-------------|
| TypeScript | AffineScript |
| ReScript | AffineScript |
| Deno | Bun |
| Node.js | Bun |
| npm | Bun |
| pnpm/yarn | Bun |
| Go | Rust |
| Python | Julia/Rust/AffineScript |
| Java/Kotlin | Rust/Tauri/Dioxus |
| Swift | Tauri/Dioxus |
| React Native | Tauri/Dioxus |
| Flutter/Dart | Tauri/Dioxus |

### Developer Ecosystem Specific

For developer tools:
- **Rust** preferred for CLI tools, git operations
- **AffineScript** for web dashboards (git-hud)
- **Deno** for automation scripts
- **Julia** for batch analysis (oikos metrics)

### Security Requirements

- No MD5/SHA1 for security (use SHA256+)
- HTTPS only (no HTTP URLs)
- No hardcoded secrets
- SHA-pinned dependencies
- SPDX license headers on all files

### TypeScript Exemptions (Approved)

Pre-migration TypeScript files that are grandfathered pending AffineScript migration. New TS files
in non-exempted paths remain blocked.

| Path / Pattern | Rationale | Unblock condition |
|---|---|---|
| `affinescript-ecosystem/affinescript-deno-test/**` | Bootstrap shim: TS/Deno test runner used to validate AffineScript output. | When AffineScript self-hosts its test runner. |
| `aggregate-library/src/test-runner.ts` | Pre-migration test runner in the aggregate library. | When migrated to AffineScript. |
| `rescript-ecosystem/packages/core/runtime-tools/bin/rrt.ts` | Legacy ReScript runtime tool (upstream fork tooling). | When rescript-ecosystem is migrated or removed. |

