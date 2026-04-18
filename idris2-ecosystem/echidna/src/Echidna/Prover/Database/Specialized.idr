module Echidna.Prover.Database.Specialized

import Echidna.Prover
import Echidna.Prover.Registry

%default total

||| Generate Specialized prover entries
SpecializedProvers : List ProverEntry
SpecializedProvers = generateBulkSpecialized 1000

||| Generate bulk Specialized entries programmatically
generateBulkSpecialized : Nat -> List ProverEntry
generateBulkSpecialized n = go 0 n []
  where
    go : Nat -> Nat -> List ProverEntry -> List ProverEntry
    go _ 0 acc = reverse acc
    go i remaining acc =
      let id = "specialized-" ++ show i
          name = "Specialized Prover " ++ show i
          category = SpecializedCat
          priority = 50 + (i % 20)
          entry = MkProverEntry id name category [NaturalLang] (Echidna.Prover. ++ id) priority
      in go (i + 1) (remaining - 1) (entry :: acc)

||| Register all Specialized provers
registerSpecialized : ProverRegistryM ()
registerSpecialized = mapM_ regProver SpecializedProvers
