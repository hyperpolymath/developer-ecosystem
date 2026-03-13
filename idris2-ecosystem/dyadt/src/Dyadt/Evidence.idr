-- SPDX-License-Identifier: MPL-2.0
||| Evidence as Dependent Types
|||
||| Evidence is indexed by the claim it supports. You can only construct
||| evidence for a claim if the claim is actually true. This is enforced
||| by the type system.
|||
||| The key insight is that Evidence is a type family indexed by Claim.
||| `Evidence (FileExists "/etc/passwd")` is a different type than
||| `Evidence (FileExists "/nonexistent")`, and only the former can
||| be inhabited (have values constructed).
module Dyadt.Evidence

import Dyadt.Claim

-- Note: Not marked total because Evidence uses negative recursion
-- in NotEvidence : (Evidence c -> Void) -> Evidence (Not c)
-- This is intentional for representing refutation proofs.

-------------------------------------------------------------------
-- Dependent List Types (defined first to avoid forward references)
-------------------------------------------------------------------

||| All elements of a list satisfy a predicate
public export
data AllOf : (a -> Type) -> List a -> Type where
  AllNil : {0 f : a -> Type} -> AllOf f []
  AllCons : {0 f : a -> Type} -> {0 x : a} -> {0 xs : List a} ->
            f x -> AllOf f xs -> AllOf f (x :: xs)

||| At least one element of a list satisfies a predicate
public export
data AnyOf : (a -> Type) -> List a -> Type where
  AnyHere : {0 f : a -> Type} -> {0 x : a} -> {0 xs : List a} ->
            f x -> AnyOf f (x :: xs)
  AnyThere : {0 f : a -> Type} -> {0 x : a} -> {0 xs : List a} ->
             AnyOf f xs -> AnyOf f (x :: xs)

-- Note: Helper functions like headOf, tailOf, mapAllOf omitted
-- due to Idris2 implicit argument inference issues.
-- Users can pattern match directly on AllCons/AllNil.

-------------------------------------------------------------------
-- Evidence Type
-------------------------------------------------------------------

||| Evidence supporting a claim
|||
||| This is a dependent type - the type of evidence depends on the claim.
||| Each constructor produces evidence for a specific claim pattern.
public export
data Evidence : Claim -> Type where
  ||| Evidence that a file exists
  ||| In practice, this would be obtained by a compile-time check or
  ||| by trusting user assertion in elaboration
  FileExistsEvidence : Evidence (FileExists path)

  ||| Evidence that a file has the claimed hash
  FileHashEvidence : Evidence (FileWithHash path hash)

  ||| Evidence that a file contains the substring
  FileContainsEvidence : Evidence (FileContains path substring)

  ||| Evidence that a file matches the regex
  FileRegexEvidence : Evidence (FileMatchesRegex path pattern)

  ||| Evidence that a directory exists
  DirectoryExistsEvidence : Evidence (DirectoryExists path)

  ||| Evidence that a command succeeds
  CommandSucceedsEvidence : Evidence (CommandSucceeds cmd args)

  ||| Evidence that git working directory is clean
  GitCleanEvidence : Evidence (GitClean repoPath)

  ||| Evidence that a git commit exists
  GitCommitExistsEvidence : Evidence (GitCommitExists commit repoPath)

  ||| Evidence that a git branch exists
  GitBranchExistsEvidence : Evidence (GitBranchExists branch repoPath)

  ||| Evidence that an env var equals a value
  EnvVarEqualsEvidence : Evidence (EnvVarEquals name value)

  ||| Evidence that an env var is set
  EnvVarSetEvidence : Evidence (EnvVarSet name)

  ||| Evidence for JSON path equality
  JsonPathEvidence : Evidence (JsonPathEquals path jsonPath expected)

  ||| Evidence for conjunction: evidence for both claims
  BothEvidence : Evidence a -> Evidence b -> Evidence (And a b)

  ||| Evidence for disjunction: evidence for left claim
  LeftEvidence : Evidence a -> Evidence (Or a b)

  ||| Evidence for disjunction: evidence for right claim
  RightEvidence : Evidence b -> Evidence (Or a b)

  ||| Evidence for negation (requires refutation)
  ||| This is tricky - we need evidence that the claim is false
  NotEvidence : (Evidence c -> Void) -> Evidence (Not c)

  ||| Evidence for all claims in a list
  AllEvidence : AllOf Evidence claims -> Evidence (AllClaims claims)

  ||| Evidence for any claim in a list
  AnyEvidence : AnyOf Evidence claims -> Evidence (AnyClaim claims)

  ||| Custom evidence with proof
  CustomEvidence : Evidence (Custom name params)

-------------------------------------------------------------------
-- Type Aliases and Helpers
-------------------------------------------------------------------

||| Type alias for lists of evidence
public export
Evidences : List Claim -> Type
Evidences = AllOf Evidence

||| Combine two pieces of evidence
public export
combine : Evidence a -> Evidence b -> Evidence (And a b)
combine = BothEvidence

||| Choose left evidence
public export
left : Evidence a -> Evidence (Or a b)
left = LeftEvidence

||| Choose right evidence
public export
right : Evidence b -> Evidence (Or a b)
right = RightEvidence
