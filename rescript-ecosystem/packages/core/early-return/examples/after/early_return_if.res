// SPDX-License-Identifier: MPL-2.0
// Example: Desugared output (what transformer produces)

let validateAge = (age: int): result<int, string> => {
  if age < 0 {
    Error("Age cannot be negative")
  } else if age > 150 {
    Error("Age unrealistic")
  } else {
    Ok(age)
  }
}

let processUser = (name: string, age: int): result<string, string> => {
  if name == "" {
    Error("Name required")
  } else {
    let validAge = validateAge(age)
    switch validAge {
    | Error(e) => Error(e)
    | Ok(validAge) => Ok(`User: ${name}, age: ${Belt.Int.toString(validAge)}`)
    }
  }
}
