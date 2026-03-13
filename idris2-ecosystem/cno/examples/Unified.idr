-- SPDX-License-Identifier: MPL-2.0
||| Unified Example: echidna + dyadt + cno
|||
||| This example demonstrates how the three proven Idris2 libraries
||| work together:
|||
||| - idris2-echidna: Theorem prover bindings
||| - idris2-dyadt: Compile-time verified claims
||| - idris2-cno: Certified Null Operations
|||
||| Together they form a complete verification ecosystem.
module Examples.Unified

import CNO
import CNO.Integration.Dyadt
import CNO.Integration.Echidna

%default total

-------------------------------------------------------------------
-- Example 1: Basic CNO with Dyadt Verification
-------------------------------------------------------------------

||| A simple CNO that's verified via dyadt claims
example1 : DyadtVerifiedCNO Integer
example1 = dyadtVerify "add_zero" addZero

||| Use the verified CNO
useExample1 : Integer
useExample1 = runDyadtVerified example1 42
-- Result: 42 (proven at compile time to be unchanged)

-------------------------------------------------------------------
-- Example 2: CNO Chain with Verification
-------------------------------------------------------------------

||| Build a chain of verified operations
example2Chain : List (DyadtVerifiedCNO Integer)
example2Chain =
  [ dyadtVerify "noop1" idCNO
  , dyadtVerify "addZero" addZero
  , dyadtVerify "mulOne" multiplyOne
  , dyadtVerify "noop2" idCNO
  ]

||| Apply the entire chain (result is identity)
applyChain : Integer -> Integer
applyChain x = foldl (\acc, dv => runDyadtVerified dv acc) x example2Chain

-------------------------------------------------------------------
-- Example 3: Complex CNO with Echidna Proof
-------------------------------------------------------------------

||| A CNO that might need external theorem proving
||| The proof obligations would be discharged by echidna
example3 : ProofCarryingCNO Integer
example3 = withExternalProof
  idCNO
  "sha256:abc123..."  -- Reference to external proof
  "Z3"                -- Prover used
  [ProveIdentity "complex_transform" "Int"]

-------------------------------------------------------------------
-- Example 4: Composing Different Verification Methods
-------------------------------------------------------------------

||| First CNO: type-level proof (Idris2 built-in)
typeLevelCNO : CNO Integer
typeLevelCNO = MkCNO id (\x => Refl)

||| Second CNO: dyadt-verified
dyadtCNO : DyadtVerifiedCNO Integer
dyadtCNO = dyadtVerify "dyadt_verified" idCNO

||| Third CNO: echidna-proved (in a real scenario)
echidnaCNO : ProofCarryingCNO Integer
echidnaCNO = withExternalProof idCNO "proof_ref" "Z3" []

||| Compose them all (the result is still a CNO!)
composedResult : Integer -> Integer
composedResult x =
  let step1 = runCNO typeLevelCNO x
      step2 = runDyadtVerified dyadtCNO step1
      step3 = runCNO (extractCNO echidnaCNO) step2
  in step3
-- Result: x (unchanged through all transformations)

-------------------------------------------------------------------
-- Example 5: The Full Ecosystem in Action
-------------------------------------------------------------------

||| A complete verification workflow:
|||
||| 1. Define a claim (dyadt)
||| 2. Prove it with a theorem prover (echidna)
||| 3. Use the result as a CNO (cno)
|||
||| This shows the complete integration.

||| Step 1: Define what we want to verify
record VerificationWorkflow where
  constructor MkWorkflow
  ||| Name of the operation
  name : String
  ||| The CNO to verify
  operation : CNO Integer
  ||| Proof obligation for echidna
  obligation : ProofObligation
  ||| Whether it's been verified
  verified : Bool

||| Step 2: Create a workflow
exampleWorkflow : VerificationWorkflow
exampleWorkflow = MkWorkflow
  "double_identity"
  (compose idCNO idCNO)  -- id . id
  (ProveComposition "id" "id" "Int")
  True  -- Assume verified by echidna

||| Step 3: Run if verified
runIfVerified : VerificationWorkflow -> Integer -> Maybe Integer
runIfVerified wf x =
  if wf.verified
    then Just (runCNO wf.operation x)
    else Nothing

-------------------------------------------------------------------
-- Summary
-------------------------------------------------------------------

||| The proven ecosystem provides:
|||
||| 1. Type-level proofs (built into Idris2)
|||    - Compile-time verification
|||    - No runtime cost
|||
||| 2. Dyadt claims (idris2-dyadt)
|||    - Express what needs to be true
|||    - Evidence-based verification
|||
||| 3. Theorem proving (idris2-echidna)
|||    - For complex proofs type-checking can't handle
|||    - 12+ provers available
|||
||| 4. CNO certification (idris2-cno)
|||    - Prove operations are identity
|||    - Composition preserves the property
|||
||| Together: complete verification from types to theorems to certified operations.

