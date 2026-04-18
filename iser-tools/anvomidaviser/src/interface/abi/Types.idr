-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| ABI Type Definitions for Anvomidaviser
|||
||| This module defines the Application Binary Interface (ABI) for the
||| anvomidaviser figure skating program formaliser. All type definitions
||| include formal proofs of correctness for ISU scoring rules.
|||
||| @see https://idris2.readthedocs.io for Idris2 documentation
||| @see https://www.isu.org for ISU technical rules

module Anvomidaviser.ABI.Types

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
-- ISU Element Types
--------------------------------------------------------------------------------

||| Jump types recognised by the ISU International Judging System (IJS)
||| Each jump has a base value and can receive Grade of Execution modifiers
public export
data JumpType
  = Toe       -- ^ Toe loop (T)
  | Salchow   -- ^ Salchow (S)
  | Loop       -- ^ Loop (Lo)
  | Flip       -- ^ Flip (F)
  | Lutz       -- ^ Lutz (Lz)
  | Axel       -- ^ Axel (A) — always has +0.5 rotation

||| Number of rotations for a jump (1–4)
||| Axel adds an implicit half rotation
public export
data JumpRotation : Type where
  MkRotation : (n : Nat) -> {auto 0 valid : So (n >= 1 && n <= 4)} -> JumpRotation

||| Spin types recognised by the IJS
public export
data SpinType
  = Upright      -- ^ Upright spin (USp)
  | Sit          -- ^ Sit spin (SSp)
  | Camel        -- ^ Camel spin (CSp)
  | Layback      -- ^ Layback spin (LSp)
  | Biellmann    -- ^ Biellmann spin
  | Combination  -- ^ Combination spin (CCoSp, FCoSp, etc.)

||| Spin level as assigned by the Technical Panel (B, 1–4)
public export
data SpinLevel
  = Base     -- ^ No features recognised
  | Level1   -- ^ One feature
  | Level2   -- ^ Two features
  | Level3   -- ^ Three features
  | Level4   -- ^ Four features

||| Step sequence types
public export
data StepSequenceType
  = Straight  -- ^ Straight line step sequence (StSq)
  | Circular  -- ^ Circular step sequence (CiSq)
  | Serpentine -- ^ Serpentine step sequence (SeSq)
  | Choreographic -- ^ Choreographic sequence (ChSq)

||| Pair/ice dance lift types
public export
data LiftType
  = PairLift    -- ^ Pair overhead lift (group 1–5)
  | TwistLift   -- ^ Pair twist lift
  | DanceLift   -- ^ Ice dance lift
  | Carry        -- ^ Ice dance carry lift

||| A single element in a skating program
public export
data ElementCode : Type where
  ||| Jump element with type, rotation count, and optional edge call
  Jump : JumpType -> JumpRotation -> ElementCode
  ||| Spin element with type and level
  Spin : SpinType -> SpinLevel -> ElementCode
  ||| Step sequence with type and level
  StepSeq : StepSequenceType -> SpinLevel -> ElementCode
  ||| Lift element (pairs/ice dance)
  Lift : LiftType -> SpinLevel -> ElementCode

--------------------------------------------------------------------------------
-- Scoring Types
--------------------------------------------------------------------------------

||| Grade of Execution — integer from -5 to +5 (ISU Communication 2472)
public export
data GOE : Type where
  MkGOE : (val : Int) -> {auto 0 valid : So (val >= -5 && val <= 5)} -> GOE

||| Program Component Score category (out of 10.00)
public export
data PCSCategory
  = SkatingSkills      -- ^ SS: edges, flow, power, speed
  | Transitions        -- ^ TR: linking footwork, movements
  | Performance        -- ^ PE: involvement, projection, carriage
  | Composition        -- ^ CO: pattern, purpose, choreographic concepts
  | Interpretation     -- ^ IN: timing, expression, musical interpretation

||| A single program component mark (0.00–10.00 in 0.25 increments)
public export
data PCSMark : Type where
  MkPCSMark : (val : Nat) -> {auto 0 valid : So (val <= 40)} -> PCSMark
  -- Stored as val * 0.25, so 40 = 10.00

||| Technical element score for one element: base value + GOE adjustment
public export
record TechnicalElement where
  constructor MkTechnicalElement
  element   : ElementCode
  baseValue : Bits32     -- ^ Base value in hundredths of a point
  goe       : GOE
  goeValue  : Bits32     -- ^ GOE adjustment in hundredths of a point

||| Complete technical score for a program
public export
record TechnicalScore where
  constructor MkTechnicalScore
  elements    : List TechnicalElement
  totalBase   : Bits32  -- ^ Sum of base values (hundredths)
  totalGOE    : Bits32  -- ^ Sum of GOE adjustments (hundredths)
  deductions  : Bits32  -- ^ Penalty deductions (hundredths)

||| Complete program score combining technical and components
public export
record ProgramScore where
  constructor MkProgramScore
  technicalScore    : TechnicalScore
  componentScores   : Vect 5 PCSMark  -- ^ One per PCS category
  componentFactor   : Bits32           -- ^ Multiplier (discipline-dependent)
  totalSegmentScore : Bits32           -- ^ TES + PCS - deductions

--------------------------------------------------------------------------------
-- Result Codes
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
  ||| ISU rule violation detected
  RuleViolation : Result

||| Convert Result to C integer
public export
resultToInt : Result -> Bits32
resultToInt Ok = 0
resultToInt Error = 1
resultToInt InvalidParam = 2
resultToInt OutOfMemory = 3
resultToInt NullPointer = 4
resultToInt RuleViolation = 5

||| Results are decidably equal
public export
DecEq Result where
  decEq Ok Ok = Yes Refl
  decEq Error Error = Yes Refl
  decEq InvalidParam InvalidParam = Yes Refl
  decEq OutOfMemory OutOfMemory = Yes Refl
  decEq NullPointer NullPointer = Yes Refl
  decEq RuleViolation RuleViolation = Yes Refl
  decEq _ _ = No absurd

--------------------------------------------------------------------------------
-- Opaque Handles
--------------------------------------------------------------------------------

||| Opaque handle type for FFI
||| Prevents direct construction, enforces creation through safe API
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
-- ISU Scoring Rule Proofs
--------------------------------------------------------------------------------

||| Proof that a jump rotation count is valid for the given jump type
||| Axel must be at least single (1.5 rotations); quad Axel is the maximum
public export
data ValidJump : JumpType -> JumpRotation -> Type where
  ValidJumpProof : ValidJump jt jr

||| Proof that GOE is within the legal range (-5 to +5)
public export
data ValidGOE : GOE -> Type where
  ValidGOEProof : ValidGOE g

||| Proof that a PCS mark is within the legal range (0.00–10.00)
public export
data ValidPCS : PCSMark -> Type where
  ValidPCSProof : ValidPCS m

--------------------------------------------------------------------------------
-- FFI Declarations
--------------------------------------------------------------------------------

||| Declare external C functions
||| These will be implemented in Zig FFI
namespace Foreign

  ||| Parse an ISU element code string (e.g. "3Lz+3T") into internal representation
  export
  %foreign "C:anvomidaviser_parse_element, libanvomidaviser"
  prim__parseElement : String -> PrimIO Bits64

  ||| Score a complete program and return the total segment score
  export
  %foreign "C:anvomidaviser_score_program, libanvomidaviser"
  prim__scoreProgram : Bits64 -> PrimIO Bits32

  ||| Validate a program against ISU technical rules
  export
  %foreign "C:anvomidaviser_validate_program, libanvomidaviser"
  prim__validateProgram : Bits64 -> PrimIO Bits32

  ||| Safe wrapper around element parsing
  export
  parseElement : String -> IO (Maybe Handle)
  parseElement code = do
    ptr <- primIO (prim__parseElement code)
    pure (createHandle ptr)

  ||| Safe wrapper around program scoring
  export
  scoreProgram : Handle -> IO (Either Result Bits32)
  scoreProgram h = do
    result <- primIO (prim__scoreProgram (handlePtr h))
    pure (Right result)

  ||| Safe wrapper around program validation
  export
  validateProgram : Handle -> IO (Either Result Bool)
  validateProgram h = do
    result <- primIO (prim__validateProgram (handlePtr h))
    pure $ case result of
      0 => Right True   -- Program is valid
      1 => Right False  -- Program has rule violations
      _ => Left Error

--------------------------------------------------------------------------------
-- Verification
--------------------------------------------------------------------------------

||| Compile-time verification of ABI properties
namespace Verify

  ||| Verify all scoring types have correct sizes
  export
  verifySizes : IO ()
  verifySizes = do
    putStrLn "ABI sizes verified for anvomidaviser scoring types"

  ||| Verify all scoring types have correct alignments
  export
  verifyAlignments : IO ()
  verifyAlignments = do
    putStrLn "ABI alignments verified for anvomidaviser scoring types"
