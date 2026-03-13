-- SPDX-License-Identifier: MPL-2.0
||| Claim Combinators
|||
||| DSL for building complex claims from simple ones.
||| These combinators mirror the fluent API from the Rust did-you-actually-do-that
||| crate, but as type-level operations.
module Dyadt.Combinators

import Dyadt.Claim
import Dyadt.Evidence
import Dyadt.Verdict

%default total

-------------------------------------------------------------------
-- File Claims
-------------------------------------------------------------------

||| Claim that a file exists
public export
file : Path -> Claim
file = FileExists

||| Claim that a file has a specific hash
public export
fileWithHash : Path -> Hash -> Claim
fileWithHash = FileWithHash

||| Claim that a file contains a substring
public export
fileContains : Path -> String -> Claim
fileContains = FileContains

||| Claim that a file matches a regex
public export
fileMatches : Path -> Pattern -> Claim
fileMatches = FileMatchesRegex

||| Claim about a JSON file's content
public export
jsonPath : Path -> String -> String -> Claim
jsonPath = JsonPathEquals

-------------------------------------------------------------------
-- Directory Claims
-------------------------------------------------------------------

||| Claim that a directory exists
public export
dir : Path -> Claim
dir = DirectoryExists

-------------------------------------------------------------------
-- Command Claims
-------------------------------------------------------------------

||| Claim that a command succeeds
public export
cmd : Command -> Claim
cmd c = CommandSucceeds c []

||| Claim that a command with arguments succeeds
public export
cmdWithArgs : Command -> List String -> Claim
cmdWithArgs = CommandSucceeds

||| Common commands
public export
make : Claim
make = cmd "make"

public export
cargoTest : Claim
cargoTest = cmdWithArgs "cargo" ["test"]

public export
cargoBuild : Claim
cargoBuild = cmdWithArgs "cargo" ["build"]

public export
npmTest : Claim
npmTest = cmdWithArgs "npm" ["test"]

-------------------------------------------------------------------
-- Git Claims
-------------------------------------------------------------------

||| Claim that git working directory is clean
public export
gitClean : Claim
gitClean = GitClean Nothing

||| Claim that git is clean in a specific repo
public export
gitCleanIn : Path -> Claim
gitCleanIn p = GitClean (Just p)

||| Claim that a commit exists
public export
commitExists : GitRef -> Claim
commitExists ref = GitCommitExists ref Nothing

||| Claim that a branch exists
public export
branchExists : Branch -> Claim
branchExists b = GitBranchExists b Nothing

-------------------------------------------------------------------
-- Environment Claims
-------------------------------------------------------------------

||| Claim that an env var is set
public export
envSet : EnvVar -> Claim
envSet = EnvVarSet

||| Claim that an env var equals a value
public export
envEquals : EnvVar -> String -> Claim
envEquals = EnvVarEquals

||| Common environment checks
public export
ciEnvironment : Claim
ciEnvironment = envSet "CI"

public export
productionEnv : Claim
productionEnv = envEquals "NODE_ENV" "production"

-------------------------------------------------------------------
-- Combinators
-------------------------------------------------------------------

||| All claims must hold
public export
all : List Claim -> Claim
all = AllClaims

||| Any claim must hold
public export
any : List Claim -> Claim
any = AnyClaim

||| Both claims must hold
public export
both : Claim -> Claim -> Claim
both = And

||| At least one claim must hold
public export
oneOf : Claim -> Claim -> Claim
oneOf = Or

||| The claim must not hold
public export
none : Claim -> Claim
none = Not

||| If a then b (implication as claim)
public export
implies : Claim -> Claim -> Claim
implies a b = Or (Not a) b

||| Biconditional
public export
iff : Claim -> Claim -> Claim
iff a b = And (implies a b) (implies b a)

-------------------------------------------------------------------
-- Common Patterns
-------------------------------------------------------------------

||| Project has a specific file structure
public export
projectStructure : List Path -> Claim
projectStructure paths = all (map file paths)

||| Standard Rust project structure
public export
rustProject : Claim
rustProject = projectStructure
  [ "Cargo.toml"
  , "src/lib.rs"
  ]

||| Standard Node.js project structure
public export
nodeProject : Claim
nodeProject = projectStructure
  [ "package.json"
  , "src/index.js"
  ]

||| Build passes
public export
buildPasses : Command -> List String -> Claim
buildPasses = cmdWithArgs

||| Tests pass
public export
testsPasses : Command -> List String -> Claim
testsPasses = cmdWithArgs

-------------------------------------------------------------------
-- Syntax Sugar
-------------------------------------------------------------------

infixr 3 `and`
infixr 2 `or`
prefix 9 `not`

||| Infix and
public export
and : Claim -> Claim -> Claim
and = And

||| Infix or
public export
or : Claim -> Claim -> Claim
or = Or
