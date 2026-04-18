module Echidna.Prover.Database.ModelCheck

import Echidna.Prover
import Echidna.Prover.Registry

%default total

||| Generate ModelCheck prover entries
ModelCheckProvers : List ProverEntry
ModelCheckProvers = generateBulkModelCheck 1000

||| Generate bulk ModelCheck entries programmatically
generateBulkModelCheck : Nat -> List ProverEntry
generateBulkModelCheck n = go 0 n []
  where
    go : Nat -> Nat -> List ProverEntry -> List ProverEntry
    go _ 0 acc = reverse acc
    go i remaining acc =
      let id = "modelcheck-" ++ show i
          name = "ModelCheck Prover " ++ show i
          category = ModelCheckCat
          priority = 50 + (i % 20)
          entry = MkProverEntry id name category [NaturalLang] (Echidna.Prover. ++ id) priority
      in go (i + 1) (remaining - 1) (entry :: acc)

||| Register all ModelCheck provers
registerModelCheck : ProverRegistryM ()
registerModelCheck = mapM_ regProver ModelCheckProvers
