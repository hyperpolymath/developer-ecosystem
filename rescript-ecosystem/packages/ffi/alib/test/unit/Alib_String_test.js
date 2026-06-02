// SPDX-License-Identifier: MPL-2.0
// Deno test runner for Alib_String

import { runTests } from "./Alib_String_test.res.js";

Deno.test("Alib.String: Branded string types", () => {
  runTests();
});
