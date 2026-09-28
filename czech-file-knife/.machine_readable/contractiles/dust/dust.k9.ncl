K9!
# SPDX-License-Identifier: MPL-2.0
# dust.k9.ncl — K9 trust-tier component of the dust trident
# Author: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# Pairs with: Dustfile.a2ml (declaration) + dust.ncl (runner).
#
# Verb:       dust            (rollback / recovery / deprecation)
# Tier:       Yard            (audit + structural checks; destructive
#                              actions gated behind --apply flag +
#                              explicit per-item approval)
# Authority:  advisory        (continue-with-warnings)
#
# dust is the retirement + audit-trail verb. Rollback paths, deprecation
# markers, evidence-preservation semantics. Where bust declares
# "broken, don't run", dust declares "how to safely undo / retire / roll
# back". Complement to bust — bust marks the dead end, dust describes
# the exit ramp.
#
# Cardinality: ONE dust trident per repo.
#
# Failure-mode focus: dust is the audit-trail preservation verb —
# defends against E1 refactor stampede (check audit trail still
# intact) and against silent removal (anything removed must have a
# rollback path; anything retired must preserve the evidence of its
# previous existence).

let base_k9 = import "../k9/template-hunt.k9.ncl" in
let base    = import "../_base.ncl" in

{
  pedigree = base_k9.pedigree_schema & {
    contractile_verb = "dust",
    paired_xfile     = "../dust/Dustfile.a2ml",
    paired_runner    = "../dust/dust.ncl",

    tier      = 'Yard,
    authority = 'advisory,

    metadata = {
      name = "dust-k9",
      version = "1.0.0",
      description = "Rollback + deprecation + audit-trail runner. Sixth trident instance — completes the full verb set.",
      paired_xfile = "Dustfile.a2ml",
      paired_runner = "dust.ncl",
      author = "Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>",
    },

    security = {
      leash = 'Yard,
      trust_level = "audit-trail verification + structural checks",
      allow_network = false,
      # dust is the verb that ACTUALLY wants filesystem write — to
      # execute declared rollback/removal — but only behind explicit
      # --apply flag + per-item approval. Default is dry-run.
      allow_filesystem_write_conditional = true,
      allow_subprocess = true,
      destructive_action_gating = {
        default_mode = 'dry_run,
        requires_flag = "--apply",
        requires_per_item_approval = true,
        approval_mechanism = 'explicit_user_signature,
      },
    },
  },

  variance_schema = {
    entry_id     | String,
    reason       | String,
    approved_by  | String,
    scope        | String,
    expires      | String,
    review_notes | String | optional,
    rollback_path_preserved | Bool,    # dust-specific: did the variance preserve rollback?
  },

  execution = {
    triggers = [ 'session_close, 'on_demand ],

    per_retirement = {
      verify_rollback_path_documented = true,
      verify_audit_trail_preserved = true,
      respect_variance = true,
      on_rollback_path_missing = 'warn,          # advisory, not block
      on_audit_trail_broken = 'warn,             # advisory, not block
      # dust-specific: flag any retirement that has been requested but
      # lacks proper rollback documentation
      flag_unsafe_retirement = true,
    },

    evidence_sinks = [
      { kind = 'verisimdb, table = "contractile_executions",
        schema = "contractile_execution_v1",
        aux_tables = [ "dust_retirement_history" ] },
      { kind = 'drift_log, path = ".machine_readable/descriptiles/DRIFT.a2ml",
        append_only = true },
    ],

    on_close = {
      re_verify_all_retirement_paths = true,
      diff_against_last_ratification = true,
      emit_drift_entries_for_missing_rollback = true,
      emit_drift_entries_for_broken_audit_trail = true,
      surface_expired_variances = true,
      block_session_close_on_any_drift = false,   # advisory
    },

    on_open = {
      render_summary = 'plain_language,
      include_drift_log_from_last_close = true,
      include_active_variances = true,
      include_recent_anchors = true,
      anchor_lookback_weeks = 8,

      negotiation = {
        required = true,
        ai_required_inputs = [
          'timeline_realism,
          'industry_standards,
          'audience_feasibility,
          'resulting_invariants,
          'ecosystem_dependencies,
        ],
        user_engagement_required = true,
        user_engagement_mode = 'per_input_response,
        specification_translation = {
          ai_produces_spec_form = true,
          user_reviews_in_domain_language = true,
          schema_authoring_is_ai_responsibility = true,
          translation_faithfulness_auditable = true,
        },
      },

      accountability_pledge = {
        required = true,
        parties = [
          {
            role = 'user,
            pledge = "I have reviewed the declared rollback paths and deprecation markers. I accept accountability for preserving audit trails when retiring code, and for ensuring every retired capability has a documented rollback path. I will not silently delete evidence of prior state.",
            signature_required = true,
          },
          {
            role = 'ai_agent,
            pledge = "I will verify audit-trail preservation in any retirement / rollback / deprecation I perform; I will refuse silent deletion of prior-state evidence; I will require rollback-path documentation before accepting a retirement request; I will operate in dry-run mode by default and require explicit --apply + per-item approval for destructive actions.",
            signature_required = true,
          },
        ],
        signed_record_destination = ".machine_readable/descriptiles/ratification-<session-id>.a2ml",
        must_precede_work = true,
      },

      ratification_record_shape = {
        includes_negotiation_transcript = true,
        includes_both_pledges = true,
        includes_retirement_schedule = true,
        signed = true,
        dated = true,
        session_id = 'required,
        contract_hash = 'required,
      },
    },
  },

  failure_mode_defenses = [
    'A1_enthusiasm_capture,
    'C2_capability_collapse,        # retirement without rollback path = capability collapse
    'D5_sycophancy,                 # AI won't agree to silent deletion
    'E1_refactor_stampede,          # audit trail preservation check
    'E2_cosmetic_churn,
    'F1_across_session_forgetting,  # retirement history tracked cross-session
  ],
}
