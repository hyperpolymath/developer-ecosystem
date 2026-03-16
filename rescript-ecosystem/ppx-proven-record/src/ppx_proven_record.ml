(* SPDX-License-Identifier: PMPL-1.0-or-later *)
(* Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> *)
(*
 * ppx_proven_record — ReScript PPX for verified record subset destructuring.
 *
 * Transforms:
 *   @rest let { className, ?children, ...otherProps } = props
 *
 * Into:
 *   let className = props.className
 *   let children = props.children
 *   let otherProps = { onClick: props.onClick, style: props.style, ... }
 *
 * The algorithm is a direct transliteration of computeComplement from
 * proven/src/Proven/SafeRecord/Proofs.idr, which is formally verified
 * to produce exhaustive, disjoint partitions.
 *
 * Status: Scaffold — implementation pending.
 *)

(* TODO: Implement the PPX transformation using ppxlib *)
(* Key steps:
 *   1. Find @rest attributes on let bindings
 *   2. Extract the requested field names from the pattern
 *   3. Look up the record type from the type environment
 *   4. Compute the complement (remaining fields)
 *   5. Generate explicit destructuring code
 *)
