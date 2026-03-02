# Security Policy

We take security seriously. We appreciate your efforts to responsibly disclose vulnerabilities and will make every effort to acknowledge your contributions.

## Table of Contents

- [Reporting a Vulnerability](#reporting-a-vulnerability)
- [Type Safety Guarantees](#type-safety-guarantees)
- [Cryptographic Requirements](#cryptographic-requirements)
- [Response Timeline](#response-timeline)
- [Scope](#scope)
- [Security Updates](#security-updates)

---

## Reporting a Vulnerability

### Preferred Method: GitHub Security Advisories

1. Navigate to [Report a Vulnerability](https://github.com/hyperpolymath/cadre-router/security/advisories/new)
2. Complete the form with as much detail as possible
3. Submit — we'll receive a private notification

### Alternative: Email

**Email:** jonathan.jewell@open.ac.uk

> **⚠️ Important:** Do not report security vulnerabilities through public GitHub issues.

---

## Type Safety Guarantees

This library provides **compile-time type safety** for routing through ReScript's type system:

### Built-in Security Properties

1. **No Route Injection**
   - Routes are variants, not strings
   - Impossible to inject malicious content
   - Parser combinators validate all inputs

2. **No XSS via Routes**
   - Route parameters are typed (e.g., `JourneyId.t` not `string`)
   - Invalid IDs rejected during parsing, not in application code
   - No string concatenation for URL construction

3. **Exhaustive Pattern Matching**
   - Compiler enforces handling of all route cases
   - Prevents undefined behavior from missing routes
   - Type-safe navigation between routes

4. **URL Validation**
   - Path segments validated by parser combinators
   - Query parameters type-checked
   - No unvalidated user input in routing logic

### Defense in Depth

1. **ReScript Types** - Compile-time route validation
2. **Parser Combinators** - Structured input validation
3. **Variant Routes** - Impossible to construct invalid routes
4. **Type-Safe Parameters** - No string-based route parameters

---

## Cryptographic Requirements

When implementing cryptographic features (e.g., signed routes, auth tokens in URLs):

### Core Requirements
- **Password Hashing:** Argon2id (512 MiB, 8 iter, 4 lanes)
- **General Hashing:** SHAKE3-512 (FIPS 202) - post-quantum
- **PQ Signatures:** Dilithium5-AES hybrid (ML-DSA-87, FIPS 204)
- **PQ Key Exchange:** Kyber-1024 + SHAKE256-KDF (ML-KEM-1024, FIPS 203)
- **Classical Signatures:** Ed448 + Dilithium5 hybrid
- **Symmetric:** XChaCha20-Poly1305 (256-bit key)
- **Key Derivation:** HKDF-SHAKE512 (FIPS 202)
- **RNG:** ChaCha20-DRBG (512-bit seed, SP 800-90Ar1)
- **Database Hashing:** BLAKE3 (512-bit) + SHAKE3-512
- **Formal Verification:** Idris2 proofs for safety-critical paths
- **Protocol Stack:** QUIC + HTTP/3 + IPv6 ONLY
- **Fallback:** SPHINCS+ for all hybrid systems

### ⚠️ TERMINATED Algorithms
- **Ed25519** - replaced by Ed448
- **SHA-1** - replaced by SHAKE3-512
- **MD5** - never use
- **HTTP/1.1, IPv4** - use QUIC + HTTP/3 + IPv6 only

### User-Friendly Hash Names
- **Algorithm:** Base32(SHAKE256(hash)) → Wordlist
- **Use Case:** Memorable route IDs (e.g., "Gigantic-Giraffe-7" for journey IDs)
- **Benefits:** User-friendly, deterministic, collision-resistant

---

## Response Timeline

| Stage | Timeframe |
|-------|-----------|
| **Initial Response** | 48 hours |
| **Triage** | 7 days |
| **Resolution** | 90 days |
| **Disclosure** | 90 days (coordinated) |

---

## Scope

### In Scope ✅

- All code in `hyperpolymath/cadre-router`
- Client-side routing modules (`src/client/*.res`)
- TEA integration modules (`src/tea/*.res`)
- Parser combinators and URL handling
- Type safety guarantees
- Build and deployment configurations

### Particularly Interested In

- **Type safety bypasses** - Ways to construct invalid routes
- **Route injection** - XSS or injection via route parameters
- **Parser vulnerabilities** - Malformed URLs causing crashes
- **Navigation hijacking** - Unauthorized route changes
- **Cryptographic weaknesses** (if crypto features added)
- **TEA subscription leaks** - Memory leaks in URL change subscriptions

### Out of Scope ❌

- Third-party dependencies (report to upstream)
- Social engineering
- DoS against production infrastructure
- Theoretical vulnerabilities without proof of concept

---

## Security Updates

### Receiving Updates

- **Watch this repository** for security alerts
- **GitHub Security Advisories:** [cadre-router/security/advisories](https://github.com/hyperpolymath/cadre-router/security/advisories)

### Supported Versions

| Version | Supported |
|---------|-----------|
| `main` branch | ✅ Yes |
| Latest release | ✅ Yes |
| Previous minor release | ✅ Yes (security fixes backported) |
| Older versions | ❌ No - please upgrade |

---

## Security Best Practices

### For Users

- Always use typed route parameters (e.g., `JourneyId.t`)
- Validate route data at parse time, not in application code
- Use parser combinators instead of string manipulation
- Keep dependencies up to date

### For Contributors

- Never commit secrets or credentials
- Use signed commits (`git config commit.gpgsign true`)
- Maintain exhaustive pattern matching for all route variants
- Add parser tests for new route types
- Document security considerations for new features
- **Never use string concatenation for URL construction**
- **All crypto code MUST follow the cryptographic requirements above**

---

*Thank you for helping keep cadre-router and its users safe through type safety.* 🛡️

---

<sub>Last updated: 2026-02-04 · Policy version: 2.0.0</sub>
