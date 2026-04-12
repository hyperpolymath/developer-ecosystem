-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Proofs.idr — Cross-cutting correctness proofs for unified-zig-api
--
-- All proofs are constructive (%default total, zero believe_me).
--
-- Proof groups:
--
--   A. Slot validity — sentinel 255 cannot build ValidSlot; rewriting an
--      idx = 255 hypothesis into the So (idx < 64) proof gives Void.
--
--   B. Roundtrip completeness — every *FromTag (*Tag x) = Just x for all
--      five enumeration types; injectivity re-exported.  Cross-enum: Result
--      and ServiceId share tag 0 but use distinct decode functions.
--
--   C. SafePath soundness — empty allowlist denies; head-match accepts;
--      Left result carries an IsSafePath witness (acceptance = safety).
--
--   D. Health status contract — 200/503 codes, distinctness, 5xx range.

module ZigApi.ABI.Proofs

import Data.Bits
import Data.List
import Data.So
import ZigApi.ABI.Types
import ZigApi.ABI.Http
import ZigApi.ABI.Process
import ZigApi.ABI.Connector
import ZigApi.ABI.Layout

%default total

-- ============================================================================
-- A. Slot validity invariants
-- ============================================================================

||| 255 < 64 reduces to False at compile time, so So (255 < 64) is empty.
||| The Oh constructor cannot inhabit So False — Idris2 rejects it as
||| impossible.
public export
sentinelCannotBeValidSlot : So (the Bits8 255 < 64) -> Void
sentinelCannotBeValidSlot Oh impossible

||| Any ValidSlot whose index would have to be 255 reduces to Void.
|||
||| Strategy: given `prf : So (idx < 64)` and `eq : idx = 255`, rewrite
||| prf by eq to produce `prf' : So (255 < 64)`, then apply
||| sentinelCannotBeValidSlot.  This works for all idx simultaneously —
||| no case split on concrete Bits8 values needed.
public export
validSlotIndexNotSentinel :
  (idx : Bits8) ->
  ValidSlot (MkSlot idx) ->
  Not (idx = 255)
validSlotIndexNotSentinel idx (IsValid idx prf) eq =
  sentinelCannotBeValidSlot (rewrite eq in prf)

||| The pool is non-empty.
public export
poolNonEmpty : Nat.lte 1 poolCapacity = True
poolNonEmpty = Refl

||| The failure sentinel (255) is strictly above the pool capacity (64 < 255).
public export
sentinelAboveCapacity : Nat.lte (S poolCapacity) connectorFailureSentinel = True
sentinelAboveCapacity = Refl

-- ============================================================================
-- B. Roundtrip completeness and tag injectivity
-- ============================================================================

||| Result: decode (encode r) = Just r.
public export
resultRoundtrip' : (r : Result) -> resultFromTag (resultTag r) = Just r
resultRoundtrip' = resultRoundtrip

||| ServiceId: decode (encode s) = Just s.
public export
serviceIdRoundtrip' : (s : ServiceId) -> serviceIdFromTag (serviceIdTag s) = Just s
serviceIdRoundtrip' = serviceIdRoundtrip

||| ConnectorState: decode (encode s) = Just s.
public export
connectorStateRoundtrip' : (s : ConnectorState) ->
    connectorStateFromTag (connectorStateTag s) = Just s
connectorStateRoundtrip' = connectorStateRoundtrip

||| HTTP Method: decode (encode m) = Just m.
public export
methodRoundtrip' : (m : Method) -> methodFromTag (methodTag m) = Just m
methodRoundtrip' = methodRoundtrip

||| ServerState: decode (encode s) = Just s.
public export
serverStateRoundtrip' : (s : ServerState) -> serverStateFromTag (serverStateTag s) = Just s
serverStateRoundtrip' = serverStateRoundtrip

||| ExecResult: decode (encode r) = Just r.
public export
execResultRoundtrip' : (r : ExecResult) -> execResultFromTag (execResultTag r) = Just r
execResultRoundtrip' = execResultRoundtrip

||| Result tag is injective (equal tags → equal constructors).
public export
resultTagInjective' : (r s : Result) -> resultTag r = resultTag s -> r = s
resultTagInjective' = resultTagInjective

-- ---- Cross-enum tag coincidence (informational) ----
--
-- Result.Ok and ServiceId.AmbientOps share tag value 0.  The ABI keeps these
-- safe by using typed functions: gnosis functions return Result; connector
-- functions return slot indices.  A caller cannot confuse them via the C API.

||| Both Ok and AmbientOps encode to 0.
public export
okAndAmbientOpsShareTag : resultTag Ok = serviceIdTag AmbientOps
okAndAmbientOpsShareTag = Refl

||| Tag 0 decodes as Ok under the Result decoder.
public export
tag0IsOk : resultFromTag 0 = Just Ok
tag0IsOk = Refl

||| Tag 0 decodes as AmbientOps under the ServiceId decoder.
public export
tag0IsAmbientOps : serviceIdFromTag 0 = Just AmbientOps
tag0IsAmbientOps = Refl

-- ============================================================================
-- C. SafePath soundness
-- ============================================================================

||| checkSafePath on the empty allowlist always returns Right (denial).
||| Proof: the `[]` branch of checkSafePath immediately returns Right.
public export
checkSafePathEmptyDenies : (path : String) -> IsRight (checkSafePath path [])
checkSafePathEmptyDenies _ = ItIsRight

||| The default allowlist is non-empty.
public export
defaultAllowlistNonEmpty : NonEmpty defaultAllowlist
defaultAllowlistNonEmpty = IsNonEmpty

||| checkSafePath returns Left (accepted) when the head of the allowlist is a
||| prefix of the path.
|||
||| Proof: with-pattern on `isPrefixOf prefix path`.  In the True branch,
||| checkSafePath returns `Left (SafeByPrefix prefix Here Refl)`, so
||| `IsLeft (Left ...)` = `ItIsLeft`.  In the False branch the assumption
||| `isPrefixOf prefix path = True` contradicts, so `absurd prf` closes it.
public export
checkSafePathHeadMatch :
  (path : String) ->
  (prefix : String) ->
  (rest : List String) ->
  isPrefixOf prefix path = True ->
  IsLeft (checkSafePath path (prefix :: rest))
checkSafePathHeadMatch path prefix rest prf with (isPrefixOf prefix path)
  checkSafePathHeadMatch path prefix rest Refl | True  = ItIsLeft
  checkSafePathHeadMatch path prefix rest prf  | False = absurd prf

||| Acceptance is safety: if checkSafePath returns Left, its payload IS an
||| IsSafePath proof.
|||
||| Proof: with-pattern on the result of checkSafePath.
||| Left wit  → return wit (the embedded IsSafePath proof).
||| Right _   → `isLeft` has type `IsLeft (Right _)` = empty ⊥ → absurd.
public export
checkSafePathLeftIsSafe :
  (path : String) ->
  (allowlist : List String) ->
  IsLeft (checkSafePath path allowlist) ->
  IsSafePath path allowlist
checkSafePathLeftIsSafe path allowlist isLeft
    with (checkSafePath path allowlist)
  checkSafePathLeftIsSafe path allowlist ItIsLeft | Left  wit = wit
  checkSafePathLeftIsSafe path allowlist isLeft   | Right _   = absurd isLeft

-- ============================================================================
-- D. Health status HTTP contract
-- ============================================================================

||| Serving maps to HTTP 200.
public export
servingIs200 : healthHttpStatus Serving = 200
servingIs200 = Refl

||| NotServing maps to HTTP 503.
public export
notServingIs503 : healthHttpStatus NotServing = 503
notServingIs503 = Refl

||| The two health codes are distinct.
public export
healthCodesDistinct : healthHttpStatus Serving = healthHttpStatus NotServing -> Void
healthCodesDistinct prf = absurd prf

||| Serving's code equals the Success class base (200 = baseStatus Success).
public export
servingCodeIsSuccessBase : healthHttpStatus Serving = baseStatus Success
servingCodeIsSuccessBase = Refl

||| 503 ≥ 500: NotServing falls in the 5xx (server error) range.
public export
notServingCodeIn5xx :
  Nat.lte (the Nat (cast (baseStatus ServerErr)))
          (the Nat (cast (healthHttpStatus NotServing))) = True
notServingCodeIn5xx = Refl

||| Health codes are strictly positive (not the zero/null sentinel).
public export
servingCodeNonZero : Not (healthHttpStatus Serving = 0)
servingCodeNonZero prf = absurd prf

public export
notServingCodeNonZero : Not (healthHttpStatus NotServing = 0)
notServingCodeNonZero prf = absurd prf
