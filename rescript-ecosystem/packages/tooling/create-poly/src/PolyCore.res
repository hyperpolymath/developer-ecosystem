// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2025 Hyperpolymath

/**
 * PolyCore - Shared foundation library for the Hyperpolymath ReScript ecosystem.
 *
 * Provides common utilities, patterns, and infrastructure for building
 * ReScript applications and MCP servers.
 */

// Re-export core modules
module Result = Core.Result
module Async = Core.Async
module Logger = Core.Logger
module Config = Core.Config

// Re-export MCP modules
module MCP = {
  module Protocol = MCP.Protocol
  module Server = MCP.Server
}
