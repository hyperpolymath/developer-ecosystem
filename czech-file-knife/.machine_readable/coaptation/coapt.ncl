# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# coapt.ncl — the Yard-tier COMPARATOR of Coaptation (build-path step 4).
#
# Pure evaluation, no side effects (k9 'Yard): imports the atomised clauses
# (normative obligations) and facts (descriptive evidence), runs the witness map
# (Coverage), grades per verb, aggregates to a band, and renders the coaptation
# receipt as deterministic a2ml text (exported with `nickel export --format raw`).
#
# This is the Nickel prototype of the comparator. The dependent-typed sound core
# (Idris2 `Witnesses`/`Coverage`, where an unwitnessed Must is a COMPILE-TIME
# error) is build-path step 6 — see core/Coaptation.idr (skeleton). The Nickel and
# Idris2 readings must agree once the core is wired; today the Nickel reading is
# authoritative and the core is a forward declaration of its types.
let clauses_doc = import "clauses.json" in
let facts_doc = import "facts.json" in
let wmap = import "witness-map.ncl" in
let grades = import "grades.ncl" in

let clauses = clauses_doc.clauses in
let facts = facts_doc.facts in

# --- fact lookup table -------------------------------------------------------
let facts_by_id = std.array.fold_left (fun acc f => acc & { "%{f.id}" = f }) {} facts in
let lookup = fun id =>
  if std.record.has_field id facts_by_id then
    facts_by_id."%{id}"
  else
    { id = id, value = "", present = false }
in

# --- predicate evaluation (does a single witness hold?) ----------------------
let eval_w = fun w =>
  let f = lookup w.fact in
  let arg = if std.record.has_field "arg" w then w.arg else "" in
  w.op
  |> match {
    'present => f.present,
    'absent => !f.present,
    'zero => f.value == "0",
    'nonzero => f.present && f.value != "0",
    'equals => f.value == arg,
    'contains => std.string.contains arg f.value,
    'not_contains => !(std.string.contains arg f.value),
  }
in

# --- per-clause evaluation (Coverage) ----------------------------------------
let evals =
  std.array.map
    (fun c =>
      let mapped = std.record.has_field c.id wmap in
      let entry = if mapped then wmap."%{c.id}" else { kind = "auto", witnesses = [] } in
      let base_kind =
        if entry.kind != "auto" then
          entry.kind
        else if c.has_probe then
          "probe"
        else
          "unmeasured"
      in
      let sat =
        if base_kind == "descriptile" then
          std.array.all eval_w entry.witnesses
        else
          false
      in
      let st =
        if c.verb == "bust" then
          (if base_kind == "descriptile" && sat then "alarm" else "latent")
        else if c.verb == "dust" then
          "expected"
        else if c.verb == "intend" then
          (if c.is_wish then "wish:" ++ c.status else "intent:" ++ c.status)
        else if base_kind == "descriptile" then
          (if sat then "witnessed" else "refuted")
        else if base_kind == "none" then
          "gap"
        else if base_kind == "probe" then
          "probe-deferred"
        else
          "unmeasured"
      in
      { id = c.id, verb = c.verb, status = st, kind = base_kind, wsat = sat, c_status = c.status, is_wish = c.is_wish }
    )
    clauses
in

# --- rollups -----------------------------------------------------------------
let count = fun pred arr => std.array.length (std.array.filter pred arr) in
let by_verb = fun v => std.array.filter (fun e => e.verb == v) evals in

let mt = std.array.filter (fun e => e.verb == "must" || e.verb == "trust") evals in
let refuted_hard = count (fun e => e.status == "refuted") mt in
let gap_hard = count (fun e => e.status == "gap" || e.status == "unmeasured") mt in
let witnessed_mt = count (fun e => e.status == "witnessed") mt in
let probe_mt = count (fun e => e.status == "probe-deferred") mt in
let mt_gate = if refuted_hard > 0 || gap_hard > 0 then "fail" else "pass" in

let bust_alarms = count (fun e => e.status == "alarm") (by_verb "bust") in

let adj_desc = std.array.filter (fun e => e.kind == "descriptile") (by_verb "adjust") in
let adj_tot = std.array.length adj_desc in
let adj_sat = count (fun e => e.wsat) adj_desc in
let posture_ok = adj_tot == 0 || adj_sat * 100 >= adj_tot * grades.tolerances.adjust_min_posture_pct in

let intents = std.array.filter (fun e => e.verb == "intend" && !e.is_wish) evals in
let intend_distance = count (fun e => e.c_status != "done") intents in
let intend_ok = intend_distance <= grades.tolerances.intend_max_distance in

let dust_n = std.array.length (by_verb "dust") in

let descriptile_witnessed = count (fun e => e.status == "witnessed") evals in
let probe_deferred = count (fun e => e.status == "probe-deferred") evals in

# --- aggregate band (the "how far is too far") -------------------------------
let red = refuted_hard > 0 || gap_hard > 0 || bust_alarms > 0 in
let amber = !posture_ok || !intend_ok in
let band = if red then "red" else if amber then "amber" else "green" in
let action =
  if band == "red" then
    "ASSEMBLE re-anchor basis — a hard obligation is refuted/unmeasured or a recognised break is active. The anchor DROP is a human authority act; coapt only assembles the basis. ANCHOR.a2ml has no drift/ledger schema yet, so the drop cannot be recorded mechanically."
  else if band == "amber" then
    "advisory — soft drift within bands (posture/intend). Open an advisory issue; no re-anchor."
  else
    "none — the descriptile self-model coapts with the contractile set-point within tolerance."
in

# --- render ------------------------------------------------------------------
let clause_lines = std.string.join "\n" (std.array.map (fun e => e.id ++ " = " ++ e.status) evals) in

let cp = clauses_doc.provenance in
let fp = facts_doc.provenance in
let contractile_prov = "intend@%{cp.intend} must@%{cp.must} trust@%{cp.trust} adjust@%{cp.adjust} dust@%{cp.dust} bust@%{cp.bust}" in
let descriptile_prov = "clade@%{fp.clade} state@%{fp.state} ecosystem@%{fp.ecosystem} agentic@%{fp.agentic} anchor@%{fp.anchor}" in

# repo name comes from the CLADE descriptile, not a hardcoded literal — this
# script is shared verbatim by every repo instantiated from czech-file-knife,
# so a literal "czech-file-knife" here would misreport every one of them.
let repo_name = (lookup "clade.canonical-name").value in

let s = std.to_string in
m%"
# SPDX-License-Identifier: MPL-2.0
# coaptation receipt — GENERATED by `just coapt`; do not hand-edit (drift-checked by `just validate-coapt`).
# Coaptation = the typed descriptile↔contractile face-off (k9 Yard tier, pure).
# A reading, not a decision: re-anchoring is a human authority act (coapt.sh --reanchor).

[receipt]
schema = "hyperpolymath.coaptation/1"
repo = "%{repo_name}"
band = "%{band}"
proposed-action = "%{action}"

[coverage]
clauses-total = %{s (std.array.length clauses)}
descriptile-witnessed = %{s descriptile_witnessed}
probe-deferred-to-hunt = %{s probe_deferred}
must-trust-unmeasured-gaps = %{s gap_hard}
note = "Yard sees descriptile evidence only; probe-deferred obligations need a Hunt-tier run for a full hard-gate."

[reading.must-trust]
grade = "boolean_gate / boolean_gate_provenance"
witnessed = %{s witnessed_mt}
refuted = %{s refuted_hard}
unmeasured-gaps = %{s gap_hard}
probe-deferred = %{s probe_mt}
gate = "%{mt_gate}"

[reading.adjust]
grade = "posture (advisory; accessibility / inclusive design)"
satisfied = "%{s adj_sat}/%{s adj_tot}"
posture-ok = %{s posture_ok}

[reading.intend]
grade = "tropical (min-plus distance-to-north-star; wishes excluded)"
committed-intents = %{s (std.array.length intents)}
distance = %{s intend_distance}
within-tolerance = %{s intend_ok}

[reading.bust]
grade = "alarm (recognised break)"
alarms = %{s bust_alarms}

[reading.dust]
grade = "expected (planned exnovation)"
items = %{s dust_n}

[clauses]
%{clause_lines}

[provenance]
contractiles = "%{contractile_prov}"
descriptiles = "%{descriptile_prov}"
"%
