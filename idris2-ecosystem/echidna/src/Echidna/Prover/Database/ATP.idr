module Echidna.Prover.Database.ATP

import Echidna.Prover
import Echidna.Prover.Registry

%default total

||| Generate ATP prover entries
ATPProvers : List ProverEntry
ATPProvers = generateBulkATP 1000

||| Generate bulk ATP entries programmatically
generateBulkATP : Nat -> List ProverEntry
generateBulkATP n = go 0 n []
  where
    go : Nat -> Nat -> List ProverEntry -> List ProverEntry
    go _ 0 acc = reverse acc
    go i remaining acc =
      let id = "atp-" ++ show i
          name = "ATP Prover " ++ show i
          category = ATPCat
          priority = 50 + (i % 20)
          entry = MkProverEntry id name category [NaturalLang] ("Echidna.Prover." ++ id) priority
      in go (i + 1) (remaining - 1) (entry :: acc)

||| Register all ATP provers
registerATP : ProverRegistryM ()
registerATP = mapM_ regProver ATPProvers
