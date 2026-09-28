<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->
<!-- Authoritative source: docs/practice/AI-CONVENTIONS.adoc -->

# Copilot Instructions

## Before Writing Code

- Read the repo deed (`*_chora.deed` in the repo root) for canonical file locations
  (its `(ply ...)` clauses carry the canonical-locations tables).
- State files (.a2ml) live in `.machine_readable/` ONLY, never the root.

## License

- SPDX: `MPL-2.0` on all new files.
- Never use AGPL-3.0.
- Copyright: `Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>`

## Code Style

- Use descriptive variable names.
- Annotate and document all files.
- Add SPDX header to every source file.
- Use `just` for build/test/lint commands.

## Banned Patterns

- Idris2: no `believe_me`, no `assert_total`
- Haskell: no `unsafeCoerce`, no `unsafePerformIO`
- OCaml: no `Obj.magic`
- Coq: no `Admitted`
- Lean: no `sorry`
- Rust: no `transmute` unless FFI with `// SAFETY:` comment

## JavaScript / TypeScript runtimes

Ordered preference (`standards/3-practice/LANGUAGE-POLICY.adoc` §1) — reach for the first
that can do the job:

1. **Bun** — default for all new work. Runs compiled ESM/JS directly, no bundler
   step. Uses an npm-compatible `package.json` plus `bun.lock`; both are
   expected, not anti-patterns.
2. **pnpm** — only where an upstream toolchain requires `node_modules`.
3. **npm** — last resort. Permitted, never preferred; a deliberate, noted choice.

**Deno is being removed**, not grandfathered. Owner ruling 2026-08-26: *"deno is
to go and bun is the way we are going, put it first everywhere unless not
possible and explain why if not."* Existing Deno projects migrate to Bun; where
Bun genuinely cannot be used, document the reason in the repo.

**TypeScript is not the language for new application code — AffineScript is.**
`LANGUAGE-POLICY.adoc` §1.2, ruled 2026-08-25, separates two questions the older
text ran together: *runtime* is Bun (where `.ts` runs at all, Bun runs it), while
the *language* target is AffineScript. TypeScript is permitted only where
AffineScript cannot reach — the same narrow, transitional carve-out JavaScript
holds for MCP protocol glue and runtime APIs. ReScript remains banned; its
migration destination is AffineScript.

## Banned Languages

- No Go (use Rust)
- No Python (use Julia or Rust)
- No Nix (use Guix)
- No Deno for new work — being removed estate-wide; use Bun (owner ruling 2026-08-26)
- No ReScript (`LANGUAGE-POLICY.adoc` §3) — migrate to AffineScript

## Containers

- Use Podman, never Docker.
- Name the file `Containerfile`, never `Dockerfile`.
- Base image: `cgr.dev/chainguard/wolfi-base:latest`.

## ABI/FFI

- This repo does not carry the Idris2/Zig ABI seam; the only FFI is the C ABI in `src/cfk-ios`.
- Cargo workspace crates live in `src/cfk-*`; every destructive operation must go through `ReversibleBackend`.

## State Files

Never create these in the repo root:
STATE.a2ml, META.a2ml, ECOSYSTEM.a2ml, AGENTIC.a2ml, NEUROSYM.a2ml, PLAYBOOK.a2ml.
They belong in `.machine_readable/` only.
