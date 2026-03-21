-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-dhcp protocol.
-- DHCPv4 (RFC 2131) message types, option codes, lease states,
-- and DORA handshake structures.

module Types

import Data.List

||| DHCP message type (option 53 values).
public export
data MsgType : Type where
  Discover : MsgType  -- Client broadcast seeking servers
  Offer    : MsgType  -- Server response with IP offer
  Request  : MsgType  -- Client selecting offered IP
  Decline  : MsgType  -- Client rejecting offered IP (conflict)
  Ack      : MsgType  -- Server confirming lease
  Nak      : MsgType  -- Server rejecting request
  Release  : MsgType  -- Client relinquishing lease
  Inform   : MsgType  -- Client requesting config without lease

||| DHCP lease lifecycle state.
public export
data LeaseState : Type where
  Init       : LeaseState
  Selecting  : LeaseState
  Requesting : LeaseState
  Bound      : LeaseState
  Renewing   : LeaseState
  Rebinding  : LeaseState
  Released   : LeaseState

||| A DHCP option (code + opaque data).
public export
record DhcpOption where
  constructor MkDhcpOption
  code : Bits8
  dat  : List Bits8

||| An acquired DHCP lease with network parameters.
public export
record Lease where
  constructor MkLease
  clientIp      : String
  subnetMask    : String
  gateway       : String
  dnsServers    : List String
  domainName    : String
  leaseTime     : Nat       -- Seconds
  renewalTime   : Nat       -- T1 in seconds
  rebindingTime : Nat       -- T2 in seconds
  serverId      : String
  state         : LeaseState
