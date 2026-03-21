-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-proxy protocol.
-- Proxy types: modes, upstreams, header rules.

module Types

||| Proxy direction mode.
public export
data ProxyMode : Type where
  Forward     : ProxyMode
  Reverse     : ProxyMode
  Transparent : ProxyMode

||| Proxy upstream.
public export
record ProxyUpstream where
  constructor MkProxyUpstream
  name    : String
  address : String
  port    : Bits16
  weight  : Nat
  tls     : Bool
