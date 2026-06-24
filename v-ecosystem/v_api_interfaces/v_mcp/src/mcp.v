// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_mcp/mcp.v — Module root for the V MCP (Model Context Protocol) library.
//
// This is the world's first V-lang MCP implementation. It maps directly
// to the proven-servers proven-mcp Idris2 ABI definitions and provides a
// complete MCP server framework with:
//
//   - Full protocol type system (types.v)
//   - JSON-RPC 2.0 message framing (jsonrpc.v)
//   - Stdio transport with Content-Length framing (transport.v)
//   - Tool registration and dispatch (tools.v)
//   - Resource registration and serving (resources.v)
//   - Prompt template registration (prompts.v)
//   - Server core with capability negotiation (server.v)
//
// Usage:
//
//   import v_mcp
//
//   mut server := v_mcp.new_server('my-server', '1.0.0')
//   server.add_tool(
//       v_mcp.ToolDefinition{ name: 'greet', description: 'Say hello' },
//       fn (params map[string]json.Any) !v_mcp.ToolResult {
//           return v_mcp.text_result('Hello!')
//       },
//   )
//   server.serve()!

module v_mcp
