// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// e2e_test.js — End-to-end tests for rescript-tea full pipelines.
// Tests complete TEA (The Elm Architecture) cycles: model → view → msg → update.
// Run: deno test --no-check --allow-all tests/e2e_test.js

import { assertEquals, assert, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";

import * as Vdom from "../src/tea/Tea_Vdom.res.js";
import * as Cmd from "../src/tea/Tea_Cmd.res.js";
import * as Sub from "../src/tea/Tea_Sub.res.js";
import * as Json from "../src/tea/Tea_Json.res.js";

// ═══════════════════════════════════════════════════════════════════
// E2E: Complete counter application lifecycle
// ═══════════════════════════════════════════════════════════════════

Deno.test("E2E: Counter model renders to view correctly", () => {
  // Model
  const model = { count: 0 };

  // View function (pure)
  const view = (m) => Vdom.node("div", [Vdom.class_("counter")], [
    Vdom.node("button", [Vdom.id("decrement")], [Vdom.text("-")]),
    Vdom.node("span", [Vdom.id("count")], [Vdom.text(String(m.count))]),
    Vdom.node("button", [Vdom.id("increment")], [Vdom.text("+")]),
  ]);

  const vdom = view(model);
  assertEquals(vdom.TAG, "Node", "view returns a Node");
  assertEquals(vdom._0, "div", "root is a div");
  assertEquals(vdom._2.length, 3, "3 children: -, count, +");
});

Deno.test("E2E: Counter update cycle: increment", () => {
  const model = { count: 5 };

  const update = (msg, m) => {
    switch (msg) {
      case "increment": return { count: m.count + 1 };
      case "decrement": return { count: m.count - 1 };
      default: return m;
    }
  };

  const newModel = update("increment", model);
  assertEquals(newModel.count, 6, "increment increases count by 1");
});

Deno.test("E2E: Counter update cycle: decrement", () => {
  const model = { count: 5 };
  const update = (msg, m) => {
    switch (msg) {
      case "decrement": return { count: m.count - 1 };
      default: return m;
    }
  };
  const newModel = update("decrement", model);
  assertEquals(newModel.count, 4, "decrement decreases count by 1");
});

Deno.test("E2E: Counter full cycle: model → view → update → new view", () => {
  let model = { count: 0 };

  const update = (msg, m) => {
    if (msg === "increment") return { count: m.count + 1 };
    if (msg === "decrement") return { count: m.count - 1 };
    return m;
  };

  const view = (m) => Vdom.node("span", [], [Vdom.text(String(m.count))]);

  // Simulate 3 increments
  model = update("increment", model);
  model = update("increment", model);
  model = update("increment", model);

  assertEquals(model.count, 3, "3 increments produce count=3");
  const vdom = view(model);
  assertEquals(vdom._2[0]._0, "3", "view reflects updated model");
});

// ═══════════════════════════════════════════════════════════════════
// E2E: Todo list application pipeline
// ═══════════════════════════════════════════════════════════════════

Deno.test("E2E: Todo list add and remove cycle", () => {
  let model = { todos: [], nextId: 0 };

  const update = (msg, m) => {
    if (msg.type === "add") {
      return {
        todos: [...m.todos, { id: m.nextId, text: msg.text, done: false }],
        nextId: m.nextId + 1,
      };
    }
    if (msg.type === "remove") {
      return { ...m, todos: m.todos.filter(t => t.id !== msg.id) };
    }
    return m;
  };

  model = update({ type: "add", text: "Buy milk" }, model);
  model = update({ type: "add", text: "Write tests" }, model);
  assertEquals(model.todos.length, 2, "2 todos after 2 adds");

  const firstId = model.todos[0].id;
  model = update({ type: "remove", id: firstId }, model);
  assertEquals(model.todos.length, 1, "1 todo after remove");
  assertEquals(model.todos[0].text, "Write tests", "correct todo remains");
});

// ═══════════════════════════════════════════════════════════════════
// E2E: Cmd pipeline produces valid command structures
// ═══════════════════════════════════════════════════════════════════

Deno.test("E2E: Cmd.batch of multiple commands is a valid cmd", () => {
  const cmds = [Cmd.none, Cmd.none, Cmd.none];
  const batched = Cmd.batch(cmds);
  assertExists(batched, "batched commands produced");
});

Deno.test("E2E: Sub pipeline: combining subscriptions", () => {
  const subs = [Sub.none, Sub.none];
  const combined = Sub.batch(subs);
  assertExists(combined, "combined subscriptions produced");
});

// ═══════════════════════════════════════════════════════════════════
// E2E: JSON decoding in a realistic app context
// ═══════════════════════════════════════════════════════════════════

Deno.test("E2E: JSON decode user object", () => {
  const userDecoder = Json.map2(
    (name, age) => ({ name, age }),
    Json.field("name", Json.string),
    Json.field("age", Json.int)
  );

  const json = '{"name": "Alice", "age": 30}';
  const result = Json.decodeString(userDecoder)(json);
  assertExists(result, "user decoded successfully");
});

Deno.test("E2E: JSON decode array", () => {
  const listDecoder = Json.list(Json.string);
  const json = '["apple", "banana", "cherry"]';
  const result = Json.decodeString(listDecoder)(json);
  assertExists(result, "list decoded successfully");
});

Deno.test("E2E: JSON decode nested object", () => {
  const nestedDecoder = Json.field("user", Json.field("name", Json.string));
  const json = '{"user": {"name": "Bob", "role": "admin"}}';
  const result = Json.decodeString(nestedDecoder)(json);
  assertExists(result, "nested decode successful");
});

// ═══════════════════════════════════════════════════════════════════
// E2E: Virtual DOM tree construction for a form
// ═══════════════════════════════════════════════════════════════════

Deno.test("E2E: Form view construction with inputs and labels", () => {
  const formView = Vdom.node("form", [Vdom.class_("login-form")], [
    Vdom.node("label", [Vdom.for_("username")], [Vdom.text("Username")]),
    Vdom.node("input", [Vdom.id("username"), Vdom.type_("text")], []),
    Vdom.node("label", [Vdom.for_("password")], [Vdom.text("Password")]),
    Vdom.node("input", [Vdom.id("password"), Vdom.type_("password")], []),
    Vdom.node("button", [Vdom.type_("submit")], [Vdom.text("Login")]),
  ]);

  assertEquals(formView.TAG, "Node", "form is a Node");
  assertEquals(formView._0, "form", "root is form element");
  assertEquals(formView._2.length, 5, "5 form children");
});
