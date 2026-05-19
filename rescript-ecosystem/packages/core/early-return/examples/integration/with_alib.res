// SPDX-License-Identifier: PMPL-1.0-or-later
// Integration example: return-sugar + rescript-alib

open Alib.String

// Combines branded types with early return sugar
let validateAndSendEmail = (input: string): result<unit, string> => {
  // Early return if input is empty
  %return.if(input == "", Error("Email required"))

  // Parse with branded type (from rescript-alib)
  let email = Email.parse(input)

  // Early return if validation failed
  %return.error(email)

  // At this point, email is Email.t (type-safe)
  sendEmail(Email.reveal(email))
  Ok()
}

// Multiple validations with early returns
let createUser = (emailStr: string, slugStr: string): result<user, string> => {
  // Validate email
  let email = Email.parse(emailStr)
  %return.error(email)

  // Validate slug
  let slug = Slug.parse(slugStr)
  %return.error(slug)

  // Both are now branded types, compile-time safe
  Ok({
    email: Email.reveal(email),
    username: Slug.reveal(slug),
  })
}
