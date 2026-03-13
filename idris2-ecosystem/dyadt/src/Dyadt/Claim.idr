-- SPDX-License-Identifier: MPL-2.0
||| Claims as Types
|||
||| In this library, claims are represented as types. A claim is something
||| that can be verified, and the type encodes exactly what is being claimed.
|||
||| This mirrors the Rust `did-you-actually-do-that` evidence types, but
||| as compile-time constructs rather than runtime data.
module Dyadt.Claim

import Data.List

%default total

||| A path in the filesystem (for type-level computation)
public export
Path : Type
Path = String

||| A SHA-256 hash (for type-level computation)
public export
Hash : Type
Hash = String

||| A regular expression pattern
public export
Pattern : Type
Pattern = String

||| A command to execute
public export
Command : Type
Command = String

||| An environment variable name
public export
EnvVar : Type
EnvVar = String

||| A git commit hash or reference
public export
GitRef : Type
GitRef = String

||| A branch name
public export
Branch : Type
Branch = String

||| Claims that can be verified
|||
||| Each constructor represents a different kind of verifiable claim,
||| mirroring the EvidenceSpec enum from did-you-actually-do-that.
public export
data Claim : Type where
  ||| Claim that a file exists at the given path
  FileExists : (path : Path) -> Claim

  ||| Claim that a file has a specific SHA-256 hash
  FileWithHash : (path : Path) -> (hash : Hash) -> Claim

  ||| Claim that a file contains a substring
  FileContains : (path : Path) -> (substring : String) -> Claim

  ||| Claim that a file matches a regex pattern
  FileMatchesRegex : (path : Path) -> (pattern : Pattern) -> Claim

  ||| Claim that a directory exists
  DirectoryExists : (path : Path) -> Claim

  ||| Claim that a command succeeds (exit code 0)
  CommandSucceeds : (cmd : Command) -> (args : List String) -> Claim

  ||| Claim that the git working directory is clean
  GitClean : (repoPath : Maybe Path) -> Claim

  ||| Claim that a git commit exists
  GitCommitExists : (commit : GitRef) -> (repoPath : Maybe Path) -> Claim

  ||| Claim that a git branch exists
  GitBranchExists : (branch : Branch) -> (repoPath : Maybe Path) -> Claim

  ||| Claim that an environment variable has a specific value
  EnvVarEquals : (name : EnvVar) -> (value : String) -> Claim

  ||| Claim that an environment variable is set (any value)
  EnvVarSet : (name : EnvVar) -> Claim

  ||| Claim that a JSON file has a value at a path
  JsonPathEquals : (path : Path) -> (jsonPath : String) -> (expected : String) -> Claim

  ||| Conjunction: both claims must hold
  And : Claim -> Claim -> Claim

  ||| Disjunction: at least one claim must hold
  Or : Claim -> Claim -> Claim

  ||| Negation: the claim must not hold
  Not : Claim -> Claim

  ||| All claims in the list must hold
  AllClaims : List Claim -> Claim

  ||| At least one claim in the list must hold
  AnyClaim : List Claim -> Claim

  ||| Custom claim with a name and parameters
  Custom : (name : String) -> (params : List (String, String)) -> Claim

||| Show a claim (for debugging)
||| Note: Recursive so marked partial
export
partial
showClaim : Claim -> String
showClaim (FileExists path) = "FileExists(" ++ path ++ ")"
showClaim (FileWithHash path hash) = "FileWithHash(" ++ path ++ ", " ++ hash ++ ")"
showClaim (FileContains path sub) = "FileContains(" ++ path ++ ", " ++ sub ++ ")"
showClaim (FileMatchesRegex path pat) = "FileMatchesRegex(" ++ path ++ ", " ++ pat ++ ")"
showClaim (DirectoryExists path) = "DirectoryExists(" ++ path ++ ")"
showClaim (CommandSucceeds cmd args) = "CommandSucceeds(" ++ cmd ++ ", " ++ show args ++ ")"
showClaim (GitClean repo) = "GitClean(" ++ show repo ++ ")"
showClaim (GitCommitExists commit repo) = "GitCommitExists(" ++ commit ++ ", " ++ show repo ++ ")"
showClaim (GitBranchExists branch repo) = "GitBranchExists(" ++ branch ++ ", " ++ show repo ++ ")"
showClaim (EnvVarEquals name val) = "EnvVarEquals(" ++ name ++ ", " ++ val ++ ")"
showClaim (EnvVarSet name) = "EnvVarSet(" ++ name ++ ")"
showClaim (JsonPathEquals path jp exp) = "JsonPathEquals(" ++ path ++ ", " ++ jp ++ ", " ++ exp ++ ")"
showClaim (And a b) = "And(" ++ showClaim a ++ ", " ++ showClaim b ++ ")"
showClaim (Or a b) = "Or(" ++ showClaim a ++ ", " ++ showClaim b ++ ")"
showClaim (Not c) = "Not(" ++ showClaim c ++ ")"
showClaim (AllClaims cs) = "AllClaims(" ++ show (map showClaim cs) ++ ")"
showClaim (AnyClaim cs) = "AnyClaim(" ++ show (map showClaim cs) ++ ")"
showClaim (Custom name params) = "Custom(" ++ name ++ ", " ++ show params ++ ")"

||| Show instance for claims (for debugging)
public export
%hint
partial
showClaimImpl : Show Claim
showClaimImpl = MkShow showClaim (\_ => showClaim)

||| Equality for claims
public export
Eq Claim where
  FileExists p1 == FileExists p2 = p1 == p2
  FileWithHash p1 h1 == FileWithHash p2 h2 = p1 == p2 && h1 == h2
  FileContains p1 s1 == FileContains p2 s2 = p1 == p2 && s1 == s2
  DirectoryExists p1 == DirectoryExists p2 = p1 == p2
  And a1 b1 == And a2 b2 = a1 == a2 && b1 == b2
  Or a1 b1 == Or a2 b2 = a1 == a2 && b1 == b2
  Not c1 == Not c2 = c1 == c2
  _ == _ = False

||| Infix operator for conjunction
public export
(&&) : Claim -> Claim -> Claim
(&&) = And

||| Infix operator for disjunction
public export
(||) : Claim -> Claim -> Claim
(||) = Or

||| Negate a claim
public export
not : Claim -> Claim
not = Not
