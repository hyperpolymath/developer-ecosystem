<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# Wokelangiser Topology

## Overview

Wokelangiser transforms existing code into consent-aware, accessible, internationalised,
and culturally sensitive software by injecting WokeLang decorator patterns at the source
level. It follows the standard hyperpolymath -iser architecture.

## Data Flow

```
wokelangiser.toml (manifest)
        |
        v
  [Rust CLI] src/main.rs
        |
        +-- manifest/mod.rs (parse & validate TOML)
        |
        +-- codegen/mod.rs (orchestrate generation)
        |       |
        |       +-- Consent point injection (@consent decorators)
        |       +-- Accessibility annotation (@accessible decorators)
        |       +-- I18n hook insertion (@i18n hooks)
        |       +-- Cultural sensitivity marking (@sensitive markers)
        |
        +-- abi/mod.rs (Rust-side ABI interface)
                |
                v
  [Idris2 ABI] src/interface/abi/
        |
        +-- Types.idr
        |     ConsentType (OptIn | OptOut | Withdraw | AuditTrail)
        |     ConsentState (Pending | Granted | Active | Revoked)
        |     ValidTransition (state machine proofs)
        |     WCAGLevel (A | AA | AAA)
        |     AccessibilityAnnotation (ariaLabel, role, focusOrder, contrastRatio)
        |     I18nHook (Locale | RTL | Pluralise | FormatSpec)
        |     CulturalContext (Cultural | Terminology | NamingConvention)
        |     Result (Ok | Error | ... | ConsentRequired | AccessibilityFailed | I18nError)
        |
        +-- Layout.idr
        |     consentRecordLayout (24 bytes, 8-byte aligned)
        |     accessibilityRecordLayout (32 bytes, 8-byte aligned)
        |     i18nRecordLayout (24 bytes, 8-byte aligned)
        |     C-ABI compliance proofs
        |
        +-- Foreign.idr
              FFI declarations for all Zig-implemented functions
              Safe wrappers with Result error handling
                |
                v
  [Zig FFI] src/interface/ffi/
        |
        +-- build.zig (shared + static library build)
        +-- src/main.zig
        |     wokelangiser_init / wokelangiser_free
        |     wokelangiser_inject_consent
        |     wokelangiser_check_consent
        |     wokelangiser_record_consent_transition
        |     wokelangiser_check_accessibility
        |     wokelangiser_annotate_element
        |     wokelangiser_contrast_ratio (WCAG 2.2 algorithm)
        |     wokelangiser_extract_strings
        |     wokelangiser_format_locale
        |     wokelangiser_check_sensitivity
        |     wokelangiser_suggest_alternative
        |
        +-- test/integration_test.zig
              Lifecycle, consent, accessibility, i18n, sensitivity, memory safety tests
                |
                v
  [Generated] src/interface/generated/abi/
        C headers auto-generated from Zig exports
```

## Module Dependency Graph

```
Wokelangiser.ABI.Types
    ^           ^
    |           |
Wokelangiser.ABI.Layout    Wokelangiser.ABI.Foreign
                                    |
                                    v
                            libwokelangiser (Zig)
                                    |
                                    v
                            wokelangiser (Rust CLI)
```

## Key Struct Layouts (FFI Boundary)

| Struct                | Size | Align | Fields                                          |
|-----------------------|------|-------|-------------------------------------------------|
| ConsentRecord         | 24B  | 8     | consent_type(u32), state(u32), timestamp(u64), subject_id(u64) |
| AccessibilityRecord   | 32B  | 8     | wcag_level(u32), focus_order(u32), contrast_ratio(u32), _pad(u32), aria_label_ptr(u64), role_ptr(u64) |
| I18nRecord            | 24B  | 8     | hook_type(u32), format_kind(u32), locale_tag_ptr(u64), source_ptr(u64) |

## Consent State Machine

```
  Pending --GrantConsent--> Granted --ActivateConsent--> Active --RevokeActive--> Revoked
                               |                                                    ^
                               +----------RevokeGranted-----------------------------+
```

All transitions are encoded as `ValidTransition` proofs in `Types.idr`.
Invalid transitions (e.g. Pending -> Active, Revoked -> anything) are
rejected at the type level.

## WCAG Contrast Thresholds

| Level | Minimum Ratio | Encoded Value |
|-------|---------------|---------------|
| A     | none          | 0             |
| AA    | 4.5:1         | 450           |
| AAA   | 7.0:1         | 700           |

Contrast ratio calculated using WCAG 2.2 relative luminance algorithm
(sRGB linearisation + weighted sum) in `wokelangiser_contrast_ratio`.

## Integration Points

| System       | Role                                              |
|--------------|---------------------------------------------------|
| iseriser     | Meta-framework that generated this scaffold        |
| proven       | Shared Idris2 verified library (consent proofs)    |
| PanLL        | Consent dashboard + accessibility audit panels     |
| BoJ-server   | Cartridge for automated accessibility scanning     |
| VeriSimDB    | Consent audit trail persistence                    |
| WokeLang     | Source language in nextgen-languages monorepo       |
