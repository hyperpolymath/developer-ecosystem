-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-sdn protocol.
-- SDN types: protocols, flow actions, switches.

module Types

||| SDN southbound protocol.
public export
data SdnProtocol : Type where
  OpenFlow13 : SdnProtocol
  OpenFlow15 : SdnProtocol
  P4         : SdnProtocol
  NETCONF    : SdnProtocol

||| Flow rule action.
public export
data FlowAction : Type where
  Forward    : FlowAction
  DropFlow   : FlowAction
  Controller : FlowAction
  Group      : FlowAction

||| SDN switch.
public export
record SdnSwitch where
  constructor MkSdnSwitch
  dpid     : String
  name     : String
  protocol : SdnProtocol
  ports    : Nat
