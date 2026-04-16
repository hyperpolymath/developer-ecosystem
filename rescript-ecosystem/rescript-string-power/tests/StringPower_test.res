// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// StringPower_test.res
// Basic sanity tests for StringPower library

open StringPower

// ============================================================================
// Utils Tests
// ============================================================================

let testInterleave = () => {
  let result = Utils.interleave(["a", "b", "c"], ["1", "2"])
  assert(result == "a1b2c")
  Console.log("✓ Utils.interleave")
}

// ============================================================================
// Fmt Tests
// ============================================================================

let testFmtBasic = () => {
  open Fmt
  let result = fmt`Hello ${S("World")}`
  assert(result == "Hello World")
  Console.log("✓ Fmt.fmt basic")
}

let testFmtMultiple = () => {
  open Fmt
  let result = fmt`${S("A")} and ${I(42)} and ${B(true)}`
  assert(result == "A and 42 and true")
  Console.log("✓ Fmt.fmt multiple values")
}

let testFmtHtmlEscape = () => {
  open Fmt
  let result = html`<div>${S("<script>alert('xss')</script>")}</div>`
  assert(String.includes(result, "&lt;script&gt;"))
  assert(!String.includes(result, "<script>"))
  Console.log("✓ Fmt.html escaping")
}

// ============================================================================
// Sql Tests
// ============================================================================

let testSqlParameterized = () => {
  open Sql
  let query = parameterized`SELECT * FROM users WHERE id = ${Sql.int(42)}`
  assert(query.text == "SELECT * FROM users WHERE id = $1")
  assert(Array.length(query.params) == 1)
  Console.log("✓ Sql.parameterized")
}

let testSqlMultipleParams = () => {
  open Sql
  let query = parameterized`SELECT * FROM users WHERE name = ${Sql.str("Alice")} AND age > ${Sql.int(18)}`
  assert(String.includes(query.text, "$1"))
  assert(String.includes(query.text, "$2"))
  assert(Array.length(query.params) == 2)
  Console.log("✓ Sql.parameterized multiple params")
}

let testSqlRaw = () => {
  open Sql
  let query = parameterized`SELECT * FROM ${Sql.raw("users")} WHERE id = ${Sql.int(1)}`
  assert(String.includes(query.text, "FROM users WHERE"))
  assert(Array.length(query.params) == 1)
  Console.log("✓ Sql.raw passthrough")
}

// ============================================================================
// Css Tests
// ============================================================================

let testCssUnits = () => {
  open Css
  let result = css`padding: ${px(16)}; margin: ${rem(1.5)};`
  assert(String.includes(result, "16px"))
  assert(String.includes(result, "1.5rem"))
  Console.log("✓ Css units")
}

let testCssVar = () => {
  open Css
  let result = css`color: ${var("primary")};`
  assert(String.includes(result, "var(--primary)"))
  Console.log("✓ Css.var")
}

let testCssScoped = () => {
  open Css
  let result = scoped`display: flex;`
  assert(String.startsWith(result.className, "sp_"))
  assert(String.includes(result.styles, result.className))
  Console.log("✓ Css.scoped")
}

// ============================================================================
// I18n Tests
// ============================================================================

let testI18nSlots = () => {
  open I18n
  let key = i18n`Hello ${slot("name")}!`
  assert(key.key == "Hello {name}!")
  assert(key.slots == ["name"])
  Console.log("✓ I18n.i18n slots")
}

let testI18nApply = () => {
  open I18n
  let key = i18n`Hello ${slot("name")}, welcome to ${slot("app")}!`
  let result = apply(key, Dict.fromArray([("name", "Alice"), ("app", "MyApp")]))
  assert(result == "Hello Alice, welcome to MyApp!")
  Console.log("✓ I18n.apply")
}

// ============================================================================
// Url Tests
// ============================================================================

let testUrlEncoding = () => {
  open Url
  let result = url`/search?q=${Url.param("hello world")}`
  assert(String.includes(result, "hello%20world"))
  Console.log("✓ Url encoding")
}

// ============================================================================
// Gql Tests
// ============================================================================

let testGqlVariables = () => {
  open Gql
  let doc = gql`query Test($id: ID!, $name: String) { user(id: $id) { name } }`
  assert(doc.variables->Array.includes("id"))
  assert(doc.variables->Array.includes("name"))
  Console.log("✓ Gql.variables extraction")
}

let testGqlOperationName = () => {
  open Gql
  let doc = gql`query FindUser($id: ID!) { user(id: $id) { name } }`
  assert(doc.operationName == Some("FindUser"))
  Console.log("✓ Gql.operationName extraction")
}

// ============================================================================
// Run All Tests
// ============================================================================

let runAllTests = () => {
  Console.log("\n=== StringPower Tests ===\n")
  
  // Utils
  testInterleave()
  
  // Fmt
  testFmtBasic()
  testFmtMultiple()
  testFmtHtmlEscape()
  
  // Sql
  testSqlParameterized()
  testSqlMultipleParams()
  testSqlRaw()
  
  // Css
  testCssUnits()
  testCssVar()
  testCssScoped()
  
  // I18n
  testI18nSlots()
  testI18nApply()
  
  // Url
  testUrlEncoding()
  
  // Gql
  testGqlVariables()
  testGqlOperationName()
  
  Console.log("\n=== All tests passed! ===\n")
}

// Auto-run
runAllTests()
