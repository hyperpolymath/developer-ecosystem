K9!
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
# minimal — the smallest valid K9 contract. Conformance fixture: every
# implementation must evaluate this and project it to expected.json.

{
  pedigree = {
    schema_version = "1.0.0",
    security_level = 'Kennel,

    # L1 — The Snout: identity
    metadata = {
      name = "hello-svc",
      version = "0.1.0",
      breed = "application/vnd.k9+nickel",
      magic_number = "K9!",
      license = "MPL-2.0",
    },

    # L3 — The Leash: security posture
    security = {
      trust_level = 'Kennel,
      allow_network = false,
      allow_subprocess = false,
    },

    # L5 — The Muscle: recipes
    recipes = {
      build = "cargo build --release",
    },
  },
}
