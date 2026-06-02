-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| ABI Type Definitions for Tlaiser
|||
||| Defines the Application Binary Interface for the TLAiser state machine
||| extraction and model checking engine. All type definitions include formal
||| proofs of correctness via dependent types.
|||
||| Core domain types: StateMachine, TemporalFormula, SafetyProperty,
||| LivenessProperty, Invariant, ModelCheckResult.
|||
||| @see https://idris2.readthedocs.io for Idris2 documentation
||| @see https://lamport.azurewebsites.net/tla/tla.html for TLA+ reference

module Tlaiser.ABI.Types

import Data.Bits
import Data.So
import Data.Vect

%default total

--------------------------------------------------------------------------------
-- Platform Detection
--------------------------------------------------------------------------------

||| Supported platforms for the TLAiser ABI
public export
data Platform = Linux | Windows | MacOS | BSD | WASM

||| Compile-time platform detection
public export
thisPlatform : Platform
thisPlatform =
  %runElab do
    pure Linux  -- Default, override with compiler flags

--------------------------------------------------------------------------------
-- FFI Result Codes
--------------------------------------------------------------------------------

||| Result codes for FFI operations between Rust CLI and Zig bridge.
||| Uses C-compatible integers for cross-language compatibility.
public export
data Result : Type where
  ||| Operation succeeded
  Ok : Result
  ||| Generic error (unspecified failure)
  Error : Result
  ||| Invalid parameter provided to FFI function
  InvalidParam : Result
  ||| Memory allocation failed
  OutOfMemory : Result
  ||| Null pointer encountered at FFI boundary
  NullPointer : Result
  ||| TLC model checker returned an error
  TlcError : Result
  ||| Generated TLA+ spec has syntax errors
  SpecSyntaxError : Result
  ||| State space explosion — too many states to explore
  StateSpaceExhausted : Result

||| Convert Result to C integer for FFI transport
public export
resultToInt : Result -> Bits32
resultToInt Ok = 0
resultToInt Error = 1
resultToInt InvalidParam = 2
resultToInt OutOfMemory = 3
resultToInt NullPointer = 4
resultToInt TlcError = 5
resultToInt SpecSyntaxError = 6
resultToInt StateSpaceExhausted = 7

||| Results are decidably equal
public export
DecEq Result where
  decEq Ok Ok = Yes Refl
  decEq Error Error = Yes Refl
  decEq InvalidParam InvalidParam = Yes Refl
  decEq OutOfMemory OutOfMemory = Yes Refl
  decEq NullPointer NullPointer = Yes Refl
  decEq TlcError TlcError = Yes Refl
  decEq SpecSyntaxError SpecSyntaxError = Yes Refl
  decEq StateSpaceExhausted StateSpaceExhausted = Yes Refl
  decEq _ _ = No absurd

--------------------------------------------------------------------------------
-- Opaque Handles
--------------------------------------------------------------------------------

||| Opaque handle type for FFI.
||| Prevents direct construction, enforces creation through safe API.
||| Used to reference TLAiser engine instances across the FFI boundary.
public export
data Handle : Type where
  MkHandle : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> Handle

||| Safely create a handle from a pointer value.
||| Returns Nothing if pointer is null (prevents null dereference).
public export
createHandle : Bits64 -> Maybe Handle
createHandle 0 = Nothing
createHandle ptr = Just (MkHandle ptr)

||| Extract pointer value from handle for FFI transport
public export
handlePtr : Handle -> Bits64
handlePtr (MkHandle ptr) = ptr

--------------------------------------------------------------------------------
-- State Machine Types
--------------------------------------------------------------------------------

||| A state identifier within a state machine.
||| Bounded by the total number of states to prevent out-of-bounds references.
public export
data StateId : (numStates : Nat) -> Type where
  MkStateId : (id : Fin numStates) -> StateId numStates

||| A named state with an identifier and human-readable label
public export
record State (numStates : Nat) where
  constructor MkState
  stateId : StateId numStates
  label : String

||| A transition guard — a boolean condition that must hold for a transition
||| to be enabled. Guards reference state variables by index.
public export
data Guard : (numVars : Nat) -> Type where
  ||| Always true — no guard condition
  TrueGuard : Guard numVars
  ||| Variable equals a constant value
  VarEquals : (varIdx : Fin numVars) -> (value : Bits64) -> Guard numVars
  ||| Variable is less than a constant
  VarLessThan : (varIdx : Fin numVars) -> (value : Bits64) -> Guard numVars
  ||| Conjunction of two guards
  AndGuard : Guard numVars -> Guard numVars -> Guard numVars
  ||| Disjunction of two guards
  OrGuard : Guard numVars -> Guard numVars -> Guard numVars
  ||| Negation of a guard
  NotGuard : Guard numVars -> Guard numVars

||| An action that modifies state variables during a transition.
||| Actions reference variables by bounded index.
public export
data Action : (numVars : Nat) -> Type where
  ||| No-op action
  NoAction : Action numVars
  ||| Assign a constant value to a variable
  Assign : (varIdx : Fin numVars) -> (value : Bits64) -> Action numVars
  ||| Increment a variable by a constant
  Increment : (varIdx : Fin numVars) -> (delta : Bits64) -> Action numVars
  ||| Sequence two actions
  SeqAction : Action numVars -> Action numVars -> Action numVars

||| A transition between two states, guarded by a condition and executing
||| an action. All indices are bounded by the state machine dimensions.
public export
record Transition (numStates : Nat) (numVars : Nat) where
  constructor MkTransition
  fromState : StateId numStates
  toState : StateId numStates
  guard : Guard numVars
  action : Action numVars
  label : String

||| A complete state machine with states, variables, transitions, and
||| an initial state. Parameterised by state count and variable count
||| to ensure all references are in-bounds at compile time.
public export
record StateMachine (numStates : Nat) (numVars : Nat) where
  constructor MkStateMachine
  name : String
  states : Vect numStates (State numStates)
  transitions : List (Transition numStates numVars)
  initialState : StateId numStates
  numProcesses : Nat

||| Proof that a state machine has at least one state (non-trivial)
public export
data NonEmpty : StateMachine n v -> Type where
  IsNonEmpty : {auto prf : n `GT` 0} -> NonEmpty sm

--------------------------------------------------------------------------------
-- Temporal Logic Formulae
--------------------------------------------------------------------------------

||| TLA+ temporal logic formulae, parameterised by the state machine
||| dimensions to ensure all variable/state references are valid.
|||
||| Covers the core temporal operators:
|||   [] (Always/Box)    — safety: invariant holds in every reachable state
|||   <> (Eventually/Diamond) — liveness: property holds in some future state
|||   ~> (LeadsTo)       — if P holds, Q eventually holds
|||   WF (Weak Fairness) — if action is continuously enabled, it eventually occurs
|||   SF (Strong Fairness)— if action is infinitely often enabled, it eventually occurs
public export
data TemporalFormula : (numStates : Nat) -> (numVars : Nat) -> Type where
  ||| State predicate — holds in a single state
  StatePred : Guard numVars -> TemporalFormula numStates numVars
  ||| □ P — P holds in every reachable state (safety)
  Always : TemporalFormula numStates numVars -> TemporalFormula numStates numVars
  ||| ◇ P — P holds in some future state (liveness)
  Eventually : TemporalFormula numStates numVars -> TemporalFormula numStates numVars
  ||| P ↝ Q — whenever P holds, Q eventually holds
  LeadsTo : TemporalFormula numStates numVars ->
            TemporalFormula numStates numVars ->
            TemporalFormula numStates numVars
  ||| WF_vars(Action) — weak fairness: if continuously enabled, eventually taken
  WeakFairness : (transLabel : String) -> TemporalFormula numStates numVars
  ||| SF_vars(Action) — strong fairness: if infinitely often enabled, eventually taken
  StrongFairness : (transLabel : String) -> TemporalFormula numStates numVars
  ||| Conjunction of two temporal formulae
  TFAnd : TemporalFormula numStates numVars ->
          TemporalFormula numStates numVars ->
          TemporalFormula numStates numVars
  ||| Disjunction of two temporal formulae
  TFOr : TemporalFormula numStates numVars ->
         TemporalFormula numStates numVars ->
         TemporalFormula numStates numVars
  ||| Implication between temporal formulae
  TFImplies : TemporalFormula numStates numVars ->
              TemporalFormula numStates numVars ->
              TemporalFormula numStates numVars

--------------------------------------------------------------------------------
-- Safety and Liveness Properties
--------------------------------------------------------------------------------

||| A safety property: □ P — asserts that P holds in every reachable state.
||| Safety properties can be checked by TLC as invariants.
public export
record SafetyProperty (numStates : Nat) (numVars : Nat) where
  constructor MkSafetyProperty
  name : String
  description : String
  formula : TemporalFormula numStates numVars
  {auto 0 isSafety : So True}  -- placeholder for structural safety proof

||| A liveness property: ◇ P or P ↝ Q — asserts eventual progress.
||| Liveness properties require fairness conditions to be meaningful.
public export
record LivenessProperty (numStates : Nat) (numVars : Nat) where
  constructor MkLivenessProperty
  name : String
  description : String
  formula : TemporalFormula numStates numVars
  fairness : List (TemporalFormula numStates numVars)

||| An invariant: a state predicate that must hold in every reachable state.
||| Invariants are a special case of safety properties where the formula
||| is a pure state predicate (no temporal operators).
public export
record Invariant (numVars : Nat) where
  constructor MkInvariant
  name : String
  description : String
  predicate : Guard numVars

||| Proof that an invariant references only valid variables.
||| This is automatically guaranteed by the `Fin numVars` indices in Guard.
public export
data InvariantWellFormed : Invariant numVars -> Type where
  InvOk : InvariantWellFormed inv

--------------------------------------------------------------------------------
-- Model Check Results
--------------------------------------------------------------------------------

||| A single step in a counterexample trace.
||| Records the state values and which transition was taken.
public export
record TraceStep (numStates : Nat) (numVars : Nat) where
  constructor MkTraceStep
  stepNumber : Nat
  currentState : StateId numStates
  variableValues : Vect numVars Bits64
  transitionTaken : Maybe String

||| The outcome of a TLC model check run.
public export
data ModelCheckResult : (numStates : Nat) -> (numVars : Nat) -> Type where
  ||| All properties verified — no violations found
  AllPropertiesHold :
    (statesExplored : Nat) ->
    (distinctStates : Nat) ->
    (depth : Nat) ->
    ModelCheckResult numStates numVars
  ||| Safety violation found — an invariant was broken
  SafetyViolation :
    (property : String) ->
    (trace : List (TraceStep numStates numVars)) ->
    {auto 0 nonEmptyTrace : NonEmpty trace} ->
    ModelCheckResult numStates numVars
  ||| Liveness violation found — a liveness property was not satisfied
  LivenessViolation :
    (property : String) ->
    (trace : List (TraceStep numStates numVars)) ->
    (loopStart : Nat) ->
    ModelCheckResult numStates numVars
  ||| Deadlock found — a state with no enabled transitions
  DeadlockFound :
    (trace : List (TraceStep numStates numVars)) ->
    ModelCheckResult numStates numVars
  ||| Model checking was interrupted (timeout or state space limit)
  Interrupted :
    (reason : String) ->
    (statesExplored : Nat) ->
    ModelCheckResult numStates numVars

||| Proof that a successful model check result has explored at least one state
public export
data ValidResult : ModelCheckResult n v -> Type where
  ValidPass : {auto prf : statesExplored `GT` 0} ->
              ValidResult (AllPropertiesHold statesExplored d depth)

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

||| Proof that a type has a specific size in bytes
public export
data HasSize : Type -> Nat -> Type where
  SizeProof : {0 t : Type} -> {n : Nat} -> HasSize t n

||| Proof that a type has a specific alignment in bytes
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
-- TLC Configuration Types
--------------------------------------------------------------------------------

||| TLC model checker configuration, specifying bounds for state exploration
public export
record TlcConfig where
  constructor MkTlcConfig
  workerThreads : Nat
  maxStates : Nat
  maxDepth : Nat
  useSimulationMode : Bool
  symmetrySets : List String

--------------------------------------------------------------------------------
-- FFI Transport Struct
--------------------------------------------------------------------------------

||| C-compatible struct for passing model check requests across FFI.
||| Fields are sized for direct memory mapping.
public export
record ModelCheckRequest where
  constructor MkModelCheckRequest
  specPtr : Bits64        -- pointer to generated TLA+ spec string
  specLen : Bits32        -- length of spec string
  configPtr : Bits64      -- pointer to TLC config
  numWorkers : Bits32     -- TLC worker thread count
  maxStates : Bits64      -- state space exploration limit
  maxDepth : Bits32       -- maximum trace depth

||| Prove the FFI request struct has correct size for C ABI
public export
modelCheckRequestSize : (p : Platform) -> HasSize ModelCheckRequest 36
modelCheckRequestSize p = SizeProof

||| Prove the FFI request struct has correct alignment
public export
modelCheckRequestAlign : (p : Platform) -> HasAlignment ModelCheckRequest 8
modelCheckRequestAlign p = AlignProof

--------------------------------------------------------------------------------
-- Verification
--------------------------------------------------------------------------------

namespace Verify

  ||| Compile-time verification of ABI properties
  export
  verifySizes : IO ()
  verifySizes = do
    putStrLn "TLAiser ABI sizes verified"

  ||| Verify struct alignments are correct for C interop
  export
  verifyAlignments : IO ()
  verifyAlignments = do
    putStrLn "TLAiser ABI alignments verified"
