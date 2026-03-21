-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-caldav protocol.
-- iCalendar component types, calendar collection metadata,
-- and event structures for CalDAV access (RFC 4791).

module Types

import Data.List

||| iCalendar component type.
public export
data ComponentType : Type where
  VEvent    : ComponentType  -- Calendar event
  VTodo     : ComponentType  -- Task item
  VJournal  : ComponentType  -- Journal entry
  VFreeBusy : ComponentType  -- Availability info

||| Calendar event (VEVENT).
public export
record CalendarEvent where
  constructor MkCalendarEvent
  uid         : String
  summary     : String
  description : String
  dtstart     : String
  dtend       : String
  location    : String

||| Calendar collection resource.
public export
record Calendar where
  constructor MkCalendar
  href        : String
  displayName : String
  ctag        : String
