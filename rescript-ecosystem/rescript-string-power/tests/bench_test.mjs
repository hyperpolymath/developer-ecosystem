// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// T5 — Benchmarks for the core string-interpolation primitives.
// Run with: deno bench --allow-read tests/bench_test.mjs

function interleave(statics, dynamics) {
  let result = statics[0];
  for (let i = 0; i < dynamics.length; i++) {
    result = result + dynamics[i] + statics[i + 1];
  }
  return result;
}

function interleaveJoin(statics, dynamics) {
  const parts = [statics[0]];
  for (let i = 0; i < dynamics.length; i++) {
    parts.push(dynamics[i], statics[i + 1]);
  }
  return parts.join("");
}

function escapeHtml(s) {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

const SMALL_STATICS = ["SELECT * FROM ", " WHERE id = ", " AND status = ", ""];
const SMALL_DYNAMICS = ["users", "42", "'active'"];

const BIG_STATICS = Array.from({ length: 21 }, (_, i) => `chunk${i}_`);
const BIG_DYNAMICS = Array.from({ length: 20 }, (_, i) => `val${i}`);

const XSS_INPUT =
  "<script>alert('xss')</script> & other \"fun\" tags <img onerror='x' />";

// ── Interleave ─────────────────────────────────────────────────────────────

Deno.bench("interleave small (3 dynamics)", () => {
  interleave(SMALL_STATICS, SMALL_DYNAMICS);
});

Deno.bench("interleave large (20 dynamics)", () => {
  interleave(BIG_STATICS, BIG_DYNAMICS);
});

Deno.bench("interleave via Array.join large", () => {
  interleaveJoin(BIG_STATICS, BIG_DYNAMICS);
});

// ── Escape ────────────────────────────────────────────────────────────────

Deno.bench("escapeHtml short", () => {
  escapeHtml("hello <world> & 'friends'");
});

Deno.bench("escapeHtml typical XSS payload", () => {
  escapeHtml(XSS_INPUT);
});

Deno.bench("escapeHtml long (2 KiB)", () => {
  escapeHtml(XSS_INPUT.repeat(30));
});
