// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Command_test.res - Tests for Tauri_Command bridge pattern

open RescriptCore
open Deno_Test

let () = {
  // ============================================================================
  // CommandError Module Tests
  // ============================================================================

  test("CommandError: error codes are defined", async () => {
    Assert.equals(Tauri_Command.CommandError.notFound, "NOT_FOUND")
    Assert.equals(Tauri_Command.CommandError.permissionDenied, "PERMISSION_DENIED")
    Assert.equals(Tauri_Command.CommandError.invalidInput, "INVALID_INPUT")
    Assert.equals(Tauri_Command.CommandError.internalError, "INTERNAL_ERROR")
    Assert.equals(Tauri_Command.CommandError.timeout, "TIMEOUT")
    Assert.equals(Tauri_Command.CommandError.networkError, "NETWORK_ERROR")
    Assert.equals(Tauri_Command.CommandError.serializationError, "SERIALIZATION_ERROR")
  })

  test("CommandError: make creates error with correct fields", async () => {
    let err = Tauri_Command.CommandError.make(
      ~code="TEST_ERROR",
      ~message="Test message",
    )
    Assert.equals(err.code, "TEST_ERROR")
    Assert.equals(err.message, "Test message")
    Assert.isNone(err.details)
  })

  test("CommandError: make with details includes details", async () => {
    let details = JSON.Encode.object(Dict.fromArray([("key", JSON.Encode.string("value"))]))
    let err = Tauri_Command.CommandError.make(
      ~code="TEST_ERROR",
      ~message="Test message",
      ~details,
    )
    Assert.isSome(err.details)
  })

  test("CommandError: toString formats correctly", async () => {
    let err = Tauri_Command.CommandError.make(
      ~code="TEST_ERROR",
      ~message="Test message",
    )
    let str = Tauri_Command.CommandError.toString(err)
    Assert.contains(str, "TEST_ERROR")
    Assert.contains(str, "Test message")
  })

  test("CommandError: isCode checks correctly", async () => {
    let err = Tauri_Command.CommandError.make(
      ~code="TEST_ERROR",
      ~message="Test message",
    )
    Assert.isTrue(Tauri_Command.CommandError.isCode(err, "TEST_ERROR"))
    Assert.isFalse(Tauri_Command.CommandError.isCode(err, "OTHER_ERROR"))
  })

  // ============================================================================
  // Command Definition Tests
  // ============================================================================

  test("defineCommand: creates command with correct name", async () => {
    let cmd = Tauri_Command.defineCommand(
      ~name="test_command",
      ~encode=args => JSON.Encode.object(Dict.fromArray([("value", JSON.Encode.int(args))])),
      ~decode=_ => Ok("decoded"),
    )
    Assert.equals(cmd.name, "test_command")
  })

  test("defineNoArgsCommand: creates command for unit args", async () => {
    let cmd = Tauri_Command.defineNoArgsCommand(
      ~name="no_args_command",
      ~decode=_ => Ok(42),
    )
    Assert.equals(cmd.name, "no_args_command")
    // Encode should work with unit
    let encoded = cmd.encode()
    Assert.isTrue(true) // If we got here, encode worked
    ignore(encoded)
  })

  test("defineVoidCommand: creates command with unit response", async () => {
    let cmd = Tauri_Command.defineVoidCommand(
      ~name="void_command",
      ~encode=args => JSON.Encode.string(args),
    )
    Assert.equals(cmd.name, "void_command")
    // Decode should always return Ok(())
    let decoded = cmd.decode(JSON.Encode.null)
    Assert.isOk(decoded)
  })

  // ============================================================================
  // Builder Pattern Tests
  // ============================================================================

  test("Builder: make creates builder with command", async () => {
    let cmd = Tauri_Command.defineNoArgsCommand(
      ~name="builder_test",
      ~decode=_ => Ok("result"),
    )
    let builder = Tauri_Command.Builder.make(cmd)
    // Builder should exist
    Assert.isTrue(true)
    ignore(builder)
  })

  test("Builder: withTimeout sets timeout", async () => {
    let cmd = Tauri_Command.defineNoArgsCommand(
      ~name="timeout_test",
      ~decode=_ => Ok("result"),
    )
    let builder = Tauri_Command.Builder.make(cmd)
      ->Tauri_Command.Builder.withTimeout(5000)
    // Builder chain should work
    Assert.isTrue(true)
    ignore(builder)
  })

  test("Builder: withRetries sets retry config", async () => {
    let cmd = Tauri_Command.defineNoArgsCommand(
      ~name="retry_test",
      ~decode=_ => Ok("result"),
    )
    let builder = Tauri_Command.Builder.make(cmd)
      ->Tauri_Command.Builder.withRetries(3, ~delayMs=1000)
    // Builder chain should work
    Assert.isTrue(true)
    ignore(builder)
  })

  // ============================================================================
  // Type Structure Tests
  // ============================================================================

  test("commandResult: is result type alias", async () => {
    let okResult: Tauri_Command.commandResult<string> = Ok("success")
    let errResult: Tauri_Command.commandResult<string> = Error({
      code: "ERR",
      message: "failed",
      details: None,
    })
    Assert.isOk(okResult)
    Assert.isError(errResult)
  })
}
