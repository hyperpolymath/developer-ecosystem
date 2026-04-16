# Proven Repo Integration for UMS Level Validation

SPDX-License-Identifier: PMPL-1.0-or-later

## Overview

This document describes how the `proven` repository's formally verified
modules (SafeJson, SafeMath) integrate with the IDApTIK UMS level
validation pipeline. The goal is crash-free level data ingestion: every
path from raw JSON to a `ValidatedLevel` is total and returns structured
errors instead of throwing exceptions.

## Data Flow

```
  Raw JSON string
       |
       v
  +---------------------+
  | Proven.SafeJson     |   (1) Total JSON parser
  | .Parser.parse       |       Returns Either ParseError JsonValue
  +---------------------+
       |
       v
  +---------------------+
  | ProvenBridge        |   (2) Field extraction & type conversion
  | .extractLevelData   |       Returns Extracted LevelData
  +---------------------+       (accumulates ALL errors, not just first)
       |
       v
  +---------------------+
  | ProvenBridge        |   (3) Decidable cross-domain checks
  | .validateAndReport  |       Returns List String (empty = pass)
  +---------------------+
       |
       v
  +---------------------+
  | Validation          |   (4) Proof-level validation
  | .ValidatedLevel     |       Erased proof witnesses (zero runtime cost)
  +---------------------+
       |
       v
  ValidatedLevel ready for game engine / level architect
```

### Stage 1: JSON Parsing (Proven.SafeJson)

**Module:** `Proven.SafeJson.Parser`
**Function:** `parse : String -> Either ParseError JsonValue`

The proven parser is total by construction:

- Bounded nesting depth (maxDepth = 1000) prevents stack overflow
- All branches return `Either ParseError` -- never throws
- ParseError carries position information for diagnostics
- Handles Unicode escapes, all JSON number formats, escape sequences

**Current status:** ProvenBridge contains a local placeholder parser.
When the proven ipkg dependency is added, the placeholder is replaced
by a single import.

### Stage 2: Field Extraction (ProvenBridge)

**Module:** `ProvenBridge`
**Function:** `parseLevelJson : String -> Either String LevelData`

This stage converts the untyped `JsonValue` tree into the strongly-typed
`LevelData` record. Key design decisions:

- **Error accumulation:** Uses `Extracted a` (Ok a | Errs (List String))
  instead of short-circuiting on the first error. A single parse attempt
  reports every problem in the JSON at once.
- **Enum mapping:** DeviceKind, GuardRank, SecurityLevel etc. are parsed
  from lowercase snake_case strings with exhaustive match arms.
- **Bounded values:** IP octets are validated into `Fin 256`; percentages
  into `Fin 101`. Out-of-range values produce clear error messages.

### Stage 3: Decidable Validation (ProvenBridge)

**Module:** `ProvenBridge`
**Function:** `validateAndReport : LevelData -> List String`

Performs the runtime-decidable subset of the proof-level checks in
`Validation.idr`:

| Check | Validation.idr proof type | validateAndReport equivalent |
|-------|---------------------------|------------------------------|
| Guard zones exist | `GuardsInZones` | `checkGuardZones` |
| Zone transitions monotonic | `ZonesOrdered` | `checkZoneOrder` |
| PBX IP in device registry | `PBXConsistent` | `checkPBX` |
| Defence targets valid | `DefenceTargetsValid` | TODO |
| No duplicate device IPs | (implicit) | `checkDuplicateIPs` |
| No duplicate zone names | (implicit) | `checkDuplicateZoneNames` |

### Stage 4: Proof-Level Validation (Validation.idr)

**Module:** `Validation`
**Type:** `ValidatedLevel`

The `ValidatedLevel` record bundles `LevelData` with erased (0-quantity)
proof witnesses. These proofs are constructed at compile time or via
decision procedures. They have zero runtime cost.

The relationship between stages 3 and 4:

- Stage 3 answers "does this data pass?" (Bool/List String) -- useful for
  error reporting to level designers in the Level Architect UI.
- Stage 4 answers "this data provably passes" (Type) -- useful for the
  game engine, which can assume invariants hold without runtime checks.

## Proven Module Mapping

| Proven module | UMS validation step | Status |
|---------------|---------------------|--------|
| `Proven.SafeJson.Parser` | JSON parsing (stage 1) | Scaffolded (local placeholder) |
| `Proven.SafeJson.Access` | Field extraction helpers (stage 2) | Scaffolded (local jGet/jAsString/etc.) |
| `Proven.SafeJson` (schema validation) | `matchesType` / `JsonType` for schema pre-check | Planned |
| `Proven.SafeMath` (if available) | Bounded arithmetic for Fin 256, Fin 101 | Planned |
| `Proven.Core` | Foundation types | Transitive dependency |

## Integration Plan

### Phase 1: Scaffolding (CURRENT)

- [x] `ProvenBridge.idr` created with local JSON types
- [x] Placeholder parser mirrors proven API
- [x] `parseLevelJson` extracts devices, zones, guards, transitions, PBX
- [x] `validateAndReport` checks guard zones, zone order, PBX, duplicates
- [ ] Remaining extractors: dogs, drones, assassins, items, wiring, mission, physical, defences

### Phase 2: Proven Dependency

- [ ] Add `proven` as a dependency in `idaptik-ums.ipkg` (requires ipkg `depends` field)
- [ ] Replace local `JValue` with `Proven.SafeJson.Parser.JsonValue`
- [ ] Replace `parseJsonString` with `Proven.SafeJson.Parser.parse`
- [ ] Replace local accessors (jGet, jAsString, etc.) with `Proven.SafeJson.Access` functions
- [ ] Use `Proven.SafeJson.matchesType` for schema pre-validation before field extraction

### Phase 3: Proven SafeMath

- [ ] Use proven SafeMath for Fin 256 arithmetic (octet bounds checking)
- [ ] Use proven SafeMath for percentage bounds (Fin 101)
- [ ] Replace cast-based conversions with formally verified alternatives

### Phase 4: Decision Procedures

- [ ] Write `DecEq`-based decision procedures that produce `ValidatedLevel` proof witnesses
- [ ] Bridge: `parseLevelJson` + decision procedures = total pipeline from String to ValidatedLevel
- [ ] Error messages from decision procedure failures feed into `validateAndReport`

## File Locations

| File | Purpose |
|------|---------|
| `idaptik-ums/src/abi/ProvenBridge.idr` | Bridge module (this integration) |
| `idaptik-ums/src/abi/Level.idr` | LevelData record definition |
| `idaptik-ums/src/abi/Validation.idr` | Proof types (ValidatedLevel) |
| `proven/src/Proven/SafeJson.idr` | SafeJson public API |
| `proven/src/Proven/SafeJson/Parser.idr` | Total JSON parser |
| `proven/src/Proven/SafeJson/Access.idr` | Safe JSON accessors and path navigation |

## Notes

- All ProvenBridge code uses `%default total`. No `believe_me`,
  `assert_total`, `sorry`, or `Admitted` are used anywhere.
- The `Extracted` type accumulates errors (like a validation applicative)
  so that level designers see ALL problems at once, not one at a time.
- The local placeholder parser is intentionally simpler than proven's
  (no Unicode \uXXXX escapes, simpler error types). It exists only to
  allow compilation and testing before the proven dependency is wired up.
- Two typed holes (`?missionHole`, `?physicalHole`) remain in
  `parseLevelJson` because `MissionConfig` and `PhysicalConfig` extractors
  are not yet implemented. These will be filled in Phase 1 completion.
