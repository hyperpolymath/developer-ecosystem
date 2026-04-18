;; SPDX-License-Identifier: AGPL-3.0-or-later
;; META.scm - Architectural decisions and project meta-information
;; Media-Type: application/meta+scheme

(define-meta cadre-router
  (version "1.0.0")

  (architecture-decisions
    ;; ADR format: (adr-NNN status date context decision consequences)
    ((adr-001 accepted "2026-01-30"
      "Need to establish repository structure and standards"
      "Adopt RSR (Rhodium Standard Repository) conventions from rsr-template-repo"
      "Ensures consistency with 500+ repos in hyperpolymath ecosystem. "
      "Enables automated quality enforcement via gitbot-fleet and Hypatia.")))

  (development-practices
    (code-style
      "Follow hyperpolymath language policy: "
      "Prefer ReScript, Rust, Gleam, Elixir. "
      "Avoid TypeScript, Go, Python per RSR.")
    (security
      "All commits signed. "
      "Hypatia neurosymbolic scanning enabled. "
      "OpenSSF Scorecard tracking."

      ;; Cryptographic Requirements (for future crypto features if needed)
      "password-hashing: Argon2id (512 MiB, 8 iter, 4 lanes) - max resistance to GPU/ASIC attacks"
      "general-hashing: SHAKE3-512 (512-bit output, FIPS 202) - post-quantum for provenance/key derivation"
      "pq-signatures: Dilithium5-AES hybrid (ML-DSA-87, FIPS 204) with SPHINCS+ backup"
      "pq-key-exchange: Kyber-1024 + SHAKE256-KDF (ML-KEM-1024, FIPS 203)"
      "classical-sigs: Ed448 + Dilithium5 hybrid - TERMINATE Ed25519/SHA-1 immediately"
      "symmetric: XChaCha20-Poly1305 (256-bit key) - larger nonce space for quantum margin"
      "key-derivation: HKDF-SHAKE512 (FIPS 202) - post-quantum KDF for all secret material"
      "rng: ChaCha20-DRBG (512-bit seed, SP 800-90Ar1) - CSPRNG for high-entropy needs"
      "database-hashing: BLAKE3 (512-bit) + SHAKE3-512 - speed + long-term storage"
      "formal-verification: Idris2 for safety-critical paths - proofs where appropriate"
      "protocol-stack: QUIC + HTTP/3 + IPv6 ONLY - terminate HTTP/1.1, IPv4, SHA-1"
      "fallback: SPHINCS+ as conservative PQ backup for all hybrid systems")
    (testing
      "Comprehensive test coverage required. "
      "CI/CD runs on all pushes.")
    (versioning
      "Semantic versioning (semver). "
      "Changelog maintained in CHANGELOG.md.")
    (documentation
      "README.adoc for overview. "
      "STATE.scm for current state. "
      "ECOSYSTEM.scm for relationships.")
    (branching
      "Main branch protected. "
      "Feature branches for new work. "
      "PRs required for merges."))

  (design-rationale
    (why-rsr
      "RSR provides standardized structure across 500+ repos, "
      "enabling automated tooling and consistent developer experience.")
    (why-hypatia
      "Neurosymbolic security scanning combines neural pattern recognition "
      "with symbolic reasoning for fast, deterministic security checks.")))
