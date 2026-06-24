-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-irc protocol.
-- IRC message structure, channel modes, user modes, and
-- numeric reply codes for real-time chat (RFC 2812).

module Types

import Data.List

||| IRC channel mode flags.
public export
data ChannelMode : Type where
  OpMode      : ChannelMode  -- +o (operator)
  VoiceMode   : ChannelMode  -- +v (voice)
  InviteOnly  : ChannelMode  -- +i
  Moderated   : ChannelMode  -- +m
  NoExternal  : ChannelMode  -- +n
  TopicLock   : ChannelMode  -- +t
  Secret      : ChannelMode  -- +s
  KeyRequired : ChannelMode  -- +k

||| Parsed IRC protocol message.
public export
record IrcMessage where
  constructor MkIrcMessage
  prefix  : Maybe String
  command : String
  params  : List String

||| IRC channel state.
public export
record ChannelState where
  constructor MkChannelState
  name  : String
  topic : String
  users : List String
  modes : List ChannelMode
