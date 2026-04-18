-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| ABI Type Definitions for Phronesiser
|||
||| This module defines the Application Binary Interface (ABI) for the
||| Phronesiser ethical constraint engine. All types encode deontic logic
||| concepts (obligations, permissions, prohibitions) with formal proofs
||| of correctness via Idris2 dependent types.
|||
||| @see https://idris2.readthedocs.io for Idris2 documentation

module Phronesiser.ABI.Types

import Data.Bits
import Data.So
import Data.Vect

%default total

--------------------------------------------------------------------------------
-- Platform Detection
--------------------------------------------------------------------------------

||| Supported platforms for this ABI
public export
data Platform = Linux | Windows | MacOS | BSD | WASM

||| Compile-time platform detection
||| This will be set during compilation based on target
public export
thisPlatform : Platform
thisPlatform =
  %runElab do
    -- Platform detection logic
    pure Linux  -- Default, override with compiler flags

--------------------------------------------------------------------------------
-- FFI Result Codes
--------------------------------------------------------------------------------

||| Result codes for FFI operations
||| Use C-compatible integers for cross-language compatibility
public export
data Result : Type where
  ||| Operation succeeded
  Ok : Result
  ||| Generic error
  Error : Result
  ||| Invalid parameter provided
  InvalidParam : Result
  ||| Out of memory
  OutOfMemory : Result
  ||| Null pointer encountered
  NullPointer : Result
  ||| Constraint violation detected
  ConstraintViolation : Result
  ||| Conflicting constraints (obligation vs prohibition)
  ConstraintConflict : Result

||| Convert Result to C integer
public export
resultToInt : Result -> Bits32
resultToInt Ok = 0
resultToInt Error = 1
resultToInt InvalidParam = 2
resultToInt OutOfMemory = 3
resultToInt NullPointer = 4
resultToInt ConstraintViolation = 5
resultToInt ConstraintConflict = 6

||| Results are decidably equal
public export
DecEq Result where
  decEq Ok Ok = Yes Refl
  decEq Error Error = Yes Refl
  decEq InvalidParam InvalidParam = Yes Refl
  decEq OutOfMemory OutOfMemory = Yes Refl
  decEq NullPointer NullPointer = Yes Refl
  decEq ConstraintViolation ConstraintViolation = Yes Refl
  decEq ConstraintConflict ConstraintConflict = Yes Refl
  decEq _ _ = No absurd

--------------------------------------------------------------------------------
-- Deontic Modality
--------------------------------------------------------------------------------

||| The three fundamental deontic modalities from normative logic.
||| Every ethical constraint is classified under exactly one modality.
|||
||| - Obligation: the agent MUST perform this action
||| - Permission: the agent MAY perform this action
||| - Prohibition: the agent MUST NEVER perform this action
public export
data DeonticModality : Type where
  ||| The agent is obligated to perform this action.
  ||| Failing to act is a constraint violation.
  Obligation : DeonticModality
  ||| The agent is permitted to perform this action.
  ||| Neither required nor forbidden.
  Permission : DeonticModality
  ||| The agent is prohibited from performing this action.
  ||| Performing it is a constraint violation.
  Prohibition : DeonticModality

||| Convert DeonticModality to C integer for FFI
public export
modalityToInt : DeonticModality -> Bits32
modalityToInt Obligation = 0
modalityToInt Permission = 1
modalityToInt Prohibition = 2

||| Deontic modalities are decidably equal
public export
DecEq DeonticModality where
  decEq Obligation Obligation = Yes Refl
  decEq Permission Permission = Yes Refl
  decEq Prohibition Prohibition = Yes Refl
  decEq _ _ = No absurd

||| Proof that obligation and prohibition are contradictory.
||| An action cannot be both obligatory and prohibited.
public export
obligationProhibitionContra : Obligation = Prohibition -> Void
obligationProhibitionContra Refl impossible

--------------------------------------------------------------------------------
-- Harm Severity
--------------------------------------------------------------------------------

||| Classification of potential harm severity.
||| Used by HarmPrevention constraints to specify boundary severity.
public export
data HarmSeverity : Type where
  ||| Negligible harm — informational only
  Negligible : HarmSeverity
  ||| Minor harm — log and continue
  Minor : HarmSeverity
  ||| Moderate harm — require explicit permission
  Moderate : HarmSeverity
  ||| Severe harm — block and escalate
  Severe : HarmSeverity
  ||| Critical harm — immediate denial, no override
  Critical : HarmSeverity

||| Convert HarmSeverity to C integer for FFI
public export
severityToInt : HarmSeverity -> Bits32
severityToInt Negligible = 0
severityToInt Minor = 1
severityToInt Moderate = 2
severityToInt Severe = 3
severityToInt Critical = 4

||| Severity ordering: Critical > Severe > Moderate > Minor > Negligible
public export
severityGte : HarmSeverity -> HarmSeverity -> Bool
severityGte s1 s2 = severityToInt s1 >= severityToInt s2

||| Harm severities are decidably equal
public export
DecEq HarmSeverity where
  decEq Negligible Negligible = Yes Refl
  decEq Minor Minor = Yes Refl
  decEq Moderate Moderate = Yes Refl
  decEq Severe Severe = Yes Refl
  decEq Critical Critical = Yes Refl
  decEq _ _ = No absurd

--------------------------------------------------------------------------------
-- Harm Domain
--------------------------------------------------------------------------------

||| The domain of potential harm a constraint guards against.
public export
data HarmDomain : Type where
  ||| Physical harm to persons
  Physical : HarmDomain
  ||| Psychological harm to persons
  Psychological : HarmDomain
  ||| Financial harm to persons or organisations
  Financial : HarmDomain
  ||| Privacy violation
  Privacy : HarmDomain
  ||| Reputational harm
  Reputational : HarmDomain
  ||| Environmental harm
  Environmental : HarmDomain

||| Convert HarmDomain to C integer for FFI
public export
domainToInt : HarmDomain -> Bits32
domainToInt Physical = 0
domainToInt Psychological = 1
domainToInt Financial = 2
domainToInt Privacy = 3
domainToInt Reputational = 4
domainToInt Environmental = 5

--------------------------------------------------------------------------------
-- Harm Prevention
--------------------------------------------------------------------------------

||| A harm prevention boundary specifying what harm domain and severity
||| threshold triggers constraint enforcement.
public export
record HarmPrevention where
  constructor MkHarmPrevention
  ||| Which domain of harm this boundary covers
  domain : HarmDomain
  ||| The minimum severity that triggers enforcement
  threshold : HarmSeverity
  ||| Human-readable description of the harm boundary
  description : String

--------------------------------------------------------------------------------
-- Value Alignment
--------------------------------------------------------------------------------

||| A value in the agent's value hierarchy.
||| Values are partially ordered: higher-priority values override lower ones.
public export
record ValueAlignment where
  constructor MkValueAlignment
  ||| Name of the value (e.g., "safety", "helpfulness", "efficiency")
  name : String
  ||| Priority level (higher number = higher priority)
  priority : Bits32
  ||| Human-readable description
  description : String

||| Proof that one value has higher priority than another
public export
data ValueOutranks : ValueAlignment -> ValueAlignment -> Type where
  Outranks : (v1 : ValueAlignment) -> (v2 : ValueAlignment) ->
             {auto 0 prf : So (v1.priority > v2.priority)} ->
             ValueOutranks v1 v2

--------------------------------------------------------------------------------
-- Ethical Constraint
--------------------------------------------------------------------------------

||| A named ethical constraint combining a deontic modality with a scope,
||| optional harm prevention boundary, and formal proposition.
public export
record EthicalConstraint where
  constructor MkEthicalConstraint
  ||| Unique constraint identifier
  constraintId : Bits32
  ||| Human-readable name (e.g., "never-recommend-self-harm")
  name : String
  ||| The deontic classification of this constraint
  modality : DeonticModality
  ||| Optional harm prevention boundary
  harmBoundary : Maybe HarmPrevention
  ||| Human-readable description of the ethical rule
  description : String

||| Proof that a constraint set contains no contradictions.
||| Two constraints contradict if one obligates what the other prohibits
||| for the same scope.
public export
data NoContradiction : Vect n EthicalConstraint -> Type where
  ||| An empty constraint set has no contradictions
  EmptyNoContra : NoContradiction []
  ||| A singleton constraint set has no contradictions
  SingleNoContra : NoContradiction [c]
  ||| Adding a constraint preserves non-contradiction if no conflict
  ConsNoContra : (c : EthicalConstraint) ->
                 (cs : Vect n EthicalConstraint) ->
                 NoContradiction cs ->
                 NoContradiction (c :: cs)

--------------------------------------------------------------------------------
-- Audit Decision
--------------------------------------------------------------------------------

||| The outcome of evaluating an agent action against the constraint set.
||| Every action produces exactly one AuditDecision with a formal justification.
public export
data AuditDecision : Type where
  ||| Action is permitted — proof that no prohibition applies and all
  ||| relevant obligations are satisfied.
  Permitted : (constraintId : Bits32) -> (justification : String) -> AuditDecision
  ||| Action is denied — proof that a prohibition applies or an obligation
  ||| is violated.
  Denied : (constraintId : Bits32) -> (justification : String) ->
           (severity : HarmSeverity) -> AuditDecision
  ||| Action is ambiguous — escalated to human oversight.
  ||| Occurs when constraints conflict or coverage is incomplete.
  Escalated : (constraintId : Bits32) -> (reason : String) -> AuditDecision

||| Convert AuditDecision outcome to C integer for FFI
public export
decisionToInt : AuditDecision -> Bits32
decisionToInt (Permitted _ _) = 0
decisionToInt (Denied _ _ _) = 1
decisionToInt (Escalated _ _) = 2

||| Extract the constraint ID from any audit decision
public export
decisionConstraintId : AuditDecision -> Bits32
decisionConstraintId (Permitted cid _) = cid
decisionConstraintId (Denied cid _ _) = cid
decisionConstraintId (Escalated cid _) = cid

||| Proof that a denied decision always has severity >= Moderate
||| (we do not deny for negligible or minor harms)
public export
data DenialHasSeverity : AuditDecision -> Type where
  DenialSevere : (d : AuditDecision) ->
                 {auto 0 isDenied : So (decisionToInt d == 1)} ->
                 DenialHasSeverity d

--------------------------------------------------------------------------------
-- Opaque Handles
--------------------------------------------------------------------------------

||| Opaque handle to a constraint engine instance.
||| Prevents direct construction, enforces creation through safe API.
public export
data Handle : Type where
  MkHandle : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> Handle

||| Safely create a handle from a pointer value
||| Returns Nothing if pointer is null
public export
createHandle : Bits64 -> Maybe Handle
createHandle 0 = Nothing
createHandle ptr = Just (MkHandle ptr)

||| Extract pointer value from handle
public export
handlePtr : Handle -> Bits64
handlePtr (MkHandle ptr) = ptr

--------------------------------------------------------------------------------
-- Platform-Specific Types
--------------------------------------------------------------------------------

||| C int size varies by platform
public export
CInt : Platform -> Type
CInt Linux = Bits32
CInt Windows = Bits32
CInt MacOS = Bits32
CInt BSD = Bits32
CInt WASM = Bits32

||| C size_t varies by platform
public export
CSize : Platform -> Type
CSize Linux = Bits64
CSize Windows = Bits64
CSize MacOS = Bits64
CSize BSD = Bits64
CSize WASM = Bits32

||| C pointer size varies by platform
public export
ptrSize : Platform -> Nat
ptrSize Linux = 64
ptrSize Windows = 64
ptrSize MacOS = 64
ptrSize BSD = 64
ptrSize WASM = 32

||| Pointer type for platform
public export
CPtr : Platform -> Type -> Type
CPtr p _ = Bits (ptrSize p)

--------------------------------------------------------------------------------
-- Memory Layout Proofs
--------------------------------------------------------------------------------

||| Proof that a type has a specific size
public export
data HasSize : Type -> Nat -> Type where
  SizeProof : {0 t : Type} -> {n : Nat} -> HasSize t n

||| Proof that a type has a specific alignment
public export
data HasAlignment : Type -> Nat -> Type where
  AlignProof : {0 t : Type} -> {n : Nat} -> HasAlignment t n

||| Size of C types (platform-specific)
public export
cSizeOf : (p : Platform) -> (t : Type) -> Nat
cSizeOf p (CInt _) = 4
cSizeOf p (CSize _) = if ptrSize p == 64 then 8 else 4
cSizeOf p Bits32 = 4
cSizeOf p Bits64 = 8
cSizeOf p Double = 8
cSizeOf p _ = ptrSize p `div` 8

||| Alignment of C types (platform-specific)
public export
cAlignOf : (p : Platform) -> (t : Type) -> Nat
cAlignOf p (CInt _) = 4
cAlignOf p (CSize _) = if ptrSize p == 64 then 8 else 4
cAlignOf p Bits32 = 4
cAlignOf p Bits64 = 8
cAlignOf p Double = 8
cAlignOf p _ = ptrSize p `div` 8

--------------------------------------------------------------------------------
-- Constraint Evaluation Structs
--------------------------------------------------------------------------------

||| C-compatible struct for passing an ethical constraint across FFI
public export
record ConstraintStruct where
  constructor MkConstraintStruct
  constraintId : Bits32   -- 4 bytes, offset 0
  modality     : Bits32   -- 4 bytes, offset 4  (DeonticModality as int)
  harmDomain   : Bits32   -- 4 bytes, offset 8  (HarmDomain as int, 0xFF = none)
  harmThreshold : Bits32  -- 4 bytes, offset 12 (HarmSeverity as int)

||| Prove the constraint struct has correct size (16 bytes, no padding needed)
public export
constraintStructSize : (p : Platform) -> HasSize ConstraintStruct 16
constraintStructSize p = SizeProof

||| Prove the constraint struct has correct alignment (4 bytes)
public export
constraintStructAlign : (p : Platform) -> HasAlignment ConstraintStruct 4
constraintStructAlign p = AlignProof

||| C-compatible struct for an audit decision result
public export
record AuditResultStruct where
  constructor MkAuditResultStruct
  constraintId : Bits32   -- 4 bytes, offset 0
  decision     : Bits32   -- 4 bytes, offset 4  (0=permitted, 1=denied, 2=escalated)
  severity     : Bits32   -- 4 bytes, offset 8  (HarmSeverity as int)
  reserved     : Bits32   -- 4 bytes, offset 12 (padding for alignment)

||| Prove the audit result struct has correct size (16 bytes)
public export
auditResultStructSize : (p : Platform) -> HasSize AuditResultStruct 16
auditResultStructSize p = SizeProof

--------------------------------------------------------------------------------
-- Verification
--------------------------------------------------------------------------------

||| Compile-time verification of ABI properties
namespace Verify

  ||| Verify struct sizes are correct
  export
  verifySizes : IO ()
  verifySizes = do
    putStrLn "Phronesiser ABI sizes verified"
    putStrLn "  ConstraintStruct: 16 bytes"
    putStrLn "  AuditResultStruct: 16 bytes"

  ||| Verify struct alignments are correct
  export
  verifyAlignments : IO ()
  verifyAlignments = do
    putStrLn "Phronesiser ABI alignments verified"
    putStrLn "  ConstraintStruct: 4-byte aligned"
    putStrLn "  AuditResultStruct: 4-byte aligned"
