// SPDX-License-Identifier: PMPL-1.0-or-later
// DLCLoader.res  Load and parse DLC puzzle packs from JSON files
//
// Parses the puzzle JSON format used in dlc/idaptik-reversible/data/puzzles/
// into the canonical PuzzleFormat.t type. Handles both legacy format
// (initialState/goalState) and tier-aware format.
//
// Usage (Deno CLI / build tools only  not for browser):
//   let puzzles = DLCLoader.loadDirectory("dlc/idaptik-reversible/data/puzzles")
//   let json = DLCLoader.bundleToJson(puzzles)

// Raw JSON puzzle shape (before normalization)
type rawHint = {
  moveNumber: option<int>,
  moveThreshold: option<int>,
  text: string,
}

type rawMetadata = {
  author: option<string>,
  created: option<string>,
  tags: option<array<string>>,
}

// Parse difficulty string to PuzzleFormat.difficulty
let parseDifficulty = (s: string): PuzzleFormat.difficulty => {
  switch String.toLowerCase(s) {
  | "beginner" => Beginner
  | "intermediate" => Intermediate
  | "advanced" => Advanced
  | "expert" => Expert
  | _ => Beginner
  }
}

// Parse tier from JSON (either int or string)
let parseTier = (json: JSON.t): PuzzleFormat.tier => {
  switch JSON.Classify.classify(json) {
  | Number(n) =>
    switch Float.toInt(n) {
    | 0 => Tier0
    | 1 => Tier1
    | 2 => Tier2
    | 3 => Tier3
    | 4 => Tier4
    | _ => Tier0
    }
  | String(s) =>
    switch String.toLowerCase(s) {
    | "tier0" | "0" => Tier0
    | "tier1" | "1" => Tier1
    | "tier2" | "2" => Tier2
    | "tier3" | "3" => Tier3
    | "tier4" | "4" => Tier4
    | _ => Tier0
    }
  | _ => Tier0
  }
}

// Infer tier from puzzle ID/filename if not explicit
let inferTierFromId = (id: string): PuzzleFormat.tier => {
  let lower = String.toLowerCase(id)
  if String.includes(lower, "tier4") || String.includes(lower, "send") || String.includes(lower, "recv") {
    Tier4
  } else if String.includes(lower, "tier3") || String.includes(lower, "call") || String.includes(lower, "subroutine") {
    Tier3
  } else if String.includes(lower, "tier2") || String.includes(lower, "stack") || String.includes(lower, "memory") {
    Tier2
  } else if String.includes(lower, "tier1") || String.includes(lower, "branch") || String.includes(lower, "loop") {
    Tier1
  } else {
    Tier0
  }
}

// Infer tier from allowed instructions
let inferTierFromInstructions = (instrs: array<string>): PuzzleFormat.tier => {
  let hasAny = (patterns: array<string>) =>
    Array.some(instrs, i => {
      let upper = String.toUpperCase(i)
      Array.some(patterns, p => String.includes(upper, p))
    })
  if hasAny(["SEND", "RECV"]) {
    Tier4
  } else if hasAny(["CALL"]) {
    Tier3
  } else if hasAny(["PUSH", "POP", "LOAD", "STORE"]) {
    Tier2
  } else if hasAny(["IF_ZERO", "IF_POS", "LOOP"]) {
    Tier1
  } else {
    Tier0
  }
}

// Extract register pairs from a state object (JSON dict of string -> int)
let extractRegisters = (stateJson: JSON.t): array<(string, int)> => {
  switch JSON.Classify.classify(stateJson) {
  | Object(dict) =>
    let keys = Dict.keysToArray(dict)
    Array.filterMap(keys, key => {
      switch Dict.get(dict, key) {
      | Some(v) =>
        switch JSON.Classify.classify(v) {
        | Number(n) => Some((key, Float.toInt(n)))
        | _ => None
        }
      | None => None
      }
    })
  | _ => []
  }
}

// Parse hints from either old format [{moveNumber, text}] or new [string]
let parseHints = (json: JSON.t): array<PuzzleFormat.hint> => {
  switch JSON.Classify.classify(json) {
  | Array(arr) =>
    Array.filterMap(arr, item => {
      switch JSON.Classify.classify(item) {
      // New format: array of strings
      | String(s) => Some({PuzzleFormat.moveThreshold: 3, text: s})
      // Old format: {moveNumber, text} objects
      | Object(dict) => {
          let text = switch Dict.get(dict, "text") {
          | Some(v) =>
            switch JSON.Classify.classify(v) {
            | String(s) => s
            | _ => ""
            }
          | None => ""
          }
          let threshold = switch Dict.get(dict, "moveNumber") {
          | Some(v) =>
            switch JSON.Classify.classify(v) {
            | Number(n) => Float.toInt(n)
            | _ => 3
            }
          | None =>
            switch Dict.get(dict, "moveThreshold") {
            | Some(v) =>
              switch JSON.Classify.classify(v) {
              | Number(n) => Float.toInt(n)
              | _ => 3
              }
            | None => 3
            }
          }
          if String.length(text) > 0 {
            Some({PuzzleFormat.moveThreshold: threshold, text})
          } else {
            None
          }
        }
      | _ => None
      }
    })
  | _ => []
  }
}

// Get a string field from a JSON object
let getString = (dict: dict<JSON.t>, key: string, default: string): string => {
  switch Dict.get(dict, key) {
  | Some(v) =>
    switch JSON.Classify.classify(v) {
    | String(s) => s
    | _ => default
    }
  | None => default
  }
}

// Get an int field from a JSON object
let getInt = (dict: dict<JSON.t>, key: string, default: int): int => {
  switch Dict.get(dict, key) {
  | Some(v) =>
    switch JSON.Classify.classify(v) {
    | Number(n) => Float.toInt(n)
    | _ => default
    }
  | None => default
  }
}

// Get a string array from a JSON object
let getStringArray = (dict: dict<JSON.t>, key: string): array<string> => {
  switch Dict.get(dict, key) {
  | Some(v) =>
    switch JSON.Classify.classify(v) {
    | Array(arr) =>
      Array.filterMap(arr, item => {
        switch JSON.Classify.classify(item) {
        | String(s) => Some(s)
        | _ => None
        }
      })
    | _ => []
    }
  | None => []
  }
}

// Parse a single puzzle JSON string into PuzzleFormat.t
// id: the puzzle identifier (typically filename without .json)
let parsePuzzleJson = (id: string, jsonStr: string): option<PuzzleFormat.t> => {
  let parsed = try {
    Some(JSON.parseExn(jsonStr))
  } catch {
  | _ => None
  }
  switch parsed {
  | None => None
  | Some(json) =>
  switch JSON.Classify.classify(json) {
  | Object(dict) => {
      let name = getString(dict, "name", id)
      let description = getString(dict, "description", "")
      let difficulty = getString(dict, "difficulty", "beginner")->parseDifficulty
      let maxMoves = getInt(dict, "maxMoves", 50)
      let parMoves = switch Dict.get(dict, "optimalMoves") {
      | Some(v) =>
        switch JSON.Classify.classify(v) {
        | Number(n) => Float.toInt(n)
        | _ => getInt(dict, "parMoves", maxMoves)
        }
      | None => getInt(dict, "parMoves", maxMoves)
      }

      // Parse initial/goal state (supports both initialState and initialRegisters)
      let initialRegisters = switch Dict.get(dict, "initialState") {
      | Some(v) => extractRegisters(v)
      | None =>
        switch Dict.get(dict, "initialRegisters") {
        | Some(v) => extractRegisters(v)
        | None => []
        }
      }
      let goalRegisters = switch Dict.get(dict, "goalState") {
      | Some(v) => extractRegisters(v)
      | None =>
        switch Dict.get(dict, "goalRegisters") {
        | Some(v) => extractRegisters(v)
        | None => []
        }
      }

      // Parse tier  explicit, or inferred
      let tier = switch Dict.get(dict, "tier") {
      | Some(v) => parseTier(v)
      | None => {
          let fromInstr = switch Dict.get(dict, "allowedInstructions") {
          | Some(_) => {
              let instrs = getStringArray(dict, "allowedInstructions")
              if Array.length(instrs) > 0 {
                Some(inferTierFromInstructions(instrs))
              } else {
                None
              }
            }
          | None => None
          }
          switch fromInstr {
          | Some(t) => t
          | None => inferTierFromId(id)
          }
        }
      }

      // Parse allowed instructions
      let allowedInstructions = {
        let arr = getStringArray(dict, "allowedInstructions")
        if Array.length(arr) > 0 {
          Some(arr)
        } else {
          None
        }
      }

      // Parse hints
      let hints = switch Dict.get(dict, "hints") {
      | Some(v) => parseHints(v)
      | None => []
      }

      // Parse tags from metadata or top-level
      let tags = {
        let topLevel = getStringArray(dict, "tags")
        if Array.length(topLevel) > 0 {
          topLevel
        } else {
          switch Dict.get(dict, "metadata") {
          | Some(v) =>
            switch JSON.Classify.classify(v) {
            | Object(metaDict) => getStringArray(metaDict, "tags")
            | _ => []
            }
          | None => []
          }
        }
      }

      Some({
        PuzzleFormat.id,
        name,
        description,
        difficulty,
        tier,
        initialRegisters,
        goalRegisters,
        initialMemory: [],
        goalMemory: [],
        maxMoves,
        parMoves,
        allowedInstructions,
        hints,
        tags,
      })
    }
  | _ => None
  }
  }
}

// Serialize a puzzle to JSON (for bundle generation)
let puzzleToJson = (p: PuzzleFormat.t): JSON.t => {
  let dict = Dict.make()
  Dict.set(dict, "id", JSON.Encode.string(p.id))
  Dict.set(dict, "name", JSON.Encode.string(p.name))
  Dict.set(dict, "description", JSON.Encode.string(p.description))
  Dict.set(dict, "difficulty", JSON.Encode.string(PuzzleFormat.difficultyToString(p.difficulty)))
  Dict.set(dict, "tier", JSON.Encode.float(Int.toFloat(PuzzleFormat.tierToInt(p.tier))))
  Dict.set(dict, "maxMoves", JSON.Encode.float(Int.toFloat(p.maxMoves)))
  Dict.set(dict, "parMoves", JSON.Encode.float(Int.toFloat(p.parMoves)))

  // Registers as objects
  let regsToJson = (regs: array<(string, int)>): JSON.t => {
    let d = Dict.make()
    Array.forEach(regs, ((k, v)) => {
      Dict.set(d, k, JSON.Encode.float(Int.toFloat(v)))
    })
    JSON.Encode.object(d)
  }
  Dict.set(dict, "initialRegisters", regsToJson(p.initialRegisters))
  Dict.set(dict, "goalRegisters", regsToJson(p.goalRegisters))

  // Memory pairs
  if Array.length(p.initialMemory) > 0 {
    let memToJson = (pairs: array<(int, int)>): JSON.t => {
      JSON.Encode.array(
        Array.map(pairs, ((addr, val_)) => {
          let d = Dict.make()
          Dict.set(d, "addr", JSON.Encode.float(Int.toFloat(addr)))
          Dict.set(d, "value", JSON.Encode.float(Int.toFloat(val_)))
          JSON.Encode.object(d)
        }),
      )
    }
    Dict.set(dict, "initialMemory", memToJson(p.initialMemory))
    Dict.set(dict, "goalMemory", memToJson(p.goalMemory))
  }

  // Allowed instructions
  switch p.allowedInstructions {
  | Some(instrs) =>
    Dict.set(dict, "allowedInstructions", JSON.Encode.array(Array.map(instrs, JSON.Encode.string)))
  | None => ()
  }

  // Hints
  if Array.length(p.hints) > 0 {
    Dict.set(
      dict,
      "hints",
      JSON.Encode.array(
        Array.map(p.hints, h => {
          let d = Dict.make()
          Dict.set(d, "moveThreshold", JSON.Encode.float(Int.toFloat(h.moveThreshold)))
          Dict.set(d, "text", JSON.Encode.string(h.text))
          JSON.Encode.object(d)
        }),
      ),
    )
  }

  // Tags
  if Array.length(p.tags) > 0 {
    Dict.set(dict, "tags", JSON.Encode.array(Array.map(p.tags, JSON.Encode.string)))
  }

  JSON.Encode.object(dict)
}

// Serialize an array of puzzles to a bundle JSON string
let bundleToJsonString = (puzzles: array<PuzzleFormat.t>): string => {
  let bundle = Dict.make()
  Dict.set(bundle, "version", JSON.Encode.string("1.0.0"))
  Dict.set(bundle, "generatedAt", JSON.Encode.string("build-time"))
  Dict.set(bundle, "count", JSON.Encode.float(Int.toFloat(Array.length(puzzles))))
  Dict.set(bundle, "puzzles", JSON.Encode.array(Array.map(puzzles, puzzleToJson)))
  JSON.stringify(JSON.Encode.object(bundle))
}
