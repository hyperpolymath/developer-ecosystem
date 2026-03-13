-- SPDX-License-Identifier: MPL-2.0
||| Verdicts: The Result of Verification
|||
||| In runtime verification, a verdict is a value (Confirmed/Refuted/etc).
||| In compile-time verification, a verdict is a type that is inhabited
||| only if the claim is verified.
|||
||| The key type is `Verified claim` - if you have a value of this type,
||| the claim has been verified at compile time.
module Dyadt.Verdict

import Dyadt.Claim
import Dyadt.Evidence

-- Note: Not marked total because Evidence module is not total

||| A verified claim
|||
||| This is the key type of the library. A value of type `Verified claim`
||| is proof that `claim` has been verified. You can only construct this
||| if you have valid evidence.
|||
||| This is analogous to runtime's `Verdict::Confirmed`, but enforced
||| by the type system rather than runtime checks.
public export
data Verified : Claim -> Type where
  ||| A claim is verified if we have evidence for it
  MkVerified : Evidence claim -> Verified claim

||| Verified conjunction
public export
data VerifiedBoth : Claim -> Claim -> Type where
  MkVerifiedBoth : Verified a -> Verified b -> VerifiedBoth a b

||| Verified disjunction
public export
data VerifiedEither : Claim -> Claim -> Type where
  VerifiedLeft : Verified a -> VerifiedEither a b
  VerifiedRight : Verified b -> VerifiedEither a b

||| Verified list (all claims) using our AllOf type
public export
data VerifiedAll : List Claim -> Type where
  MkVerifiedAll : AllOf Evidence claims -> VerifiedAll claims

||| Verified list (any claim) using our AnyOf type
public export
data VerifiedAny : List Claim -> Type where
  MkVerifiedAny : AnyOf Evidence claims -> VerifiedAny claims

||| Extract evidence from a verified claim
public export
evidence : Verified claim -> Evidence claim
evidence (MkVerified ev) = ev

||| A verified claim implies the claim holds
||| This is the elimination principle for Verified
public export
verified : Verified claim -> Evidence claim
verified = evidence

||| Trust assertion: declare a claim is verified without evidence
||| USE WITH CAUTION - this breaks the verification guarantee
||| Only use when you have external assurance the claim holds
public export
trustMe : {claim : Claim} -> Verified claim
-- PROOF_TODO: Replace cast with actual proof
-- PROOF_TODO: Replace cast with actual proof
trustMe = MkVerified (cast ())

||| Runtime fallback for claims that can't be checked at compile time
||| Note: Implementation would need System.File, etc.
public export
verifyAtRuntime : (claim : Claim) -> IO (Maybe (Verified claim))
verifyAtRuntime claim = pure Nothing  -- Stub: actual impl needs file operations
