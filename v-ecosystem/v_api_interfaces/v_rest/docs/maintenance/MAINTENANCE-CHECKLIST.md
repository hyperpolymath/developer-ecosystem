# Maintenance Checklist

This checklist is the standard maintenance and release-gate workflow for repositories bootstrapped from this template.

## Quick Start

Run the automated maintenance audit first:

```bash
just maint-audit
jq . reports/maintenance/latest.json
```

Release hard-pass mode (fails on warnings and failures):

```bash
just maint-hard-pass
```

## Permission Policy (Audit-First)

Default behavior is non-mutating audit.

```bash
just perms-audit
```

Opt-in lock (after snapshot):

```bash
just perms-snapshot
just perms-lock
```

Restore local modes from snapshot:

```bash
just perms-restore
```

### Why this is safe for developers and users

- Git tracks executable bit only, not full UNIX mode matrix.
- Running lock/audit scripts does not force mode resets on every pull for collaborators.
- `perms-lock` is opt-in and reversible via `perms-restore`.

Use `.maintenance-perms-ignore` for justified exceptions (regex per line).

## Core Flow

1. Run `just maint-audit` and inspect report.
2. Fix all `fail` items first.
3. Triage `warn` items and either fix or explicitly justify.
4. Run language checks (`just quality`, plus ecosystem-specific checks).
5. Run security checks (`just security`).
6. Run `panic-attack` where available.
7. Re-run `just maint-hard-pass` before release/tag.

## Corrective, Adaptive, Perfective Scope

- Corrective: regressions, crashes, broken tests/commands, security faults.
- Adaptive: dependency and API compatibility updates, deprecation migrations.
- Perfective: clarity, docs parity, workflow improvements, measurable performance improvements.

## AI Execution Integrity Contract

When an AI agent runs this workflow, it must follow fail-closed execution:

1. Do not claim any step is done unless executed.
2. No silent skips; mark skipped steps with explicit reason.
3. Provide evidence for each step: command, status, summary, artifact path.
4. Re-run failing checks after each fix and report rerun status.
5. Final output must include unresolved risks and exact next actions.

Enforcement phrase for prompts:

```text
Fail closed: if evidence is missing for any checklist item, treat that item as NOT DONE.
```

## Scripts

- `scripts/maintenance/run-maintenance.sh`
- `scripts/maintenance/perms-state.sh`

## Suggested Artifacts

- `reports/maintenance/latest.json`
- `reports/maintenance/<timestamp>.json`
- panic-attacker report under `/tmp` or `reports/security/`
