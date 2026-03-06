// SPDX-License-Identifier: PMPL-1.0 OR PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2024 Hyperpolymath

/**
 * Bridge Contract Tests
 *
 * These tests verify behavioral invariants and algebraic properties
 * of the Bridge module, ensuring the API contracts are upheld.
 */

import { test, describe } from "node:test";
import { strictEqual, deepStrictEqual, ok } from "node:assert";
import {
  transform,
  transformSafe,
  compose,
  identity,
  uppercase,
  prefix,
  suffix,
  info,
} from "../lib/es6/src/Bridge.mjs";

describe("Bridge Contracts", () => {

  describe("identity laws", () => {
    test("identity returns input unchanged for any string", () => {
      const testCases = ["", "hello", "  spaces  ", "123", "émoji 🎉", "\n\t"];
      for (const input of testCases) {
        strictEqual(identity(input), input, `identity(${JSON.stringify(input)}) should equal input`);
      }
    });

    test("identity ∘ identity = identity (idempotent)", () => {
      const input = "test";
      strictEqual(identity(identity(input)), identity(input));
    });
  });

  describe("composition laws", () => {
    test("compose(f, identity) = f (right identity)", () => {
      const f = prefix("pre-");
      const composed = compose(f, identity);
      const input = "test";
      strictEqual(composed(input), f(input));
    });

    test("compose(identity, f) = f (left identity)", () => {
      const f = suffix("-suf");
      const composed = compose(identity, f);
      const input = "test";
      strictEqual(composed(input), f(input));
    });

    test("compose(f, compose(g, h)) = compose(compose(f, g), h) (associativity)", () => {
      const f = prefix("a-");
      const g = suffix("-b");
      const h = uppercase;
      const input = "x";

      const leftAssoc = compose(f, compose(g, h));
      const rightAssoc = compose(compose(f, g), h);

      strictEqual(leftAssoc(input), rightAssoc(input));
    });
  });

  describe("transform contracts", () => {
    test("transform always prepends [bridge] prefix", () => {
      const inputs = ["", "a", "hello world", "123"];
      for (const input of inputs) {
        ok(transform(input).startsWith("[bridge] "),
           `transform(${JSON.stringify(input)}) should start with [bridge] `);
      }
    });

    test("transform preserves input after prefix", () => {
      const input = "original";
      strictEqual(transform(input), "[bridge] " + input);
    });

    test("transform output length = input length + 9", () => {
      const inputs = ["", "a", "hello"];
      for (const input of inputs) {
        strictEqual(transform(input).length, input.length + 9,
          `transform adds exactly 9 characters ([bridge] )`);
      }
    });
  });

  describe("transformSafe contracts", () => {
    test("transformSafe returns Error variant for empty string only", () => {
      const result = transformSafe("");
      strictEqual(result.TAG, "Error");
    });

    test("transformSafe returns Ok variant for non-empty strings", () => {
      const inputs = [" ", "a", "test", "\n"];
      for (const input of inputs) {
        const result = transformSafe(input);
        strictEqual(result.TAG, "Ok",
          `transformSafe(${JSON.stringify(input)}) should return Ok`);
      }
    });

    test("transformSafe Ok value equals transform output", () => {
      const input = "test";
      const result = transformSafe(input);
      strictEqual(result._0, transform(input));
    });

    test("transformSafe result is exhaustive (Ok or Error)", () => {
      const inputs = ["", "a", "test"];
      for (const input of inputs) {
        const result = transformSafe(input);
        ok(result.TAG === "Ok" || result.TAG === "Error",
          "Result must be Ok or Error");
      }
    });
  });

  describe("prefix/suffix factory contracts", () => {
    test("prefix factory returns a function", () => {
      strictEqual(typeof prefix("x"), "function");
    });

    test("suffix factory returns a function", () => {
      strictEqual(typeof suffix("x"), "function");
    });

    test("prefix(a)(prefix(b)(x)) = prefix(a + b)(x) (prefix composition)", () => {
      const input = "test";
      const a = "first-";
      const b = "second-";
      strictEqual(prefix(a)(prefix(b)(input)), a + b + input);
    });

    test("suffix(a)(suffix(b)(x)) has both suffixes", () => {
      const input = "test";
      const result = suffix("-a")(suffix("-b")(input));
      strictEqual(result, "test-b-a");
    });

    test("prefix with empty string is identity-like", () => {
      const input = "test";
      strictEqual(prefix("")(input), input);
    });

    test("suffix with empty string is identity-like", () => {
      const input = "test";
      strictEqual(suffix("")(input), input);
    });
  });

  describe("uppercase contracts", () => {
    test("uppercase is idempotent: uppercase(uppercase(x)) = uppercase(x)", () => {
      const inputs = ["hello", "HELLO", "HeLLo", "123", ""];
      for (const input of inputs) {
        strictEqual(uppercase(uppercase(input)), uppercase(input),
          `uppercase should be idempotent for ${JSON.stringify(input)}`);
      }
    });

    test("uppercase preserves length", () => {
      const inputs = ["hello", "test", "abc123"];
      for (const input of inputs) {
        strictEqual(uppercase(input).length, input.length);
      }
    });

    test("uppercase of empty string is empty string", () => {
      strictEqual(uppercase(""), "");
    });
  });

  describe("info contracts", () => {
    test("info output contains config name", () => {
      const config = { name: "mybridge", version: "1.0.0" };
      ok(info(config).includes(config.name));
    });

    test("info output contains config version", () => {
      const config = { name: "mybridge", version: "2.5.3" };
      ok(info(config).includes(config.version));
    });

    test("info format is 'name vversion'", () => {
      const config = { name: "test", version: "1.0.0" };
      strictEqual(info(config), "test v1.0.0");
    });
  });

  describe("type preservation contracts", () => {
    test("all transform functions return strings", () => {
      const fns = [
        () => transform("x"),
        () => identity("x"),
        () => uppercase("x"),
        () => prefix("a")("x"),
        () => suffix("b")("x"),
        () => compose(identity, identity)("x"),
      ];
      for (const fn of fns) {
        strictEqual(typeof fn(), "string", "Function should return string");
      }
    });
  });
});
