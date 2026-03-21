-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-pqc protocol.
-- PQC types: algorithms, hybrid modes, key pairs.

module Types

||| Post-quantum algorithm.
public export
data PqcAlgorithm : Type where
  MLKEM512   : PqcAlgorithm
  MLKEM768   : PqcAlgorithm
  MLKEM1024  : PqcAlgorithm
  MLDSA44    : PqcAlgorithm
  MLDSA65    : PqcAlgorithm
  MLDSA87    : PqcAlgorithm
  SLHDSA128F : PqcAlgorithm
  SLHDSA256F : PqcAlgorithm

||| Hybrid key exchange mode.
public export
data HybridMode : Type where
  PqcOnly      : HybridMode
  HybridX25519 : HybridMode
  HybridP384   : HybridMode

||| PQC key pair.
public export
record PqcKeyPair where
  constructor MkPqcKeyPair
  keyId     : String
  algorithm : PqcAlgorithm
  hybrid    : HybridMode
