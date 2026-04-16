// SPDX-License-Identifier: PMPL-1.0-or-later
// DesktopIntegration  Handles native OS shortcuts and tray integration

//  Tauri Bindings 

// Check if we are running inside a Tauri container
let hasTauri: unit => bool = %raw(`
  function() {
    return !!(window && window.__TAURI__);
  }
`)

// Generic Tauri invoke helper
let invoke: (string, 'a) => promise<'b> = %raw(`
  function(command, args) {
    if (window && window.__TAURI__) {
      return window.__TAURI__.core.invoke(command, args);
    }
    return Promise.reject("Tauri not available");
  }
`)

//  Shortcut Management 

// Create a shortcut on the user's desktop (Linux only for now)
let createDesktopShortcut = (): promise<string> => {
  invoke("create_desktop_shortcut", %raw("{}"))
}

// Create a shortcut in the applications menu (Linux only)
let createMenuShortcut = (): promise<string> => {
  invoke("create_menu_shortcut", %raw("{}"))
}

// Toggle the system tray icon (Tauri only)
let toggleSystemTray = (enable: bool): promise<unit> => {
  invoke("toggle_system_tray", {"enable": enable})
}

//  First Run Logic 

let keyShortcutsCreated = "desktop-shortcuts-created"

// Check if we've already prompted for shortcuts
let hasCreatedShortcuts = (): bool => {
  Storage.getString(keyShortcutsCreated)->Option.isSome
}

// Mark shortcuts as created (to stop prompting)
let markShortcutsAsCreated = (): unit => {
  Storage.setString(keyShortcutsCreated, "true")
}
