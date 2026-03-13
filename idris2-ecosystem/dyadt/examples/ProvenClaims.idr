-- SPDX-License-Identifier: MPL-2.0
||| Proven Claims Example
|||
||| Demonstrates how dyadt claims can be verified at compile time.
module Examples.ProvenClaims

import Dyadt
import Dyadt.Combinators

%default total

-------------------------------------------------------------------
-- Example 1: Simple File Claims
-------------------------------------------------------------------

||| Claim that a config file exists
||| If this compiles, the claim is well-formed
configClaim : Claim
configClaim = file "config.toml"

||| Claim with hash verification
hashClaim : Claim
hashClaim = fileWithHash "Cargo.toml" "sha256:abc123"

-------------------------------------------------------------------
-- Example 2: Compound Claims
-------------------------------------------------------------------

||| A project is ready to build when:
||| - Cargo.toml exists
||| - src/lib.rs exists
||| - Git working directory is clean
buildReadyClaim : Claim
buildReadyClaim = all
  [ file "Cargo.toml"
  , file "src/lib.rs"
  , gitClean
  ]

||| Using infix syntax
deployReadyClaim : Claim
deployReadyClaim =
  file "Cargo.toml" `and`
  gitClean `and`
  envSet "DEPLOY_KEY" `and`
  cargoTest

-------------------------------------------------------------------
-- Example 3: Type-Level Verification
-------------------------------------------------------------------

||| If this type-checks, we have evidence of the file claim
||| (In practice, would need elaboration-time file checking)
exampleEvidence : Evidence (FileExists "example.txt")
exampleEvidence = FileExistsEvidence

||| Combined evidence
combinedEvidence : Evidence (And (FileExists "a.txt") (FileExists "b.txt"))
combinedEvidence = BothEvidence FileExistsEvidence FileExistsEvidence

-------------------------------------------------------------------
-- Example 4: Verified Wrappers
-------------------------------------------------------------------

||| A verified claim at the type level
exampleVerified : Verified (FileExists "README.md")
exampleVerified = MkVerified FileExistsEvidence

-------------------------------------------------------------------
-- Example 5: Integration Patterns
-------------------------------------------------------------------

||| Standard Rust project verification
rustProjectClaims : Claim
rustProjectClaims = rustProject `and` cargoTest `and` gitClean

||| CI environment check
ciEnvironmentClaims : Claim
ciEnvironmentClaims =
  ciEnvironment `and`
  envSet "CI_COMMIT_SHA" `and`
  file "Cargo.toml"

-------------------------------------------------------------------
-- Example 6: Custom Claims
-------------------------------------------------------------------

||| Custom claim for domain-specific verification
databaseReady : Claim
databaseReady = Custom "database_migrations_current" []

||| Custom claim with parameters
apiKeyValid : String -> Claim
apiKeyValid keyName = Custom "api_key_valid" [keyName]

