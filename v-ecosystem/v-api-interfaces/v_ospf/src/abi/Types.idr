-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-ospf protocol.
-- OSPF types: area types, neighbor states.

module Types

import Data.List

||| OSPF area type.
public export
data OspfAreaType : Type where
  Normal        : OspfAreaType
  Stub          : OspfAreaType
  TotallyStubby : OspfAreaType
  NSSA          : OspfAreaType

||| OSPF neighbor state machine.
public export
data NeighborState : Type where
  Down     : NeighborState
  Init     : NeighborState
  TwoWay   : NeighborState
  ExStart  : NeighborState
  Exchange : NeighborState
  Loading  : NeighborState
  Full     : NeighborState

||| OSPF area.
public export
record OspfArea where
  constructor MkOspfArea
  areaId     : String
  areaType   : OspfAreaType
  interfaces : List String
