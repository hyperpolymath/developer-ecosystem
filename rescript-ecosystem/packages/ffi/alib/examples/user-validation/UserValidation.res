// SPDX-License-Identifier: MPL-2.0
// Real-world example: User validation with branded types

open Alib.String
open Alib.Result

type user = {
  email: Email.t,
  username: Slug.t,
  website: option<Url.t>,
}

type validationError =
  | InvalidEmail(string)
  | InvalidUsername(string)
  | InvalidWebsite(string)

// Validate user input with early returns (works great with rescript-early-return)
let validateUser = (
  ~emailStr: string,
  ~usernameStr: string,
  ~websiteStr: option<string>,
): result<user, validationError> => {
  // Validate email
  let email = Email.parse(emailStr)
  let email = switch email {
  | Ok(e) => e
  | Error(InvalidFormat({input, _})) => return Error(InvalidEmail(input))
  }

  // Validate username as slug (kebab-case)
  let username = Slug.parse(usernameStr)
  let username = switch username {
  | Ok(u) => u
  | Error(InvalidFormat({input, _})) => return Error(InvalidUsername(input))
  }

  // Optional website URL
  let website = switch websiteStr {
  | None => None
  | Some(urlStr) =>
      switch Url.parse(urlStr) {
      | Ok(url) => Some(url)
      | Error(InvalidFormat({input, _})) => return Error(InvalidWebsite(input))
      }
  }

  // All validations passed
  Ok({
    email: email,
    username: username,
    website: website,
  })
}

// Usage example
let example = () => {
  let result = validateUser(
    ~emailStr="user@example.com",
    ~usernameStr="john-doe",
    ~websiteStr=Some("https://example.com"),
  )

  switch result {
  | Ok(user) => {
      // user.email is Email.t (type-safe)
      // user.username is Slug.t (type-safe)
      Js.log("Valid user:")
      Js.log(`Email: ${Email.reveal(user.email)}`)
      Js.log(`Username: ${Slug.reveal(user.username)}`)
      switch user.website {
      | Some(url) => Js.log(`Website: ${Url.reveal(url)}`)
      | None => ()
      }
    }
  | Error(InvalidEmail(email)) => Js.log(`Invalid email: ${email}`)
  | Error(InvalidUsername(username)) => Js.log(`Invalid username: ${username}`)
  | Error(InvalidWebsite(url)) => Js.log(`Invalid website: ${url}`)
  }
}
