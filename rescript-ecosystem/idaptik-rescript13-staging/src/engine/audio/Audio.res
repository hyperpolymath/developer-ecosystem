// SPDX-License-Identifier: PMPL-1.0-or-later
// Audio management for ReScript

// BGM - Background Music management
module BGM = {
  type t = {
    mutable currentAlias: option<string>,
    mutable current: option<PixiSound.Sound.t>,
    mutable volume: float,
  }

  let make = (): t => {
    currentAlias: None,
    current: None,
    volume: 1.0,
  }

  let play = async (bgm: t, alias: string, ~volume=1.0, ()): unit => {
    // Do nothing if the requested music is already being played
    if bgm.currentAlias == Some(alias) {
      ()
    } else {
      // Fade out and stop current music
      switch bgm.current {
      | Some(current) =>
        let _ = Motion.animate(current, {"volume": 0.0}, {duration: 1.0, ease: "linear"})
        let _ = await Promise.make((resolve, _) => {
          let _ = setTimeout(() => {
            PixiSound.Sound.stop(current)
            resolve()
          }, 1000)
        })
      | None => ()
      }

      // Find and play the new music
      let newSound = PixiSound.find(alias)
      bgm.current = Some(newSound)
      bgm.currentAlias = Some(alias)

      PixiSound.Sound.play(newSound, {"loop": true, "volume": volume})
      PixiSound.Sound.setVolume(newSound, 0.0)
      let _ = Motion.animate(newSound, {"volume": bgm.volume}, {duration: 1.0, ease: "linear"})
    }
  }

  let getVolume = (bgm: t): float => bgm.volume

  let setVolume = (bgm: t, v: float): unit => {
    bgm.volume = v
    switch bgm.current {
    | Some(sound) => PixiSound.Sound.setVolume(sound, v)
    | None => ()
    }
  }
}

// SFX - Sound effects management
module SFX = {
  type t = {
    mutable volume: float,
  }

  let make = (): t => {
    volume: 1.0,
  }

  let play = (sfx: t, alias: string, ~volume=1.0, ()): unit => {
    let finalVolume = sfx.volume *. volume
    PixiSound.play(alias, {"volume": finalVolume})
  }

  let getVolume = (sfx: t): float => sfx.volume

  let setVolume = (sfx: t, v: float): unit => {
    sfx.volume = v
  }
}

// Audio manager
type audioManager = {
  bgm: BGM.t,
  sfx: SFX.t,
}

let makeAudioManager = (): audioManager => {
  bgm: BGM.make(),
  sfx: SFX.make(),
}

let getMasterVolume = (): float => PixiSound.volumeAll

// Helper to set volumeAll on the sound object
let setVolumeAllRaw: (PixiSound.soundType, float) => unit = %raw(`
  function(sound, volume) {
    sound.volumeAll = volume;
  }
`)

let setMasterVolume = (volume: float): unit => {
  setVolumeAllRaw(PixiSound.sound, volume)
  if volume == 0.0 {
    PixiSound.muteAll()
  } else {
    PixiSound.unmuteAll()
  }
}
