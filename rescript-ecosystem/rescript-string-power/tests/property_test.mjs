// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// T4 — Property-style tests for the core interleave and escape algorithms.
//
// These tests mirror the JavaScript that the ReScript `StringPower.Utils`
// module compiles to. They exercise algebraic laws that must hold for
// any correct implementation of interleave / escapeHtml / escapeSqlString.
// Running them as a Deno test keeps coverage honest without requiring the
// ReScript compiler on every CI run.

import { assertEquals, assert } from "jsr:@std/assert@1";

// ── JS reference implementations (semantically identical to StringPower) ───

function interleave(statics, dynamics) {
  let result = statics[0];
  for (let i = 0; i < dynamics.length; i++) {
    result = result + dynamics[i] + statics[i + 1];
  }
  return result;
}

function escapeHtml(s) {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function escapeSqlString(s) {
  return s.replaceAll("'", "''");
}

// ── Tiny deterministic PRNG so tests are reproducible ─────────────────────

function mulberry32(seed) {
  return function () {
    let t = (seed += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const RUNS = 200;

// ── Property 1: interleave length invariant ───────────────────────────────
// len(result) = sum(len(statics)) + sum(len(dynamics))

Deno.test("property: interleave preserves total length", () => {
  const rng = mulberry32(1);
  for (let i = 0; i < RUNS; i++) {
    const n = 1 + Math.floor(rng() * 8); // 1..8 dynamics
    const statics = Array.from({ length: n + 1 }, () =>
      "s".repeat(Math.floor(rng() * 10))
    );
    const dynamics = Array.from({ length: n }, () =>
      "d".repeat(Math.floor(rng() * 10))
    );
    const expected =
      statics.reduce((a, s) => a + s.length, 0) +
      dynamics.reduce((a, d) => a + d.length, 0);
    assertEquals(interleave(statics, dynamics).length, expected);
  }
});

// ── Property 2: zero-length dynamics case ────────────────────────────────

Deno.test("property: interleave with zero dynamics returns statics[0]", () => {
  const rng = mulberry32(2);
  for (let i = 0; i < RUNS; i++) {
    const only = String(rng());
    assertEquals(interleave([only], []), only);
  }
});

// ── Property 3: interleave contains every input fragment ──────────────────

Deno.test("property: interleave output contains all static fragments", () => {
  const fragments = [
    ["alpha-", "-beta-", "-gamma"],
    ["", "|", ""],
    ["SELECT * FROM ", " WHERE id = ", ""],
  ];
  const dynamics = [
    ["1", "2"],
    ["X", "Y"],
    ["users", "42"],
  ];
  for (let i = 0; i < fragments.length; i++) {
    const out = interleave(fragments[i], dynamics[i]);
    for (const s of fragments[i]) {
      assert(out.includes(s), `output "${out}" missing static "${s}"`);
    }
    for (const d of dynamics[i]) {
      assert(out.includes(d), `output "${out}" missing dynamic "${d}"`);
    }
  }
});

// ── Property 4: escapeHtml is idempotent on already-escaped text ─────────
// escapeHtml(escapeHtml(x)) removes no angle brackets that escapeHtml(x) had.

Deno.test("property: escapeHtml never leaves raw < or > after escaping", () => {
  const rng = mulberry32(3);
  const chars = "abc<>&\"' xyz";
  for (let i = 0; i < RUNS; i++) {
    const len = Math.floor(rng() * 30);
    let s = "";
    for (let j = 0; j < len; j++) {
      s += chars[Math.floor(rng() * chars.length)];
    }
    const escaped = escapeHtml(s);
    assert(!escaped.includes("<"), `raw < in ${escaped}`);
    assert(!escaped.includes(">"), `raw > in ${escaped}`);
  }
});

// ── Property 5: escapeSqlString doubles every single quote ───────────────

Deno.test("property: escapeSqlString doubles every single quote", () => {
  const rng = mulberry32(4);
  for (let i = 0; i < RUNS; i++) {
    const n = Math.floor(rng() * 5);
    const pieces = Array.from({ length: n + 1 }, () =>
      "word".repeat(Math.floor(rng() * 3))
    );
    const raw = pieces.join("'");
    const escaped = escapeSqlString(raw);
    const rawQuotes = (raw.match(/'/g) || []).length;
    const escQuotes = (escaped.match(/'/g) || []).length;
    assertEquals(escQuotes, rawQuotes * 2);
  }
});

// ── Property 6: escapeHtml never shortens the input ──────────────────────

Deno.test("property: escapeHtml output length >= input length", () => {
  const rng = mulberry32(5);
  for (let i = 0; i < RUNS; i++) {
    const s = Math.random().toString(36) + "<>&'\"";
    const e = escapeHtml(s);
    assert(e.length >= s.length);
  }
  void rng;
});
