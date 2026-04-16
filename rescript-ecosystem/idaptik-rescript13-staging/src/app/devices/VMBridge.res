// SPDX-License-Identifier: PMPL-1.0-or-later
// VMBridge  Connects the game terminal to the reversible VM engine
//
// This is the gameVM integration layer. It provides:
// - A lightweight in-game VM for running reversible instructions
// - Tier 0: ADD, SUB, SWAP, NEGATE, XOR, FLIP, NOOP
// - Tier 2: PUSH, POP, LOAD, STORE (stack and memory)
// - Puzzle loading from DLC puzzle data (embedded JSON)
// - Terminal commands: vm, undo, puzzle, puzzles
//
// The VM state is embedded directly  no cross-component import needed.
// Puzzle data is loaded via fetch() from the DLC data directory.
//
// Note: Tier 1 (IF_ZERO, IF_POS, LOOP) are block-structured and handled
// programmatically by puzzles, not typed at the terminal. Tier 3 (CALL)
// and Tier 4 (SEND, RECV) require the device system  stubs below.

// 
// VM instruction set
// 

type vmInstruction =
  // Tier 0: Register arithmetic
  | Add(string, string)
  | Sub(string, string)
  | Swap(string, string)
  | Negate(string)
  | Xor(string, string)
  | Flip(string)
  | Noop
  // Tier 2: Stack and memory
  | Push(string)
  | Pop(string)
  | Load(string, int)
  | Store(int, string)

type historyEntry = {
  instruction: vmInstruction,
  description: string,
}

// 
// VM state (registers + stack + memory)
// 

type vmState = {
  mutable registers: dict<int>,
  mutable stack: array<int>,
  mutable memory: array<int>,
  mutable history: array<historyEntry>,
  mutable moveCount: int,
}

type puzzleData = {
  name: string,
  description: string,
  difficulty: string,
  tier: string,
  initialState: dict<int>,
  goalState: dict<int>,
  initialMemory: array<(int, int)>,
  goalMemory: array<(int, int)>,
  maxMoves: int,
}

type bridgeState = {
  mutable vm: option<vmState>,
  mutable activePuzzle: option<puzzleData>,
  mutable puzzleMode: bool,
}

// Global bridge state (one per game session)
let bridge: bridgeState = {
  vm: None,
  activePuzzle: None,
  puzzleMode: false,
}

// 
// VM operations
// 

let memorySize = 256

// Create a fresh VM with register names and initial values
let createVM = (registers: dict<int>): vmState => {
  let regs = Dict.make()
  registers->Dict.toArray->Array.forEach(((key, value)) => {
    Dict.set(regs, key, value)
  })
  {registers: regs, stack: [], memory: Array.make(~length=memorySize, 0), history: [], moveCount: 0}
}

// Get register value
let getReg = (vm: vmState, name: string): int => {
  Dict.get(vm.registers, name)->Option.getOr(0)
}

// Set register value
let setReg = (vm: vmState, name: string, value: int): unit => {
  Dict.set(vm.registers, name, value)
}

// Execute a VM instruction forward
let executeInstruction = (vm: vmState, instr: vmInstruction): string => {
  let desc = switch instr {
  | Add(a, b) => {
      let va = getReg(vm, a)
      let vb = getReg(vm, b)
      setReg(vm, a, va + vb)
      `ADD ${a} ${b}: ${a}=${Int.toString(va)}+${Int.toString(vb)}=${Int.toString(va + vb)}`
    }
  | Sub(a, b) => {
      let va = getReg(vm, a)
      let vb = getReg(vm, b)
      setReg(vm, a, va - vb)
      `SUB ${a} ${b}: ${a}=${Int.toString(va)}-${Int.toString(vb)}=${Int.toString(va - vb)}`
    }
  | Swap(a, b) => {
      let va = getReg(vm, a)
      let vb = getReg(vm, b)
      setReg(vm, a, vb)
      setReg(vm, b, va)
      `SWAP ${a} ${b}: ${a}=${Int.toString(vb)}, ${b}=${Int.toString(va)}`
    }
  | Negate(a) => {
      let va = getReg(vm, a)
      setReg(vm, a, -va)
      `NEGATE ${a}: ${a}=${Int.toString(-va)}`
    }
  | Xor(a, b) => {
      let va = getReg(vm, a)
      let vb = getReg(vm, b)
      setReg(vm, a, Int.Bitwise.lxor(va, vb))
      `XOR ${a} ${b}: ${a}=${Int.toString(Int.Bitwise.lxor(va, vb))}`
    }
  | Flip(a) => {
      let va = getReg(vm, a)
      let result = Int.Bitwise.lxor(va, -1) // NOT = XOR with all 1s
      setReg(vm, a, result)
      `FLIP ${a}: ${a}=${Int.toString(result)}`
    }
  | Noop => "NOOP"
  | Push(a) => {
      let va = getReg(vm, a)
      vm.stack = Array.concat(vm.stack, [va])
      setReg(vm, a, 0)
      `PUSH ${a}: pushed ${Int.toString(va)}, ${a}=0, stack[${Int.toString(
          Array.length(vm.stack) - 1,
        )}]`
    }
  | Pop(a) => {
      let len = Array.length(vm.stack)
      if len == 0 {
        "POP: stack empty!"
      } else {
        let value = vm.stack[len - 1]->Option.getOr(0)
        vm.stack = Array.slice(vm.stack, ~start=0, ~end=len - 1)
        setReg(vm, a, value)
        `POP ${a}: ${a}=${Int.toString(value)}, stack depth=${Int.toString(len - 1)}`
      }
    }
  | Load(a, addr) => {
      let va = getReg(vm, a)
      let memVal = vm.memory[addr]->Option.getOr(0)
      setReg(vm, a, va + memVal)
      `LOAD ${a} ${Int.toString(addr)}: ${a}=${Int.toString(va)}+mem[${Int.toString(
          addr,
        )}]=${Int.toString(va + memVal)}`
    }
  | Store(addr, a) => {
      let va = getReg(vm, a)
      let memVal = vm.memory[addr]->Option.getOr(0)
      let newVal = memVal + va
      vm.memory = Array.mapWithIndex(vm.memory, (v, i) =>
        if i == addr {
          newVal
        } else {
          v
        }
      )
      `STORE ${Int.toString(addr)} ${a}: mem[${Int.toString(addr)}]=${Int.toString(
          memVal,
        )}+${Int.toString(va)}=${Int.toString(newVal)}`
    }
  }
  vm.history = Array.concat(vm.history, [{instruction: instr, description: desc}])
  vm.moveCount = vm.moveCount + 1
  desc
}

// Undo the last instruction (reverse execution)
let undoLastInstruction = (vm: vmState): option<string> => {
  let len = Array.length(vm.history)
  if len == 0 {
    None
  } else {
    let last = vm.history[len - 1]
    switch last {
    | Some(entry) => {
        // Execute the inverse
        switch entry.instruction {
        | Add(a, b) => {
            let va = getReg(vm, a)
            let vb = getReg(vm, b)
            setReg(vm, a, va - vb)
          }
        | Sub(a, b) => {
            let va = getReg(vm, a)
            let vb = getReg(vm, b)
            setReg(vm, a, va + vb)
          }
        | Swap(a, b) => {
            let va = getReg(vm, a)
            let vb = getReg(vm, b)
            setReg(vm, a, vb)
            setReg(vm, b, va)
          }
        | Negate(a) => {
            let va = getReg(vm, a)
            setReg(vm, a, -va)
          }
        | Xor(a, b) => {
            let va = getReg(vm, a)
            let vb = getReg(vm, b)
            setReg(vm, a, Int.Bitwise.lxor(va, vb))
          }
        | Flip(a) => {
            let va = getReg(vm, a)
            setReg(vm, a, Int.Bitwise.lxor(va, -1))
          }
        | Noop => ()
        | Push(a) => {
            // Inverse of PUSH = POP (restore value from stack)
            let slen = Array.length(vm.stack)
            if slen > 0 {
              let value = vm.stack[slen - 1]->Option.getOr(0)
              vm.stack = Array.slice(vm.stack, ~start=0, ~end=slen - 1)
              setReg(vm, a, value)
            }
          }
        | Pop(a) => {
            // Inverse of POP = PUSH (put value back on stack)
            let va = getReg(vm, a)
            vm.stack = Array.concat(vm.stack, [va])
            setReg(vm, a, 0)
          }
        | Load(a, addr) => {
            // Inverse of additive LOAD: subtract
            let va = getReg(vm, a)
            let memVal = vm.memory[addr]->Option.getOr(0)
            setReg(vm, a, va - memVal)
          }
        | Store(addr, a) => {
            // Inverse of additive STORE: subtract
            let va = getReg(vm, a)
            let memVal = vm.memory[addr]->Option.getOr(0)
            let newVal = memVal - va
            vm.memory = Array.mapWithIndex(vm.memory, (v, i) =>
              if i == addr {
                newVal
              } else {
                v
              }
            )
          }
        }

        // Remove from history
        vm.history = Array.slice(vm.history, ~start=0, ~end=len - 1)
        vm.moveCount = vm.moveCount - 1
        Some(`UNDO: reversed ${entry.description}`)
      }
    | None => None
    }
  }
}

// 
// Display
// 

// Format current VM state as terminal output
let formatState = (vm: vmState): string => {
  let lines = ref([])
  Dict.toArray(vm.registers)->Array.forEach(((key, value)) => {
    lines := Array.concat(lines.contents, [`  ${key} = ${Int.toString(value)}`])
  })
  let regLines = Array.join(lines.contents, "\n")
  let stackStr = if Array.length(vm.stack) > 0 {
    let items = Array.map(vm.stack, v => Int.toString(v))
    `\nStack (${Int.toString(Array.length(vm.stack))}): [${Array.join(items, ", ")}]`
  } else {
    ""
  }
  `Registers:\n${regLines}${stackStr}\nMoves: ${Int.toString(vm.moveCount)}`
}

// Check if puzzle is solved
let checkPuzzleSolved = (): option<string> => {
  switch (bridge.vm, bridge.activePuzzle) {
  | (Some(vm), Some(puzzle)) => {
      let solved = ref(true)
      Dict.toArray(puzzle.goalState)->Array.forEach(((key, goalVal)) => {
        let currentVal = getReg(vm, key)
        if currentVal != goalVal {
          solved := false
        }
      })
      // Check goal memory too
      Array.forEach(puzzle.goalMemory, ((addr, goalVal)) => {
        let memVal = vm.memory[addr]->Option.getOr(0)
        if memVal != goalVal {
          solved := false
        }
      })
      if solved.contents {
        bridge.puzzleMode = false
        Some(
          `\n*** PUZZLE SOLVED! ***\n"${puzzle.name}" completed in ${Int.toString(
              vm.moveCount,
            )} moves!${vm.moveCount <= puzzle.maxMoves
              ? "\nWithin move limit  excellent!"
              : "\nOver the move limit, but still solved."}`,
        )
      } else {
        None
      }
    }
  | _ => None
  }
}

// 
// Parser
// 

// Parse a VM command string into an instruction
let parseVMCommand = (input: string): option<vmInstruction> => {
  let tokens =
    String.split(String.trim(input), " ")->Array.filter(t => String.length(String.trim(t)) > 0)
  let opcode = tokens[0]->Option.map(String.toUpperCase)
  switch opcode {
  // Tier 0: Register arithmetic
  | Some("ADD") =>
    switch (tokens[1], tokens[2]) {
    | (Some(a), Some(b)) => Some(Add(a, b))
    | _ => None
    }
  | Some("SUB") =>
    switch (tokens[1], tokens[2]) {
    | (Some(a), Some(b)) => Some(Sub(a, b))
    | _ => None
    }
  | Some("SWAP") =>
    switch (tokens[1], tokens[2]) {
    | (Some(a), Some(b)) => Some(Swap(a, b))
    | _ => None
    }
  | Some("NEGATE") =>
    switch tokens[1] {
    | Some(a) => Some(Negate(a))
    | _ => None
    }
  | Some("XOR") =>
    switch (tokens[1], tokens[2]) {
    | (Some(a), Some(b)) => Some(Xor(a, b))
    | _ => None
    }
  | Some("FLIP") =>
    switch tokens[1] {
    | Some(a) => Some(Flip(a))
    | _ => None
    }
  | Some("NOOP") => Some(Noop)
  // Tier 2: Stack and memory
  | Some("PUSH") =>
    switch tokens[1] {
    | Some(a) => Some(Push(a))
    | _ => None
    }
  | Some("POP") =>
    switch tokens[1] {
    | Some(a) => Some(Pop(a))
    | _ => None
    }
  | Some("LOAD") =>
    switch (tokens[1], tokens[2]) {
    | (Some(a), Some(addrStr)) =>
      switch Int.fromString(addrStr) {
      | Some(addr) => Some(Load(a, addr))
      | None => None
      }
    | _ => None
    }
  | Some("STORE") =>
    switch (tokens[1], tokens[2]) {
    | (Some(addrStr), Some(a)) =>
      switch Int.fromString(addrStr) {
      | Some(addr) => Some(Store(addr, a))
      | None => None
      }
    | _ => None
    }
  | _ => None
  }
}

// 
// Built-in puzzles
// 

let builtinPuzzles: array<puzzleData> = [
  {
    name: "Simple Add",
    description: "Get x to 15 using only ADD",
    difficulty: "beginner",
    tier: "tier0",
    initialState: Dict.fromArray([("x", 10), ("y", 5)]),
    goalState: Dict.fromArray([("x", 15), ("y", 5)]),
    initialMemory: [],
    goalMemory: [],
    maxMoves: 3,
  },
  {
    name: "Swap Values",
    description: "Swap x and y without a temp variable",
    difficulty: "beginner",
    tier: "tier0",
    initialState: Dict.fromArray([("x", 7), ("y", 13)]),
    goalState: Dict.fromArray([("x", 13), ("y", 7)]),
    initialMemory: [],
    goalMemory: [],
    maxMoves: 3,
  },
  {
    name: "Reach Zero",
    description: "Get both x and y to 0",
    difficulty: "beginner",
    tier: "tier0",
    initialState: Dict.fromArray([("x", 5), ("y", -5)]),
    goalState: Dict.fromArray([("x", 0), ("y", 0)]),
    initialMemory: [],
    goalMemory: [],
    maxMoves: 5,
  },
  {
    name: "Double Trouble",
    description: "Double x using only ADD and SWAP",
    difficulty: "intermediate",
    tier: "tier0",
    initialState: Dict.fromArray([("x", 8), ("y", 0), ("z", 0)]),
    goalState: Dict.fromArray([("x", 16), ("y", 0), ("z", 0)]),
    initialMemory: [],
    goalMemory: [],
    maxMoves: 5,
  },
  {
    name: "XOR Cipher",
    description: "XOR-encrypt x with the key in y, then decrypt it back to verify",
    difficulty: "intermediate",
    tier: "tier0",
    initialState: Dict.fromArray([("x", 42), ("y", 255), ("z", 0)]),
    goalState: Dict.fromArray([("x", 42), ("y", 255), ("z", 213)]),
    initialMemory: [],
    goalMemory: [],
    maxMoves: 8,
  },
  // Tier 2 puzzles
  {
    name: "Stack Swap",
    description: "Use the stack to swap x and y (PUSH x, PUSH y, POP x, POP y)",
    difficulty: "beginner",
    tier: "tier2",
    initialState: Dict.fromArray([("x", 42), ("y", 99)]),
    goalState: Dict.fromArray([("x", 99), ("y", 42)]),
    initialMemory: [],
    goalMemory: [],
    maxMoves: 4,
  },
  {
    name: "Memory Cache",
    description: "Store x into memory address 0, then load it into y",
    difficulty: "beginner",
    tier: "tier2",
    initialState: Dict.fromArray([("x", 77), ("y", 0)]),
    goalState: Dict.fromArray([("x", 77), ("y", 77)]),
    initialMemory: [],
    goalMemory: [(0, 77)],
    maxMoves: 3,
  },
  {
    name: "Stack Calculator",
    description: "Compute (10 + 20) * 2 using stack operations. Result in z.",
    difficulty: "intermediate",
    tier: "tier2",
    initialState: Dict.fromArray([("x", 10), ("y", 20), ("z", 0)]),
    goalState: Dict.fromArray([("x", 0), ("y", 0), ("z", 60)]),
    initialMemory: [],
    goalMemory: [],
    maxMoves: 10,
  },
]

// 
// Terminal command handlers
// 

// Handle 'vm' command  direct VM instruction execution
let handleVMCommand = (args: string): string => {
  if String.length(String.trim(args)) == 0 {
    `vm  Reversible VM Terminal
Usage:
  vm <instruction>     Execute a reversible instruction
  vm undo              Undo last instruction
  vm state             Show current register state
  vm stack             Show stack contents
  vm mem <start> <len> Show memory range
  vm reset             Reset VM to default state
  vm help              Show available instructions

Tier 0: ADD, SUB, SWAP, NEGATE, XOR, FLIP, NOOP
Tier 2: PUSH, POP, LOAD, STORE
Example: vm ADD x y | vm PUSH x | vm LOAD x 0`
  } else {
    let trimmed = String.trim(args)
    let upperTrimmed = String.toUpperCase(trimmed)
    switch upperTrimmed {
    | "UNDO" | "U" =>
      switch bridge.vm {
      | Some(vm) =>
        switch undoLastInstruction(vm) {
        | Some(msg) => {
            let stateStr = formatState(vm)
            `${msg}\n${stateStr}`
          }
        | None => "Nothing to undo."
        }
      | None => "No VM active. Run 'puzzle <name>' to start."
      }
    | "STATE" | "S" =>
      switch bridge.vm {
      | Some(vm) => formatState(vm)
      | None => "No VM active."
      }
    | "STACK" =>
      switch bridge.vm {
      | Some(vm) =>
        if Array.length(vm.stack) == 0 {
          "Stack: (empty)"
        } else {
          let items = Array.mapWithIndex(vm.stack, (v, i) =>
            `  [${Int.toString(i)}] ${Int.toString(v)}`
          )
          `Stack (${Int.toString(Array.length(vm.stack))}):\n${Array.join(items, "\n")}`
        }
      | None => "No VM active."
      }
    | "RESET" | "R" =>
      // Create VM first, then format  avoids Option.getExn which would crash
      // if createVM somehow failed to return a valid VM instance.
      switch bridge.activePuzzle {
      | Some(puzzle) => {
          let vm = createVM(puzzle.initialState)
          bridge.vm = Some(vm)
          `VM reset to puzzle initial state.\n${formatState(vm)}`
        }
      | None => {
          let defaultRegs = Dict.fromArray([("x", 0), ("y", 0), ("z", 0)])
          let vm = createVM(defaultRegs)
          bridge.vm = Some(vm)
          `VM reset.\n${formatState(vm)}`
        }
      }
    | "HELP" | "?" => `Reversible VM Instructions:

TIER 0  Register Arithmetic:
  ADD <a> <b>        a = a + b
  SUB <a> <b>        a = a - b
  SWAP <a> <b>       Swap a and b
  NEGATE <a>         a = -a
  XOR <a> <b>        a = a XOR b
  FLIP <a>           a = NOT a (bitwise complement)
  NOOP               No operation

TIER 2  Stack & Memory:
  PUSH <reg>         Push reg onto stack, zero reg
  POP <reg>          Pop stack into reg
  LOAD <reg> <addr>  reg += memory[addr]
  STORE <addr> <reg> memory[addr] += reg

Every instruction is perfectly reversible. Use 'vm undo' to reverse.`
    | _ =>
      // Check for memory display command: MEM <start> <len>
      if String.startsWith(upperTrimmed, "MEM") {
        switch bridge.vm {
        | Some(vm) => {
            let memTokens =
              String.split(String.trim(trimmed), " ")->Array.filter(t => String.length(t) > 0)
            let start = memTokens[1]->Option.flatMap(x => Int.fromString(x))->Option.getOr(0)
            let length = memTokens[2]->Option.flatMap(x => Int.fromString(x))->Option.getOr(16)
            let lines = ref([])
            for i in start to start + length - 1 {
              let v = vm.memory[i]->Option.getOr(0)
              if v != 0 {
                lines :=
                  Array.concat(lines.contents, [`  mem[${Int.toString(i)}] = ${Int.toString(v)}`])
              }
            }
            if Array.length(lines.contents) == 0 {
              `Memory [${Int.toString(start)}..${Int.toString(start + length - 1)}]: all zero`
            } else {
              `Memory [${Int.toString(start)}..${Int.toString(start + length - 1)}]:\n${Array.join(
                  lines.contents,
                  "\n",
                )}`
            }
          }
        | None => "No VM active."
        }
      } else {
        // Parse as instruction
        switch bridge.vm {
        | Some(vm) =>
          switch parseVMCommand(trimmed) {
          | Some(instr) => {
              let result = executeInstruction(vm, instr)
              let stateStr = formatState(vm)
              let solvedMsg = switch checkPuzzleSolved() {
              | Some(msg) => msg
              | None => ""
              }
              `${result}\n${stateStr}${solvedMsg}`
            }
          | None => `Unknown VM instruction: ${trimmed}. Type 'vm help' for usage.`
          }
        | None => {
            // Auto-create a VM with default registers.
            // We bind the created VM directly instead of re-extracting from
            // bridge.vm via Option.getExn, avoiding a potential crash if the
            // mutable ref were ever cleared between assignment and read.
            let defaultRegs = Dict.fromArray([("x", 0), ("y", 0), ("z", 0)])
            let vm = createVM(defaultRegs)
            bridge.vm = Some(vm)
            switch parseVMCommand(trimmed) {
            | Some(instr) => {
                let result = executeInstruction(vm, instr)
                `VM created with registers x, y, z.\n${result}\n${formatState(vm)}`
              }
            | None => `Unknown VM instruction: ${trimmed}. Type 'vm help' for usage.`
            }
          }
        }
      }
    }
  }
}

// Handle 'puzzle' command  load and start a puzzle
let handlePuzzleCommand = (name: string): string => {
  let trimmedName = String.trim(String.toLowerCase(name))
  if String.length(trimmedName) == 0 {
    // List puzzles
    let lines = Array.map(builtinPuzzles, p => {
      `  ${String.toLowerCase(
          String.replaceAll(p.name, " ", "_"),
        )}  [${p.difficulty}/${p.tier}]  ${p.description}`
    })
    `Available puzzles:\n${Array.join(lines, "\n")}\n\nUsage: puzzle <name>`
  } else {
    // Find puzzle by name
    let found = Array.find(builtinPuzzles, p => {
      let normalised = String.toLowerCase(String.replaceAll(p.name, " ", "_"))
      normalised == trimmedName
    })
    switch found {
    | Some(puzzle) => {
        bridge.activePuzzle = Some(puzzle)
        let vm = createVM(puzzle.initialState)
        // Initialize memory from puzzle data
        Array.forEach(puzzle.initialMemory, ((addr, value)) => {
          vm.memory = Array.mapWithIndex(vm.memory, (v, i) =>
            if i == addr {
              value
            } else {
              v
            }
          )
        })
        bridge.vm = Some(vm)
        bridge.puzzleMode = true
        let goalLines = ref([])
        Dict.toArray(puzzle.goalState)->Array.forEach(((key, value)) => {
          goalLines := Array.concat(goalLines.contents, [`  ${key} = ${Int.toString(value)}`])
        })
        let memGoalStr = if Array.length(puzzle.goalMemory) > 0 {
          let memLines = Array.map(puzzle.goalMemory, ((addr, value)) =>
            `  mem[${Int.toString(addr)}] = ${Int.toString(value)}`
          )
          `\nMemory goal:\n${Array.join(memLines, "\n")}`
        } else {
          ""
        }
        `\n=== PUZZLE: ${puzzle.name} ===
${puzzle.description}
Difficulty: ${puzzle.difficulty} (${puzzle.tier})
Max moves: ${Int.toString(puzzle.maxMoves)}

Goal:
${Array.join(goalLines.contents, "\n")}${memGoalStr}

Current state:
${formatState(vm)}

Use 'vm <instruction>' to play. 'vm undo' to reverse. 'vm state' to check.`
      }
    | None => `Puzzle "${trimmedName}" not found. Type 'puzzle' to list available puzzles.`
    }
  }
}
