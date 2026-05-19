// SPDX-License-Identifier: PMPL-1.0-or-later
// Real-world example: API request with result chaining

open Alib.String
open Alib.Result

type apiError =
  | ValidationError(string)
  | NetworkError(string)
  | ServerError(int, string)

// Parse JSON response with branded types
let parseUserResponse = (json: Js.Json.t): result<Email.t, apiError> => {
  // Simplified JSON parsing
  switch Js.Json.decodeObject(json) {
  | None => Error(ValidationError("Invalid JSON"))
  | Some(obj) =>
      switch Js.Dict.get(obj, "email") {
      | None => Error(ValidationError("Missing email field"))
      | Some(emailJson) =>
          switch Js.Json.decodeString(emailJson) {
          | None => Error(ValidationError("Email must be string"))
          | Some(emailStr) =>
              switch Email.parse(emailStr) {
              | Ok(email) => Ok(email)
              | Error(InvalidFormat({input, _})) =>
                  Error(ValidationError(`Invalid email: ${input}`))
              }
          }
      }
  }
}

// Chaining result operations with Alib.Result
let fetchUserEmail = async (userId: string): result<Email.t, apiError> => {
  try {
    let response = await Fetch.fetch(`https://api.example.com/users/${userId}`)
    let json = await response->Fetch.Response.json

    // Use result combinators
    json
    ->parseUserResponse
    ->tap(email => Js.log(`Fetched email: ${Email.reveal(email)}`))
    ->mapError(err => {
        Js.log2("Error:", err)
        err
      })
  } catch {
  | Js.Exn.Error(e) =>
      switch Js.Exn.message(e) {
      | Some(msg) => Error(NetworkError(msg))
      | None => Error(NetworkError("Unknown network error"))
      }
  }
}

// Usage with multiple operations
let example = async () => {
  let userId = "123"

  let result = await fetchUserEmail(userId)

  switch result {
  | Ok(email) => {
      // email is Email.t (branded, validated)
      Js.log(`Success: ${Email.reveal(email)}`)
    }
  | Error(ValidationError(msg)) => Js.log(`Validation error: ${msg}`)
  | Error(NetworkError(msg)) => Js.log(`Network error: ${msg}`)
  | Error(ServerError(code, msg)) => Js.log(`Server error ${Js.Int.toString(code)}: ${msg}`)
  }
}
