// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
// SafeDOM.res — Public API surface for rescript-dom-mounter.
//
// This module re-exports the high-assurance core living under src/Core/SafeDOMCore.res.
// Application code should import SafeDOM rather than SafeDOMCore directly, so that
// internal restructuring of the core does not break downstream consumers.
//
// The module exposes:
//   - Type aliases (mountResult, mountSpec) for pattern matching in application code
//   - Sub-modules (MountTracer, ProvenSelector, ProvenHTML) for direct access
//   - All mounting functions (mount, mountString, mountSafe, mountBatch)
//   - Lifecycle functions (unmount, remount, onDOMReady, mountWhenReady)
//   - CSP-aware mounting (mountWithNonce)
//   - DOM query helper (findMountPoint)

module SafeDOMCore = SafeDOMCore

type mountResult = SafeDOMCore.mountResult

type mountSpec = SafeDOMCore.mountSpec

module MountTracer = SafeDOMCore.MountTracer
module ProvenSelector = SafeDOMCore.ProvenSelector
module ProvenHTML = SafeDOMCore.ProvenHTML

let findMountPoint = SafeDOMCore.findMountPoint

let mount = SafeDOMCore.mount

let mountString = SafeDOMCore.mountString

let mountSafe = SafeDOMCore.mountSafe

let mountBatch = SafeDOMCore.mountBatch

let onDOMReady = SafeDOMCore.onDOMReady

let mountWhenReady = SafeDOMCore.mountWhenReady

// Lifecycle: remove mounted content and update in place
let unmount = SafeDOMCore.unmount

let remount = SafeDOMCore.remount

// CSP-compliant mounting with nonce injection
let mountWithNonce = SafeDOMCore.mountWithNonce
