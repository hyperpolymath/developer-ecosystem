-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-dds protocol.
-- DDS QoS policies, topic types, sample metadata, and
-- participant structures for real-time pub-sub messaging.

module Types

import Data.List

||| DDS reliability QoS kind.
public export
data ReliabilityKind : Type where
  BestEffort : ReliabilityKind
  Reliable   : ReliabilityKind

||| DDS durability QoS kind.
public export
data DurabilityKind : Type where
  Volatile       : DurabilityKind
  TransientLocal : DurabilityKind
  Transient      : DurabilityKind
  Persistent     : DurabilityKind

||| DDS history QoS kind.
public export
data HistoryKind : Type where
  KeepLast : HistoryKind
  KeepAll  : HistoryKind

||| DDS QoS policy bundle.
public export
record QosPolicy where
  constructor MkQosPolicy
  reliability : ReliabilityKind
  durability  : DurabilityKind
  history     : HistoryKind
  depth       : Nat

||| DDS topic definition.
public export
record Topic where
  constructor MkTopic
  name     : String
  typeName : String
  qos      : QosPolicy
