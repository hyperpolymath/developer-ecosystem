-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-httpd protocol.
-- HTTP server types: virtual hosts, TLS versions, methods.

module Types

||| TLS protocol version.
public export
data TlsVersion : Type where
  TLS12 : TlsVersion
  TLS13 : TlsVersion

||| HTTP method.
public export
data HttpMethod : Type where
  GET     : HttpMethod
  POST    : HttpMethod
  PUT     : HttpMethod
  DELETE  : HttpMethod
  PATCH   : HttpMethod
  HEAD    : HttpMethod
  OPTIONS : HttpMethod

||| Virtual host.
public export
record VirtualHost where
  constructor MkVirtualHost
  hostname     : String
  documentRoot : String
  minTls       : TlsVersion
