# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (c) 2026 Joshua B. Jewell and Jonathan D.A. Jewell
#
# test/property_test.exs
# Property-based (P2P) tests for IDApTIK Sync Server using StreamData.
#
# These tests verify invariants that must hold for any valid input:
#   P1 - JSON encode/decode roundtrip for any map with string keys + safe values.
#   P2 - Router health endpoint always returns 200 regardless of request context.
#   P3 - JSON encoding of response payloads always produces valid binary output.
#   P4 - Level ID strings with arbitrary alphanumeric content don't crash routing.
#   P5 - Repeated Jason.encode! calls on the same term are deterministic.

defmodule IDApixiTIK.SyncServer.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  use Plug.Test

  alias IDApixiTIK.SyncServerWeb.Endpoint

  @opts Endpoint.init([])

  # ---------------------------------------------------------------------------
  # P1: Jason JSON roundtrip invariant
  # ---------------------------------------------------------------------------

  property "P1: Jason.encode!/1 followed by Jason.decode!/1 is identity for maps" do
    check all(
      pairs <-
        map_of(
          string(:alphanumeric, min_length: 1, max_length: 20),
          one_of([string(:alphanumeric), integer(), boolean(), constant(nil)]),
          min_length: 0,
          max_length: 10
        )
    ) do
      encoded = Jason.encode!(pairs)
      decoded = Jason.decode!(encoded)

      # String keys are preserved; nil values become JSON null and decode back to nil.
      for {k, v} <- pairs do
        assert decoded[k] == v,
               "Roundtrip mismatch for key #{inspect(k)}: #{inspect(v)} != #{inspect(decoded[k])}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # P2: Health endpoint invariant
  # ---------------------------------------------------------------------------

  property "P2: GET /health always returns 200 regardless of arbitrary header values" do
    check all(
      header_value <- string(:printable, min_length: 0, max_length: 64),
      max_runs: 20
    ) do
      conn =
        conn(:get, "/health")
        |> put_req_header("x-test-header", header_value)
        |> Endpoint.call(@opts)

      assert conn.status == 200, "Expected 200, got #{conn.status}"
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "ok"
    end
  end

  # ---------------------------------------------------------------------------
  # P3: Jason.encode! on response maps always produces a non-empty binary
  # ---------------------------------------------------------------------------

  property "P3: Jason.encode! on any safe response payload produces a non-empty binary" do
    check all(
      status <- member_of(["ok", "error", "pending", "active"]),
      code   <- integer(200..599),
      msg    <- string(:alphanumeric, min_length: 0, max_length: 100)
    ) do
      payload = %{"status" => status, "code" => code, "message" => msg}
      result = Jason.encode!(payload)
      assert is_binary(result)
      assert byte_size(result) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # P4: Routing with arbitrary (safe) level IDs does not crash
  # ---------------------------------------------------------------------------

  property "P4: GET /sync/:level_id never crashes for alphanumeric level IDs" do
    check all(
      level_id <- string(:alphanumeric, min_length: 1, max_length: 40),
      max_runs: 30
    ) do
      conn =
        conn(:get, "/sync/#{level_id}")
        |> Endpoint.call(@opts)

      # 200 if level found, 404 if not, 500 for unexpected errors.
      # We only assert that a response was returned (no crash).
      assert conn.status in [200, 404, 500],
             "Unexpected status #{conn.status} for level_id=#{level_id}"
      assert is_binary(conn.resp_body)
    end
  end

  # ---------------------------------------------------------------------------
  # P5: Jason.encode! is deterministic (same input → same output)
  # ---------------------------------------------------------------------------

  property "P5: Jason.encode! is deterministic for the same input" do
    check all(
      pairs <-
        map_of(
          string(:alphanumeric, min_length: 1, max_length: 10),
          integer(),
          min_length: 0,
          max_length: 5
        )
    ) do
      first  = Jason.encode!(pairs)
      second = Jason.encode!(pairs)
      assert first == second,
             "Jason.encode! is not deterministic for #{inspect(pairs)}"
    end
  end
end
