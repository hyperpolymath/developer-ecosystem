-- SPDX-License-Identifier: MPL-2.0
||| Did You Actually Do That? - Compile-Time Edition
|||
||| This library provides compile-time verification of claims using Idris2's
||| dependent type system. Where the Rust `did-you-actually-do-that` crate
||| performs runtime verification, this library encodes claims as types,
||| turning verification into type checking.
|||
||| ## Core Concept
|||
||| In runtime verification:
||| ```
||| Claim → Evidence → Runtime Check → Verdict
||| ```
|||
||| In compile-time verification:
||| ```
||| Claim : Type → Evidence : Claim → Type Checker → Compiles (or not)
||| ```
|||
||| ## Quick Start
|||
||| ```idris
||| import Dyadt
|||
||| ||| A claim that a file exists - proven at compile time
||| fileExistsProof : Verified (FileExists "/etc/passwd")
||| fileExistsProof = verify FileExistsEvidence
|||
||| ||| A claim with multiple evidence requirements
||| configValid : Verified (All [FileExists "config.toml", FileContains "config.toml" "version"])
||| configValid = verifyAll [FileExistsEvidence, FileContainsEvidence]
||| ```
module Dyadt

import public Dyadt.Claim
import public Dyadt.Evidence
import public Dyadt.Verdict
import public Dyadt.Verifier
import public Dyadt.Combinators

||| Library version
public export
dyadtVersion : String
dyadtVersion = "0.1.0"

||| The core verification function - if this compiles, the claim is verified
|||
||| @claim The claim to verify
||| @evidence The evidence supporting the claim
public export
verify : {claim : Claim} -> (evidence : Evidence claim) -> Verified claim
verify ev = MkVerified ev

||| Verify multiple claims at once
public export
verifyAll : {claims : List Claim} -> AllOf Evidence claims -> Verified (AllClaims claims)
verifyAll evs = MkVerified (AllEvidence evs)

||| Verify at least one of multiple claims
public export
verifyAny : {claims : List Claim} -> AnyOf Evidence claims -> Verified (AnyClaim claims)
verifyAny ev = MkVerified (AnyEvidence ev)

||| A verified claim can be used as evidence for dependent claims
public export
useVerified : Verified claim -> Evidence claim
useVerified (MkVerified ev) = ev

||| Chain verification: if A is verified and A implies B, then B is verified
public export
chain : Verified a -> (Evidence a -> Evidence b) -> Verified b
chain (MkVerified ev) f = MkVerified (f ev)

||| Combine two verifications
public export
both : Verified a -> Verified b -> Verified (And a b)
both (MkVerified ea) (MkVerified eb) = MkVerified (BothEvidence ea eb)

||| Either of two verifications
public export
either : Either (Verified a) (Verified b) -> Verified (Or a b)
either (Left (MkVerified ea)) = MkVerified (LeftEvidence ea)
either (Right (MkVerified eb)) = MkVerified (RightEvidence eb)
