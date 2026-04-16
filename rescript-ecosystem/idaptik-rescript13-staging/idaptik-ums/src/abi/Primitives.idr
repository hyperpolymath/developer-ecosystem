-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Primitives.idr — Basic bounded types for IDApTIK Level Architect ABI
module Primitives

import Data.Fin

%default total

||| An IPv4 address represented as four octets, each bounded 0-255.
public export
record IpAddress where
  constructor MkIpAddress
  octet1 : Fin 256
  octet2 : Fin 256
  octet3 : Fin 256
  octet4 : Fin 256

public export
Eq IpAddress where
  (MkIpAddress a1 a2 a3 a4) == (MkIpAddress b1 b2 b3 b4) =
    a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4

||| A percentage value bounded 0-100.
public export
record Percentage where
  constructor MkPercentage
  value : Fin 101

||| World X coordinate wrapper for horizontal positions.
public export
record WorldX where
  constructor MkWorldX
  position : Double

||| Security levels from weakest to strongest.
public export
data SecurityLevel = Open | Weak | Medium | Strong

public export
Eq SecurityLevel where
  Open   == Open   = True
  Weak   == Weak   = True
  Medium == Medium = True
  Strong == Strong = True
  _      == _      = False
