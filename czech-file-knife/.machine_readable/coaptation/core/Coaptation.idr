||| SPDX-License-Identifier: MPL-2.0
||| Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
||| Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
|||
||| Coaptation sound core — build-path step 6 (in progress). Declares the
||| dependent-typed shape of the descriptile↔contractile face-off: obligations
||| (Clause), evidence (Fact), the witness relation, and the TOTALITY of coverage.
|||
||| The central property is now PROVEN, not merely declared: `MayGap` has no
||| constructor for `Must`/`Trust`, so `TotalCoverage` forces `IsWitnessed` on every
||| hard obligation — an unwitnessed Must is a compile-time error. The `failing`
||| block below makes `idris2 --check` itself the proof: it asserts that gapping a
||| Must does NOT typecheck.
|||
||| Still pending (the remaining sub-step): WIRING this core to consume the runner's
||| atomised JSON (clauses.json / facts.json) so the Idris reading and the Nickel
||| reading provably agree. Until then the Nickel comparator (coapt.ncl) is the
||| AUTHORITATIVE reading and this core proves the property on hand-built examples.
module Coaptation

import Data.Vect
import Data.Fin

||| The six normative contractile verbs.
public export
data Verb = Intend | Must | Trust | Adjust | Dust | Bust

||| The descriptive families that emit evidence (the descriptiles).
public export
data Family = CLADE | STATE | ECOSYSTEM | AGENTIC | ANCHOR

||| A contractile obligation, indexed by its verb.
public export
data Clause : Verb -> Type where
  MkClause : (id : String) -> (v : Verb) -> Clause v

||| A descriptive fact, indexed by its family.
public export
data Fact : Family -> Type where
  MkFact : (id : String) -> (f : Family) -> Fact f

||| Existential wrappers so heterogeneous clauses/facts share one vector spine.
public export
SomeClause : Type
SomeClause = (v : Verb ** Clause v)

public export
SomeFact : Type
SomeFact = (f : Family ** Fact f)

||| The correspondence: inhabited iff a fact witnesses an obligation. The single
||| constructor here is a PLACEHOLDER; soundness-critical Must/Trust correspondences
||| graduate to real, content-bearing proof obligations — the whole reason for
||| putting the core in Idris2.
public export
data Witnesses : SomeClause -> SomeFact -> Type where
  Attests : (c : SomeClause) -> (x : SomeFact) -> Witnesses c x

||| Permission to leave an obligation UNWITNESSED. This is the load-bearing type:
||| it has constructors ONLY for the verbs whose grade tolerates a gap —
||| Intend (tropical distance), Adjust (advisory posture), Dust (planned exnovation),
||| Bust (a declared-but-latent break). There is deliberately NO constructor for
||| `Must` or `Trust`, so `MayGap (Must ** _)` and `MayGap (Trust ** _)` are
||| UNINHABITED: a hard obligation cannot be gapped.
public export
data MayGap : SomeClause -> Type where
  IntendMayGap : MayGap (Intend ** c)
  AdjustMayGap : MayGap (Adjust ** c)
  DustMayGap   : MayGap (Dust   ** c)
  BustMayGap   : MayGap (Bust   ** c)

||| How a single obligation is resolved: either a fact witnesses it, or its verb
||| permits a gap. A Must/Trust clause can ONLY take the `IsWitnessed` branch,
||| because `IsGap` demands a `MayGap` that does not exist for those verbs.
public export
data Resolved : SomeClause -> Type where
  IsWitnessed : (x : SomeFact) -> Witnesses c x -> Resolved c
  IsGap       : MayGap c -> Resolved c

||| Coverage is TOTAL by construction: a resolution for every obligation in the
||| vector. Because `Resolved` forces `IsWitnessed` on Must/Trust, an unwitnessed
||| hard obligation is a COMPILE-TIME error, not a forgotten check — the whole
||| reason for putting the core in Idris2.
public export
TotalCoverage : {n : Nat} -> Vect n SomeClause -> Type
TotalCoverage cs = (i : Fin n) -> Resolved (index i cs)

-- ───────────────────────────────────────────────────────────────────────────
-- Worked example + machine-checked proof of the central property.
-- (`idris2 --check` passing IS the proof: the `failing` block must NOT compile.)
-- ───────────────────────────────────────────────────────────────────────────

exampleClauses : Vect 2 SomeClause
exampleClauses = [ (Must ** MkClause "must.license-present" Must)
                 , (Adjust ** MkClause "adjust.placeholder-drift" Adjust) ]

exampleFact : SomeFact
exampleFact = (STATE ** MkFact "state.status" STATE)

||| A VALID total covering: the Must clause is witnessed; the Adjust clause is
||| allowed to gap. This typechecks.
exampleCoverage : TotalCoverage Coaptation.exampleClauses
exampleCoverage FZ      = IsWitnessed exampleFact (Attests _ exampleFact)
exampleCoverage (FS FZ) = IsGap AdjustMayGap

-- PROOF that an unwitnessed Must is rejected: gapping position 0 (the Must clause)
-- has no `MayGap (Must ** _)` to offer, so this body cannot typecheck. The `failing`
-- block asserts exactly that — if it ever DID compile, the build would break.
failing
  unwitnessedMustIsATypeError : TotalCoverage Coaptation.exampleClauses
  unwitnessedMustIsATypeError FZ      = IsGap AdjustMayGap  -- needs MayGap (Must**_): impossible
  unwitnessedMustIsATypeError (FS FZ) = IsGap AdjustMayGap
