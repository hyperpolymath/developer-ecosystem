// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Joshua B. Jewell and Jonathan D.A. Jewell
// connectivity_test.mjs — Smoke-test for sync server WebSocket + REST
//
// Validates that the sync server container is reachable and the Phoenix
// Channel handshake works.  Run after `podman-compose up -d`:
//
//   deno run --allow-net test/connectivity_test.mjs
//   # or against a non-default host/port:
//   SYNC_HOST=localhost SYNC_PORT=4000 deno run --allow-net test/connectivity_test.mjs

const HOST = Deno.env.get("SYNC_HOST") ?? "localhost";
const PORT = parseInt(Deno.env.get("SYNC_PORT") ?? "4000");
const BASE_URL = `http://${HOST}:${PORT}`;
// vsn=2.0.0 tells Phoenix to use V2 JSON serializer, which encodes messages
// as arrays [join_ref, ref, topic, event, payload] rather than the V1 object
// format {topic, event, payload, ref}.  Raw WebSocket clients must opt-in.
const WS_URL  = `ws://${HOST}:${PORT}/socket/websocket?vsn=2.0.0`;

let passed = 0;
let failed = 0;

// ---------------------------------------------------------------------------
// Minimal assertion helpers
// ---------------------------------------------------------------------------

function assert(condition, label) {
  if (condition) {
    console.log(`  ✓ ${label}`);
    passed++;
  } else {
    console.error(`  ✗ ${label}`);
    failed++;
  }
}

async function assertJson(url, label, check) {
  try {
    const res = await fetch(url);
    const body = await res.json();
    assert(check(res, body), `${label} [${res.status}]`);
  } catch (e) {
    console.error(`  ✗ ${label} — ${e.message}`);
    failed++;
  }
}

// ---------------------------------------------------------------------------
// REST smoke tests
// ---------------------------------------------------------------------------

console.log("\n── REST API ─────────────────────────────────────────────────");

await assertJson(`${BASE_URL}/health`, "GET /health returns {status:'ok'}", (_r, body) =>
  body.status === "ok"
);

await assertJson(`${BASE_URL}/`, "GET / returns server info", (_r, body) =>
  body.server === "IDApTIK Sync Server" && Array.isArray(body.channels)
);

await assertJson(`${BASE_URL}/sessions`, "GET /sessions returns array", (_r, body) =>
  Array.isArray(body)
);

await assertJson(`${BASE_URL}/sessions/nonexistent`, "GET /sessions/:id returns 404 for unknown", (r, _body) =>
  r.status === 404
);

// ---------------------------------------------------------------------------
// WebSocket Phoenix Channel handshake
// ---------------------------------------------------------------------------

console.log("\n── WebSocket Channel ────────────────────────────────────────");

await new Promise((resolve) => {
  const ws = new WebSocket(`${WS_URL}&player_id=test_smoke_runner`);
  const sessionId = `smoke_${Date.now()}`;
  let joinAcked = false;
  let timeout;

  ws.onopen = () => {
    assert(true, "WebSocket connection established");

    // Send Phoenix Channel join message for game:<session_id>
    // Phoenix wire format: [join_ref, ref, topic, event, payload]
    const joinMsg = JSON.stringify([null, "1", `game:${sessionId}`, "phx_join", {
      player_id: "smoke_hacker",
      role: "hacker",
    }]);
    ws.send(joinMsg);

    // 3-second timeout — server should reply quickly
    timeout = setTimeout(() => {
      if (!joinAcked) {
        assert(false, "Channel join acknowledged within 3 s");
      }
      ws.close();
    }, 3000);
  };

  ws.onmessage = (event) => {
    try {
      const msg = JSON.parse(event.data);
      // Phoenix reply: [join_ref, ref, topic, "phx_reply", {status, response}]
      // Guard: only process the first phx_reply to prevent looping when the
      // server sends additional replies (e.g. for subsequent position events).
      if (Array.isArray(msg) && msg[3] === "phx_reply" && !joinAcked) {
        const status = msg[4]?.status;
        joinAcked = true;
        clearTimeout(timeout);
        assert(status === "ok", `Channel join acknowledged (status="${status}")`);

        // Send a position update to validate event routing
        ws.send(JSON.stringify([null, "2", `game:${sessionId}`, "position", { x: 42, y: 100 }]));
        setTimeout(() => ws.close(), 200);
      }
    } catch (_) {
      // Non-JSON frame — ignore
    }
  };

  ws.onerror = (err) => {
    assert(false, `WebSocket error: ${err.message ?? "unknown"}`);
    clearTimeout(timeout);
    ws.close();
  };

  ws.onclose = () => resolve();
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

console.log(`\n── Results ──────────────────────────────────────────────────`);
console.log(`   Passed: ${passed}   Failed: ${failed}`);

if (failed > 0) {
  console.error("\nSome tests failed. Is the sync server running?");
  console.error(`  podman-compose up -d\n  # wait ~20s for healthcheck, then re-run`);
  Deno.exit(1);
} else {
  console.log("\nAll checks passed — sync server is reachable and accepting channels.");
}
