-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Inventory.idr — Item and inventory system
module Inventory

import Primitives
import Types

%default total

||| Cable connector types.
public export
data CableType = Ethernet | FibreLC | FibreSC | Serial | USB | Universal

||| Adapter types for connecting incompatible ports.
public export
data AdapterType = EthernetToFibre | USBToSerial | MediaConverter

||| Specialised tool types.
public export
data ToolType = Crimper | Splicer | Multimeter | WireCutter | Debugger

||| Pluggable module types (SFP/GBIC etc).
public export
data ModuleType = SFP | GBIC | QSFP | Transceiver

||| Consumable items.
public export
data ConsumableType = BatteryPack | EMP | SmokeGrenade | Decryptor

||| All item categories in the game.
public export
data ItemKind
  = Cable CableType
  | Adapter AdapterType
  | Tool ToolType
  | Module ModuleType
  | Storage Nat          -- capacity in bytes
  | Consumable ConsumableType
  | Keycard String       -- zone name the keycard grants access to
  | Radio

||| An inventory item with metadata.
public export
record Item where
  constructor MkItem
  id            : String
  kind          : ItemKind
  name          : String
  weight        : Nat
  condition     : ItemCondition
  usesRemaining : Maybe Nat

||| An item placed in the game world inside a container device.
public export
record WorldItem where
  constructor MkWorldItem
  item      : Item
  worldX    : WorldX
  container : String
