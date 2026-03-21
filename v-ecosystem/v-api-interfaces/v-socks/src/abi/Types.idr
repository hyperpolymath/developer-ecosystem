-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-socks protocol.
-- SOCKS5 commands, authentication methods, address types,
-- and reply codes for proxied connections (RFC 1928).

module Types

import Data.List

||| SOCKS5 authentication method.
public export
data AuthMethod : Type where
  NoAuth       : AuthMethod  -- No authentication required
  UserPass     : AuthMethod  -- Username/password (RFC 1929)
  NoAcceptable : AuthMethod  -- Server rejects all methods

||| SOCKS5 command type.
public export
data Command : Type where
  Connect      : Command  -- TCP connect
  Bind         : Command  -- TCP bind (accept incoming)
  UdpAssociate : Command  -- UDP relay

||| SOCKS5 address type.
public export
data AddressType : Type where
  IPv4Addr   : AddressType
  DomainName : AddressType
  IPv6Addr   : AddressType

||| SOCKS5 reply status.
public export
data ReplyStatus : Type where
  Succeeded          : ReplyStatus
  GeneralFailure     : ReplyStatus
  NotAllowed         : ReplyStatus
  NetworkUnreachable : ReplyStatus
  HostUnreachable    : ReplyStatus
  ConnectionRefused  : ReplyStatus

||| Bound address from proxy.
public export
record BoundAddress where
  constructor MkBoundAddress
  addrType : AddressType
  addr     : String
  port     : Bits16
