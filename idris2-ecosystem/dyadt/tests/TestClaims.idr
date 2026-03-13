-- SPDX-License-Identifier: MPL-2.0
||| Dyadt Claims Tests
|||
||| These tests verify claim construction and evidence types.
||| If this module compiles, the type-level proofs are valid.
module TestClaims

import Dyadt
import Dyadt.Claim
import Dyadt.Evidence
import Dyadt.Verdict

-------------------------------------------------------------------
-- Test: Basic Claim Construction
-------------------------------------------------------------------

||| A simple file existence claim
testFileExists : Claim
testFileExists = FileExists "/etc/passwd"

||| A claim with hash verification
testFileWithHash : Claim
testFileWithHash = FileWithHash "config.json" "abc123"

||| Git clean claim
testGitClean : Claim
testGitClean = GitClean (Just "/home/user/repo")

-------------------------------------------------------------------
-- Test: Compound Claims
-------------------------------------------------------------------

||| And combination
testAndClaim : Claim
testAndClaim = And (FileExists "a.txt") (FileExists "b.txt")

||| Or combination
testOrClaim : Claim
testOrClaim = Or (FileExists "a.txt") (FileExists "b.txt")

||| Negation
testNotClaim : Claim
testNotClaim = Not (FileExists "should-not-exist.txt")

||| All claims
testAllClaims : Claim
testAllClaims = AllClaims [FileExists "a.txt", FileExists "b.txt", FileExists "c.txt"]

-------------------------------------------------------------------
-- Test: Custom Claims
-------------------------------------------------------------------

||| Custom claim with parameters
testCustomClaim : Claim
testCustomClaim = Custom "my-verification" []

-------------------------------------------------------------------
-- Test: Evidence Construction (AllOf)
-------------------------------------------------------------------

||| Empty AllOf evidence
emptyAllOf : AllOf (\x => x = x) []
emptyAllOf = AllNil

||| Evidence that a predicate holds for all elements
exampleAllOfStructure : AllOf (\n => n = n) [1, 2, 3]
exampleAllOfStructure = AllCons Refl (AllCons Refl (AllCons Refl AllNil))

-------------------------------------------------------------------
-- Test: Evidence Construction (AnyOf)
-------------------------------------------------------------------

||| AnyOf evidence for first element
exampleAnyHere : AnyOf (\n => n = 1) [1, 2, 3]
exampleAnyHere = AnyHere Refl

||| AnyOf evidence for second element
exampleAnyThere : AnyOf (\n => n = 2) [1, 2, 3]
exampleAnyThere = AnyThere (AnyHere Refl)

-------------------------------------------------------------------
-- Test: Verdict Types
-------------------------------------------------------------------

||| A verified result type
exampleVerified : Verified (Custom "test" [])
exampleVerified = MkVerified CustomEvidence
