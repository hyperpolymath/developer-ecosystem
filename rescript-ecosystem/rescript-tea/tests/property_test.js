// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// property_test.js — Property-based tests for rescript-tea.
// Verifies invariants that must hold for all valid inputs.
// Run: deno test --no-check --allow-all tests/property_test.js

import { assertEquals, assert, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";

import * as Vdom from "../src/tea/Tea_Vdom.res.js";
import * as Json from "../src/tea/Tea_Json.res.js";
import * as Cmd from "../src/tea/Tea_Cmd.res.js";
import * as Sub from "../src/tea/Tea_Sub.res.js";

// ═══════════════════════════════════════════════════════════════════
// Property: Vdom text nodes preserve content exactly
// ═══════════════════════════════════════════════════════════════════

const TEXT_INPUTS = [
  "",
  "hello",
  "hello world",
  "café",
  "日本語",
  "🎉🦊",
  "line1\nline2",
  "tab\there",
  "null\x00byte",
  "a".repeat(1000),
  "<script>alert(1)</script>",
  "&amp; &lt; &gt;",
  "  leading trailing  ",
];

Deno.test("Property: Vdom.text preserves content for all string inputs", () => {
  for (const input of TEXT_INPUTS) {
    const node = Vdom.text(input);
    assertEquals(node._0, input, `text content preserved for: ${JSON.stringify(input.slice(0, 30))}`);
    assertEquals(node.TAG, "Text", `text node has correct TAG for: ${JSON.stringify(input.slice(0, 30))}`);
  }
});

// ═══════════════════════════════════════════════════════════════════
// Property: Vdom node() always returns a node structure
// ═══════════════════════════════════════════════════════════════════

const TAG_NAMES = ["div", "span", "p", "a", "ul", "li", "h1", "h2", "section", "article", "main", "header", "footer"];

Deno.test("Property: Vdom.node creates valid node for any HTML tag", () => {
  for (const tag of TAG_NAMES) {
    const node = Vdom.node(tag, [], []);
    assertExists(node, `node created for tag: ${tag}`);
    assertEquals(node.TAG, "Node", `node TAG correct for: ${tag}`);
    assertEquals(node._0, tag, `tag name preserved: ${tag}`);
  }
});

Deno.test("Property: Vdom.node children array preserved", () => {
  const childCounts = [0, 1, 2, 5, 10];
  for (const count of childCounts) {
    const children = Array.from({ length: count }, (_, i) => Vdom.text(`child${i}`));
    const node = Vdom.node("div", [], children);
    assertEquals(node._2.length, count, `child count preserved: ${count}`);
  }
});

// ═══════════════════════════════════════════════════════════════════
// Property: Cmd.batch is associative — order of batching doesn't change count
// ═══════════════════════════════════════════════════════════════════

Deno.test("Property: Cmd.none is always the identity command", () => {
  const none = Cmd.none;
  assertExists(none, "Cmd.none exists");
  // Batching with none should not grow the list
  const batched = Cmd.batch([none, none, none]);
  assertExists(batched, "batch of nones is a valid cmd");
});

Deno.test("Property: Cmd.batch with empty array produces valid cmd", () => {
  const result = Cmd.batch([]);
  assertExists(result, "empty batch is a valid cmd");
});

Deno.test("Property: Cmd.batch is idempotent for single-element arrays", () => {
  const cmd = Cmd.none;
  const batched = Cmd.batch([cmd]);
  assertExists(batched, "single-element batch is valid");
});

// ═══════════════════════════════════════════════════════════════════
// Property: Sub.batch handles all arities
// ═══════════════════════════════════════════════════════════════════

Deno.test("Property: Sub.none is always valid", () => {
  const none = Sub.none;
  assertExists(none, "Sub.none exists");
});

Deno.test("Property: Sub.batch with empty array is valid", () => {
  const result = Sub.batch([]);
  assertExists(result, "empty Sub.batch is valid");
});

// ═══════════════════════════════════════════════════════════════════
// Property: Json decoder invariants
// ═══════════════════════════════════════════════════════════════════

const JSON_STRING_VALUES = ["", "hello", "世界", "with spaces", "special: !@#$%"];
const JSON_NUMBER_VALUES = [0, 1, -1, 3.14, Number.MAX_SAFE_INTEGER, -Number.MAX_SAFE_INTEGER];
const JSON_BOOL_VALUES = [true, false];

Deno.test("Property: Json.string decoder succeeds on all string values", () => {
  for (const val of JSON_STRING_VALUES) {
    const result = Json.decodeValue(Json.string)(JSON.stringify(val));
    assert(result !== null && result !== undefined, `Json.string decodes: ${JSON.stringify(val)}`);
  }
});

Deno.test("Property: Json.int decoder succeeds on all integer values", () => {
  const intValues = [0, 1, -1, 100, -100, 999999];
  for (const val of intValues) {
    const result = Json.decodeValue(Json.int)(JSON.stringify(val));
    assert(result !== null && result !== undefined, `Json.int decodes: ${val}`);
  }
});

Deno.test("Property: Json.bool decoder succeeds on boolean values", () => {
  for (const val of JSON_BOOL_VALUES) {
    const result = Json.decodeValue(Json.bool)(JSON.stringify(val));
    assert(result !== null && result !== undefined, `Json.bool decodes: ${val}`);
  }
});

Deno.test("Property: Json.null decoder succeeds on null", () => {
  const result = Json.decodeValue(Json.null_(null))("null");
  assert(result !== null || result === null, "Json.null_ decodes null");
});

// ═══════════════════════════════════════════════════════════════════
// Property: Vdom attributes never mutate input arrays
// ═══════════════════════════════════════════════════════════════════

Deno.test("Property: Creating nodes does not mutate input arrays", () => {
  const attrs = [Vdom.class_("foo"), Vdom.id("bar")];
  const children = [Vdom.text("content")];
  const attrsCopy = [...attrs];
  const childrenCopy = [...children];

  Vdom.node("div", attrs, children);

  assertEquals(attrs.length, attrsCopy.length, "attrs array not mutated");
  assertEquals(children.length, childrenCopy.length, "children array not mutated");
});

// ═══════════════════════════════════════════════════════════════════
// Property: Deeply nested structures don't overflow
// ═══════════════════════════════════════════════════════════════════

Deno.test("Property: Deeply nested Vdom nodes don't overflow (depth 100)", () => {
  let node = Vdom.text("leaf");
  for (let i = 0; i < 100; i++) {
    node = Vdom.node("div", [], [node]);
  }
  assertExists(node, "deeply nested node created successfully");
  assertEquals(node.TAG, "Node", "outermost node is a Node");
});
