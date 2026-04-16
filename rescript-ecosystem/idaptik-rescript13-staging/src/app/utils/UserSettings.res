// SPDX-License-Identifier: PMPL-1.0-or-later
// User settings for ReScript

let keyVolumeMaster = "volume-master"
let keyVolumeBgm = "volume-bgm"
let keyVolumeSfx = "volume-sfx"
let keySystemTray = "system-tray-enabled"

// Get overall sound volume
let getMasterVolume = (): float => {
  Storage.getNumber(keyVolumeMaster)->Option.getOr(0.5)
}

// Get background music volume
let getBgmVolume = (): float => {
  Storage.getNumber(keyVolumeBgm)->Option.getOr(1.0)
}

// Get sound effects volume
let getSfxVolume = (): float => {
  Storage.getNumber(keyVolumeSfx)->Option.getOr(1.0)
}

// Check if system tray is enabled
let isSystemTrayEnabled = (): bool => {
  Storage.getBool(keySystemTray)->Option.getOr(false)
}

// Initialize user settings
let init = (): unit => {
  switch GetEngine.get() {
  | Some(engine) =>
    Audio.setMasterVolume(getMasterVolume())
    Audio.BGM.setVolume(engine.audio.bgm, getBgmVolume())
    Audio.SFX.setVolume(engine.audio.sfx, getSfxVolume())

    // Initialize system tray if enabled and in Tauri
    if DesktopIntegration.hasTauri() && isSystemTrayEnabled() {
      let _ = DesktopIntegration.toggleSystemTray(true)
    }
  | None => ()
  }
}

// Set overall sound volume
let setMasterVolume = (value: float): unit => {
  switch GetEngine.get() {
  | Some(_) =>
    Audio.setMasterVolume(value)
    Storage.setNumber(keyVolumeMaster, value)
  | None => ()
  }
}

// Set background music volume
let setBgmVolume = (value: float): unit => {
  switch GetEngine.get() {
  | Some(engine) =>
    Audio.BGM.setVolume(engine.audio.bgm, value)
    Storage.setNumber(keyVolumeBgm, value)
  | None => ()
  }
}

// Set sound effects volume
let setSfxVolume = (value: float): unit => {
  switch GetEngine.get() {
  | Some(engine) =>
    Audio.SFX.setVolume(engine.audio.sfx, value)
    Storage.setNumber(keyVolumeSfx, value)
  | None => ()
  }
}

// Set system tray status
let setSystemTrayEnabled = (enabled: bool): unit => {
  Storage.setBool(keySystemTray, enabled)
  if DesktopIntegration.hasTauri() {
    let _ = DesktopIntegration.toggleSystemTray(enabled)
  }
}
