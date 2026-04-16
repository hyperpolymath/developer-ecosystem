// SPDX-License-Identifier: PMPL-1.0-or-later
// Password Cracker  brute force / dictionary attack mini-game
// Wired into Terminal.res as the `crack` command

// Attack method
type attackMethod = BruteForce | Dictionary | Hybrid

// Crack attempt result
type crackResult =
  | Success({password: string, attempts: int, method: attackMethod})
  | Failed({attempts: int, reason: string})
  | InProgress({progress: float, attempts: int})

// Common password dictionary (for game  not real passwords)
let commonPasswords = [
  "p-ssw-rd",
  "12345678",
  "sys-admin",
  "root-node",
  "toor-access",
  "allow-me-in",
  "welcome-usr",
  "monk-ey-pod",
  "drag-on-fly",
  "master-key",
  "qwerty-uiop",
  "abc-123-xyz",
  "pass-word-99",
  "i-love-code",
  "trust-no-one",
  "p-ssw-rd-0",
  "P-ssw-rd-123",
  "admin-portal",
  "change-me-now",
  "guest-access",
]

// Hash simulation (game mechanic, not real crypto)
let simpleHash = (input: string): int => {
  let hash = ref(5381)
  for i in 0 to String.length(input) - 1 {
    let c = String.charCodeAt(input, i)->Float.toInt
    hash := hash.contents * 33 + c
  }
  hash.contents
}

// Determine crack difficulty based on security level
type crackDifficulty = {
  maxAttempts: int,
  successChance: float,
  timePerAttemptMs: float,
}

let getDifficulty = (securityLevel: DeviceType.securityLevel): crackDifficulty => {
  switch securityLevel {
  | Open => {maxAttempts: 5, successChance: 0.95, timePerAttemptMs: 100.0}
  | Weak => {maxAttempts: 50, successChance: 0.80, timePerAttemptMs: 200.0}
  | Medium => {maxAttempts: 500, successChance: 0.40, timePerAttemptMs: 500.0}
  | Strong => {maxAttempts: 5000, successChance: 0.05, timePerAttemptMs: 1000.0}
  }
}

// Attempt dictionary attack
let dictionaryAttack = (
  ~targetHash: int,
  ~securityLevel: DeviceType.securityLevel,
): crackResult => {
  let difficulty = getDifficulty(securityLevel)
  let found = ref(None)
  let attempts = ref(0)

  commonPasswords->Array.forEach(pwd => {
    if Option.isNone(found.contents) && attempts.contents < difficulty.maxAttempts {
      attempts := attempts.contents + 1
      if simpleHash(pwd) == targetHash {
        found := Some(pwd)
      }
    }
  })

  switch found.contents {
  | Some(pwd) => Success({password: pwd, attempts: attempts.contents, method: Dictionary})
  | None => {
      // Random chance based on difficulty
      let roll = Math.random()
      if roll < difficulty.successChance *. 0.3 {
        let masked = Int.Bitwise.land(targetHash, 0xFFFF)
        Success({
          password: "cr4ck3d_" ++ Int.toString(masked),
          attempts: difficulty.maxAttempts,
          method: BruteForce,
        })
      } else {
        Failed({
          attempts: attempts.contents,
          reason: "Password not in dictionary. Try a different method.",
        })
      }
    }
  }
}

// Format attack result as terminal output
let formatResult = (result: crackResult): string => {
  switch result {
  | Success({password, attempts, method}) => {
      let methodStr = switch method {
      | BruteForce => "brute-force"
      | Dictionary => "dictionary"
      | Hybrid => "hybrid"
      }
      `[+] PASSWORD FOUND!\n    Password: ${password}\n    Method: ${methodStr}\n    Attempts: ${Int.toString(
          attempts,
        )}`
    }
  | Failed({attempts, reason}) =>
    `[-] CRACK FAILED\n    Attempts: ${Int.toString(attempts)}\n    Reason: ${reason}`
  | InProgress({progress, attempts}) => {
      let pct = Float.toFixed(progress *. 100.0, ~digits=1)
      `[*] Cracking... ${pct}% (${Int.toString(attempts)} attempts)`
    }
  }
}

// Format the initial attack display
let formatAttackStart = (~targetIp: string, ~service: string, ~method: attackMethod): string => {
  let methodStr = switch method {
  | BruteForce => "Brute Force"
  | Dictionary => "Dictionary"
  | Hybrid => "Hybrid"
  }
  `[*] Starting ${methodStr} attack on ${targetIp}:${service}...\n[*] Loading wordlist (${Int.toString(
      Array.length(commonPasswords),
    )} entries)...`
}
