// SPDX-License-Identifier: PMPL-1.0-or-later
// Inventory UI Helpers

open Inventory

// Format for HUD display
let formatQuickbar = (inv: Inventory.t): array<HUD.inventorySlot> => {
  inv.slots->Array.map(slot => {
    switch slot.item {
    | Some(item) => {
        let icon = switch item.kind {
        | Cable(_) => Some("cable")
        | Adapter(_) => Some("adapter")
        | Tool(_) => Some("tool")
        | Module(_) => Some("module")
        | Storage(_) => Some("usb")
        | Consumable(_) => Some("tape")
        | Keycard(_) => Some("keycard")
        | Radio => Some("radio")
        }
        let qty = switch item.usesRemaining {
        | Some(n) => n
        | None => 1
        }
        {HUD.itemName: Some(item.name), itemIcon: icon, quantity: qty}
      }
    | None => if slot.locked {
        {HUD.itemName: Some("[LOCKED]"), itemIcon: None, quantity: 0}
      } else {
        HUD.emptySlot
      }
    }
  })
}
