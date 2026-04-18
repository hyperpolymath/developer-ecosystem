module TestTypes

public export
data SmallProverKind
  = Z3
  | CVC5
  | Agda

public export
Show SmallProverKind where
  show Z3 = "Z3"
  show CVC5 = "CVC5"
  show Agda = "Agda"

public export
Eq SmallProverKind where
  Z3 == Z3 = True
  CVC5 == CVC5 = True
  Agda == Agda = True
  _ == _ = False