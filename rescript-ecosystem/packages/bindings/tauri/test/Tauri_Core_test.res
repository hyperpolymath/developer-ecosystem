// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Core_test.res - Tests for Tauri_Core bindings

open RescriptCore
open Deno_Test

// Note: These are unit tests for the binding structure.
// Full integration tests require a running Tauri app.

let () = {
  // ============================================================================
  // Type Structure Tests
  // ============================================================================

  test("Tauri_Core: invokeOptions type has correct structure", async () => {
    let opts: Tauri_Core.invokeOptions = {
      headers: Dict.fromArray([("Content-Type", "application/json")]),
    }
    Assert.isSome(opts.headers)
  })

  test("Tauri_Core: permissionState variants exist", async () => {
    let granted: Tauri_Core.permissionState = Granted
    let denied: Tauri_Core.permissionState = Denied
    let prompt: Tauri_Core.permissionState = Prompt

    Assert.equals(granted, Tauri_Core.Granted)
    Assert.equals(denied, Tauri_Core.Denied)
    Assert.equals(prompt, Tauri_Core.Prompt)
  })

  test("Tauri_Core: imageDimensions has width and height", async () => {
    let dims: Tauri_Core.imageDimensions = {width: 100, height: 200}
    Assert.equals(dims.width, 100)
    Assert.equals(dims.height, 200)
  })

  // ============================================================================
  // Function Existence Tests (type-level verification)
  // ============================================================================

  test("Tauri_Core: invoke function exists", async () => {
    // Type check - function signature is correct
    let _: (string, ~args: Tauri_Core.invokeArgs=?, ~options: Tauri_Core.invokeOptions=?) => promise<'a> =
      Tauri_Core.invoke
    Assert.isTrue(true)
  })

  test("Tauri_Core: app info functions exist", async () => {
    let _getName: unit => promise<string> = Tauri_Core.getName
    let _getVersion: unit => promise<string> = Tauri_Core.getVersion
    let _getTauriVersion: unit => promise<string> = Tauri_Core.getTauriVersion
    Assert.isTrue(true)
  })

  test("Tauri_Core: channel functions exist", async () => {
    let _makeChannel: unit => Tauri_Core.channel<'t> = Tauri_Core.makeChannel
    let _onMessage: (Tauri_Core.channel<'t>, 't => unit) => unit = Tauri_Core.onMessage
    let _channelId: Tauri_Core.channel<'t> => int = Tauri_Core.channelId
    Assert.isTrue(true)
  })

  test("Tauri_Core: resource functions exist", async () => {
    let _makeResource: int => Tauri_Core.resource = Tauri_Core.makeResource
    let _closeResource: Tauri_Core.resource => promise<unit> = Tauri_Core.closeResource
    let _resourceRid: Tauri_Core.resource => int = Tauri_Core.resourceRid
    Assert.isTrue(true)
  })
}
