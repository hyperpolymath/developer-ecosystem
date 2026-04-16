// SPDX-License-Identifier: PMPL-1.0-or-later
// Local storage utilities for ReScript


@val @scope("localStorage") external getItem: string => Nullable.t<string> = "getItem"
@val @scope("localStorage") external setItem: (string, string) => unit = "setItem"

// Get a string value from storage
let getString = (key: string): option<string> => {
  getItem(key)->Nullable.toOption
}

// Set a string value to storage
let setString = (key: string, value: string): unit => {
  setItem(key, value)
}

// Get a number value from storage
let getNumber = (key: string): option<float> => {
  switch getString(key) {
  | Some(str) =>
    let value = Float.fromString(str)
    switch value {
    | Some(n) if !Float.isNaN(n) => Some(n)
    | _ => None
    }
  | None => None
  }
}

// Set a number value to storage
let setNumber = (key: string, value: float): unit => {
  setString(key, Float.toString(value))
}

// Get a boolean value from storage
let getBool = (key: string): option<bool> => {
  switch getString(key) {
  | Some(str) =>
    let lower = String.toLowerCase(str)
    if lower == "true" {
      Some(true)
    } else if lower == "false" {
      Some(false)
    } else {
      None
    }
  | None => None
  }
}

// Set a boolean value to storage
let setBool = (key: string, value: bool): unit => {
  setString(key, value ? "true" : "false")
}

// Get an object value from storage
let getObject = (key: string): option<JSON.t> => {
  switch getString(key) {
  | Some(str) =>
    try {
      Some(JSON.parseExn(str))
    } catch {
    | _ => None
    }
  | None => None
  }
}

// Set an object value to storage
let setObject = (key: string, value: 'a): unit => {
  setString(key, JSON.stringifyAny(value)->Option.getOr(""))
}
