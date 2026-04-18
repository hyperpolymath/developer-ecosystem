module Echidna.Prover.Types

import Data.List
import Data.String

%default total

public export
data ProverKind = Z3 | CVC5 | Agda

public export
Show ProverKind where
  show Z3 = "Z3"
  show CVC5 = "CVC5"
  show Agda = "Agda"

public export
Eq ProverKind where
  Z3 == Z3 = True
  CVC5 == CVC5 = True
  Agda == Agda = True
  _ == _ = False