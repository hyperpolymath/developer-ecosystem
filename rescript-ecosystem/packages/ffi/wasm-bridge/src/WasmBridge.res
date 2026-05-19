// SPDX-License-Identifier: PMPL-1.0-or-later
@val external initWasm: unit => promise<unit> = "init"
@val external deriveKey: (array<int>, array<int>) => promise<array<int>> = "deriveKey"

let init = () => {
  initWasm()->Promise.then_(_ => {
    Console.log("WASM initialized")
    Promise.resolve()
  })
}

let deriveKeyFromStrings = (password: string, salt: string): promise<array<int>> => {
  let passwordBytes = password->String.split("")->Array.map(c => c->Js.String2.charCodeAt(0)->Int.fromFloat)
  let saltBytes = salt->String.split("")->Array.map(c => c->Js.String2.charCodeAt(0)->Int.fromFloat)
  deriveKey(passwordBytes, saltBytes)
}
