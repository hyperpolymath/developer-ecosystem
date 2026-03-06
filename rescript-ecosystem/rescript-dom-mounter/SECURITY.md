# Security Policy

We take security seriously. We appreciate your efforts to responsibly disclose vulnerabilities and will make every effort to acknowledge your contributions.

## Table of Contents

- [Reporting a Vulnerability](#reporting-a-vulnerability)
- [Formal Verification Guarantees](#formal-verification-guarantees)
- [Cryptographic Requirements](#cryptographic-requirements)
- [Response Timeline](#response-timeline)
- [Disclosure Policy](#disclosure-policy)
- [Scope](#scope)
- [Security Updates](#security-updates)

---

## Reporting a Vulnerability

### Preferred Method: GitHub Security Advisories

1. Navigate to [Report a Vulnerability](https://github.com/hyperpolymath/rescript-dom-mounter/security/advisories/new)
2. Complete the form with as much detail as possible
3. Submit — we'll receive a private notification

### Alternative: Email

**Email:** jonathan.jewell@open.ac.uk

> **⚠️ Important:** Do not report security vulnerabilities through public GitHub issues.

---

## Formal Verification Guarantees

This library provides **compile-time mathematical proofs** of safety properties using Idris2 dependent types. These are not runtime checks—they are **formal guarantees** proven at compile time:

### Proven Properties

1. **No Null Pointer Dereferences**
   - DOM elements proven non-null at type level
   - Impossible to construct `DOMElement` with null pointer
   - Type: `DOMElement : Type where MkDOMElement : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> DOMElement`

2. **No Invalid Selectors**
   - CSS selectors proven 1-255 characters
   - Compile-time bounds checking via dependent types
   - Type: `ValidatedSelector` with proven `InBounds length 1 255`

3. **No Malformed HTML**
   - HTML content proven 0-1MB (no DoS)
   - Balanced tag verification
   - Type: `ValidatedHTML` with proven `InBounds length 0 1048576`

4. **Memory Layout Correctness**
   - Platform-specific struct layouts proven correct
   - Alignment and padding verified at compile-time
   - Cross-platform C ABI compatibility guaranteed

### Defense in Depth

Even with formal verification, we apply multiple security layers:

1. **Idris2 Proofs** - Mathematical guarantees at ABI layer
2. **Zig Validation** - Runtime validation in FFI layer
3. **ReScript Types** - Type safety at application layer
4. **Bounded Operations** - Size limits prevent resource exhaustion
5. **Error Propagation** - No silent failures

### Security Through Formal Methods

If you discover a way to violate these proven properties, **this is a critical vulnerability**. It would indicate:

- A soundness bug in the Idris2 type system
- A bug in our proof encoding
- An ABI mismatch between Idris2 and Zig layers

Such findings are extremely valuable and will be prioritized immediately.

---

## Cryptographic Requirements

When implementing cryptographic features (if extended beyond DOM mounting):

### Core Requirements
- **Password Hashing:** Argon2id (512 MiB, 8 iter, 4 lanes)
- **General Hashing:** SHAKE3-512 (FIPS 202) - post-quantum
- **PQ Signatures:** Dilithium5-AES hybrid (ML-DSA-87, FIPS 204)
- **PQ Key Exchange:** Kyber-1024 + SHAKE256-KDF (ML-KEM-1024, FIPS 203)
- **Classical Signatures:** Ed448 + Dilithium5 hybrid
- **Symmetric:** XChaCha20-Poly1305 (256-bit key)
- **Key Derivation:** HKDF-SHAKE512 (FIPS 202)
- **RNG:** ChaCha20-DRBG (512-bit seed, SP 800-90Ar1)
- **Formal Verification:** Idris2 proofs REQUIRED for all crypto primitives
- **Fallback:** SPHINCS+ for all hybrid systems

### ⚠️ TERMINATED Algorithms
- **Ed25519** - replaced by Ed448
- **SHA-1** - replaced by SHAKE3-512
- **MD5** - never use
- **HTTP/1.1, IPv4** - use QUIC + HTTP/3 + IPv6 only

---

## Response Timeline

| Stage | Timeframe |
|-------|-----------|
| **Initial Response** | 48 hours |
| **Triage** | 7 days |
| **Resolution** | 90 days |
| **Disclosure** | 90 days (coordinated) |

---

## Disclosure Policy

We follow **coordinated disclosure**:

1. Report privately
2. We acknowledge and investigate
3. We develop a fix
4. We coordinate disclosure timing
5. Public disclosure with fix

---

## Scope

### In Scope ✅

- All code in `hyperpolymath/rescript-dom-mounter`
- ReScript API layer (`src/SafeDOM.res`)
- Idris2 ABI layer (`src/abi/*.idr`)
- Zig FFI layer (`ffi/zig/src/*.zig`)
- Formal proofs and type safety guarantees
- Build and deployment configurations

### Particularly Interested In

- **Proof soundness bugs** - Ways to violate proven properties
- **ABI/FFI mismatches** - Discrepancies between Idris2 and Zig layers
- **Memory safety issues** - Buffer overflows, use-after-free
- **Type system exploits** - Ways to bypass type safety
- **Cryptographic weaknesses** (if crypto features added)
- **Supply chain vulnerabilities**

### Out of Scope ❌

- Third-party dependencies (report to upstream)
- Social engineering
- Physical security
- DoS against production infrastructure
- Theoretical vulnerabilities without proof of concept

---

## Security Updates

### Receiving Updates

- **Watch this repository** for security alerts
- **GitHub Security Advisories:** [rescript-dom-mounter/security/advisories](https://github.com/hyperpolymath/rescript-dom-mounter/security/advisories)

### Supported Versions

| Version | Supported |
|---------|-----------|
| `main` branch | ✅ Yes |
| Latest release (v1.0+) | ✅ Yes |
| Older versions | ❌ No - please upgrade |

---

## Security Best Practices

### For Users

- Always use the latest stable release
- Verify Idris2 proofs compile (`idris2 --typecheck src/abi/SafeDOM.idr`)
- Keep dependencies up to date
- Subscribe to security notifications

### For Contributors

- Never commit secrets or credentials
- Use signed commits (`git config commit.gpgsign true`)
- Run `idris2 --typecheck` before submitting PRs
- Add proofs for new safety properties
- Document proof obligations in code comments
- Never bypass type safety with `believe_me` unless absolutely necessary and well-documented
- **All crypto code MUST have Idris2 proofs**

---

*Thank you for helping keep rescript-dom-mounter and its users safe through formal verification.* 🛡️

---

<sub>Last updated: 2026-02-04 · Policy version: 2.0.0</sub>
