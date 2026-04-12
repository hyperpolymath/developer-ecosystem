-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Process.idr — Safe subprocess execution types for unified-zig-api
--
-- Defines the SafePath predicate (allowlist-based path validation) and the
-- ExecResult type for subprocess execution outcomes.  The safe_path logic
-- here mirrors the Zig implementation in ffi/zig/src/process.zig.

module ZigApi.ABI.Process

import Data.Bits
import Data.List
import Data.List.Elem
import Data.String
import Decidable.Equality
import ZigApi.ABI.Types

%default total

-- ============================================================================
-- SafePath predicate
-- ============================================================================

||| A path is safe if it starts with at least one element of the allowlist.
||| Constructor SafeByPrefix provides a direct witness: pfx is in allowlist
||| and is a prefix of path. (Note: "prefix" is an Idris2 keyword — use pfx.)
public export
data IsSafePath : String -> List String -> Type where
  SafeByPrefix : {pfx : String} -> {allowlist : List String} -> {path : String} -> Elem pfx allowlist -> isPrefixOf pfx path = True -> IsSafePath path allowlist

||| Decision procedure: check whether any allowlist prefix matches.
||| Returns Left (proof of safety) or Right (no match found).
public export
checkSafePath :
  (path : String) ->
  (allowlist : List String) ->
  Either (IsSafePath path allowlist) String
checkSafePath path [] = Right "path denied: allowlist is empty"
checkSafePath path (p :: ps) with (decEq (isPrefixOf p path) True)
  _ | Yes prf = Left (SafeByPrefix Here prf)
  _ | No  _   = case checkSafePath path ps of
    Left (SafeByPrefix qElem qPrf) => Left (SafeByPrefix (There qElem) qPrf)
    Right msg => Right msg

-- ============================================================================
-- Standard allowlist (matches Zig DEFAULT_ALLOWLIST)
-- ============================================================================

||| Default allowlist for gnosis template and SCM path arguments.
||| Mirrors process.zig's DEFAULT_ALLOWLIST constant.
public export
defaultAllowlist : List String
defaultAllowlist =
  [ "/var/mnt/eclipse/repos/"
  , "/home/hyper/"
  , "/tmp/"
  , "./"
  ]

-- ============================================================================
-- ExecResult  (Zig: pub const ExecResult = enum(u8))
-- ============================================================================

||| Outcome of a subprocess execution.
public export
data ExecResult
  = ExecOk       -- 0 subprocess exited 0, stdout captured
  | ExecFailed   -- 1 subprocess exited non-zero
  | ExecTimeout  -- 2 subprocess exceeded time limit
  | ExecDenied   -- 3 path validation rejected an argument
  | ExecNotFound -- 4 binary not found on PATH
  | ExecOomErr   -- 5 allocation failure during exec

public export
execResultTag : ExecResult -> Bits8
execResultTag ExecOk       = 0
execResultTag ExecFailed   = 1
execResultTag ExecTimeout  = 2
execResultTag ExecDenied   = 3
execResultTag ExecNotFound = 4
execResultTag ExecOomErr   = 5

public export
execResultFromTag : Bits8 -> Maybe ExecResult
execResultFromTag 0 = Just ExecOk
execResultFromTag 1 = Just ExecFailed
execResultFromTag 2 = Just ExecTimeout
execResultFromTag 3 = Just ExecDenied
execResultFromTag 4 = Just ExecNotFound
execResultFromTag 5 = Just ExecOomErr
execResultFromTag _ = Nothing

public export
execResultRoundtrip : (r : ExecResult) -> execResultFromTag (execResultTag r) = Just r
execResultRoundtrip ExecOk       = Refl
execResultRoundtrip ExecFailed   = Refl
execResultRoundtrip ExecTimeout  = Refl
execResultRoundtrip ExecDenied   = Refl
execResultRoundtrip ExecNotFound = Refl
execResultRoundtrip ExecOomErr   = Refl

-- ============================================================================
-- GnosisCommand — structured representation of a gnosis CLI call
-- ============================================================================

||| The render mode parameter (mirrors gnosis --mode flag).
public export
data RenderMode = Plain | Badges | HTML | JSON

public export
renderModeFlag : RenderMode -> String
renderModeFlag Plain  = "--plain"
renderModeFlag Badges = "--badges"
renderModeFlag HTML   = "--html"
renderModeFlag JSON   = "--json"

||| A validated gnosis render command.
||| Construction requires proofs that template_path and scm_path are safe.
public export
record GnosisRenderCmd where
  constructor MkRenderCmd
  template_path : String
  scm_path      : String
  mode          : RenderMode
  {auto 0 tpSafe : IsSafePath template_path ZigApi.ABI.Process.defaultAllowlist}
  {auto 0 spSafe : IsSafePath scm_path      ZigApi.ABI.Process.defaultAllowlist}

||| A validated gnosis context dump command.
public export
record GnosisContextCmd where
  constructor MkContextCmd
  scm_path : String
  {auto 0 spSafe : IsSafePath scm_path ZigApi.ABI.Process.defaultAllowlist}
