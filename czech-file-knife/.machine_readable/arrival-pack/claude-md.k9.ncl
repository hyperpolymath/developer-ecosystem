K9!
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# claude-md.k9.ncl — k9 contract for the CLAUDE.md arrival-pack drift check.
#
# Yard-tier (pure evaluation / comparison; no exec, no network, no FS write):
# the check regenerates the arrival-pack region from this repo's a2ml and asserts
# the committed CLAUDE.md region byte-matches it. The runnable side is verify.sh;
# writing (Hunt-tier) is generate.sh. This record documents and validates the
# contract shape.
{
  pedigree = {
    schema_version = "1.0.0",
    contractile_verb = "trust",   # provenance: the view must equal its source
    semantics = "projection-fidelity",
    security = {
      leash = 'Yard,
      trust_level = "read-only comparison",
      allow_network = false,
      allow_filesystem_write = false,
      allow_subprocess = true,    # runs extract.sh + nickel to reproduce the view
    },
    metadata = {
      name = "claude-md-arrival-pack",
      version = "1.0.0",
      description = "CLAUDE.md arrival pack is a faithful projection of this repo's a2ml.",
      paired_runner = "verify.sh",
      writer = "generate.sh",
      author = "Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>",
    },
  },

  # Inputs the projection reads (single source of truth).
  inputs = {
    descriptiles = [
      ".machine_readable/descriptiles/CLADE.a2ml",
      ".machine_readable/descriptiles/ECOSYSTEM.a2ml",
      ".machine_readable/descriptiles/AGENTIC.a2ml",
      ".machine_readable/descriptiles/STATE.a2ml",
      ".machine_readable/descriptiles/anchors/ANCHOR.a2ml",
    ],
    estate_common = "hyperpolymath/manifesto@<pinned-sha>",  # DRAFT-unratified today
    target = "CLAUDE.md",
    markers = { begin = "<!-- ARRIVAL-PACK:BEGIN", end = "ARRIVAL-PACK:END" },
  },

  # Checks (all must hold).
  checks = [
    { id = "inputs-exist",   desc = "every descriptiles input file exists and parses" },
    { id = "region-present", desc = "CLAUDE.md contains exactly one BEGIN/END region" },
    { id = "no-drift",       desc = "committed region byte-equals freshly generated region" },
  ],

  run = {
    on_any_fail = "exit-nonzero",   # gate (trust-tier): drift blocks
    command = "bash .machine_readable/arrival-pack/verify.sh",
  },
}
