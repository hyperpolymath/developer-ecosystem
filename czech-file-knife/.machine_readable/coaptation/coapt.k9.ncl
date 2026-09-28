K9!
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# coapt.k9.ncl — k9 contract for the coaptation receipt's drift check.
#
# Yard-tier (pure evaluation / comparison; no network, no FS write): the check
# regenerates the coaptation receipt from this repo's contractiles (normative
# set-point) and descriptiles (descriptive self-model) and asserts the committed
# receipt byte-matches it. The runnable side is verify.sh; the writer (Hunt-tier,
# leashed) is coapt.sh. This record documents and validates the contract shape and
# sits alongside arrival-pack/claude-md.k9.ncl as its architectural sibling.
{
  pedigree = {
    schema_version = "1.0.0",
    contractile_verb = "trust",   # provenance: the reading must equal its sources
    semantics = "coaptation-fidelity",
    security = {
      leash = 'Yard,
      trust_level = "read-only comparison",
      allow_network = false,
      allow_filesystem_write = false,
      allow_subprocess = true,    # runs the extractors + nickel to reproduce the reading
    },
    metadata = {
      name = "coaptation",
      version = "0.1.0",
      description = "The committed coaptation receipt is a faithful, current reading of this repo's contractiles vs descriptiles.",
      paired_runner = "verify.sh",
      writer = "coapt.sh",
      author = "Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>",
    },
  },

  # Inputs the reading reads (the two sides of the face-off + the knowledge layer).
  inputs = {
    contractiles = [
      ".machine_readable/contractiles/intend/Intentfile.a2ml",
      ".machine_readable/contractiles/must/Mustfile.a2ml",
      ".machine_readable/contractiles/trust/Trustfile.a2ml",
      ".machine_readable/contractiles/adjust/Adjustfile.a2ml",
      ".machine_readable/contractiles/dust/Dustfile.a2ml",
      ".machine_readable/contractiles/bust/Bustfile.a2ml",
    ],
    descriptiles = [
      ".machine_readable/descriptiles/CLADE.a2ml",
      ".machine_readable/descriptiles/STATE.a2ml",
      ".machine_readable/descriptiles/ECOSYSTEM.a2ml",
      ".machine_readable/descriptiles/AGENTIC.a2ml",
      ".machine_readable/descriptiles/anchors/ANCHOR.a2ml",
    ],
    witness_map = ".machine_readable/coaptation/witness-map.ncl",
    grades = ".machine_readable/coaptation/grades.ncl",
    comparator = ".machine_readable/coaptation/coapt.ncl",
    target = ".machine_readable/coaptation/receipts/latest.a2ml",
  },

  # Checks (all must hold).
  checks = [
    { id = "clauses-atomise", desc = "every Xfile ###/#### clause lifts to a stable id verb.slug" },
    { id = "facts-extract",   desc = "every descriptile fact lifts to a stable id family.key" },
    { id = "coverage-total",  desc = "every clause is witnessed, refuted, probe-deferred, expected, or an explicit gap (Coverage is total)" },
    { id = "no-drift",        desc = "committed receipt byte-equals a freshly generated receipt" },
  ],

  run = {
    on_any_fail = "exit-nonzero",   # gate (trust-tier): drift blocks
    command = "bash .machine_readable/coaptation/verify.sh",
  },
}
