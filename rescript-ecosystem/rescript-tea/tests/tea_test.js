// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// tea_test.js — Comprehensive tests for rescript-tea modules.
// Run: deno test --no-check --allow-all tests/tea_test.js

import { assertEquals, assertExists, assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

import * as Vdom from "../src/tea/Tea_Vdom.res.js";
import * as Json from "../src/tea/Tea_Json.res.js";
import * as Cmd from "../src/tea/Tea_Cmd.res.js";
import * as Sub from "../src/tea/Tea_Sub.res.js";
import * as Ssr from "../src/tea/Tea_Ssr.res.js";
import * as Test from "../src/tea/Tea_Test.res.js";

// ═══════════════════════════════════════════════════════════════════
// Tea_Vdom tests
// ═══════════════════════════════════════════════════════════════════

Deno.test("Tea_Vdom: text creates a Text node", () => {
  const node = Vdom.text("hello");
  assertEquals(node.TAG, "Text");
  assertEquals(node._0, "hello");
});

Deno.test("Tea_Vdom: text with empty string", () => {
  const node = Vdom.text("");
  assertEquals(node.TAG, "Text");
  assertEquals(node._0, "");
});

Deno.test("Tea_Vdom: nodeA creates an Element node", () => {
  const node = Vdom.nodeA("div", [], []);
  assertEquals(node.TAG, "Element");
  assertEquals(node._0, "div");
  assertEquals(node._1.length, 0);
  assertEquals(node._2.length, 0);
});

Deno.test("Tea_Vdom: nodeA with attributes and children", () => {
  const child = Vdom.text("content");
  const attr = Vdom.class_("main");
  const node = Vdom.nodeA("div", [attr], [child]);
  assertEquals(node.TAG, "Element");
  assertEquals(node._0, "div");
  assertEquals(node._1.length, 1);
  assertEquals(node._2.length, 1);
  assertEquals(node._2[0].TAG, "Text");
  assertEquals(node._2[0]._0, "content");
});

Deno.test("Tea_Vdom: keyedA creates a KeyedElement node", () => {
  const child1 = Vdom.text("item 1");
  const child2 = Vdom.text("item 2");
  const node = Vdom.keyedA("ul", [], [["k1", child1], ["k2", child2]]);
  assertEquals(node.TAG, "KeyedElement");
  assertEquals(node._0, "ul");
  assertEquals(node._2.length, 2);
  assertEquals(node._2[0][0], "k1");
  assertEquals(node._2[1][0], "k2");
});

Deno.test("Tea_Vdom: fragmentA creates a Fragment node", () => {
  const c1 = Vdom.text("a");
  const c2 = Vdom.text("b");
  const node = Vdom.fragmentA([c1, c2]);
  assertEquals(node.TAG, "Fragment");
  assertEquals(node._0.length, 2);
});

Deno.test("Tea_Vdom: fragmentA with empty children", () => {
  const node = Vdom.fragmentA([]);
  assertEquals(node.TAG, "Fragment");
  assertEquals(node._0.length, 0);
});

Deno.test("Tea_Vdom: class_ creates a Property attribute", () => {
  const attr = Vdom.class_("my-class");
  assertEquals(attr.TAG, "Property");
  assertEquals(attr._0, "class");
  assertEquals(attr._1, "my-class");
});

Deno.test("Tea_Vdom: id creates an id Property", () => {
  const attr = Vdom.id("main");
  assertEquals(attr.TAG, "Property");
  assertEquals(attr._0, "id");
  assertEquals(attr._1, "main");
});

Deno.test("Tea_Vdom: style creates a Style attribute", () => {
  const attr = Vdom.style("color", "red");
  assertEquals(attr.TAG, "Style");
  assertEquals(attr._0, "color");
  assertEquals(attr._1, "red");
});

Deno.test("Tea_Vdom: prop creates a generic Property", () => {
  const attr = Vdom.prop("data-custom", "value");
  assertEquals(attr.TAG, "Property");
  assertEquals(attr._0, "data-custom");
  assertEquals(attr._1, "value");
});

Deno.test("Tea_Vdom: noProp creates an empty Property", () => {
  assertEquals(Vdom.noProp.TAG, "Property");
  assertEquals(Vdom.noProp._0, "");
  assertEquals(Vdom.noProp._1, "");
});

Deno.test("Tea_Vdom: disabled(true) renders as 'true'", () => {
  const attr = Vdom.disabled(true);
  assertEquals(attr._1, "true");
});

Deno.test("Tea_Vdom: disabled(false) renders as 'false'", () => {
  const attr = Vdom.disabled(false);
  assertEquals(attr._1, "false");
});

Deno.test("Tea_Vdom: onClick creates an Event attribute", () => {
  const attr = Vdom.onClick("Clicked");
  assertEquals(attr.TAG, "Event");
  assertEquals(attr._0, "click");
});

Deno.test("Tea_Vdom: onInput creates an EventWithValue attribute", () => {
  const attr = Vdom.onInput((v) => `typed:${v}`);
  assertEquals(attr.TAG, "EventWithValue");
  assertEquals(attr._0, "input");
});

Deno.test("Tea_Vdom: onSubmit creates an EventPreventDefault attribute", () => {
  const attr = Vdom.onSubmit("Submit");
  assertEquals(attr.TAG, "EventPreventDefault");
  assertEquals(attr._0, "submit");
});

Deno.test("Tea_Vdom: map on Text node preserves text", () => {
  const node = Vdom.text("hello");
  const mapped = Vdom.map(node, (msg) => `mapped:${msg}`);
  assertEquals(mapped.TAG, "Text");
  assertEquals(mapped._0, "hello");
});

Deno.test("Tea_Vdom: map on Element node transforms events", () => {
  const attr = Vdom.onClick("click");
  const child = Vdom.text("child");
  const node = Vdom.nodeA("div", [attr], [child]);
  const mapped = Vdom.map(node, (msg) => `mapped:${msg}`);

  assertEquals(mapped.TAG, "Element");
  assertEquals(mapped._0, "div");
  // The event handler should be mapped
  const mappedEvent = mapped._1[0];
  assertEquals(mappedEvent.TAG, "Event");
  assertEquals(mappedEvent._1(), "mapped:click");
});

Deno.test("Tea_Vdom: map on KeyedElement preserves keys", () => {
  const child = Vdom.text("item");
  const node = Vdom.keyedA("ul", [], [["k1", child]]);
  const mapped = Vdom.map(node, (msg) => `m:${msg}`);
  assertEquals(mapped.TAG, "KeyedElement");
  assertEquals(mapped._2[0][0], "k1");
});

Deno.test("Tea_Vdom: map on Fragment maps all children", () => {
  const c1 = Vdom.text("a");
  const c2 = Vdom.text("b");
  const node = Vdom.fragmentA([c1, c2]);
  const mapped = Vdom.map(node, (msg) => msg);
  assertEquals(mapped.TAG, "Fragment");
  assertEquals(mapped._0.length, 2);
});

Deno.test("Tea_Vdom: mapAttr on Property preserves it unchanged", () => {
  const attr = Vdom.class_("test");
  const mapped = Vdom.mapAttr(attr, (msg) => `x:${msg}`);
  assertEquals(mapped.TAG, "Property");
  assertEquals(mapped._0, "class");
  assertEquals(mapped._1, "test");
});

Deno.test("Tea_Vdom: mapAttr on Style preserves it unchanged", () => {
  const attr = Vdom.style("color", "blue");
  const mapped = Vdom.mapAttr(attr, (msg) => msg);
  assertEquals(mapped.TAG, "Style");
  assertEquals(mapped._0, "color");
  assertEquals(mapped._1, "blue");
});

Deno.test("Tea_Vdom: data_ creates data attribute", () => {
  const attr = Vdom.data_("testid", "123");
  assertEquals(attr.TAG, "Property");
  assertEquals(attr._0, "data-testid");
  assertEquals(attr._1, "123");
});

Deno.test("Tea_Vdom: ariaLabel creates aria-label attribute", () => {
  const attr = Vdom.ariaLabel("Close menu");
  assertEquals(attr._0, "aria-label");
  assertEquals(attr._1, "Close menu");
});

Deno.test("Tea_Vdom: role creates role attribute", () => {
  const attr = Vdom.role("button");
  assertEquals(attr._0, "role");
  assertEquals(attr._1, "button");
});

Deno.test("Tea_Vdom: tabIndex creates tabindex attribute", () => {
  const attr = Vdom.tabIndex(0);
  assertEquals(attr._0, "tabindex");
  assertEquals(attr._1, "0");
});

// ═══════════════════════════════════════════════════════════════════
// Tea_Json tests
// ═══════════════════════════════════════════════════════════════════

Deno.test("Tea_Json: string decoder on string value", () => {
  const result = Json.string("hello");
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, "hello");
});

Deno.test("Tea_Json: string decoder on non-string fails", () => {
  const result = Json.string(42);
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: int decoder on integer value", () => {
  const result = Json.int(42);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, 42);
});

Deno.test("Tea_Json: int decoder on float value fails", () => {
  const result = Json.int(3.14);
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: int decoder on non-number fails", () => {
  const result = Json.int("42");
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: float decoder on number value", () => {
  const result = Json.float(3.14);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, 3.14);
});

Deno.test("Tea_Json: float decoder on integer value", () => {
  const result = Json.float(42);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, 42);
});

Deno.test("Tea_Json: float decoder on non-number fails", () => {
  const result = Json.float("3.14");
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: bool decoder on true", () => {
  const result = Json.bool(true);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, true);
});

Deno.test("Tea_Json: bool decoder on false", () => {
  const result = Json.bool(false);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, false);
});

Deno.test("Tea_Json: bool decoder on non-boolean fails", () => {
  const result = Json.bool("true");
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: null decoder on null value", () => {
  const decoder = Json.$$null("default");
  const result = decoder(null);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, "default");
});

Deno.test("Tea_Json: null decoder on non-null fails", () => {
  const decoder = Json.$$null("default");
  const result = decoder(42);
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: field decoder extracts field", () => {
  const decoder = Json.field("name", Json.string);
  const json = JSON.parse('{"name": "Alice"}');
  const result = decoder(json);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, "Alice");
});

Deno.test("Tea_Json: field decoder on missing field fails", () => {
  const decoder = Json.field("name", Json.string);
  const json = JSON.parse('{"age": 30}');
  const result = decoder(json);
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: field decoder on non-object fails", () => {
  const decoder = Json.field("name", Json.string);
  const result = decoder(42);
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: optionalField returns Some on present field", () => {
  const decoder = Json.optionalField("name", Json.string);
  const json = JSON.parse('{"name": "Alice"}');
  const result = decoder(json);
  assertEquals(result.TAG, "Ok");
  // ReScript Option: Some is the raw value, None is undefined
  assertEquals(result._0, "Alice");
});

Deno.test("Tea_Json: optionalField returns None on missing field", () => {
  const decoder = Json.optionalField("name", Json.string);
  const json = JSON.parse('{"age": 30}');
  const result = decoder(json);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, undefined);
});

Deno.test("Tea_Json: optionalField returns None on null field", () => {
  const decoder = Json.optionalField("name", Json.string);
  const json = JSON.parse('{"name": null}');
  const result = decoder(json);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, undefined);
});

Deno.test("Tea_Json: at decoder navigates nested path", () => {
  const decoder = Json.at(["person", "name"], Json.string);
  const json = JSON.parse('{"person": {"name": "Bob"}}');
  const result = decoder(json);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, "Bob");
});

Deno.test("Tea_Json: at decoder fails on missing intermediate field", () => {
  const decoder = Json.at(["person", "name"], Json.string);
  const json = JSON.parse('{"other": {}}');
  const result = decoder(json);
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: array decoder on valid array", () => {
  const decoder = Json.array(Json.int);
  const json = JSON.parse("[1, 2, 3]");
  const result = decoder(json);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, [1, 2, 3]);
});

Deno.test("Tea_Json: array decoder on empty array", () => {
  const decoder = Json.array(Json.string);
  const json = JSON.parse("[]");
  const result = decoder(json);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, []);
});

Deno.test("Tea_Json: array decoder fails on non-array", () => {
  const decoder = Json.array(Json.int);
  const result = decoder(42);
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: array decoder fails on element type mismatch", () => {
  const decoder = Json.array(Json.int);
  const json = JSON.parse('[1, "two", 3]');
  const result = decoder(json);
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: index decoder extracts element by index", () => {
  const decoder = Json.index(1, Json.string);
  const json = JSON.parse('["a", "b", "c"]');
  const result = decoder(json);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, "b");
});

Deno.test("Tea_Json: index decoder fails on out of bounds", () => {
  const decoder = Json.index(5, Json.string);
  const json = JSON.parse('["a", "b"]');
  const result = decoder(json);
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: map transforms decoder result", () => {
  const decoder = Json.map(Json.int, (n) => n * 2);
  const result = decoder(42);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, 84);
});

Deno.test("Tea_Json: map propagates errors", () => {
  const decoder = Json.map(Json.int, (n) => n * 2);
  const result = decoder("not a number");
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: map2 combines two decoders", () => {
  const decoder = Json.map2(
    (name, age) => ({ name, age }),
    Json.field("name", Json.string),
    Json.field("age", Json.int),
  );
  const json = JSON.parse('{"name": "Alice", "age": 30}');
  const result = decoder(json);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, { name: "Alice", age: 30 });
});

Deno.test("Tea_Json: map2 fails if first decoder fails", () => {
  const decoder = Json.map2(
    (a, b) => [a, b],
    Json.field("missing", Json.string),
    Json.field("age", Json.int),
  );
  const json = JSON.parse('{"age": 30}');
  const result = decoder(json);
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: map3 combines three decoders", () => {
  const decoder = Json.map3(
    (a, b, c) => `${a}-${b}-${c}`,
    Json.field("a", Json.string),
    Json.field("b", Json.string),
    Json.field("c", Json.string),
  );
  const json = JSON.parse('{"a": "x", "b": "y", "c": "z"}');
  const result = decoder(json);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, "x-y-z");
});

Deno.test("Tea_Json: andThen chains decoders", () => {
  // Decode a "type" field, then decode the rest based on its value
  const decoder = Json.andThen(
    Json.field("type", Json.string),
    (type) => {
      if (type === "number") {
        return Json.field("value", Json.int);
      }
      return Json.fail("Unknown type");
    },
  );
  const json = JSON.parse('{"type": "number", "value": 42}');
  const result = decoder(json);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, 42);
});

Deno.test("Tea_Json: andThen propagates first decoder error", () => {
  const decoder = Json.andThen(Json.field("type", Json.string), (_) => Json.succeed(1));
  const json = JSON.parse('{"other": "x"}');
  const result = decoder(json);
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: oneOf tries decoders in order", () => {
  const decoder = Json.oneOf([Json.int, Json.map(Json.string, (s) => parseInt(s))]);
  // Try with a number
  const result1 = decoder(42);
  assertEquals(result1.TAG, "Ok");
  assertEquals(result1._0, 42);
  // Try with a string that can be parsed
  const result2 = decoder("99");
  assertEquals(result2.TAG, "Ok");
  assertEquals(result2._0, 99);
});

Deno.test("Tea_Json: oneOf fails when no decoder matches", () => {
  const decoder = Json.oneOf([Json.int, Json.bool]);
  const result = decoder("hello");
  assertEquals(result.TAG, "Error");
  assertEquals(result._0.TAG, "OneOf");
});

Deno.test("Tea_Json: optional wraps decoder result in option", () => {
  const decoder = Json.optional(Json.int);
  const result1 = decoder(42);
  assertEquals(result1.TAG, "Ok");
  assertEquals(result1._0, 42);

  const result2 = decoder("not a number");
  assertEquals(result2.TAG, "Ok");
  assertEquals(result2._0, undefined);
});

Deno.test("Tea_Json: nullable returns None on null", () => {
  const decoder = Json.nullable(Json.string);
  const result = decoder(null);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, undefined);
});

Deno.test("Tea_Json: nullable decodes non-null values", () => {
  const decoder = Json.nullable(Json.string);
  const result = decoder("hello");
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, "hello");
});

Deno.test("Tea_Json: nullable fails on type mismatch for non-null", () => {
  const decoder = Json.nullable(Json.string);
  const result = decoder(42);
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: succeed always returns the given value", () => {
  const decoder = Json.succeed(42);
  const result1 = decoder("anything");
  assertEquals(result1.TAG, "Ok");
  assertEquals(result1._0, 42);

  const result2 = decoder(null);
  assertEquals(result2.TAG, "Ok");
  assertEquals(result2._0, 42);
});

Deno.test("Tea_Json: fail always returns an error", () => {
  const decoder = Json.fail("nope");
  const result = decoder("anything");
  assertEquals(result.TAG, "Error");
  assertEquals(result._0.TAG, "Failure");
  assertEquals(result._0._0, "nope");
});

Deno.test("Tea_Json: value returns raw JSON", () => {
  const json = JSON.parse('{"key": "val"}');
  const result = Json.value(json);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, json);
});

Deno.test("Tea_Json: decodeString with valid JSON", () => {
  const result = Json.decodeString(Json.int, "42");
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, 42);
});

Deno.test("Tea_Json: decodeString with valid JSON object", () => {
  const decoder = Json.field("name", Json.string);
  const result = Json.decodeString(decoder, '{"name": "Alice"}');
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, "Alice");
});

Deno.test("Tea_Json: decodeString with invalid JSON", () => {
  const result = Json.decodeString(Json.int, "{not valid}");
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: decodeString with valid JSON but wrong type", () => {
  const result = Json.decodeString(Json.int, '"hello"');
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: errorToString on simple Failure", () => {
  const error = { TAG: "Failure", _0: "Expected a string", _1: 42 };
  const str = Json.errorToString(error);
  assertEquals(str, "Expected a string");
});

Deno.test("Tea_Json: errorToString on nested Field error", () => {
  const error = {
    TAG: "Field",
    _0: "user",
    _1: { TAG: "Field", _0: "name", _1: { TAG: "Failure", _0: "Expected a string", _1: null } },
  };
  const str = Json.errorToString(error);
  assert(str.includes("user"));
  assert(str.includes("name"));
  assert(str.includes("Expected a string"));
});

Deno.test("Tea_Json: errorToString on OneOf error", () => {
  const error = {
    TAG: "OneOf",
    _0: [
      { TAG: "Failure", _0: "Expected an integer", _1: "x" },
      { TAG: "Failure", _0: "Expected a boolean", _1: "x" },
    ],
  };
  const str = Json.errorToString(error);
  assert(str.includes("None of the decoders matched"));
});

Deno.test("Tea_Json: dict decoder decodes object as dict", () => {
  const decoder = Json.dict(Json.int);
  const json = JSON.parse('{"a": 1, "b": 2, "c": 3}');
  const result = decoder(json);
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0["a"], 1);
  assertEquals(result._0["b"], 2);
  assertEquals(result._0["c"], 3);
});

Deno.test("Tea_Json: dict decoder fails on non-object", () => {
  const decoder = Json.dict(Json.int);
  const result = decoder(42);
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: dict decoder fails on value type mismatch", () => {
  const decoder = Json.dict(Json.int);
  const json = JSON.parse('{"a": 1, "b": "two"}');
  const result = decoder(json);
  assertEquals(result.TAG, "Error");
});

Deno.test("Tea_Json: toHttpDecoder returns Ok string on success", () => {
  const httpDecoder = Json.toHttpDecoder(Json.field("name", Json.string));
  const result = httpDecoder('{"name": "Alice"}');
  assertEquals(result.TAG, "Ok");
  assertEquals(result._0, "Alice");
});

Deno.test("Tea_Json: toHttpDecoder returns Error string on failure", () => {
  const httpDecoder = Json.toHttpDecoder(Json.field("name", Json.string));
  const result = httpDecoder('{"age": 30}');
  assertEquals(result.TAG, "Error");
  assert(typeof result._0 === "string");
});

// ═══════════════════════════════════════════════════════════════════
// Tea_Cmd tests
// ═══════════════════════════════════════════════════════════════════

Deno.test("Tea_Cmd: none is the string 'None'", () => {
  assertEquals(Cmd.none, "None");
});

Deno.test("Tea_Cmd: msg creates a Msg command", () => {
  const cmd = Cmd.msg("hello");
  assertEquals(cmd.TAG, "Msg");
  assertEquals(cmd._0, "hello");
});

Deno.test("Tea_Cmd: batch of empty list returns none", () => {
  // ReScript list: empty = 0
  const cmd = Cmd.batch(0);
  assertEquals(cmd, "None");
});

Deno.test("Tea_Cmd: batch of single command returns that command", () => {
  // ReScript list: {hd: x, tl: 0}
  const inner = Cmd.msg("a");
  const cmd = Cmd.batch({ hd: inner, tl: 0 });
  assertEquals(cmd.TAG, "Msg");
  assertEquals(cmd._0, "a");
});

Deno.test("Tea_Cmd: batch of multiple commands returns Batch", () => {
  const c1 = Cmd.msg("a");
  const c2 = Cmd.msg("b");
  const cmd = Cmd.batch({ hd: c1, tl: { hd: c2, tl: 0 } });
  assertEquals(cmd.TAG, "Batch");
  assertEquals(cmd._0.length, 2);
});

Deno.test("Tea_Cmd: map on none returns none", () => {
  const result = Cmd.map(Cmd.none, (x) => `mapped:${x}`);
  assertEquals(result, "None");
});

Deno.test("Tea_Cmd: map on Msg transforms the message", () => {
  const cmd = Cmd.msg(10);
  const mapped = Cmd.map(cmd, (n) => n * 2);
  assertEquals(mapped.TAG, "Msg");
  assertEquals(mapped._0, 20);
});

Deno.test("Tea_Cmd: map on Batch maps all inner commands", () => {
  const c1 = Cmd.msg(1);
  const c2 = Cmd.msg(2);
  const batched = Cmd.batch({ hd: c1, tl: { hd: c2, tl: 0 } });
  const mapped = Cmd.map(batched, (n) => n * 10);
  assertEquals(mapped.TAG, "Batch");
  assertEquals(mapped._0[0]._0, 10);
  assertEquals(mapped._0[1]._0, 20);
});

Deno.test("Tea_Cmd: call creates a Call command", () => {
  const cmd = Cmd.call((_callbacks) => {});
  assertEquals(cmd.TAG, "Call");
});

Deno.test("Tea_Cmd: execute dispatches Msg immediately", () => {
  const messages = [];
  Cmd.execute(Cmd.msg("hello"), (m) => messages.push(m));
  assertEquals(messages, ["hello"]);
});

Deno.test("Tea_Cmd: execute on none does nothing", () => {
  const messages = [];
  Cmd.execute(Cmd.none, (m) => messages.push(m));
  assertEquals(messages, []);
});

Deno.test("Tea_Cmd: execute on Batch dispatches all", () => {
  const messages = [];
  const batched = Cmd.batch({ hd: Cmd.msg("a"), tl: { hd: Cmd.msg("b"), tl: 0 } });
  Cmd.execute(batched, (m) => messages.push(m));
  assertEquals(messages, ["a", "b"]);
});

// ═══════════════════════════════════════════════════════════════════
// Tea_Sub tests
// ═══════════════════════════════════════════════════════════════════

Deno.test("Tea_Sub: none is the string 'None'", () => {
  assertEquals(Sub.none, "None");
});

Deno.test("Tea_Sub: registration creates a Registration", () => {
  const sub = Sub.registration("key1", (_dispatch) => () => {});
  assertEquals(sub.TAG, "Registration");
  assertEquals(sub._0, "key1");
});

Deno.test("Tea_Sub: batch of empty list returns none", () => {
  const sub = Sub.batch(0);
  assertEquals(sub, "None");
});

Deno.test("Tea_Sub: batch of single sub returns that sub", () => {
  const inner = Sub.registration("k", (_d) => () => {});
  const sub = Sub.batch({ hd: inner, tl: 0 });
  assertEquals(sub.TAG, "Registration");
});

Deno.test("Tea_Sub: batch of multiple subs returns Batch", () => {
  const s1 = Sub.registration("k1", (_d) => () => {});
  const s2 = Sub.registration("k2", (_d) => () => {});
  const sub = Sub.batch({ hd: s1, tl: { hd: s2, tl: 0 } });
  assertEquals(sub.TAG, "Batch");
  assertEquals(sub._0.length, 2);
});

Deno.test("Tea_Sub: batch filters out None subs", () => {
  const s1 = Sub.none;
  const s2 = Sub.registration("k1", (_d) => () => {});
  const sub = Sub.batch({ hd: s1, tl: { hd: s2, tl: 0 } });
  // Only one non-None, so batch should return it directly
  assertEquals(sub.TAG, "Registration");
});

Deno.test("Tea_Sub: map on none returns none", () => {
  const mapped = Sub.map(Sub.none, (x) => `m:${x}`);
  assertEquals(mapped, "None");
});

Deno.test("Tea_Sub: map on Registration wraps dispatch", () => {
  let capturedMsg = null;
  const sub = Sub.registration("k", (dispatch) => {
    dispatch("original");
    return () => {};
  });
  const mapped = Sub.map(sub, (msg) => `mapped:${msg}`);
  assertEquals(mapped.TAG, "Registration");
  // Enable the mapped subscription
  mapped._1((msg) => {
    capturedMsg = msg;
  });
  assertEquals(capturedMsg, "mapped:original");
});

Deno.test("Tea_Sub: getKeys returns empty for none", () => {
  const keys = Sub.getKeys(Sub.none);
  assertEquals(keys, []);
});

Deno.test("Tea_Sub: getKeys returns key for Registration", () => {
  const sub = Sub.registration("timer-1", (_d) => () => {});
  const keys = Sub.getKeys(sub);
  assertEquals(keys, ["timer-1"]);
});

Deno.test("Tea_Sub: getKeys returns all keys for Batch", () => {
  const s1 = Sub.registration("k1", (_d) => () => {});
  const s2 = Sub.registration("k2", (_d) => () => {});
  const sub = Sub.batch({ hd: s1, tl: { hd: s2, tl: 0 } });
  const keys = Sub.getKeys(sub);
  assertEquals(keys, ["k1", "k2"]);
});

Deno.test("Tea_Sub: enable returns cleanup function", () => {
  let cleaned = false;
  const sub = Sub.registration("k", (_dispatch) => () => {
    cleaned = true;
  });
  const cleanup = Sub.enable(sub, (_msg) => {});
  assertEquals(cleaned, false);
  cleanup();
  assertEquals(cleaned, true);
});

// ═══════════════════════════════════════════════════════════════════
// Tea_Ssr tests
// ═══════════════════════════════════════════════════════════════════

Deno.test("Tea_Ssr: toString on Text node", () => {
  const node = Vdom.text("hello world");
  assertEquals(Ssr.toString(node), "hello world");
});

Deno.test("Tea_Ssr: toString escapes HTML in text", () => {
  const node = Vdom.text("<script>alert('xss')</script>");
  const result = Ssr.toString(node);
  assert(!result.includes("<script>"));
  assert(result.includes("&lt;script&gt;"));
});

Deno.test("Tea_Ssr: toString on empty Element", () => {
  const node = Vdom.nodeA("div", [], []);
  assertEquals(Ssr.toString(node), "<div></div>");
});

Deno.test("Tea_Ssr: toString on Element with text child", () => {
  const node = Vdom.nodeA("p", [], [Vdom.text("hello")]);
  assertEquals(Ssr.toString(node), "<p>hello</p>");
});

Deno.test("Tea_Ssr: toString on Element with class attribute", () => {
  const node = Vdom.nodeA("div", [Vdom.class_("container")], []);
  assertEquals(Ssr.toString(node), '<div class="container"></div>');
});

Deno.test("Tea_Ssr: toString on Element with multiple attributes", () => {
  const node = Vdom.nodeA("input", [Vdom.type_("text"), Vdom.id("name")], []);
  const result = Ssr.toString(node);
  assert(result.includes('type="text"'));
  assert(result.includes('id="name"'));
});

Deno.test("Tea_Ssr: toString on void element (br)", () => {
  const node = Vdom.nodeA("br", [], []);
  assertEquals(Ssr.toString(node), "<br />");
});

Deno.test("Tea_Ssr: toString on void element (img)", () => {
  const node = Vdom.nodeA("img", [Vdom.src("photo.jpg"), Vdom.alt("Photo")], []);
  const result = Ssr.toString(node);
  assert(result.startsWith("<img"));
  assert(result.endsWith(" />"));
  assert(result.includes('src="photo.jpg"'));
  assert(result.includes('alt="Photo"'));
});

Deno.test("Tea_Ssr: toString on void element (hr)", () => {
  const node = Vdom.nodeA("hr", [], []);
  assertEquals(Ssr.toString(node), "<hr />");
});

Deno.test("Tea_Ssr: toString on void element (input)", () => {
  const node = Vdom.nodeA("input", [Vdom.type_("text")], []);
  const result = Ssr.toString(node);
  assert(result.startsWith("<input"));
  assert(result.endsWith(" />"));
});

Deno.test("Tea_Ssr: toString on Fragment", () => {
  const node = Vdom.fragmentA([Vdom.text("a"), Vdom.text("b")]);
  assertEquals(Ssr.toString(node), "ab");
});

Deno.test("Tea_Ssr: toString on Fragment with elements", () => {
  const node = Vdom.fragmentA([
    Vdom.nodeA("span", [], [Vdom.text("hello")]),
    Vdom.nodeA("span", [], [Vdom.text("world")]),
  ]);
  assertEquals(Ssr.toString(node), "<span>hello</span><span>world</span>");
});

Deno.test("Tea_Ssr: toString on nested elements", () => {
  const node = Vdom.nodeA("div", [], [
    Vdom.nodeA("ul", [], [
      Vdom.nodeA("li", [], [Vdom.text("item 1")]),
      Vdom.nodeA("li", [], [Vdom.text("item 2")]),
    ]),
  ]);
  assertEquals(Ssr.toString(node), "<div><ul><li>item 1</li><li>item 2</li></ul></div>");
});

Deno.test("Tea_Ssr: toString on KeyedElement", () => {
  const node = Vdom.keyedA("ul", [], [
    ["k1", Vdom.nodeA("li", [], [Vdom.text("a")])],
    ["k2", Vdom.nodeA("li", [], [Vdom.text("b")])],
  ]);
  assertEquals(Ssr.toString(node), "<ul><li>a</li><li>b</li></ul>");
});

Deno.test("Tea_Ssr: toString escapes attribute values", () => {
  const node = Vdom.nodeA("div", [Vdom.class_('a"b')], []);
  const result = Ssr.toString(node);
  assert(result.includes('class="a&quot;b"'));
});

Deno.test("Tea_Ssr: toString renders style attributes as collected style", () => {
  const node = Vdom.nodeA(
    "div",
    [Vdom.style("color", "red"), Vdom.style("font-size", "14px")],
    [],
  );
  const result = Ssr.toString(node);
  assert(result.includes('style="'));
  assert(result.includes("color: red"));
  assert(result.includes("font-size: 14px"));
});

Deno.test("Tea_Ssr: toString renders boolean attribute (checked true)", () => {
  const node = Vdom.nodeA("input", [Vdom.type_("checkbox"), Vdom.checked(true)], []);
  const result = Ssr.toString(node);
  // Boolean attribute should appear as just the attribute name when true
  assert(result.includes(" checked"));
  // Should NOT include checked="true"
  assert(!result.includes('checked="true"'));
});

Deno.test("Tea_Ssr: toString omits boolean attribute when false", () => {
  const node = Vdom.nodeA("input", [Vdom.type_("checkbox"), Vdom.checked(false)], []);
  const result = Ssr.toString(node);
  assert(!result.includes("checked"));
});

Deno.test("Tea_Ssr: toString skips event attributes", () => {
  const node = Vdom.nodeA("button", [Vdom.onClick("Click")], [Vdom.text("Go")]);
  assertEquals(Ssr.toString(node), "<button>Go</button>");
});

Deno.test("Tea_Ssr: toString skips noProp", () => {
  const node = Vdom.nodeA("div", [Vdom.noProp], []);
  assertEquals(Ssr.toString(node), "<div></div>");
});

Deno.test("Tea_Ssr: toStringPretty with default indent", () => {
  const node = Vdom.nodeA("div", [], [
    Vdom.nodeA("p", [], [Vdom.text("hello")]),
  ]);
  const result = Ssr.toStringPretty(node, 2);
  assert(result.includes("<div>"));
  assert(result.includes("  <p>hello</p>"));
  assert(result.includes("</div>"));
});

Deno.test("Tea_Ssr: toStringPretty with custom indent", () => {
  const node = Vdom.nodeA("div", [], [
    Vdom.nodeA("span", [], [Vdom.text("hi")]),
  ]);
  const result = Ssr.toStringPretty(node, 4);
  assert(result.includes("    <span>hi</span>"));
});

Deno.test("Tea_Ssr: toStringPretty on empty element", () => {
  const node = Vdom.nodeA("div", [], []);
  const result = Ssr.toStringPretty(node, 2);
  assertEquals(result, "<div></div>");
});

Deno.test("Tea_Ssr: toStringPretty on Fragment", () => {
  const node = Vdom.fragmentA([Vdom.text("a"), Vdom.text("b")]);
  const result = Ssr.toStringPretty(node, 2);
  assert(result.includes("a"));
  assert(result.includes("b"));
});

Deno.test("Tea_Ssr: escapeHtml escapes all special characters", () => {
  const result = Ssr.escapeHtml('&<>"\'');
  assertEquals(result, "&amp;&lt;&gt;&quot;&#x27;");
});

Deno.test("Tea_Ssr: escapeHtml on safe string is identity", () => {
  assertEquals(Ssr.escapeHtml("hello world"), "hello world");
});

Deno.test("Tea_Ssr: isVoidElement recognises all void elements", () => {
  const voids = ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"];
  for (const tag of voids) {
    assertEquals(Ssr.isVoidElement(tag), true, `${tag} should be void`);
  }
});

Deno.test("Tea_Ssr: isVoidElement returns false for regular elements", () => {
  assertEquals(Ssr.isVoidElement("div"), false);
  assertEquals(Ssr.isVoidElement("span"), false);
  assertEquals(Ssr.isVoidElement("p"), false);
});

// ═══════════════════════════════════════════════════════════════════
// Tea_Test tests (meta: testing the test module)
// ═══════════════════════════════════════════════════════════════════

// A simple counter app for testing Tea_Test
const counterInit = () => [0, Cmd.none];
const counterUpdate = (model, msg) => {
  switch (msg) {
    case "Increment":
      return [model + 1, Cmd.none];
    case "Decrement":
      return [model - 1, Cmd.none];
    case "Reset":
      return [0, Cmd.none];
    default:
      return [model, Cmd.none];
  }
};

Deno.test("Tea_Test: simulate creates simulation with initial model", () => {
  const sim = Test.simulate(counterInit, counterUpdate);
  assertEquals(Test.model(sim), 0);
});

Deno.test("Tea_Test: send updates the model", () => {
  const sim = Test.simulate(counterInit, counterUpdate);
  Test.send(sim, "Increment");
  assertEquals(Test.model(sim), 1);
});

Deno.test("Tea_Test: send multiple messages", () => {
  const sim = Test.simulate(counterInit, counterUpdate);
  Test.send(sim, "Increment");
  Test.send(sim, "Increment");
  Test.send(sim, "Increment");
  assertEquals(Test.model(sim), 3);
});

Deno.test("Tea_Test: send decrement", () => {
  const sim = Test.simulate(counterInit, counterUpdate);
  Test.send(sim, "Decrement");
  assertEquals(Test.model(sim), -1);
});

Deno.test("Tea_Test: messageCount tracks sent messages", () => {
  const sim = Test.simulate(counterInit, counterUpdate);
  assertEquals(Test.messageCount(sim), 0);
  Test.send(sim, "Increment");
  assertEquals(Test.messageCount(sim), 1);
  Test.send(sim, "Increment");
  assertEquals(Test.messageCount(sim), 2);
});

Deno.test("Tea_Test: sendAll sends multiple messages at once", () => {
  const sim = Test.simulate(counterInit, counterUpdate);
  Test.sendAll(sim, ["Increment", "Increment", "Increment", "Decrement"]);
  assertEquals(Test.model(sim), 2);
  assertEquals(Test.messageCount(sim), 4);
});

Deno.test("Tea_Test: messageHistory records all messages", () => {
  const sim = Test.simulate(counterInit, counterUpdate);
  Test.send(sim, "Increment");
  Test.send(sim, "Decrement");
  Test.send(sim, "Reset");
  assertEquals(Test.messageHistory(sim), ["Increment", "Decrement", "Reset"]);
});

Deno.test("Tea_Test: assertModel passes for correct predicate", () => {
  const sim = Test.simulate(counterInit, counterUpdate);
  Test.send(sim, "Increment");
  const result = Test.assertModel(sim, (m) => m === 1, "should be 1");
  assertEquals(result, true);
});

Deno.test("Tea_Test: assertModel fails for incorrect predicate", () => {
  const sim = Test.simulate(counterInit, counterUpdate);
  // Suppress console.error for this test
  const origError = console.error;
  console.error = () => {};
  const result = Test.assertModel(sim, (m) => m === 99, "should be 99");
  console.error = origError;
  assertEquals(result, false);
});

Deno.test("Tea_Test: runScenario executes steps and reports results", () => {
  const sim = Test.simulate(counterInit, counterUpdate);
  const results = Test.runScenario(sim, [
    ["Increment", (m) => m === 1, "first increment"],
    ["Increment", (m) => m === 2, "second increment"],
    ["Decrement", (m) => m === 1, "decrement back"],
  ]);
  assertEquals(results.length, 3);
  // Each result is [stepIndex, label, passed]
  assertEquals(results[0][2], true);
  assertEquals(results[1][2], true);
  assertEquals(results[2][2], true);
});

Deno.test("Tea_Test: runScenario reports failures", () => {
  const sim = Test.simulate(counterInit, counterUpdate);
  const origError = console.error;
  console.error = () => {};
  const results = Test.runScenario(sim, [
    ["Increment", (m) => m === 999, "impossible check"],
  ]);
  console.error = origError;
  assertEquals(results[0][2], false);
});

Deno.test("Tea_Test: viewSnapshot renders model through view", () => {
  const view = (model) => Vdom.nodeA("span", [], [Vdom.text(`Count: ${model}`)]);
  const html = Test.viewSnapshot(view, 42);
  assertEquals(html, "<span>Count: 42</span>");
});

Deno.test("Tea_Test: viewSnapshot with complex view", () => {
  const view = (model) =>
    Vdom.nodeA("div", [Vdom.class_("counter")], [
      Vdom.nodeA("h1", [], [Vdom.text("Counter")]),
      Vdom.nodeA("p", [], [Vdom.text(`Value: ${model}`)]),
    ]);
  const html = Test.viewSnapshot(view, 5);
  assert(html.includes('<div class="counter">'));
  assert(html.includes("<h1>Counter</h1>"));
  assert(html.includes("<p>Value: 5</p>"));
});

Deno.test("Tea_Test: hasCommands returns false for no commands", () => {
  const sim = Test.simulate(counterInit, counterUpdate);
  assertEquals(Test.hasCommands(sim), false);
});

Deno.test("Tea_Test: simulate with init that produces a command", () => {
  const initWithCmd = () => [0, Cmd.msg("InitDone")];
  const sim = Test.simulate(initWithCmd, counterUpdate);
  assertEquals(Test.model(sim), 0);
  assertEquals(Test.hasCommands(sim), true);
});
