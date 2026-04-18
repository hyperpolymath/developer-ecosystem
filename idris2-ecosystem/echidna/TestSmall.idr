module TestSmall

public export
data ProverKind
  = Z3         -- SMT solver
  | CVC5       -- SMT solver
  | Yices      -- SMT solver
  | MathSAT    -- SMT solver
  | Boolector  -- Bit-blasting SMT solver
  | Bitwuzla   -- SMT solver
  | Agda       -- Dependent type theory
  | Coq        -- Interactive theorem prover (Rocq)
  | Lean4      -- Functional programming and proving
  | Lean3      -- Functional programming and proving