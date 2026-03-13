// SPDX-License-Identifier: PMPL-1.0
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
// ETF type definitions

type rec erlangTerm =
  | Integer(int)
  | Float(float)
  | Atom(string)
  | Binary(Js.TypedArray2.Uint8Array.t)
  | Tuple(array<erlangTerm>)
  | List(array<erlangTerm>)
  | Map(Dict.t<erlangTerm>)
  | Nil

let atom = (name: string): erlangTerm => Atom(name)
let integer = (n: int): erlangTerm => Integer(n)
let float = (n: float): erlangTerm => Float(n)
let binary = (data: Js.TypedArray2.Uint8Array.t): erlangTerm => Binary(data)
let tuple = (elements: array<erlangTerm>): erlangTerm => Tuple(elements)
let list = (elements: array<erlangTerm>): erlangTerm => List(elements)
let nil: erlangTerm = Nil

let stringToBinary = (s: string): erlangTerm => {
  let encoder = %raw(`new TextEncoder()`)
  Binary(%raw(`encoder.encode(s)`))
}

let binaryToString = (term: erlangTerm): option<string> => {
  switch term {
  | Binary(data) =>
    let decoder = %raw(`new TextDecoder()`)
    Some(%raw(`decoder.decode(data)`))
  | _ => None
  }
}
