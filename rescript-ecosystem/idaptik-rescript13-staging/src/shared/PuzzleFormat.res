// SPDX-License-Identifier: PMPL-1.0-or-later
// PuzzleFormat.res  Shared puzzle data format
//
// This is the canonical puzzle format used by:
// - dlc/idaptik-reversible/ (puzzle content)
// - main-game/ VMBridge (embedded puzzles + DLC loading)
// - idaptik-ums/ (puzzle creation/validation)
//
// Puzzle JSON files in dlc/data/puzzles/ must conform to this format.

type difficulty =
  | Beginner
  | Intermediate
  | Advanced
  | Expert

type tier =
  | Tier0  // Register arithmetic only
  | Tier1  // + Conditionals (IF_ZERO, IF_POS, LOOP)
  | Tier2  // + Stack and memory (PUSH, POP, LOAD, STORE)
  | Tier3  // + Subroutines (CALL)
  | Tier4  // + I/O channels (SEND, RECV)

type hint = {
  moveThreshold: int,  // Show this hint after N moves without progress
  text: string,
}

// A single puzzle definition
type t = {
  id: string,
  name: string,
  description: string,
  difficulty: difficulty,
  tier: tier,
  initialRegisters: array<(string, int)>,
  goalRegisters: array<(string, int)>,
  initialMemory: array<(int, int)>,      // (address, value) pairs
  goalMemory: array<(int, int)>,          // (address, value) pairs  empty if memory not tested
  maxMoves: int,
  parMoves: int,                          // Optimal solution length
  allowedInstructions: option<array<string>>,  // None = all allowed
  hints: array<hint>,
  tags: array<string>,                    // e.g., ["tutorial", "xor", "stack"]
}

// A DLC puzzle pack
type pack = {
  packId: string,
  name: string,
  description: string,
  version: string,
  author: string,
  puzzles: array<t>,
}

let difficultyToString = (d: difficulty): string => {
  switch d {
  | Beginner => "beginner"
  | Intermediate => "intermediate"
  | Advanced => "advanced"
  | Expert => "expert"
  }
}

let difficultyFromString = (s: string): option<difficulty> => {
  switch String.toLowerCase(s) {
  | "beginner" => Some(Beginner)
  | "intermediate" => Some(Intermediate)
  | "advanced" => Some(Advanced)
  | "expert" => Some(Expert)
  | _ => None
  }
}

let tierToString = (t: tier): string => {
  switch t {
  | Tier0 => "tier0"
  | Tier1 => "tier1"
  | Tier2 => "tier2"
  | Tier3 => "tier3"
  | Tier4 => "tier4"
  }
}

let tierToInt = (t: tier): int => {
  switch t {
  | Tier0 => 0
  | Tier1 => 1
  | Tier2 => 2
  | Tier3 => 3
  | Tier4 => 4
  }
}
