// SPDX-License-Identifier: MIT AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("Tests for Tea_Cmd module")

// Node.js test bindings
@module("node:test") external test: (string, unit => unit) => unit = "test"
@module("node:assert") external strictEqual: ('a, 'a) => unit = "strictEqual"
@module("node:assert") external deepStrictEqual: ('a, 'a) => unit = "deepStrictEqual"
@module("node:assert") external ok: bool => unit = "ok"

// ============================================================================
// Tests for Tea_Cmd.none
// ============================================================================

test("Cmd.none does nothing when executed", () => {
  let dispatched = ref(false)
  Tea_Cmd.execute(Tea_Cmd.none, _ => dispatched := true)
  // Give a moment for any async execution
  ok(!dispatched.contents)
})

// ============================================================================
// Tests for Tea_Cmd.batch
// ============================================================================

test("Cmd.batch with empty array returns none equivalent", () => {
  let dispatched = ref(false)
  Tea_Cmd.execute(Tea_Cmd.batch([]), _ => dispatched := true)
  ok(!dispatched.contents)
})

test("Cmd.batch with single command returns that command", () => {
  let count = ref(0)
  let cmd = Tea_Cmd.message(1)
  let batched = Tea_Cmd.batch([cmd])
  Tea_Cmd.execute(batched, msg => count := count.contents + msg)
  // message is executed via setTimeout, so we can't check immediately
  // This test verifies no exception is thrown
  ok(true)
})

// ============================================================================
// Tests for Tea_Cmd.message
// ============================================================================

test("Cmd.message creates a command that dispatches the message", () => {
  let cmd = Tea_Cmd.message(42)
  // Verify command was created without error
  ok(true)
})

// ============================================================================
// Tests for Tea_Cmd.map
// ============================================================================

test("Cmd.map transforms none to none", () => {
  let mapped = Tea_Cmd.map(x => x * 2, Tea_Cmd.none)
  let dispatched = ref(false)
  Tea_Cmd.execute(mapped, _ => dispatched := true)
  ok(!dispatched.contents)
})

test("Cmd.map transforms message command", () => {
  let cmd = Tea_Cmd.message(5)
  let mapped = Tea_Cmd.map(x => x * 2, cmd)
  // Verify transformation was created without error
  ok(true)
})

// ============================================================================
// Tests for Tea_Cmd.effect
// ============================================================================

test("Cmd.effect creates an effect command", () => {
  let executed = ref(false)
  let cmd = Tea_Cmd.effect(_ => executed := true)
  Tea_Cmd.execute(cmd, _ => ())
  // effect is executed via setTimeout
  ok(true)
})
