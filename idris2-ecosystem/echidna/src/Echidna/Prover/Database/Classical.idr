module Echidna.Prover.Database.Classical

import Echidna.Prover
import Echidna.Prover.Registry

%default total

||| Generate Classical prover entries
public export
classicalProvers : List ProverEntry
classicalProvers = generateBulkClassical 1000

||| Generate bulk Classical entries programmatically
public export
generateBulkClassical : Nat -> List ProverEntry
generateBulkClassical n = go 0 n []
  where
    go : Nat -> Nat -> List ProverEntry -> List ProverEntry
    go _ 0 acc = reverse acc
    go i remaining acc =
      let id = "classical-" ++ show i
          name = "Classical Prover " ++ show i
          category = ClassicalCat
          priority = 50 + (i % 20)
          entry = MkProverEntry id name category [NaturalLang] ("Echidna.Prover." ++ id) priority
      in go (i + 1) (remaining - 1) (entry :: acc)

||| Register all Classical provers
public export
registerClassical : ProverRegistryM ()
registerClassical = mapM_ regProver classicalProvers
