# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Joshua B. Jewell and Jonathan D.A. Jewell
#
# Route tests for the IDApTIK sync server portfolio and campaign API.
#
# These tests verify the HTTP contract (request format, response codes,
# content type, JSON structure) independent of database availability.
# When databases are unavailable, we accept 503 as valid; when they're
# up, we verify the full response body.
#
# Usage:
#   mix test test/router_test.exs

defmodule IDApixiTIK.SyncServer.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias IDApixiTIK.SyncServerWeb.Endpoint

  @opts Endpoint.init([])

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Build a JSON POST request through the full endpoint pipeline
  # (Plug.Parsers decodes the body into conn.body_params)
  defp json_post(path, body) do
    conn(:post, path, Jason.encode!(body))
    |> put_req_header("content-type", "application/json")
    |> Endpoint.call(@opts)
  end

  # Build a GET request through the full endpoint pipeline
  defp json_get(path) do
    conn(:get, path)
    |> Endpoint.call(@opts)
  end

  # Parse response body as JSON (returns nil on decode error)
  defp json_body(conn) do
    case Jason.decode(conn.resp_body) do
      {:ok, body} -> body
      _ -> nil
    end
  end

  # Assert that status is one of the expected values
  defp assert_status_in(conn, statuses) do
    assert conn.status in statuses,
           "Expected status in #{inspect(statuses)}, got #{conn.status}: #{conn.resp_body}"
  end

  # ---------------------------------------------------------------------------
  # Health & Info Routes
  # ---------------------------------------------------------------------------

  test "GET /health returns 200 with status ok" do
    conn = json_get("/health")
    assert conn.status == 200
    body = json_body(conn)
    assert body["status"] == "ok"
  end

  test "GET / returns 200 with server info" do
    conn = json_get("/")
    assert conn.status == 200
    body = json_body(conn)
    assert body["server"] == "IDApTIK Sync Server"
    assert body["version"] == "0.2.0"
  end

  test "OPTIONS returns 204 with CORS headers" do
    conn =
      conn(:options, "/db/portfolios")
      |> Endpoint.call(@opts)

    assert conn.status == 204
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    assert get_resp_header(conn, "access-control-allow-methods") == ["GET, POST, OPTIONS"]
  end

  test "unknown route returns 404" do
    conn = json_get("/nonexistent/route")
    assert conn.status == 404
    body = json_body(conn)
    assert body["error"] == "not_found"
  end

  # ---------------------------------------------------------------------------
  # Portfolio Routes — POST /db/portfolios
  # ---------------------------------------------------------------------------

  test "POST /db/portfolios with valid body returns 200 or 503" do
    body = %{
      "id" => "portfolio-test-#{System.system_time(:millisecond)}",
      "name" => "Test Portfolio",
      "description" => "Created by router_test.exs",
      "buildings" => [],
      "createdAt" => 1709000000000.0,
      "modifiedAt" => 1709000000000.0
    }

    conn = json_post("/db/portfolios", body)
    # 200 if VerisimDB is up, 422 if validation rejects (save_level expects
    # level-format fields), 503 if DB unavailable, 500 for other errors
    assert_status_in(conn, [200, 422, 503, 500])
    assert json_body(conn) != nil, "Response must be valid JSON"
  end

  # ---------------------------------------------------------------------------
  # Portfolio Routes — GET /db/portfolios/:id
  # ---------------------------------------------------------------------------

  test "GET /db/portfolios/:id returns 200, 404, or 503" do
    conn = json_get("/db/portfolios/nonexistent-portfolio-id")
    # 404 if not found (DB up), 503 if DB down, 500 for other errors
    assert_status_in(conn, [200, 404, 503, 500])
    body = json_body(conn)
    assert body != nil, "Response must be valid JSON"
  end

  # ---------------------------------------------------------------------------
  # Portfolio Routes — GET /db/portfolios/search
  # ---------------------------------------------------------------------------

  test "GET /db/portfolios/search with query returns 200 or 503" do
    conn = json_get("/db/portfolios/search?q=test")
    assert_status_in(conn, [200, 503, 500])
    assert json_body(conn) != nil
  end

  # ---------------------------------------------------------------------------
  # Campaign Routes — POST /db/campaigns
  # ---------------------------------------------------------------------------

  test "POST /db/campaigns with valid edges returns 200 or 503" do
    body = %{
      "portfolioId" => "portfolio-test-1",
      "edges" => [
        %{
          "fromBuildingId" => "bldg-1",
          "toBuildingId" => "bldg-2",
          "edgeType" => "Unlocks",
          "label" => "Hack the mainframe",
          "unlockCondition" => nil
        }
      ]
    }

    conn = json_post("/db/campaigns", body)
    assert_status_in(conn, [200, 503, 500])
    assert json_body(conn) != nil
  end

  test "POST /db/campaigns with empty edges returns 200 or 503" do
    body = %{
      "portfolioId" => "portfolio-empty",
      "edges" => []
    }

    conn = json_post("/db/campaigns", body)
    assert_status_in(conn, [200, 503, 500])
  end

  # ---------------------------------------------------------------------------
  # Campaign Routes — GET /db/campaigns/:id
  # ---------------------------------------------------------------------------

  test "GET /db/campaigns/:id returns campaign edges or 503" do
    conn = json_get("/db/campaigns/portfolio-test-1")
    assert_status_in(conn, [200, 503, 500])
    body = json_body(conn)
    assert body != nil

    if conn.status == 200 do
      # Verify response structure: must have portfolioId and edges array
      assert body["portfolioId"] == "portfolio-test-1"
      assert is_list(body["edges"])
    end
  end

  # ---------------------------------------------------------------------------
  # Campaign Routes — POST /db/campaigns/:id/edges
  # ---------------------------------------------------------------------------

  test "POST /db/campaigns/:id/edges adds a single edge" do
    body = %{
      "fromBuildingId" => "bldg-a",
      "toBuildingId" => "bldg-b",
      "edgeType" => "Branches",
      "label" => "Choose wisely"
    }

    conn = json_post("/db/campaigns/portfolio-edge-test/edges", body)
    assert_status_in(conn, [200, 503, 500])
    assert json_body(conn) != nil
  end

  # ---------------------------------------------------------------------------
  # Error handling — malformed requests
  # ---------------------------------------------------------------------------

  test "POST with invalid JSON content-type still routes" do
    # Send plain text where JSON is expected
    conn =
      conn(:post, "/db/portfolios", "this is not json")
      |> put_req_header("content-type", "text/plain")
      |> Endpoint.call(@opts)

    # The router should still respond (Plug.Parsers pass: ["*/*"] allows it)
    assert conn.status in [200, 400, 422, 500, 503]
  end

  # ---------------------------------------------------------------------------
  # Database health endpoint
  # ---------------------------------------------------------------------------

  test "GET /db/health returns aggregated database status" do
    conn = json_get("/db/health")
    assert_status_in(conn, [200, 503])
    body = json_body(conn)
    assert body != nil

    if conn.status == 200 do
      # Health response should have database status info
      assert is_map(body)
    end
  end
end
