-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-gameserver protocol.
-- Game server types: session state, lobby descriptors, player
-- slots, matchmaking queues, and tick synchronisation.

module Types

import Data.List

||| Game session lifecycle state.
public export
data SessionState : Type where
  Lobby      : SessionState
  Starting   : SessionState
  InProgress : SessionState
  Paused     : SessionState
  Ended      : SessionState

||| Player connection status.
public export
data PlayerStatus : Type where
  Connected    : PlayerStatus
  Ready        : PlayerStatus
  Playing      : PlayerStatus
  Spectating   : PlayerStatus
  Disconnected : PlayerStatus

||| Player descriptor.
public export
record Player where
  constructor MkPlayer
  playerId : String
  name     : String
  status   : PlayerStatus
  score    : Int

||| Game session descriptor.
public export
record GameSession where
  constructor MkGameSession
  sessionId  : String
  state      : SessionState
  maxPlayers : Nat
  tickRate   : Nat
  mapName    : String
