# URGENT: ReScript Migration Required

**Generated:** 2026-03-02
**Current stable ReScript:** 12.2.0
**Pre-release:** 13.0.0-alpha.2 (2025-02-27)

This repo has ReScript code that needs migration. Address in priority order.

## CRITICAL: Pure BuckleScript (bsconfig.json only)

These locations use the legacy BuckleScript config format with NO rescript.json.
**ReScript 13 removes bsconfig.json support entirely.**

- `satellites/repo-management/grim-repo`

**Action required:**
1. Rename `bsconfig.json` → `rescript.json`
2. Replace `bs-dependencies` → `dependencies`, `bs-dev-dependencies` → `dev-dependencies`
3. Remove `bsc-flags` (deprecated)
4. Check for `.re` (Reason) files → convert to `.res` syntax
5. Replace any `bs-platform` dependency with `rescript` ^12.2.0
6. Migrate all `@bs.` attributes to `@` equivalents
7. Migrate `Js.*` APIs to `@rescript/core` equivalents

## HIGH: Partial Migration (both bsconfig.json and rescript.json)

These have both config files — migration was started but not completed.

- `satellites/developer-ux/recon-silly-ation`

**Action required:**
1. Delete the leftover `bsconfig.json` files
2. Ensure `rescript.json` has all needed config migrated
3. Verify build still works with `rescript.json` only

## HIGH: ReScript 11.x → 12.2.0 Upgrade Required

ReScript 11 is outdated. v12 has breaking changes that need migration.

- `rescript-ecosystem/cadre-router/tea-router (^11.0.0
^11.1.0)`

**Key v11 → v12 migration steps:**
1. Update `package.json`: `"rescript": "^12.2.0"`
2. Add `@rescript/core` and `@rescript/react` (if applicable) to dependencies
3. Config: `bs-dependencies` → `dependencies`, `bs-dev-dependencies` → `dev-dependencies`
4. Remove `bsc-flags` from config
5. JSX: v3 is removed in v12 — must use JSX v4
6. Module format: `es6`/`es6-global` → `esmodule` (now default)
7. Migrate deprecated `Js.*` APIs → `@rescript/core` equivalents:
   - `Js.Dict` → `Dict`, `Js.Console.log` → `Console.log`
   - `Js.String2` → `String`, `Js.Array2` → `Array`
   - `Js.Math` → `Math`, `Js.Float` → `Float`, `Js.Int` → `Int`
   - `Js.Promise` → `Promise`, `Js.Nullable` → `Nullable`
8. Functions ending in `Exn` → `OrThrow` (e.g. `getExn` → `getOrThrow`)
9. Run `npx rescript-tools migrate` for automated codemods

## CHECK: Version Unknown or Unpinned

- `satellites/developer-ux/rescript-evangeliser (no version pinned)`
- `satellites/developer-ux/recon-silly-ation (no version pinned)`
- `deno-ecosystem/projects/beamdeno (no version pinned)`
- `deno-ecosystem/projects/bundeno (no version pinned)`
- `deno-ecosystem/projects/deno-bunbridge (no version pinned)`
- `v-ecosystem/v-deno (no version pinned)`
- `rescript-ecosystem/cadre-router (no version pinned)`
- `rescript-ecosystem/cadre-router/tea-router-pkg (no version pinned)`

**Action:** Pin to `"rescript": "^12.2.0"` explicitly.

---

## ReScript 13 Preparation (v13.0.0-alpha.2 available)

v13 is in alpha. These breaking changes are CONFIRMED — prepare now:

1. **`bsconfig.json` support removed** — must use `rescript.json` only
2. **`rescript-legacy` command removed** — only modern build system
3. **`bs-dependencies`/`bs-dev-dependencies`/`bsc-flags` config keys removed**
4. **Uncurried `(. args) => ...` syntax removed** — use standard `(args) => ...`
5. **`es6`/`es6-global` module format names removed** — use `esmodule`
6. **`external-stdlib` config option removed**
7. **`--dev`, `--create-sourcedirs`, `build -w` CLI flags removed**
8. **`Int.fromString`/`Float.fromString` API changes** — no explicit radix arg
9. **`js-post-build` behaviour changed** — now passes correct output paths

**Migration path:** Complete all v12 migration FIRST, then test against v13-alpha.
