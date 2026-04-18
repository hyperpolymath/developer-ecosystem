module TestProver

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
  | Idris2     -- Dependent type theory
  | Isabelle   -- Higher-order logic
  | Metamath   -- Plain text verifier
  | HOLLight   -- Classical higher-order logic
  | HOL4       -- Higher-order logic
  | Mizar      -- Mathematical vernacular
  | PVS        -- Specification and verification
  | ACL2       -- Applicative Common Lisp
  | Vampire    -- First-order ATP
  | EProver    -- First-order ATP
  | SPAS       -- First-order ATP
  | iProver    -- First-order ATP
  | LeoIII     -- Higher-order ATP
  | TLC        -- TLA+ model checker
  | Alloy      -- Relational model checker
  | NuSMV      -- Symbolic model checker
  | Spin       -- Explicit-state model checker
  | PRISM      -- Probabilistic model checker
  | AltErgo    -- SMT solver for program verification
  | FStar      -- Dependent type system
  | Why3       -- Software verification platform
  | Dafny      -- Programming language with built-in verifier
  | KeYmaeraX  -- Hybrid systems theorem prover