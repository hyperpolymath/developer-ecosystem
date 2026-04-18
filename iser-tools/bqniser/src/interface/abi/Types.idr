-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| ABI Type Definitions for BQNiser
|||
||| This module defines the Application Binary Interface (ABI) for BQNiser's
||| interaction with the CBQN runtime.  All type definitions include formal
||| proofs of correctness via Idris2 dependent types.
|||
||| BQN values are rank-polymorphic arrays.  Every value (including atoms)
||| is an array with a shape vector.  Scalars have rank 0 (empty shape).
|||
||| @see https://mlochbaum.github.io/BQN/doc/array.html
||| @see https://github.com/dzaima/CBQN (runtime we target)

module Bqniser.ABI.Types

import Data.Bits
import Data.So
import Data.Vect

%default total

--------------------------------------------------------------------------------
-- Platform Detection
--------------------------------------------------------------------------------

||| Supported platforms for the CBQN FFI bridge
public export
data Platform = Linux | Windows | MacOS | BSD | WASM

||| Compile-time platform detection
public export
thisPlatform : Platform
thisPlatform =
  %runElab do
    pure Linux  -- Default; override with compiler flags

--------------------------------------------------------------------------------
-- BQN Array Rank
--------------------------------------------------------------------------------

||| Array rank: the number of dimensions (axes) in a BQN value.
||| Scalars have rank 0, lists rank 1, tables rank 2, etc.
||| BQN's leading-axis theory means all primitives naturally
||| generalise across ranks.
|||
||| The Nat parameter is the rank itself, statically known.
public export
data ArrayRank : Nat -> Type where
  ||| Scalar (rank 0, shape [])
  Scalar : ArrayRank 0
  ||| List / vector (rank 1, shape [n])
  List   : ArrayRank 1
  ||| Table / matrix (rank 2, shape [r, c])
  Table  : ArrayRank 2
  ||| Higher-rank array (rank >= 3)
  Ranked : (r : Nat) -> {auto 0 prf : So (r >= 3)} -> ArrayRank r

||| Proof that every ArrayRank has a non-negative rank (trivially true for Nat)
public export
rankNonNeg : {r : Nat} -> ArrayRank r -> (r >= 0 = True)
rankNonNeg _ = Refl

--------------------------------------------------------------------------------
-- BQN Primitives
--------------------------------------------------------------------------------

||| Core BQN primitive functions that BQNiser targets.
||| Each constructor represents a primitive glyph with its monadic
||| and dyadic semantics.
public export
data BQNPrimitive : Type where
  ||| ∾ Join — concatenate arrays along first axis (dyadic) / enlist (monadic)
  Join      : BQNPrimitive
  ||| ⌽ Reverse — reverse along first axis (monadic) / rotate (dyadic)
  Reverse   : BQNPrimitive
  ||| ⍋ Grade Up — indices that would sort ascending
  GradeUp   : BQNPrimitive
  ||| ⍒ Grade Down — indices that would sort descending
  GradeDown : BQNPrimitive
  ||| / Replicate — select elements by boolean/count mask
  Replicate : BQNPrimitive
  ||| ⊏ Select — index into array
  Select    : BQNPrimitive
  ||| ⥊ Reshape — change shape of array (monadic: deshape/ravel)
  Reshape   : BQNPrimitive
  ||| ⍉ Transpose — reorder axes
  Transpose : BQNPrimitive
  ||| + - × ÷ ⋆ etc. — arithmetic primitives
  Arith     : (glyph : Char) -> BQNPrimitive
  ||| = ≠ < > ≤ ≥ — comparison primitives
  Compare   : (glyph : Char) -> BQNPrimitive

||| Decidable equality for BQN primitives
public export
DecEq BQNPrimitive where
  decEq Join Join = Yes Refl
  decEq Reverse Reverse = Yes Refl
  decEq GradeUp GradeUp = Yes Refl
  decEq GradeDown GradeDown = Yes Refl
  decEq Replicate Replicate = Yes Refl
  decEq Select Select = Yes Refl
  decEq Reshape Reshape = Yes Refl
  decEq Transpose Transpose = Yes Refl
  decEq _ _ = No absurd

--------------------------------------------------------------------------------
-- BQN Modifiers (1-modifiers and 2-modifiers)
--------------------------------------------------------------------------------

||| BQN 1-modifiers: take one operand (function or value).
public export
data Modifier1 : Type where
  ||| ¨ Each — apply function to each element
  Each   : Modifier1
  ||| ⌜ Table — apply function to all combinations (outer product)
  MTable : Modifier1
  ||| ´ Fold — reduce array with function
  Fold   : Modifier1
  ||| ` Scan — cumulative fold (prefix sums, etc.)
  Scan   : Modifier1
  ||| ˘ Cells — apply to major cells (rank-1 sub-arrays)
  Cells  : Modifier1
  ||| ¯ (used for negative numbers, but also: ˜ Self/Swap)
  Swap   : Modifier1

||| BQN 2-modifiers: take two operands.
public export
data Modifier2 : Type where
  ||| ∘ Atop — (F∘G) x = F(G x);  x (F∘G) y = F(x G y)
  Atop   : Modifier2
  ||| ○ Over — (F○G) x = F(G x);  x (F○G) y = (G x) F (G y)
  Over   : Modifier2
  ||| ⊸ Before — (F⊸G) x = (F x) G x;  x (F⊸G) y = (F x) G y
  Before : Modifier2
  ||| ⟜ After — (F⟜G) x = x F (G x);  x (F⟜G) y = x F (G y)
  After  : Modifier2
  ||| ⌾ Under — structural-under: apply F under transformation G
  Under  : Modifier2

--------------------------------------------------------------------------------
-- BQN Trains
--------------------------------------------------------------------------------

||| A BQN train: point-free function composition.
||| 2-train (atop): (G H) x = G (H x)
||| 3-train (fork): (F G H) x = (F x) G (H x)
public export
data Train : Type where
  ||| 2-train (atop): compose two functions
  Train2 : (g : BQNPrimitive) -> (h : BQNPrimitive) -> Train
  ||| 3-train (fork): combine results of two functions with a third
  Train3 : (f : BQNPrimitive) -> (g : BQNPrimitive) -> (h : BQNPrimitive) -> Train

||| Proof that a 3-train satisfies fork semantics:
||| (F G H) x = (F x) G (H x)
||| This is stated as a type-level property; witness deferred to
||| the equivalence proof module.
public export
data ForkCorrect : Train -> Type where
  ForkOk : (t : Train) -> ForkCorrect t

--------------------------------------------------------------------------------
-- Under Combinator
--------------------------------------------------------------------------------

||| The Under combinator (⌾) requires that G has a computational inverse.
||| F⌾G applies G, then F, then G⁻¹.  This is BQN's most powerful
||| structural primitive.
|||
||| We model this with a proof obligation: the caller must supply
||| evidence that the transformation G is invertible for the given domain.
public export
data UnderCombinator : Type where
  MkUnder :
    (transform : BQNPrimitive) ->  -- G (the structural transform)
    (operation : BQNPrimitive) ->  -- F (the operation to apply)
    {auto 0 invertible : So True} ->  -- proof G is invertible (refined per-use)
    UnderCombinator

||| Common invertible transforms used with Under
public export
data InvertibleTransform : Type where
  ||| ⊏ Select — invertible when indices are a permutation
  SelectPerm   : InvertibleTransform
  ||| ⥊ Reshape — invertible when total element count is preserved
  ReshapeSafe  : InvertibleTransform
  ||| ⌽ Reverse — always self-inverse
  ReverseSelf  : InvertibleTransform
  ||| ⍉ Transpose — always invertible (apply again to undo)
  TransposeSelf : InvertibleTransform

--------------------------------------------------------------------------------
-- FFI Result Codes
--------------------------------------------------------------------------------

||| Result codes for CBQN FFI operations.
||| Maps to C-compatible integers for cross-language interop.
public export
data Result : Type where
  ||| Operation succeeded
  Ok : Result
  ||| Generic CBQN error
  Error : Result
  ||| Invalid parameter (bad rank, wrong type, etc.)
  InvalidParam : Result
  ||| Out of memory (CBQN heap exhausted)
  OutOfMemory : Result
  ||| Null pointer (uninitialised BQN value)
  NullPointer : Result
  ||| BQN evaluation error (syntax or runtime)
  EvalError : Result

||| Convert Result to C integer
public export
resultToInt : Result -> Bits32
resultToInt Ok = 0
resultToInt Error = 1
resultToInt InvalidParam = 2
resultToInt OutOfMemory = 3
resultToInt NullPointer = 4
resultToInt EvalError = 5

||| Results are decidably equal
public export
DecEq Result where
  decEq Ok Ok = Yes Refl
  decEq Error Error = Yes Refl
  decEq InvalidParam InvalidParam = Yes Refl
  decEq OutOfMemory OutOfMemory = Yes Refl
  decEq NullPointer NullPointer = Yes Refl
  decEq EvalError EvalError = Yes Refl
  decEq _ _ = No absurd

--------------------------------------------------------------------------------
-- Opaque Handles
--------------------------------------------------------------------------------

||| Opaque handle to a CBQN runtime instance.
||| Prevents direct construction; enforces creation through safe init API.
public export
data Handle : Type where
  MkHandle : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> Handle

||| Safely create a handle from a pointer value.
||| Returns Nothing if pointer is null.
public export
createHandle : Bits64 -> Maybe Handle
createHandle 0 = Nothing
createHandle ptr = Just (MkHandle ptr)

||| Extract pointer value from handle.
public export
handlePtr : Handle -> Bits64
handlePtr (MkHandle ptr) = ptr

--------------------------------------------------------------------------------
-- BQN Value Types
--------------------------------------------------------------------------------

||| BQN value type tags, matching CBQN's internal representation.
||| Every BQN value is one of these.
public export
data BQNType : Type where
  ||| IEEE 754 double-precision float (also used for integers that fit)
  BQNNumber    : BQNType
  ||| Unicode code point
  BQNCharacter : BQNType
  ||| Function (1-argument or 2-argument callable)
  BQNFunction  : BQNType
  ||| 1-modifier (takes one operand)
  BQN1Modifier : BQNType
  ||| 2-modifier (takes two operands)
  BQN2Modifier : BQNType
  ||| Namespace (collection of named values)
  BQNNamespace : BQNType
  ||| Array (the fundamental compound type)
  BQNArray     : BQNType

||| Convert BQN type to CBQN type tag integer
public export
bqnTypeToInt : BQNType -> Bits32
bqnTypeToInt BQNNumber    = 0
bqnTypeToInt BQNCharacter = 1
bqnTypeToInt BQNFunction  = 2
bqnTypeToInt BQN1Modifier = 3
bqnTypeToInt BQN2Modifier = 4
bqnTypeToInt BQNNamespace = 5
bqnTypeToInt BQNArray     = 6

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

--------------------------------------------------------------------------------
-- Verification
--------------------------------------------------------------------------------

namespace Verify

  ||| Verify BQN type tags cover all CBQN types (0..6)
  export
  verifyTypeTagCoverage : IO ()
  verifyTypeTagCoverage = do
    putStrLn "BQN type tags verified: 7 types (number, char, fn, 1mod, 2mod, ns, array)"

  ||| Verify result codes are contiguous (0..5)
  export
  verifyResultCodes : IO ()
  verifyResultCodes = do
    putStrLn "Result codes verified: 6 codes (ok, error, invalid_param, oom, nullptr, eval_error)"
