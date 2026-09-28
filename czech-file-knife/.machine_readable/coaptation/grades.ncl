# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# grades.ncl — grade types per verb + aggregation tolerances (step 3).
#
# The face-off is graded PER VERB, not as one Boolean (that is the design point):
#
#   must   — boolean_gate            : every witnessed obligation must hold; a
#                                      refuted or unmeasured Must is a hard fail.
#   trust  — boolean_gate_provenance : as must, and the witness carries provenance
#                                      (the content hash of the descriptile source).
#   adjust — posture                 : graded fraction in [0,1]; ADVISORY, never a
#                                      hard gate (accessibility / inclusive design).
#   intend — tropical                : min-plus distance-to-north-star = number of
#                                      committed intents not yet `done`. Wishes
#                                      (horizon aspirations) do NOT count as drift.
#   bust   — alarm                   : a recognised break; alarms iff its witness
#                                      shows the failure is ACTIVE (not just declared).
#   dust   — expected                : planned exnovation; reported, never alarms.
#
# Aggregate band (the "how far is too far" judged against Intend/Must/Trust):
#   red    — any Must/Trust refuted or unmeasured, OR any Bust alarm.
#   amber  — adjust posture below floor, OR intend distance over tolerance.
#   green  — none of the above.
#
# Bands map to proposed actions in the receipt; the re-anchor DROP itself is always
# a human authority act (see coapt.sh --reanchor).
{
  verb_grade = {
    must = "boolean_gate",
    trust = "boolean_gate_provenance",
    adjust = "posture",
    intend = "tropical",
    bust = "alarm",
    dust = "expected",
  },

  tolerances = {
    # intend tropical distance: > this many unmet committed intents ⇒ amber.
    intend_max_distance = 2,
    # adjust posture floor: witnessed-fraction < this ⇒ amber (expressed as a
    # 2*sat >= tot integer test in the comparator to avoid float formatting).
    adjust_min_posture_pct = 50,
  },
}
