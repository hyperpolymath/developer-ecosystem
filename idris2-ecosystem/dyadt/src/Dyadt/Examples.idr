-- SPDX-License-Identifier: MPL-2.0
||| Dyadt Examples
|||
||| Practical examples of compile-time claim verification.
||| These examples demonstrate common patterns for using the library.
module Dyadt.Examples

import Dyadt
import Dyadt.Claim
import Dyadt.Evidence
import Dyadt.Verdict
import Dyadt.Combinators

-- Note: Not marked total because Evidence uses negative recursion
-- (NotEvidence : (Evidence c -> Void) -> Evidence (Not c))
-- This is intentional - see Dyadt.Evidence for rationale

-------------------------------------------------------------------
-- Basic File Claims
-------------------------------------------------------------------

||| Claim that /etc/passwd exists (standard Unix file)
public export
passwdClaim : Claim
passwdClaim = FileExists "/etc/passwd"

||| Evidence for the claim (asserted by the developer)
public export
passwdEvidence : Evidence (FileExists "/etc/passwd")
passwdEvidence = FileExistsEvidence

||| Verified claim - if this compiles, the type system accepts it
public export
passwdVerified : Verified (FileExists "/etc/passwd")
passwdVerified = MkVerified passwdEvidence

-------------------------------------------------------------------
-- Configuration Verification
-------------------------------------------------------------------

||| A typical configuration claim
public export
configExistsClaim : Claim
configExistsClaim = FileExists "config.toml"

||| Claim that config has correct format
public export
configValidClaim : Claim
configValidClaim = And
  (FileExists "config.toml")
  (FileContains "config.toml" "[database]")

||| Evidence for valid config
public export
configValidEvidence : Evidence (And (FileExists "config.toml") (FileContains "config.toml" "[database]"))
configValidEvidence = BothEvidence FileExistsEvidence FileContainsEvidence

-------------------------------------------------------------------
-- Git Repository Claims
-------------------------------------------------------------------

||| Claim that the git repo is clean before deployment
public export
cleanRepoClaim : Claim
cleanRepoClaim = GitClean Nothing

||| Claim that we're on a specific branch
public export
onMainBranch : Claim
onMainBranch = GitBranchExists "main" Nothing

||| Complete pre-deployment check
public export
preDeployCheck : Claim
preDeployCheck = AllClaims
  [ GitClean Nothing
  , GitBranchExists "main" Nothing
  , FileExists "Dockerfile"
  ]

-------------------------------------------------------------------
-- Environment Claims
-------------------------------------------------------------------

||| Claim that we're in production environment
public export
isProdEnv : Claim
isProdEnv = EnvVarEquals "ENV" "production"

||| Claim that database URL is set
public export
dbConfigured : Claim
dbConfigured = EnvVarSet "DATABASE_URL"

||| Complete environment check
public export
envReady : Claim
envReady = And dbConfigured (EnvVarSet "API_KEY")

-------------------------------------------------------------------
-- Command Execution Claims
-------------------------------------------------------------------

||| Claim that npm build succeeds
public export
buildSucceeds : Claim
buildSucceeds = CommandSucceeds "npm" ["run", "build"]

||| Claim that tests pass
public export
testsPass : Claim
testsPass = CommandSucceeds "npm" ["test"]

||| Full CI check
public export
ciPasses : Claim
ciPasses = AllClaims
  [ CommandSucceeds "npm" ["install"]
  , CommandSucceeds "npm" ["run", "lint"]
  , CommandSucceeds "npm" ["test"]
  , CommandSucceeds "npm" ["run", "build"]
  ]

-------------------------------------------------------------------
-- File Content Claims
-------------------------------------------------------------------

||| Claim that README has required sections
public export
readmeComplete : Claim
readmeComplete = AllClaims
  [ FileExists "README.md"
  , FileContains "README.md" "## Installation"
  , FileContains "README.md" "## Usage"
  , FileContains "README.md" "## License"
  ]

||| Claim about JSON configuration
public export
jsonConfigValid : Claim
jsonConfigValid = JsonPathEquals "package.json" "$.name" "my-project"

-------------------------------------------------------------------
-- Compound Claims with Operators
-------------------------------------------------------------------

||| Using the && operator
public export
bothFilesExist : Claim
bothFilesExist = FileExists "a.txt" && FileExists "b.txt"

||| Using the || operator
public export
eitherFileExists : Claim
eitherFileExists = FileExists "config.yaml" || FileExists "config.json"

||| Negation - file should NOT exist
public export
noSecrets : Claim
noSecrets = Not (FileExists ".env.local")

-------------------------------------------------------------------
-- Evidence Construction Examples
-------------------------------------------------------------------

||| Building evidence for AllClaims
public export
allFilesEvidence : AllOf Evidence [FileExists "a.txt", FileExists "b.txt", FileExists "c.txt"]
allFilesEvidence = AllCons FileExistsEvidence
                 (AllCons FileExistsEvidence
                 (AllCons FileExistsEvidence
                  AllNil))

||| Building evidence for AnyClaim
public export
anyFileEvidence : AnyOf Evidence [FileExists "a.txt", FileExists "b.txt"]
anyFileEvidence = AnyHere FileExistsEvidence  -- First one matches

||| Alternative: second one matches
public export
anyFileEvidence2 : AnyOf Evidence [FileExists "a.txt", FileExists "b.txt"]
anyFileEvidence2 = AnyThere (AnyHere FileExistsEvidence)  -- Second one matches

-------------------------------------------------------------------
-- Verification Patterns
-------------------------------------------------------------------

||| Verify a simple claim
public export
verifiedFile : Verified (FileExists "/etc/hosts")
verifiedFile = verify FileExistsEvidence

||| Verify a compound claim
public export
verifiedBoth : Verified (And (FileExists "a.txt") (FileExists "b.txt"))
verifiedBoth = both (verify FileExistsEvidence) (verify FileExistsEvidence)

||| Using verifyAll for list of claims
public export
verifiedAll : Verified (AllClaims [FileExists "a.txt", FileExists "b.txt"])
verifiedAll = verifyAll (AllCons FileExistsEvidence (AllCons FileExistsEvidence AllNil))

||| Chain verification - derive one claim from another
public export
deriveDir : Verified (FileExists "dir/file.txt") -> Verified (DirectoryExists "dir")
deriveDir vFile = chain vFile (\_ => DirectoryExistsEvidence)

-------------------------------------------------------------------
-- Custom Claims
-------------------------------------------------------------------

||| A custom domain-specific claim
public export
customSecurityCheck : Claim
customSecurityCheck = Custom "security-audit" [("level", "high"), ("scanner", "snyk")]

||| Evidence for custom claim
public export
customEvidence : Evidence (Custom "security-audit" [("level", "high"), ("scanner", "snyk")])
customEvidence = CustomEvidence

-------------------------------------------------------------------
-- Real-World Scenario: Deployment Pipeline
-------------------------------------------------------------------

||| Pre-deployment verification claim
public export
deploymentReady : Claim
deploymentReady = AllClaims
  [ GitClean Nothing                        -- No uncommitted changes
  , GitBranchExists "main" Nothing          -- On correct branch
  , FileExists "Dockerfile"                 -- Container config present
  , FileWithHash "config.prod.toml" "abc123" -- Config hasn't changed unexpectedly
  , CommandSucceeds "npm" ["test"]          -- Tests pass
  , Not (FileExists ".env.local")           -- No local-only configs
  ]

||| Evidence for deployment readiness
public export
deploymentEvidence : Evidence (AllClaims
  [ GitClean Nothing
  , GitBranchExists "main" Nothing
  , FileExists "Dockerfile"
  , FileWithHash "config.prod.toml" "abc123"
  , CommandSucceeds "npm" ["test"]
  , Not (FileExists ".env.local")
  ])
deploymentEvidence = AllEvidence
  (AllCons GitCleanEvidence
  (AllCons GitBranchExistsEvidence
  (AllCons FileExistsEvidence
  (AllCons FileHashEvidence
  (AllCons CommandSucceedsEvidence
  (AllCons (NotEvidence (\ev => case ev of FileExistsEvidence => absurd_trusted))
   AllNil))))))
  where
    -- Trust that .env.local doesn't exist
    absurd_trusted : Void
-- PROOF_TODO: Replace cast with actual proof
-- PROOF_TODO: Replace cast with actual proof
    absurd_trusted = cast ()

