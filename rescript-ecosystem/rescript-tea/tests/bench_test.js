// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// bench_test.js — Benchmarks for rescript-tea modules.
// Run: deno bench --no-check --allow-all tests/bench_test.js

import * as Vdom from "../src/tea/Tea_Vdom.res.js";
import * as Json from "../src/tea/Tea_Json.res.js";
import * as Ssr from "../src/tea/Tea_Ssr.res.js";
import * as Cmd from "../src/tea/Tea_Cmd.res.js";
import * as Sub from "../src/tea/Tea_Sub.res.js";

// ═══════════════════════════════════════════════════════════════════
// VDOM Creation Benchmarks
// ═══════════════════════════════════════════════════════════════════

Deno.bench("VDOM: create Text node", () => {
  Vdom.text("hello world");
});

Deno.bench("VDOM: create empty Element", () => {
  Vdom.nodeA("div", [], []);
});

Deno.bench("VDOM: create Element with 5 attributes", () => {
  Vdom.nodeA(
    "div",
    [
      Vdom.class_("container"),
      Vdom.id("main"),
      Vdom.style("color", "red"),
      Vdom.ariaLabel("Main content"),
      Vdom.role("main"),
    ],
    [],
  );
});

Deno.bench("VDOM: create Element with 10 children", () => {
  const children = [];
  for (let i = 0; i < 10; i++) {
    children.push(Vdom.nodeA("li", [], [Vdom.text(`Item ${i}`)]));
  }
  Vdom.nodeA("ul", [], children);
});

Deno.bench("VDOM: create Element with 100 children", () => {
  const children = [];
  for (let i = 0; i < 100; i++) {
    children.push(Vdom.nodeA("li", [], [Vdom.text(`Item ${i}`)]));
  }
  Vdom.nodeA("ul", [], children);
});

Deno.bench("VDOM: create KeyedElement with 10 children", () => {
  const children = [];
  for (let i = 0; i < 10; i++) {
    children.push([`key-${i}`, Vdom.nodeA("li", [], [Vdom.text(`Item ${i}`)])]);
  }
  Vdom.keyedA("ul", [], children);
});

Deno.bench("VDOM: create KeyedElement with 100 children", () => {
  const children = [];
  for (let i = 0; i < 100; i++) {
    children.push([`key-${i}`, Vdom.nodeA("li", [], [Vdom.text(`Item ${i}`)])]);
  }
  Vdom.keyedA("ul", [], children);
});

Deno.bench("VDOM: create Fragment with 10 children", () => {
  const children = [];
  for (let i = 0; i < 10; i++) {
    children.push(Vdom.text(`text ${i}`));
  }
  Vdom.fragmentA(children);
});

Deno.bench("VDOM: create Fragment with 100 children", () => {
  const children = [];
  for (let i = 0; i < 100; i++) {
    children.push(Vdom.text(`text ${i}`));
  }
  Vdom.fragmentA(children);
});

// ═══════════════════════════════════════════════════════════════════
// VDOM Map Benchmarks
// ═══════════════════════════════════════════════════════════════════

const shallowTree = Vdom.nodeA(
  "div",
  [Vdom.onClick("click"), Vdom.class_("test")],
  [Vdom.text("a"), Vdom.text("b"), Vdom.text("c")],
);

Deno.bench("VDOM map: shallow tree (3 children)", () => {
  Vdom.map(shallowTree, (msg) => ({ type: "Wrapped", msg }));
});

// Build a deeper tree for benchmarking
function buildDeepTree(depth) {
  if (depth <= 0) return Vdom.text("leaf");
  return Vdom.nodeA(
    "div",
    [Vdom.onClick("click")],
    [buildDeepTree(depth - 1), buildDeepTree(depth - 1)],
  );
}

const deepTree5 = buildDeepTree(5);
const deepTree8 = buildDeepTree(8);

Deno.bench("VDOM map: deep tree (depth 5, ~63 nodes)", () => {
  Vdom.map(deepTree5, (msg) => `mapped:${msg}`);
});

Deno.bench("VDOM map: deep tree (depth 8, ~511 nodes)", () => {
  Vdom.map(deepTree8, (msg) => `mapped:${msg}`);
});

// ═══════════════════════════════════════════════════════════════════
// JSON Decoder Benchmarks
// ═══════════════════════════════════════════════════════════════════

Deno.bench("JSON decoder: string", () => {
  Json.string("hello");
});

Deno.bench("JSON decoder: int", () => {
  Json.int(42);
});

Deno.bench("JSON decoder: float", () => {
  Json.float(3.14);
});

Deno.bench("JSON decoder: bool", () => {
  Json.bool(true);
});

const simpleObject = JSON.parse('{"name": "Alice", "age": 30}');
const simpleDecoder = Json.map2(
  (name, age) => ({ name, age }),
  Json.field("name", Json.string),
  Json.field("age", Json.int),
);

Deno.bench("JSON decoder: simple object (2 fields)", () => {
  simpleDecoder(simpleObject);
});

const complexObject = JSON.parse(
  '{"user": {"name": "Alice", "age": 30, "email": "a@b.com", "active": true}, "scores": [1,2,3]}',
);
const complexDecoder = Json.map2(
  (user, scores) => ({ user, scores }),
  Json.field(
    "user",
    Json.map4(
      (name, age, email, active) => ({ name, age, email, active }),
      Json.field("name", Json.string),
      Json.field("age", Json.int),
      Json.field("email", Json.string),
      Json.field("active", Json.bool),
    ),
  ),
  Json.field("scores", Json.array(Json.int)),
);

Deno.bench("JSON decoder: complex nested object", () => {
  complexDecoder(complexObject);
});

const nestedJson = JSON.parse('{"a": {"b": {"c": {"d": "deep"}}}}');
const nestedDecoder = Json.at(["a", "b", "c", "d"], Json.string);

Deno.bench("JSON decoder: deeply nested 'at' path (4 levels)", () => {
  nestedDecoder(nestedJson);
});

const arrayJson = JSON.parse("[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]");
const arrayDecoder = Json.array(Json.int);

Deno.bench("JSON decoder: array of 10 ints", () => {
  arrayDecoder(arrayJson);
});

const largeArrayJson = JSON.parse(JSON.stringify(Array.from({ length: 100 }, (_, i) => i)));

Deno.bench("JSON decoder: array of 100 ints", () => {
  arrayDecoder(largeArrayJson);
});

Deno.bench("JSON decoder: decodeString", () => {
  Json.decodeString(Json.int, "42");
});

Deno.bench("JSON decoder: decodeString complex", () => {
  Json.decodeString(simpleDecoder, '{"name": "Bob", "age": 25}');
});

const oneOfDecoder = Json.oneOf([Json.int, Json.map(Json.string, (s) => parseInt(s))]);

Deno.bench("JSON decoder: oneOf (first matches)", () => {
  oneOfDecoder(42);
});

Deno.bench("JSON decoder: oneOf (second matches)", () => {
  oneOfDecoder("42");
});

const dictJson = JSON.parse('{"a": 1, "b": 2, "c": 3, "d": 4, "e": 5}');
const dictDecoder = Json.dict(Json.int);

Deno.bench("JSON decoder: dict with 5 entries", () => {
  dictDecoder(dictJson);
});

// ═══════════════════════════════════════════════════════════════════
// SSR Benchmarks
// ═══════════════════════════════════════════════════════════════════

const smallVdom = Vdom.nodeA("p", [Vdom.class_("text")], [Vdom.text("Hello")]);

Deno.bench("SSR toString: small (1 element, 1 text)", () => {
  Ssr.toString(smallVdom);
});

const mediumVdom = Vdom.nodeA("div", [Vdom.class_("container")], [
  Vdom.nodeA("h1", [], [Vdom.text("Title")]),
  Vdom.nodeA("ul", [], [
    Vdom.nodeA("li", [Vdom.class_("item")], [Vdom.text("Item 1")]),
    Vdom.nodeA("li", [Vdom.class_("item")], [Vdom.text("Item 2")]),
    Vdom.nodeA("li", [Vdom.class_("item")], [Vdom.text("Item 3")]),
  ]),
  Vdom.nodeA("p", [Vdom.style("color", "red")], [Vdom.text("Footer")]),
]);

Deno.bench("SSR toString: medium (~10 nodes)", () => {
  Ssr.toString(mediumVdom);
});

// Build a large VDOM tree
function buildLargeList(n) {
  const items = [];
  for (let i = 0; i < n; i++) {
    items.push(
      Vdom.nodeA("tr", [], [
        Vdom.nodeA("td", [], [Vdom.text(`${i}`)]),
        Vdom.nodeA("td", [], [Vdom.text(`Name ${i}`)]),
        Vdom.nodeA("td", [], [Vdom.text(`email${i}@example.com`)]),
      ]),
    );
  }
  return Vdom.nodeA(
    "table",
    [Vdom.class_("data-table")],
    [Vdom.nodeA("tbody", [], items)],
  );
}

const largeVdom50 = buildLargeList(50);
const largeVdom200 = buildLargeList(200);

Deno.bench("SSR toString: large table (50 rows, ~200 nodes)", () => {
  Ssr.toString(largeVdom50);
});

Deno.bench("SSR toString: large table (200 rows, ~800 nodes)", () => {
  Ssr.toString(largeVdom200);
});

Deno.bench("SSR toStringPretty: medium (~10 nodes)", () => {
  Ssr.toStringPretty(mediumVdom, 2);
});

Deno.bench("SSR toStringPretty: large table (50 rows)", () => {
  Ssr.toStringPretty(largeVdom50, 2);
});

Deno.bench("SSR escapeHtml: safe string", () => {
  Ssr.escapeHtml("hello world no special chars");
});

Deno.bench("SSR escapeHtml: string with all special chars", () => {
  Ssr.escapeHtml('Hello <world> & "everyone" it\'s a test');
});

// ═══════════════════════════════════════════════════════════════════
// Cmd/Sub Batch Benchmarks
// ═══════════════════════════════════════════════════════════════════

function makeReScriptList(arr) {
  let list = 0; // empty list
  for (let i = arr.length - 1; i >= 0; i--) {
    list = { hd: arr[i], tl: list };
  }
  return list;
}

Deno.bench("Cmd batch: 10 commands", () => {
  const cmds = [];
  for (let i = 0; i < 10; i++) cmds.push(Cmd.msg(i));
  Cmd.batch(makeReScriptList(cmds));
});

Deno.bench("Cmd batch: 100 commands", () => {
  const cmds = [];
  for (let i = 0; i < 100; i++) cmds.push(Cmd.msg(i));
  Cmd.batch(makeReScriptList(cmds));
});

Deno.bench("Cmd batch: 1000 commands", () => {
  const cmds = [];
  for (let i = 0; i < 1000; i++) cmds.push(Cmd.msg(i));
  Cmd.batch(makeReScriptList(cmds));
});

Deno.bench("Cmd map: batch of 100", () => {
  const cmds = [];
  for (let i = 0; i < 100; i++) cmds.push(Cmd.msg(i));
  const batched = Cmd.batch(makeReScriptList(cmds));
  Cmd.map(batched, (n) => n * 2);
});

Deno.bench("Sub batch: 10 subscriptions", () => {
  const subs = [];
  for (let i = 0; i < 10; i++) subs.push(Sub.registration(`k${i}`, (_d) => () => {}));
  Sub.batch(makeReScriptList(subs));
});

Deno.bench("Sub batch: 100 subscriptions", () => {
  const subs = [];
  for (let i = 0; i < 100; i++) subs.push(Sub.registration(`k${i}`, (_d) => () => {}));
  Sub.batch(makeReScriptList(subs));
});

Deno.bench("Sub batch: 1000 subscriptions", () => {
  const subs = [];
  for (let i = 0; i < 1000; i++) subs.push(Sub.registration(`k${i}`, (_d) => () => {}));
  Sub.batch(makeReScriptList(subs));
});

Deno.bench("Sub map: batch of 100", () => {
  const subs = [];
  for (let i = 0; i < 100; i++) subs.push(Sub.registration(`k${i}`, (_d) => () => {}));
  const batched = Sub.batch(makeReScriptList(subs));
  Sub.map(batched, (msg) => ({ wrapped: msg }));
});

Deno.bench("Sub getKeys: batch of 100", () => {
  const subs = [];
  for (let i = 0; i < 100; i++) subs.push(Sub.registration(`k${i}`, (_d) => () => {}));
  const batched = Sub.batch(makeReScriptList(subs));
  Sub.getKeys(batched);
});
