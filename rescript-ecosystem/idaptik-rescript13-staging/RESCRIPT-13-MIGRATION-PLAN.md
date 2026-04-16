# ReScript 12 → 13 Migration Plan: IDApTIK

**Purpose:** Structured migration testing on a real-world ReScript 12 codebase to produce
a migration report for the ReScript team ahead of their April 2026 retreat.

**Repo:** `hyperpolymath/idaptik-rescript13-staging` (private)
**Source:** Cloned from `hyperpolymath/idaptik` at commit `ecbb7b2` (2026-03-02)
**Codebase:** ~542 `.res` files, browser game (PixiJS), reversible VM, multiplayer sync

## Current State (Baseline)

| Property | Value |
|----------|-------|
| ReScript version | 12.2.0 (via deno.json, upgraded from 12.1.0 during merge resolution) |
| @rescript/core | 1.6.1 |
| @rescript/runtime | (bundled with rescript 12.1.0) |
| Module system | `esmodule` |
| Config file | `rescript.json` (no bsconfig.json anywhere) |
| Config keys | All modern (`dependencies`, `compiler-flags`) |
| Uncurried syntax | Default (no `(. args) =>` dot syntax) |
| Deprecated Js.* APIs | **ZERO** (fully migrated 2026-03-02) |
| Build command | `deno run --node-modules-dir=auto ... npm:rescript@12.2.0` |
| Known workaround | `rescript-legacy` was used for UTF-8 crash (now removed from repo) |

## v13 Breaking Changes Audit

### Already Clean (no action needed)

- [x] `bsconfig.json` → `rescript.json` — already done
- [x] `bs-dependencies` → `dependencies` — already done
- [x] `bsc-flags` → `compiler-flags` — already done
- [x] `"module": "es6"` → `"module": "esmodule"` — already done
- [x] `(. args) =>` dot-uncurried syntax — none found
- [x] `external-stdlib` config — not used
- [x] Deprecated `Js.*` APIs — fully migrated
- [x] `Int.fromString` / `Float.fromString` with radix — not used

### Needs Testing

- [ ] **`rescript-legacy` removal** — v13 removes the legacy build system entirely.
      IDApTIK previously required `rescript-legacy` due to a UTF-8 crash in `rescript.exe`.
      Test: does `rescript@13.0.0-alpha.2` crash on this codebase?

- [ ] **`esmodule` as default** — IDApTIK explicitly sets `"module": "esmodule"`.
      Test: remove the explicit setting and verify the default works.

- [ ] **`js-post-build` working directory** — not currently used, but verify monorepo
      subpackage behavior hasn't regressed.

- [ ] **`@rescript/runtime` version pairing** — v13 requires runtime v13.
      Test: does deno correctly resolve the paired runtime?

- [ ] **Two package specs with same suffix** — not currently used, but verify.

## Test Plan (Migration Phases)

### Phase 1: Baseline Verification
**Goal:** Confirm clean build on current v12.1.0

```bash
deno task res:clean
deno task res:build
# Expected: 0 errors, 0 warnings
```

Record: file count, build time, output size, any warnings.

### Phase 2: Version Bump (v12.1.0 → v12.2.0)
**Goal:** Pick up latest v12 stable before jumping to v13

- Update deno.json: `rescript@12.2.0`
- Build and test
- Record any new warnings or behavioral changes
- Note: v12.2.0 backported `Array.zip/unzip/zipBy/partition` from v13

### Phase 3: Version Bump (v12.2.0 → v13.0.0-alpha.2)
**Goal:** Test the actual v13 migration

- Update deno.json: `rescript@13.0.0-alpha.2`
- Update @rescript/runtime if needed
- Build and record all errors/warnings
- Document every change needed to achieve clean build

### Phase 4: UTF-8 Crash Test
**Goal:** Determine if the `rescript.exe` UTF-8 crash is fixed in v13

- Remove any `rescript-legacy` workarounds
- Use `rescript` directly (not `rescript-legacy`)
- Build with file paths containing non-ASCII characters
- Test on Fedora 43 (Linux) with UTF-8 locale

### Phase 5: Edge Cases & Regression Testing

- [ ] Build artifact output paths match expectations
- [ ] Source maps still work
- [ ] Hot reload (vite + rescript watcher) still works
- [ ] Deno-specific module resolution still works
- [ ] `Belt` interop with `@rescript/core` still works
- [ ] `%raw` JavaScript FFI still works
- [ ] PixiJS bindings compile and run
- [ ] VM instruction tests pass
- [ ] Multiplayer WebSocket sync compiles

### Phase 6: Report Generation

For each phase, record:
1. **Errors encountered** (with file, line, error message)
2. **Warnings** (new warnings not present in v12)
3. **Code changes required** (diff for each fix)
4. **Build time comparison** (v12 vs v13)
5. **Output size comparison**
6. **Behavioral changes** (any runtime differences)

## Report Structure (for ReScript team)

```
1. Executive Summary
   - Codebase profile (size, complexity, dependencies)
   - Migration difficulty rating (1-5)
   - Total code changes required
   - Blockers found

2. Pre-Migration Audit
   - Deprecated API usage (Js.*, Belt overlap with core)
   - Config file modernization
   - Build system compatibility

3. Phase-by-Phase Results
   - v12.1.0 baseline
   - v12.2.0 intermediate
   - v13.0.0-alpha.2 target
   - Errors, fixes, and workarounds for each

4. UTF-8 / Platform Issues
   - rescript.exe crash status
   - Deno runtime integration
   - Linux-specific issues

5. Performance Comparison
   - Build times
   - Output sizes
   - Runtime behavior

6. Recommendations
   - Migration guide improvements needed
   - Breaking changes that need better documentation
   - Suggested deprecation warnings for v12
   - Edge cases to add to v13 test suite

7. Appendix
   - Full diff of all migration changes
   - Build logs
   - Error screenshots
```

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Baseline with v12.2.0 (upgraded from v12.1.0 via upstream merge) |
| `phase-2/v12.2.0` | Intermediate v12.2.0 testing |
| `phase-3/v13-alpha` | v13 migration work |
| `phase-4/utf8-test` | UTF-8 crash investigation |
| `report/final` | Final report + all diffs |

## Timeline

| When | What |
|------|------|
| Now (March 2026) | Repo created, baseline frozen, plan written, merge conflicts resolved, v12.2.0 bump applied |
| Mid-March | Phase 1-2 (baseline verification + v12.2.0 build test) |
| Late March | Phase 3-5 (v13 migration + edge cases) |
| Early April | Phase 6 (report generation) |
| April retreat | Deliver report to ReScript team |

## Notes

- This repo is **private** — it contains game code not intended for public release
- The source repo (`hyperpolymath/idaptik`) remains on v12.1.0 stable
- Do NOT push v13 changes back to the source repo
- If v13 alpha.3 ships during testing, create a new branch to test it too
