-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-vpn protocol.
-- VPN backend selection, peer lifecycle states, key pairs, tunnel
-- configuration, and status monitoring structures.

module Types

import Data.List

||| VPN backend protocol implementation.
public export
data VpnBackend : Type where
  WireGuard : VpnBackend  -- WireGuard kernel/userspace interface
  OpenVPN   : VpnBackend  -- OpenVPN management socket protocol

||| Connectivity status of a VPN peer.
public export
data PeerState : Type where
  Disconnected : PeerState  -- No handshake established
  Connecting   : PeerState  -- Handshake in progress
  Connected    : PeerState  -- Active tunnel with recent handshake
  Stale        : PeerState  -- Handshake older than threshold

||| Connection lifecycle state for the management interface.
public export
data ConnState : Type where
  MgmtDisconnected : ConnState
  MgmtConnected    : ConnState

||| A WireGuard cryptographic key pair (base64-encoded strings).
public export
record KeyPair where
  constructor MkKeyPair
  privateKey : String
  publicKey  : String

||| A VPN peer with cryptographic identity and traffic statistics.
public export
record Peer where
  constructor MkPeer
  publicKey           : String
  presharedKey        : String
  endpoint            : String
  allowedIps          : List String
  latestHandshake     : Nat        -- Unix timestamp
  transferRx          : Nat        -- Bytes received
  transferTx          : Nat        -- Bytes transmitted
  persistentKeepalive : Nat        -- Seconds (0 = disabled)
  state               : PeerState

||| Local tunnel interface configuration.
public export
record TunnelConfig where
  constructor MkTunnelConfig
  interfaceName : String
  privateKey    : String
  listenPort    : Nat
  address       : String  -- CIDR notation
  dnsServers    : List String
  mtu           : Nat

||| Runtime statistics for a tunnel interface.
public export
record TunnelStatus where
  constructor MkTunnelStatus
  interfaceName : String
  publicKey     : String
  listenPort    : Nat
  peerCount     : Nat
  totalRx       : Nat
  totalTx       : Nat
  upSince       : Nat  -- Unix timestamp
  isActive      : Bool

||| An OpenVPN connected client with traffic statistics.
public export
record OpenVpnClient where
  constructor MkOpenVpnClient
  commonName     : String
  realAddress    : String
  virtualAddress : String
  bytesReceived  : Nat
  bytesSent      : Nat
  connectedSince : String
