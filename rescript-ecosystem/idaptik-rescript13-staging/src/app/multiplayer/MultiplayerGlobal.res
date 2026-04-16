// SPDX-License-Identifier: PMPL-1.0-or-later
// MultiplayerGlobal.res  Singleton multiplayer client instance
//
// Single global MultiplayerClient for the game session. Terminal commands,
// the game loop, and device interactions all reference this instance.

// Global client instance (one per browser session)
let client = MultiplayerClient.make(
  ~playerId=`player_${Int.toString(Math.Int.random(10000, 99999))}`,
  ~role=MultiplayerClient.Hacker,
)

// Whether multiplayer is enabled (can be toggled in settings)
let enabled = ref(false)

// Initialise with callbacks that integrate with the game
let init = (
  ~onPlayerJoined: option<MultiplayerClient.coopPlayer => unit>=?,
  ~onPlayerLeft: option<string => unit>=?,
  ~onPlayerMoved: option<(string, float, float) => unit>=?,
  ~onVMExecute: option<(string, string, string, array<string>) => unit>=?,
  ~onVMUndo: option<(string, string) => unit>=?,
  ~onChat: option<MultiplayerClient.chatMessage => unit>=?,
  ~onCovertLinkDiscovered: option<(string, string) => unit>=?,
  ~onCovertLinkActivated: option<(string, string) => unit>=?,
  ~onCovertLinkCoopRequest: option<(string, string) => unit>=?,
  (),
): unit => {
  switch onPlayerJoined {
  | Some(cb) => client.handlers.onPlayerJoined = Some(cb)
  | None => ()
  }
  switch onPlayerLeft {
  | Some(cb) => client.handlers.onPlayerLeft = Some(cb)
  | None => ()
  }
  switch onPlayerMoved {
  | Some(cb) => client.handlers.onPlayerMoved = Some(cb)
  | None => ()
  }
  switch onVMExecute {
  | Some(cb) => client.handlers.onVMExecute = Some(cb)
  | None => ()
  }
  switch onVMUndo {
  | Some(cb) => client.handlers.onVMUndo = Some(cb)
  | None => ()
  }
  switch onChat {
  | Some(cb) => client.handlers.onChat = Some(cb)
  | None => ()
  }
  switch onCovertLinkDiscovered {
  | Some(cb) => client.handlers.onCovertLinkDiscovered = Some(cb)
  | None => ()
  }
  switch onCovertLinkActivated {
  | Some(cb) => client.handlers.onCovertLinkActivated = Some(cb)
  | None => ()
  }
  switch onCovertLinkCoopRequest {
  | Some(cb) => client.handlers.onCovertLinkCoopRequest = Some(cb)
  | None => ()
  }
  enabled := true
}
