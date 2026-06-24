-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-xmpp protocol.
-- XMPP stanza types, presence states, JID structure, roster
-- subscription states, and message types.

module Types

import Data.List

||| XMPP stanza type (the three core stanza kinds).
public export
data StanzaType : Type where
  Message  : StanzaType  -- <message> stanza
  Presence : StanzaType  -- <presence> stanza
  IQ       : StanzaType  -- <iq> stanza (info/query)

||| XMPP message type attribute (RFC 6121 section 5.2.2).
public export
data MessageType : Type where
  Chat      : MessageType  -- One-to-one chat message
  GroupChat : MessageType  -- Multi-user chat message
  Headline  : MessageType  -- Alert/notification (no reply expected)
  Normal    : MessageType  -- Single message outside a session
  Error_    : MessageType  -- Error response to a message

||| IQ stanza type attribute (RFC 6120 section 8.2.3).
public export
data IQType : Type where
  Get    : IQType  -- Request information
  Set    : IQType  -- Modify information
  Result : IQType  -- Response with requested data
  Error  : IQType  -- Error response

||| Presence show value (RFC 6121 section 4.7.2.1).
public export
data PresenceShow : Type where
  Available : PresenceShow  -- Default (no <show> element)
  Away      : PresenceShow  -- Temporarily away
  Chat      : PresenceShow  -- Actively interested in chatting
  DND       : PresenceShow  -- Do not disturb
  XA        : PresenceShow  -- Extended away

||| Roster subscription state (RFC 6121 section 2.1.2.5).
public export
data SubscriptionState : Type where
  SubNone : SubscriptionState  -- No subscription
  SubTo   : SubscriptionState  -- Subscribed to contact's presence
  SubFrom : SubscriptionState  -- Contact subscribed to our presence
  SubBoth : SubscriptionState  -- Mutual subscription

||| Connection lifecycle state.
public export
data ConnState : Type where
  Disconnected   : ConnState
  StreamOpened   : ConnState
  Authenticated  : ConnState
  Bound          : ConnState

||| A Jabber ID with local, domain, and optional resource parts.
public export
record JID where
  constructor MkJID
  local    : String
  domain   : String
  resource : String

||| A roster entry (contact) with JID, name, groups, and subscription.
public export
record RosterItem where
  constructor MkRosterItem
  jid          : JID
  name         : String
  groups       : List String
  subscription : SubscriptionState

||| An XMPP message with sender, recipient, type, and body text.
public export
record XmppMessage where
  constructor MkXmppMessage
  from_jid : JID
  to_jid   : JID
  msgType  : MessageType
  body     : String
  id       : String
