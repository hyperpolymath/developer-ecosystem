-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-firewall protocol.
-- Firewall management types: rules, zones, actions, protocol
-- selectors, and IP set descriptors.

module Types

import Data.List

||| Firewall backend.
public export
data FwBackend : Type where
  Nftables : FwBackend
  Iptables : FwBackend
  PF       : FwBackend

||| Packet action.
public export
data RuleAction : Type where
  Accept    : RuleAction
  Drop      : RuleAction
  Reject    : RuleAction
  Log       : RuleAction
  RateLimit : RuleAction

||| Network protocol selector.
public export
data Protocol : Type where
  TCP  : Protocol
  UDP  : Protocol
  ICMP : Protocol
  Any  : Protocol

||| Firewall rule.
public export
record FwRule where
  constructor MkFwRule
  ruleId   : Nat
  chain    : String
  action   : RuleAction
  protocol : Protocol
  dstPort  : Bits16

||| Firewall zone.
public export
record Zone where
  constructor MkZone
  name          : String
  interfaces    : List String
  defaultAction : RuleAction
