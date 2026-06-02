// SPDX-License-Identifier: MPL-2.0
// Example: Early return with conditional

let validateAge = (age: int): result<int, string> => {
  %return.if(age < 0, Error("Age cannot be negative"))
  %return.if(age > 150, Error("Age unrealistic"))

  Ok(age)
}

let processUser = (name: string, age: int): result<string, string> => {
  %return.if(name == "", Error("Name required"))

  let validAge = validateAge(age)
  %return.error(validAge)

  Ok(`User: ${name}, age: ${Belt.Int.toString(validAge)}`)
}
