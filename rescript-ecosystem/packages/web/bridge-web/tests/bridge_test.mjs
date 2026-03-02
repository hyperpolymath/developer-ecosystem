// SPDX-License-Identifier: PMPL-1.0 OR PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2024 Hyperpolymath

/**
 * Bridge module tests - verifies input → output transformations
 */

import { test, describe } from "node:test";
import { strictEqual, deepStrictEqual } from "node:assert";
import {
  defaultConfig,
  transform,
  transformSafe,
  compose,
  identity,
  uppercase,
  prefix,
  suffix,
  info,
} from "../lib/es6/src/Bridge.mjs";

describe("Bridge", () => {
  describe("transform", () => {
    test("adds bridge prefix to input", () => {
      strictEqual(transform("hello"), "[bridge] hello");
    });

    test("handles empty string", () => {
      strictEqual(transform(""), "[bridge] ");
    });
  });

  describe("transformSafe", () => {
    test("returns Ok for valid input", () => {
      const result = transformSafe("hello");
      deepStrictEqual(result, { TAG: "Ok", _0: "[bridge] hello" });
    });

    test("returns Error for empty input", () => {
      const result = transformSafe("");
      deepStrictEqual(result, { TAG: "Error", _0: "Input cannot be empty" });
    });
  });

  describe("compose", () => {
    test("composes two functions left-to-right", () => {
      const prefixHello = prefix("hello-");
      const suffixWorld = suffix("-world");
      const composed = compose(prefixHello, suffixWorld);
      strictEqual(composed("test"), "hello-test-world");
    });
  });

  describe("identity", () => {
    test("returns input unchanged", () => {
      strictEqual(identity("test"), "test");
    });
  });

  describe("uppercase", () => {
    test("converts string to uppercase", () => {
      strictEqual(uppercase("hello"), "HELLO");
    });
  });

  describe("prefix", () => {
    test("creates a function that adds prefix", () => {
      const addPrefix = prefix("pre-");
      strictEqual(addPrefix("test"), "pre-test");
    });
  });

  describe("suffix", () => {
    test("creates a function that adds suffix", () => {
      const addSuffix = suffix("-suf");
      strictEqual(addSuffix("test"), "test-suf");
    });
  });

  describe("info", () => {
    test("returns formatted config info", () => {
      strictEqual(info(defaultConfig), "bridge v0.1.0");
    });

    test("works with custom config", () => {
      const customConfig = { name: "custom", version: "1.0.0" };
      strictEqual(info(customConfig), "custom v1.0.0");
    });
  });

  describe("defaultConfig", () => {
    test("has correct default values", () => {
      deepStrictEqual(defaultConfig, { name: "bridge", version: "0.1.0" });
    });
  });
});
