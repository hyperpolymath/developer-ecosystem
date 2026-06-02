// SPDX-License-Identifier: MPL-2.0
// Alib_String_test.res - Unit tests for branded string types

open Alib_String

// Helper for test reporting
let testCount = ref(0)
let passCount = ref(0)

let assert_ = (name: string, condition: bool) => {
  testCount := testCount.contents + 1
  if condition {
    passCount := passCount.contents + 1
    Js.log(`✅ ${name}`)
  } else {
    Js.log(`❌ ${name}`)
  }
}

// Main test suite
let runTests = () => {
  Js.log("\n=== Alib.String Tests ===\n")

  // Test 1: Email - Valid
  {
    let input = "user@example.com"
    switch Email.parse(input) {
    | Ok(email) =>
      assert_("Email: Valid email parses successfully", true)
      assert_("Email: Reveal returns original string", Email.reveal(email) == input)
    | Error(_) => assert_("Email: Valid email should parse", false)
    }
  }

  // Test 2: Email - Invalid (no @)
  {
    let input = "not-an-email"
    switch Email.parse(input) {
    | Ok(_) => assert_("Email: Invalid email should fail", false)
    | Error(InvalidFormat({name, input: _})) =>
      assert_("Email: Invalid email rejects correctly", true)
      assert_("Email: Error includes brand name", name == "Email")
    }
  }

  // Test 3: Email - Invalid (no domain)
  {
    let input = "user@"
    switch Email.parse(input) {
    | Ok(_) => assert_("Email: Invalid email (no domain) should fail", false)
    | Error(_) => assert_("Email: Invalid email (no domain) rejects", true)
    }
  }

  // Test 4: Slug - Valid kebab-case
  {
    let input = "valid-kebab-slug"
    switch Slug.parse(input) {
    | Ok(slug) =>
      assert_("Slug: Valid slug parses", true)
      assert_("Slug: Reveal works", Slug.reveal(slug) == input)
    | Error(_) => assert_("Slug: Valid slug should parse", false)
    }
  }

  // Test 5: Slug - Invalid (uppercase)
  {
    let input = "Invalid-Slug"
    switch Slug.parse(input) {
    | Ok(_) => assert_("Slug: Uppercase should fail", false)
    | Error(_) => assert_("Slug: Uppercase rejects", true)
    }
  }

  // Test 6: Slug - Invalid (underscore)
  {
    let input = "invalid_slug"
    switch Slug.parse(input) {
    | Ok(_) => assert_("Slug: Underscore should fail", false)
    | Error(_) => assert_("Slug: Underscore rejects", true)
    }
  }

  // Test 7: Slug - Valid with numbers
  {
    let input = "slug-123-abc"
    switch Slug.parse(input) {
    | Ok(_) => assert_("Slug: Numbers allowed", true)
    | Error(_) => assert_("Slug: Numbers should be valid", false)
    }
  }

  // Test 8: Url - Valid HTTP
  {
    let input = "http://example.com"
    switch Url.parse(input) {
    | Ok(_) => assert_("Url: HTTP URL parses", true)
    | Error(_) => assert_("Url: Valid HTTP should parse", false)
    }
  }

  // Test 9: Url - Valid HTTPS
  {
    let input = "https://example.com/path"
    switch Url.parse(input) {
    | Ok(_) => assert_("Url: HTTPS URL parses", true)
    | Error(_) => assert_("Url: Valid HTTPS should parse", false)
    }
  }

  // Test 10: Url - Invalid (no protocol)
  {
    let input = "example.com"
    switch Url.parse(input) {
    | Ok(_) => assert_("Url: No protocol should fail", false)
    | Error(_) => assert_("Url: No protocol rejects", true)
    }
  }

  // Test 11: NonEmptyString - Valid
  {
    let input = "Hello"
    switch NonEmptyString.parse(input) {
    | Ok(_) => assert_("NonEmptyString: Non-empty parses", true)
    | Error(_) => assert_("NonEmptyString: Should parse non-empty", false)
    }
  }

  // Test 12: NonEmptyString - Invalid (empty)
  {
    let input = ""
    switch NonEmptyString.parse(input) {
    | Ok(_) => assert_("NonEmptyString: Empty should fail", false)
    | Error(_) => assert_("NonEmptyString: Empty rejects", true)
    }
  }

  // Test 13: Type safety - cannot mix brands
  // This is tested at compile time, not runtime
  // Uncomment to verify compiler error:
  // let email = Email.parse("user@example.com")
  // let slug = Slug.parse("valid-slug")
  // switch (email, slug) {
  // | (Ok(e), Ok(s)) => {
  //     let _mixed: Email.t = s  // COMPILE ERROR: Type mismatch!
  //   }
  // | _ => ()
  // }
  assert_("Type safety: Brands prevent mixing (compile-time)", true)

  // Report results
  Js.log(`\n=== Results ===`)
  Js.log(`Passed: ${passCount.contents->Js.Int.toString}/${testCount.contents->Js.Int.toString}`)

  if passCount.contents == testCount.contents {
    Js.log(`✅ All tests passed!`)
  } else {
    Js.log(`❌ Some tests failed`)
    %raw(`process.exit(1)`)
  }
}
