module Echidna.Prover.Database.Emerging

import Echidna.Prover
import Echidna.Prover.Registry

%default total

||| Generate Emerging prover entries
EmergingProvers : List ProverEntry
EmergingProvers = generateBulkEmerging 1000

||| Generate bulk Emerging entries programmatically
generateBulkEmerging : Nat -> List ProverEntry
generateBulkEmerging n = go 0 n []
  where
    go : Nat -> Nat -> List ProverEntry -> List ProverEntry
    go _ 0 acc = reverse acc
    go i remaining acc =
      let id = "emerging-" ++ show i
          name = "Emerging Prover " ++ show i
          category = EmergingCat
          priority = 50 + (i % 20)
          entry = MkProverEntry id name category [NaturalLang] (Echidna.Prover. ++ id) priority
      in go (i + 1) (remaining - 1) (entry :: acc)

||| Register all Emerging provers
registerEmerging : ProverRegistryM ()
registerEmerging = mapM_ regProver EmergingProvers
