// SPDX-License-Identifier: PMPL-1.0-or-later
// Inventory  physical toolkit system (ADR-0009)
//
// Jessica carries a small, finite set of physical items in her kit.
// The inventory is strict: limited slots, weight capacity, and items
// must be found in-world. Three difficulty tiers control specificity.

//  Difficulty Tier 

type difficultyTier =
  | Accessible // Tier 1: universal cables, pre-stocked, forgiving
  | Realistic // Tier 2: typed cables, limited supplies, breakable tools
  | Hardcore // Tier 3: empty kit, everything scavenged, wear/damage

//  Item Types 

type cableType =
  | Ethernet // RJ45, Cat5e/Cat6
  | FibreLC // LC connector fibre
  | FibreSC // SC connector fibre
  | Serial // DB-9 / console cable
  | USB // USB-A, USB-C
  | Universal // Tier 1 only  works in any port

type adapterType =
  | USBToSerial // USB-A to DB-9
  | MediaConverter // Copper to fibre
  | GenderChanger // Male-to-male or female-to-female
  | RJ45toRJ11 // Phone to Ethernet

type toolType =
  | Crimper // Make Ethernet cables
  | FibreCleaver // Prepare fibre ends
  | FibreSplicer // Join fibre strands
  | OTDR // Optical time-domain reflectometer (diagnosis)
  | WireCutters // Basic tool
  | Multimeter // Test connections

type moduleType =
  | SFP1G // 1 Gbps SFP
  | SFP10G // 10 Gbps SFP+
  | GBIC // Older gigabit module
  | RJ45Transceiver // Copper SFP

type storageType =
  | USBDrive(int) // Capacity in MB
  | SDCard(int) // Capacity in MB

type consumableType =
  | CableTie
  | ElectricalTape
  | SpliceProtector
  | HeatShrink

//  Item 

type itemKind =
  | Cable(cableType)
  | Adapter(adapterType)
  | Tool(toolType)
  | Module(moduleType)
  | Storage(storageType)
  | Consumable(consumableType)
  | Keycard(string) // Access level description
  | Radio // Stolen guard radio

type itemCondition =
  | Pristine // New, full functionality
  | Good // Minor wear, works fine
  | Worn // Reduced performance
  | Damaged // Degraded, may fail
  | Broken // Non-functional (Tier 3 only)

type item = {
  id: string,
  kind: itemKind,
  name: string,
  weight: float, // In kg
  mutable condition: itemCondition,
  mutable usesRemaining: option<int>, // Tools: limited uses (Tier 2+)
  cableLength: option<float>, // Cables: length in metres
  description: string,
}

//  Inventory State 

type slot = {
  mutable item: option<item>,
  locked: bool, // Locked slots need to be unlocked via progression
}

type t = {
  slots: array<slot>,
  maxWeight: float,
  tier: difficultyTier,
  mutable totalWeight: float,
}

//  Construction 

let make = (~tier: difficultyTier): t => {
  let slots = switch tier {
  | Accessible => [
      {item: None, locked: false},
      {item: None, locked: false},
      {item: None, locked: false},
      {item: None, locked: false},
      {item: None, locked: false}, // Unlocked on Accessible
      {item: None, locked: false},
    ]
  | Realistic => [
      {item: None, locked: false},
      {item: None, locked: false},
      {item: None, locked: false},
      {item: None, locked: false},
      {item: None, locked: true},
      {item: None, locked: true},
    ]
  | Hardcore => [
      {item: None, locked: false},
      {item: None, locked: false},
      {item: None, locked: false},
      {item: None, locked: false},
      {item: None, locked: true},
      {item: None, locked: true},
    ]
  }

  {
    slots,
    maxWeight: 3.0,
    tier,
    totalWeight: 0.0,
  }
}

//  Weight Calculation 

let recalculateWeight = (inv: t): unit => {
  inv.totalWeight =
    inv.slots->Array.reduce(0.0, (acc, slot) => {
      switch slot.item {
      | Some(item) => acc +. item.weight
      | None => acc
      }
    })
}

let remainingCapacity = (inv: t): float => {
  inv.maxWeight -. inv.totalWeight
}

//  Slot Operations 

// Find the first empty, unlocked slot
let findEmptySlot = (inv: t): option<int> => {
  let result = ref(None)
  inv.slots->Array.forEachWithIndex((slot, i) => {
    if Option.isNone(result.contents) && Option.isNone(slot.item) && !(slot.locked) {
      result := Some(i)
    }
  })
  result.contents
}

// Add an item to inventory (returns false if no room or too heavy)
let addItem = (inv: t, ~item: item): bool => {
  if inv.totalWeight +. item.weight > inv.maxWeight {
    false // Too heavy
  } else {
    switch findEmptySlot(inv) {
    | Some(index) => switch inv.slots[index] {
      | Some(slot) => {
          slot.item = Some(item)
          recalculateWeight(inv)
          true
        }
      | None => false
      }
    | None => false // No empty slot
    }
  }
}

// Remove item from a specific slot
let removeFromSlot = (inv: t, ~index: int): option<item> => {
  switch inv.slots[index] {
  | Some(slot) => {
      let removed = slot.item
      slot.item = None
      recalculateWeight(inv)
      removed
    }
  | None => None
  }
}

// Get item in a specific slot
let getSlot = (inv: t, ~index: int): option<item> => {
  switch inv.slots[index] {
  | Some(slot) => slot.item
  | None => None
  }
}

// Check if inventory has a specific item kind
let hasItemKind = (inv: t, ~kind: itemKind): bool => {
  inv.slots->Array.some(slot => {
    switch slot.item {
    | Some(item) => item.kind == kind
    | None => false
    }
  })
}

// Find first item matching a kind
let findByKind = (inv: t, ~kind: itemKind): option<(int, item)> => {
  let result = ref(None)
  inv.slots->Array.forEachWithIndex((slot, i) => {
    if Option.isNone(result.contents) {
      switch slot.item {
      | Some(item) if item.kind == kind => result := Some((i, item))
      | _ => ()
      }
    }
  })
  result.contents
}

// Unlock a locked slot (progression reward)
let unlockSlot = (inv: t, ~index: int): bool => {
  switch inv.slots[index] {
  | Some(slot) if slot.locked => {
      // Mutate by replacing the slot (locked is not mutable)
      inv.slots->Array.set(index, {item: None, locked: false})
      true
    }
  | _ => false
  }
}

//  Tool Usage 

// Use a tool (decrements uses, may break on Tier 2+)
let useTool = (inv: t, ~index: int): bool => {
  switch getSlot(inv, ~index) {
  | Some(item) => switch item.usesRemaining {
    | Some(uses) if uses > 0 => {
        item.usesRemaining = Some(uses - 1)

        // Degrade condition based on tier
        if uses <= 1 {
          item.condition = Broken
        } else if uses <= 3 && inv.tier != Accessible {
          item.condition = Damaged
        } else if uses <= 6 && inv.tier == Hardcore {
          item.condition = Worn
        }
        true
      }
    | Some(_) => false // No uses left
    | None => true // Infinite use item (cables, etc.)
    }
  | None => false
  }
}

//  Cable Compatibility 

type portType =
  | EthernetPort
  | FibreLCPort
  | FibreSCPort
  | SerialPort
  | USBPort
  | ConsolePort

type compatibility =
  | Compatible // Perfect fit
  | Degraded(string) // Works but with penalty (Tier 1 only)
  | Incompatible // Won't connect

let checkCableCompatibility = (inv: t, ~cable: cableType, ~port: portType): compatibility => {
  switch inv.tier {
  | Accessible => // Tier 1: Universal cables work everywhere
    if cable == Universal {
      Compatible
    } else {
      switch (cable, port) {
      | (Ethernet, EthernetPort)
      | (FibreLC, FibreLCPort)
      | (FibreSC, FibreSCPort)
      | (Serial, SerialPort | ConsolePort)
      | (USB, USBPort) =>
        Compatible
      | _ => Degraded("Universal adapter applied") // Tier 1 forgiveness
      }
    }
  | Realistic | Hardcore => switch (cable, port) {
    | (Ethernet, EthernetPort) => Compatible
    | (FibreLC, FibreLCPort) => Compatible
    | (FibreSC, FibreSCPort) => Compatible
    | (Serial, SerialPort | ConsolePort) => Compatible
    | (USB, USBPort) => Compatible
    | (FibreLC, FibreSCPort) | (FibreSC, FibreLCPort) => Incompatible // Wrong fibre connector
    | (Universal, _) => Compatible // Shouldn't appear on Tier 2+
    | _ => Incompatible
    }
  }
}

//  Pre-Mission Loadout 

// Generate starting items based on difficulty tier
let getStartingLoadout = (tier: difficultyTier): array<item> => {
  switch tier {
  | Accessible => [
      {
        id: "start_cable",
        kind: Cable(Universal),
        name: "Universal Cable",
        weight: 0.1,
        condition: Pristine,
        usesRemaining: None,
        cableLength: Some(5.0),
        description: "Works in any port",
      },
      {
        id: "start_adapter",
        kind: Adapter(USBToSerial),
        name: "USB-Serial Adapter",
        weight: 0.05,
        condition: Pristine,
        usesRemaining: None,
        cableLength: None,
        description: "USB to serial console",
      },
      {
        id: "start_usb",
        kind: Storage(USBDrive(4096)),
        name: "4GB USB Drive",
        weight: 0.02,
        condition: Pristine,
        usesRemaining: None,
        cableLength: None,
        description: "Portable storage for exfiltration",
      },
    ]
  | Realistic => [
      {
        id: "start_eth",
        kind: Cable(Ethernet),
        name: "Cat6 Cable (2m)",
        weight: 0.15,
        condition: Good,
        usesRemaining: None,
        cableLength: Some(2.0),
        description: "Standard Ethernet patch cable",
      },
      {
        id: "start_serial",
        kind: Cable(Serial),
        name: "Console Cable",
        weight: 0.1,
        condition: Good,
        usesRemaining: None,
        cableLength: Some(1.5),
        description: "DB-9 serial console cable",
      },
    ]
  | Hardcore => [] // Empty kit  everything must be found
  }
}

// Apply starting loadout to inventory
let applyLoadout = (inv: t): unit => {
  let items = getStartingLoadout(inv.tier)
  items->Array.forEach(item => {
    let _ = addItem(inv, ~item)
  })
}

//  Queries 

let getSlotCount = (inv: t): int => Array.length(inv.slots)

let getFilledCount = (inv: t): int => {
  inv.slots->Array.filter(s => Option.isSome(s.item))->Array.length
}

let getUnlockedCount = (inv: t): int => {
  inv.slots->Array.filter(s => !s.locked)->Array.length
}


// Item name helper
let itemKindToString = (kind: itemKind): string => {
  switch kind {
  | Cable(Ethernet) => "Ethernet Cable"
  | Cable(FibreLC) => "LC Fibre Cable"
  | Cable(FibreSC) => "SC Fibre Cable"
  | Cable(Serial) => "Serial Cable"
  | Cable(USB) => "USB Cable"
  | Cable(Universal) => "Universal Cable"
  | Adapter(USBToSerial) => "USB-Serial Adapter"
  | Adapter(MediaConverter) => "Media Converter"
  | Adapter(GenderChanger) => "Gender Changer"
  | Adapter(RJ45toRJ11) => "RJ45-RJ11 Adapter"
  | Tool(Crimper) => "Crimper"
  | Tool(FibreCleaver) => "Fibre Cleaver"
  | Tool(FibreSplicer) => "Fibre Splicer"
  | Tool(OTDR) => "OTDR"
  | Tool(WireCutters) => "Wire Cutters"
  | Tool(Multimeter) => "Multimeter"
  | Module(SFP1G) => "SFP (1G)"
  | Module(SFP10G) => "SFP+ (10G)"
  | Module(GBIC) => "GBIC"
  | Module(RJ45Transceiver) => "RJ45 SFP"
  | Storage(USBDrive(mb)) => `USB Drive (${Int.toString(mb)}MB)`
  | Storage(SDCard(mb)) => `SD Card (${Int.toString(mb)}MB)`
  | Consumable(CableTie) => "Cable Tie"
  | Consumable(ElectricalTape) => "Electrical Tape"
  | Consumable(SpliceProtector) => "Splice Protector"
  | Consumable(HeatShrink) => "Heat Shrink"
  | Keycard(level) => `Keycard (${level})`
  | Radio => "Guard Radio"
  }
}

let conditionToString = (c: itemCondition): string => {
  switch c {
  | Pristine => "Pristine"
  | Good => "Good"
  | Worn => "Worn"
  | Damaged => "Damaged"
  | Broken => "BROKEN"
  }
}

// Format item detail for terminal `inspect` command
let formatItemDetail = (item: item): string => {
  let cond = conditionToString(item.condition)
  let weight = Float.toFixed(item.weight, ~digits=2)
  let length = switch item.cableLength {
  | Some(l) => ` (${Float.toFixed(l, ~digits=1)}m)`
  | None => ""
  }
  let uses = switch item.usesRemaining {
  | Some(n) => ` [${Int.toString(n)} uses]`
  | None => ""
  }
  `${item.name}${length}\nCondition: ${cond}${uses}\nWeight: ${weight} kg\n${item.description}`
}
