// SPDX-License-Identifier: PMPL-1.0-or-later
// @pixi/sound Bindings for ReScript

module Sound = {
  type t
  @get external volume: t => float = "volume"
  @set external setVolume: (t, float) => unit = "volume"
  @send external play: (t, {..}) => unit = "play"
  @send external stop: t => unit = "stop"
}

type playOptions = {
  loop?: bool,
  volume?: float,
}

// Main sound singleton
@module("@pixi/sound") @scope("sound") external volumeAll: float = "volumeAll"
@module("@pixi/sound") @scope("sound") external muteAll: unit => unit = "muteAll"
@module("@pixi/sound") @scope("sound") external unmuteAll: unit => unit = "unmuteAll"
@module("@pixi/sound") @scope("sound") external pauseAll: unit => unit = "pauseAll"
@module("@pixi/sound") @scope("sound") external resumeAll: unit => unit = "resumeAll"
@module("@pixi/sound") @scope("sound") external find: string => Sound.t = "find"
@module("@pixi/sound") @scope("sound") external play: (string, {..}) => unit = "play"

// The sound singleton type
type soundType

// Side-effect import to register plugin (just import the sound object to trigger registration)
@module("@pixi/sound") external sound: soundType = "sound"
