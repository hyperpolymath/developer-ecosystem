// SPDX-License-Identifier: PMPL-1.0-or-later
// Deno test runner for Alib_String

import { runTests } from "./Alib_String_test.res.js";

Deno.test("Alib.String: Branded string types", () => {
  runTests();
});
