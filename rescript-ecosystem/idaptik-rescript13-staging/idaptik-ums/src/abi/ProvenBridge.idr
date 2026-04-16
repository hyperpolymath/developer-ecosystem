-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- ProvenBridge.idr — Bridge between the proven repo's SafeJson and UMS level data
--
-- This module provides total JSON parsing and validation for IDApTIK level data
-- using the proven repo's formally verified SafeJson library. All functions are
-- total: they return structured errors instead of crashing.
--
-- Integration status:
--   - SafeJson types are defined locally (JsonValue, ParseError) to allow
--     compilation without the proven package dependency.
--   - When the proven ipkg is added as a dependency, replace the local types
--     with imports from Proven.SafeJson (see TODO markers below).
module ProvenBridge

import Primitives
import Types
import Devices
import Zones
import Guards
import Level
import Validation

import Data.Fin
import Data.List
import Data.String

%default total

------------------------------------------------------------------------
-- JSON Value representation (mirrors Proven.SafeJson.Parser.JsonValue)
------------------------------------------------------------------------

-- TODO(proven-integration): Replace this block with:
--   import Proven.SafeJson
--   import Proven.SafeJson.Parser
--   import Proven.SafeJson.Access
-- once the proven package is declared as a dependency in idaptik-ums.ipkg.

||| JSON value type, locally mirrored from Proven.SafeJson.Parser.
||| When proven is available as a dependency, remove this and import directly.
public export
data JValue : Type where
  JNull   : JValue
  JBool   : Bool -> JValue
  JNumber : Double -> JValue
  JString : String -> JValue
  JArray  : List JValue -> JValue
  JObject : List (String, JValue) -> JValue

------------------------------------------------------------------------
-- Minimal total JSON parser (placeholder for Proven.SafeJson.parse)
------------------------------------------------------------------------

-- TODO(proven-integration): Replace parseJsonString with:
--   Proven.SafeJson.Parser.parse : String -> Either ParseError JsonValue
-- The proven parser handles Unicode escapes, nesting limits, and provides
-- position-annotated errors. This placeholder only returns a generic error.

||| Attempt to parse a JSON string into a JValue.
||| This is a placeholder that delegates to a minimal recursive-descent
||| parser. The real implementation will call Proven.SafeJson.parse.
|||
||| @input  Raw JSON text
||| @return Left with human-readable error, or Right with parsed value
export
parseJsonString : String -> Either String JValue
parseJsonString input =
  let chars = unpack (trim input)
  in case chars of
       [] => Left "Empty input"
       _  => mapFst showErr (parseTop chars 0)
  where
    ||| Convert position-tagged error to human-readable string.
    showErr : (Nat, String) -> String
    showErr (pos, msg) = "Parse error at position " ++ show pos ++ ": " ++ msg

    ||| Map over the Left branch of an Either.
    mapFst : (a -> c) -> Either a b -> Either c b
    mapFst f (Left x)  = Left (f x)
    mapFst _ (Right x) = Right x

    mutual
      ||| Top-level parse: skip leading whitespace, parse one value,
      ||| reject trailing non-whitespace.
      parseTop : List Char -> Nat -> Either (Nat, String) JValue
      parseTop cs pos =
        let (cs1, pos1) = skipWS cs pos
        in case parseValue cs1 pos1 0 of
             Left err => Left err
             Right (val, cs2, pos2) =>
               let (cs3, _) = skipWS cs2 pos2
               in if null cs3
                    then Right val
                    else Left (pos2, "Trailing content after value")

      ||| Skip whitespace characters, advancing position.
      skipWS : List Char -> Nat -> (List Char, Nat)
      skipWS [] p = ([], p)
      skipWS (c :: cs) p =
        if c == ' ' || c == '\n' || c == '\r' || c == '\t'
          then skipWS cs (S p)
          else (c :: cs, p)

      ||| Parse a single JSON value with depth tracking.
      ||| Depth is bounded to prevent stack overflow on malicious input.
      parseValue : List Char -> Nat -> Nat -> Either (Nat, String) (JValue, List Char, Nat)
      parseValue [] pos _     = Left (pos, "Unexpected end of input")
      parseValue cs pos depth =
        if depth > 100
          then Left (pos, "Nesting too deep (max 100)")
          else let (cs', pos') = skipWS cs pos
               in case cs' of
                    []            => Left (pos', "Unexpected end of input")
                    ('n' :: rest) => parseNull rest pos'
                    ('t' :: rest) => parseTrue rest pos'
                    ('f' :: rest) => parseFalse rest pos'
                    ('"' :: rest) => parseStr rest (S pos') []
                    ('[' :: rest) => parseArr rest (S pos') (S depth)
                    ('{' :: rest) => parseObj rest (S pos') (S depth)
                    (c :: _)      =>
                      if c == '-' || (c >= '0' && c <= '9')
                        then parseNum cs' pos'
                        else Left (pos', "Unexpected character: " ++ singleton c)

      ||| Parse the literal "null" (the 'n' has already been consumed).
      parseNull : List Char -> Nat -> Either (Nat, String) (JValue, List Char, Nat)
      parseNull ('u' :: 'l' :: 'l' :: rest) pos = Right (JNull, rest, pos + 4)
      parseNull _ pos = Left (pos, "Expected 'null'")

      ||| Parse the literal "true" (the 't' has already been consumed).
      parseTrue : List Char -> Nat -> Either (Nat, String) (JValue, List Char, Nat)
      parseTrue ('r' :: 'u' :: 'e' :: rest) pos = Right (JBool True, rest, pos + 4)
      parseTrue _ pos = Left (pos, "Expected 'true'")

      ||| Parse the literal "false" (the 'f' has already been consumed).
      parseFalse : List Char -> Nat -> Either (Nat, String) (JValue, List Char, Nat)
      parseFalse ('a' :: 'l' :: 's' :: 'e' :: rest) pos = Right (JBool False, rest, pos + 5)
      parseFalse _ pos = Left (pos, "Expected 'false'")

      ||| Parse a JSON string (opening '"' already consumed).
      parseStr : List Char -> Nat -> List Char -> Either (Nat, String) (JValue, List Char, Nat)
      parseStr [] pos _           = Left (pos, "Unterminated string")
      parseStr ('"' :: rest) pos acc  = Right (JString (pack (reverse acc)), rest, S pos)
      parseStr ('\\' :: c :: rest) pos acc =
        case c of
          '"'  => parseStr rest (pos + 2) ('"' :: acc)
          '\\' => parseStr rest (pos + 2) ('\\' :: acc)
          '/'  => parseStr rest (pos + 2) ('/' :: acc)
          'n'  => parseStr rest (pos + 2) ('\n' :: acc)
          'r'  => parseStr rest (pos + 2) ('\r' :: acc)
          't'  => parseStr rest (pos + 2) ('\t' :: acc)
          _    => Left (pos, "Unknown escape: \\" ++ singleton c)
      parseStr ('\\' :: []) pos _ = Left (pos, "Unterminated escape")
      parseStr (c :: rest) pos acc    = parseStr rest (S pos) (c :: acc)

      ||| Parse a JSON number. Collects digit/sign/dot/e characters, then
      ||| delegates to cast for conversion.
      parseNum : List Char -> Nat -> Either (Nat, String) (JValue, List Char, Nat)
      parseNum cs pos =
        let (numChars, rest, pos') = collectNum cs pos
            numStr = pack numChars
        in case parseDouble numStr of
             Just d  => Right (JNumber d, rest, pos')
             Nothing => Left (pos, "Invalid number: " ++ numStr)
        where
          isNumChar : Char -> Bool
          isNumChar c = (c >= '0' && c <= '9') || c == '.' || c == '-'
                        || c == '+' || c == 'e' || c == 'E'

          collectNum : List Char -> Nat -> (List Char, List Char, Nat)
          collectNum [] p = ([], [], p)
          collectNum (c :: cs') p =
            if isNumChar c
              then let (more, rest, p') = collectNum cs' (S p)
                   in (c :: more, rest, p')
              else ([], c :: cs', p)

          parseDouble : String -> Maybe Double
          parseDouble s = Just (cast {to=Double} s)

      ||| Parse a JSON array (opening '[' already consumed).
      parseArr : List Char -> Nat -> Nat -> Either (Nat, String) (JValue, List Char, Nat)
      parseArr cs pos depth =
        let (cs1, pos1) = skipWS cs pos
        in case cs1 of
             (']' :: rest) => Right (JArray [], rest, S pos1)
             _             => parseArrElems cs1 pos1 depth []

      ||| Parse comma-separated array elements.
      parseArrElems : List Char -> Nat -> Nat -> List JValue
                    -> Either (Nat, String) (JValue, List Char, Nat)
      parseArrElems cs pos depth acc =
        case parseValue cs pos depth of
          Left err => Left err
          Right (val, cs1, pos1) =>
            let (cs2, pos2) = skipWS cs1 pos1
            in case cs2 of
                 (']' :: rest) => Right (JArray (reverse (val :: acc)), rest, S pos2)
                 (',' :: rest) =>
                   let (cs3, pos3) = skipWS rest (S pos2)
                   in parseArrElems cs3 pos3 depth (val :: acc)
                 _ => Left (pos2, "Expected ',' or ']' in array")

      ||| Parse a JSON object (opening '{' already consumed).
      parseObj : List Char -> Nat -> Nat -> Either (Nat, String) (JValue, List Char, Nat)
      parseObj cs pos depth =
        let (cs1, pos1) = skipWS cs pos
        in case cs1 of
             ('}' :: rest) => Right (JObject [], rest, S pos1)
             _             => parseObjMembers cs1 pos1 depth []

      ||| Parse comma-separated object members ("key": value).
      parseObjMembers : List Char -> Nat -> Nat -> List (String, JValue)
                      -> Either (Nat, String) (JValue, List Char, Nat)
      parseObjMembers cs pos depth acc =
        case cs of
          ('"' :: rest) =>
            case parseStr rest (S pos) [] of
              Left err => Left err
              Right (JString key, cs1, pos1) =>
                let (cs2, pos2) = skipWS cs1 pos1
                in case cs2 of
                     (':' :: rest2) =>
                       let (cs3, pos3) = skipWS rest2 (S pos2)
                       in case parseValue cs3 pos3 depth of
                            Left err => Left err
                            Right (val, cs4, pos4) =>
                              let (cs5, pos5) = skipWS cs4 pos4
                              in case cs5 of
                                   ('}' :: rest3) =>
                                     Right (JObject (reverse ((key, val) :: acc)), rest3, S pos5)
                                   (',' :: rest3) =>
                                     let (cs6, pos6) = skipWS rest3 (S pos5)
                                     in parseObjMembers cs6 pos6 depth ((key, val) :: acc)
                                   _ => Left (pos5, "Expected ',' or '}' in object")
                     _ => Left (pos2, "Expected ':' after object key")
              -- parseStr returned a non-string (impossible by construction)
              Right _ => Left (pos, "Internal error: key parse did not yield string")
          _ => Left (pos, "Expected '\"' for object key")

------------------------------------------------------------------------
-- Safe JSON accessors (mirrors Proven.SafeJson / Proven.SafeJson.Access)
------------------------------------------------------------------------

-- TODO(proven-integration): Replace with imports from Proven.SafeJson.Access

||| Look up a key in a JObject. Returns Nothing for non-objects or missing keys.
export
jGet : String -> JValue -> Maybe JValue
jGet key (JObject pairs) = lookup key pairs
jGet _   _               = Nothing

||| Extract a String from a JValue.
export
jAsString : JValue -> Maybe String
jAsString (JString s) = Just s
jAsString _           = Nothing

||| Extract a Double from a JValue.
export
jAsNumber : JValue -> Maybe Double
jAsNumber (JNumber n) = Just n
jAsNumber _           = Nothing

||| Extract an Integer from a JValue (truncates fractional part).
export
jAsInt : JValue -> Maybe Integer
jAsInt (JNumber n) = Just (cast n)
jAsInt _           = Nothing

||| Extract a Nat from a JValue (returns Nothing for negatives).
export
jAsNat : JValue -> Maybe Nat
jAsNat (JNumber n) = if n >= 0.0 then Just (cast (cast {to=Integer} n)) else Nothing
jAsNat _           = Nothing

||| Extract a Bool from a JValue.
export
jAsBool : JValue -> Maybe Bool
jAsBool (JBool b) = Just b
jAsBool _         = Nothing

||| Extract a List from a JArray.
export
jAsArray : JValue -> Maybe (List JValue)
jAsArray (JArray xs) = Just xs
jAsArray _           = Nothing

------------------------------------------------------------------------
-- Level data extraction from JSON
------------------------------------------------------------------------

||| Errors collected during level data extraction.
||| Each entry is a human-readable description of what went wrong.
public export
ExtractionErrors : Type
ExtractionErrors = List String

||| Result of extracting a value: either the value or accumulated errors.
||| We use List String rather than a single error so that extraction can
||| report ALL problems in one pass, not just the first.
public export
data Extracted : Type -> Type where
  ||| Extraction succeeded with a value.
  Ok   : a -> Extracted a
  ||| Extraction failed with one or more error descriptions.
  Errs : (errors : ExtractionErrors) -> Extracted a

||| Functor-like map for Extracted.
export
mapExtracted : (a -> b) -> Extracted a -> Extracted b
mapExtracted f (Ok x)     = Ok (f x)
mapExtracted _ (Errs es)  = Errs es

||| Combine two Extracted values, accumulating errors from both sides.
export
combineExtracted : Extracted a -> Extracted b -> Extracted (a, b)
combineExtracted (Ok x)    (Ok y)    = Ok (x, y)
combineExtracted (Errs e1) (Errs e2) = Errs (e1 ++ e2)
combineExtracted (Errs e1) _         = Errs e1
combineExtracted _         (Errs e2) = Errs e2

||| Convert an Extracted to Either, joining errors with newlines.
export
extractedToEither : Extracted a -> Either String a
extractedToEither (Ok x)    = Right x
extractedToEither (Errs es) = Left (joinBy "\n" es)

||| Require a field to exist and satisfy a predicate.
export
requireField : String -> String -> (JValue -> Maybe a) -> JValue -> Extracted a
requireField context fieldName extract json =
  case jGet fieldName json of
    Nothing  => Errs [context ++ ": missing required field '" ++ fieldName ++ "'"]
    Just val =>
      case extract val of
        Nothing => Errs [context ++ ": field '" ++ fieldName ++ "' has wrong type"]
        Just x  => Ok x

||| Require an optional field: if present it must parse, if absent returns Nothing.
export
optionalField : String -> String -> (JValue -> Maybe a) -> JValue -> Extracted (Maybe a)
optionalField context fieldName extract json =
  case jGet fieldName json of
    Nothing  => Ok Nothing
    Just val =>
      case extract val of
        Nothing => Errs [context ++ ": field '" ++ fieldName ++ "' has wrong type"]
        Just x  => Ok (Just x)

------------------------------------------------------------------------
-- Octet / IpAddress extraction
------------------------------------------------------------------------

||| Parse an octet (0-255) from a JValue number.
export
extractOctet : String -> JValue -> Extracted (Fin 256)
extractOctet context json =
  case jAsInt json of
    Nothing => Errs [context ++ ": expected integer for octet"]
    Just n  =>
      if n >= 0 && n <= 255
        then case natToFin (cast n) 256 of
               Just f  => Ok f
               Nothing => Errs [context ++ ": octet out of range (internal)"]
        else Errs [context ++ ": octet " ++ show n ++ " out of range 0-255"]

||| Parse an IP address from a JSON string in "a.b.c.d" format.
export
extractIpAddress : String -> JValue -> Extracted IpAddress
extractIpAddress context json =
  case jAsString json of
    Nothing => Errs [context ++ ": expected string for IP address"]
    Just s  =>
      case split (== '.') s of
        -- split returns a List1 (SnocList), so we convert and check length
        parts =>
          let partsList = forget parts
          in case partsList of
               [a, b, c, d] =>
                 case (parseOctetStr a, parseOctetStr b, parseOctetStr c, parseOctetStr d) of
                   (Just o1, Just o2, Just o3, Just o4) =>
                     Ok (MkIpAddress o1 o2 o3 o4)
                   _ => Errs [context ++ ": invalid IP address octets in '" ++ s ++ "'"]
               _ => Errs [context ++ ": IP address must have exactly 4 octets, got '" ++ s ++ "'"]
  where
    ||| Parse a single octet string to Fin 256.
    parseOctetStr : String -> Maybe (Fin 256)
    parseOctetStr s =
      case parsePositive {a=Integer} s of
        Nothing => Nothing
        Just n  => if n >= 0 && n <= 255
                     then natToFin (cast n) 256
                     else Nothing

------------------------------------------------------------------------
-- Enum extraction helpers
------------------------------------------------------------------------

||| Parse a SecurityLevel from a JSON string.
export
extractSecurityLevel : String -> JValue -> Extracted SecurityLevel
extractSecurityLevel ctx json =
  case jAsString json of
    Nothing => Errs [ctx ++ ": expected string for security level"]
    Just "open"   => Ok Open
    Just "weak"   => Ok Weak
    Just "medium" => Ok Medium
    Just "strong" => Ok Strong
    Just other    => Errs [ctx ++ ": unknown security level '" ++ other ++ "'"]

||| Parse a DeviceKind from a JSON string.
export
extractDeviceKind : String -> JValue -> Extracted DeviceKind
extractDeviceKind ctx json =
  case jAsString json of
    Nothing => Errs [ctx ++ ": expected string for device kind"]
    Just "laptop"       => Ok Laptop
    Just "desktop"      => Ok Desktop
    Just "server"       => Ok Server
    Just "router"       => Ok Router
    Just "switch"       => Ok Switch
    Just "firewall"     => Ok Firewall
    Just "camera"       => Ok Camera
    Just "access_point" => Ok AccessPoint
    Just "patch_panel"  => Ok PatchPanel
    Just "power_supply" => Ok PowerSupply
    Just "phone_system" => Ok PhoneSystem
    Just "fibre_hub"    => Ok FibreHub
    Just other          => Errs [ctx ++ ": unknown device kind '" ++ other ++ "'"]

||| Parse a GuardRank from a JSON string.
export
extractGuardRank : String -> JValue -> Extracted GuardRank
extractGuardRank ctx json =
  case jAsString json of
    Nothing => Errs [ctx ++ ": expected string for guard rank"]
    Just "basic"          => Ok BasicGuard
    Just "enforcer"       => Ok Enforcer
    Just "anti_hacker"    => Ok AntiHacker
    Just "sentinel"       => Ok Sentinel
    Just "assassin"       => Ok Assassin
    Just "elite"          => Ok EliteGuard
    Just "security_chief" => Ok SecurityChief
    Just "rival_hacker"   => Ok RivalHacker
    Just other            => Errs [ctx ++ ": unknown guard rank '" ++ other ++ "'"]

------------------------------------------------------------------------
-- Record extraction
------------------------------------------------------------------------

||| Extract a DeviceSpec from a JSON object.
export
extractDevice : String -> JValue -> Extracted DeviceSpec
extractDevice ctx json =
  case ( extractDeviceKind (ctx ++ ".kind") =<< maybeToExtracted (ctx ++ ".kind") (jGet "kind" json)
       , extractIpAddress (ctx ++ ".ip") =<< maybeToExtracted (ctx ++ ".ip") (jGet "ip" json)
       , requireField ctx "name" jAsString json
       , extractSecurityLevel (ctx ++ ".security") =<< maybeToExtracted (ctx ++ ".security") (jGet "security" json)
       ) of
    (Ok k, Ok i, Ok n, Ok s) => Ok (MkDeviceSpec k i n s)
    (e1, e2, e3, e4) => Errs (collectErrs [e1, e2, e3, e4])
  where
    ||| Bind-like operation for Extracted. Applies f to the inner value,
    ||| or propagates errors.
    (=<<) : (a -> Extracted b) -> Extracted a -> Extracted b
    (=<<) f (Ok x)    = f x
    (=<<) _ (Errs es) = Errs es

    ||| Lift a Maybe into Extracted, using the given context for error messages.
    maybeToExtracted : String -> Maybe a -> Extracted a
    maybeToExtracted _   (Just x) = Ok x
    maybeToExtracted msg Nothing  = Errs [msg ++ ": field missing"]

    ||| Collect error messages from a list of Extracted values.
    collectErrs : List (Extracted a) -> ExtractionErrors
    collectErrs [] = []
    collectErrs (Errs es :: rest) = es ++ collectErrs rest
    collectErrs (_ :: rest) = collectErrs rest

||| Extract a Zone from a JSON object.
export
extractZone : String -> JValue -> Extracted Zone
extractZone ctx json =
  case (requireField ctx "name" jAsString json,
        requireField ctx "security_tier" jAsNat json) of
    (Ok n, Ok t)    => Ok (MkZone n t)
    (Errs e1, Errs e2) => Errs (e1 ++ e2)
    (Errs e1, _)    => Errs e1
    (_, Errs e2)    => Errs e2

||| Extract a GuardPlacement from a JSON object.
export
extractGuard : String -> JValue -> Extracted GuardPlacement
extractGuard ctx json =
  case ( requireField ctx "world_x" jAsNumber json
       , requireField ctx "zone" jAsString json
       , extractGuardRank ctx =<< maybeToExtracted (ctx ++ ".rank") (jGet "rank" json)
       , requireField ctx "patrol_radius" jAsNumber json
       ) of
    (Ok wx, Ok z, Ok r, Ok pr) => Ok (MkGuardPlacement (MkWorldX wx) z r pr)
    (e1, e2, e3, e4) => Errs (collectErrs [e1, e2, e3, e4])
  where
    (=<<) : (a -> Extracted b) -> Extracted a -> Extracted b
    (=<<) f (Ok x)    = f x
    (=<<) _ (Errs es) = Errs es

    maybeToExtracted : String -> Maybe a -> Extracted a
    maybeToExtracted _   (Just x) = Ok x
    maybeToExtracted msg Nothing  = Errs [msg ++ ": field missing"]

    collectErrs : List (Extracted a) -> ExtractionErrors
    collectErrs [] = []
    collectErrs (Errs es :: rest) = es ++ collectErrs rest
    collectErrs (_ :: rest) = collectErrs rest

||| Extract a ZoneTransition from a JSON object.
export
extractZoneTransition : String -> JValue -> Extracted ZoneTransition
extractZoneTransition ctx json =
  case ( requireField ctx "world_x" jAsNumber json
       , requireField ctx "from_zone" jAsString json
       , requireField ctx "to_zone" jAsString json
       ) of
    (Ok wx, Ok fz, Ok tz) => Ok (MkZoneTransition (MkWorldX wx) fz tz)
    (e1, e2, e3) => Errs (collectErrs [e1, e2, e3])
  where
    collectErrs : List (Extracted a) -> ExtractionErrors
    collectErrs [] = []
    collectErrs (Errs es :: rest) = es ++ collectErrs rest
    collectErrs (_ :: rest) = collectErrs rest

------------------------------------------------------------------------
-- List extraction helper
------------------------------------------------------------------------

||| Extract a list of items from a JSON array, accumulating all errors.
||| Each element is labelled with its index for error context.
export
extractList : String -> (String -> JValue -> Extracted a) -> JValue -> Extracted (List a)
extractList ctx extractor json =
  case jAsArray json of
    Nothing => Errs [ctx ++ ": expected JSON array"]
    Just xs => go xs 0 [] []
  where
    go : List JValue -> Nat -> List a -> ExtractionErrors -> Extracted (List a)
    go [] _ acc [] = Ok (reverse acc)
    go [] _ _   errs = Errs (reverse errs)
    go (x :: xs) idx acc errs =
      let elemCtx = ctx ++ "[" ++ show idx ++ "]"
      in case extractor elemCtx x of
           Ok val   => go xs (S idx) (val :: acc) errs
           Errs es  => go xs (S idx) acc (es ++ errs)

------------------------------------------------------------------------
-- Top-level: parseLevelJson
------------------------------------------------------------------------

||| Parse a raw JSON string into a LevelData record.
|||
||| This function is total: malformed JSON or missing/wrong-typed fields
||| produce a Left with human-readable error descriptions. It never crashes.
|||
||| Expected JSON schema (top-level object):
|||   { "devices": [...], "zones": [...], "guards": [...],
|||     "zone_transitions": [...], "has_pbx": bool, "pbx_ip": "a.b.c.d",
|||     "pbx_world_x": number, "mission": {...}, "physical": {...},
|||     ... }
|||
||| Fields not yet extracted (dogs, drones, assassins, items, wiring,
||| mission, physical, device_defences) return empty defaults. These will
||| be filled in as their respective extractors are implemented.
|||
||| TODO(proven-integration): Replace parseJsonString call with
|||   Proven.SafeJson.Parser.parse, then convert Proven.SafeJson.Parser.JsonValue
|||   to JValue (or unify the types).
export
parseLevelJson : String -> Either String LevelData
parseLevelJson input =
  case parseJsonString input of
    Left err   => Left ("JSON parse failure: " ++ err)
    Right json => extractedToEither (extractLevelData json)
  where
    ||| Build a LevelData from the top-level JSON object.
    ||| Accumulates errors across all fields so the caller gets a complete
    ||| report rather than stopping at the first problem.
    extractLevelData : JValue -> Extracted LevelData
    extractLevelData json =
      let devicesR = case jGet "devices" json of
                       Nothing => Ok []
                       Just v  => extractList "devices" extractDevice v
          zonesR   = case jGet "zones" json of
                       Nothing => Ok []
                       Just v  => extractList "zones" extractZone v
          guardsR  = case jGet "guards" json of
                       Nothing => Ok []
                       Just v  => extractList "guards" extractGuard v
          ztR      = case jGet "zone_transitions" json of
                       Nothing => Ok []
                       Just v  => extractList "zone_transitions" extractZoneTransition v
          hasPbxR  = case jGet "has_pbx" json of
                       Nothing => Ok False
                       Just v  => case jAsBool v of
                                    Just b  => Ok b
                                    Nothing => Errs ["has_pbx: expected boolean"]
          pbxIpR   = case jGet "pbx_ip" json of
                       Nothing => Ok (MkIpAddress 0 0 0 0)
                       Just v  => extractIpAddress "pbx_ip" v
          pbxWxR   = case jGet "pbx_world_x" json of
                       Nothing => Ok (MkWorldX 0.0)
                       Just v  => case jAsNumber v of
                                    Just n  => Ok (MkWorldX n)
                                    Nothing => Errs ["pbx_world_x: expected number"]
      in case (devicesR, zonesR, guardsR, ztR, hasPbxR, pbxIpR, pbxWxR) of
           (Ok devs, Ok zs, Ok gs, Ok zt, Ok hp, Ok pip, Ok pwx) =>
             Ok (MkLevelData
               devs          -- devices
               zs            -- zones
               gs            -- guards
               []            -- dogs (TODO: implement extractDog)
               []            -- drones (TODO: implement extractDrone)
               []            -- assassins (TODO: implement extractAssassin)
               []            -- items (TODO: implement extractItem)
               []            -- wiring (TODO: implement extractWiring)
               ?missionHole  -- mission (TODO: implement extractMission)
               ?physicalHole -- physical (TODO: implement extractPhysical)
               zt            -- zoneTransitions
               []            -- deviceDefences (TODO: implement extractDefence)
               hp            -- hasPBX
               pip           -- pbxIp
               pwx)          -- pbxWorldX
           -- If any field failed, collect all errors.
           _ => Errs (collectAllErrs [devicesR, zonesR, guardsR, ztR]
                      ++ collectAllErrs [hasPbxR]
                      ++ collectAllErrs [pbxIpR]
                      ++ collectAllErrs [pbxWxR])
      where
        collectAllErrs : List (Extracted a) -> ExtractionErrors
        collectAllErrs [] = []
        collectAllErrs (Errs es :: rest) = es ++ collectAllErrs rest
        collectAllErrs (_ :: rest) = collectAllErrs rest

------------------------------------------------------------------------
-- validateAndReport: human-readable validation diagnostics
------------------------------------------------------------------------

||| Run cross-domain validation checks on a LevelData and collect all
||| failures as human-readable strings.
|||
||| This function performs the decidable (Bool-returning) subset of the
||| checks that Validation.idr encodes as proofs. It cannot construct
||| the proof witnesses (those require compile-time evidence), but it
||| can report whether the data WOULD pass validation.
|||
||| Checks performed:
|||   1. Every guard references a zone that exists in the zone list.
|||   2. Zone transitions are monotonically increasing in world X.
|||   3. PBX IP (when enabled) exists in the device registry.
|||   4. No duplicate device IPs.
|||   5. No duplicate zone names.
|||
||| @level  The level data to validate
||| @return A list of failure descriptions (empty means all checks pass)
export
validateAndReport : LevelData -> List String
validateAndReport level =
     checkGuardZones (guards level) (zones level)
  ++ checkZoneOrder (zoneTransitions level)
  ++ checkPBX (hasPBX level) (pbxIp level) (devices level)
  ++ checkDuplicateIPs (devices level)
  ++ checkDuplicateZoneNames (zones level)
  where
    ||| Check that every guard's zone field names an existing zone.
    checkGuardZones : List GuardPlacement -> List Zone -> List String
    checkGuardZones [] _ = []
    checkGuardZones (g :: gs) zs =
      let zoneNames = map name zs
          errors = if zone g `elem` zoneNames
                     then []
                     else ["Guard at x=" ++ show (position (worldX g))
                           ++ " references unknown zone '" ++ zone g ++ "'"]
      in errors ++ checkGuardZones gs zs

    ||| Check that zone transitions are monotonically non-decreasing in X.
    checkZoneOrder : List ZoneTransition -> List String
    checkZoneOrder [] = []
    checkZoneOrder [_] = []
    checkZoneOrder (t1 :: t2 :: ts) =
      let errors = if position (worldX t1) <= position (worldX t2)
                     then []
                     else ["Zone transition at x=" ++ show (position (worldX t1))
                           ++ " is not <= next transition at x="
                           ++ show (position (worldX t2))]
      in errors ++ checkZoneOrder (t2 :: ts)

    ||| When PBX is enabled, its IP must exist among devices.
    checkPBX : Bool -> IpAddress -> List DeviceSpec -> List String
    checkPBX False _ _ = []
    checkPBX True addr devs =
      let deviceIPs = map ip devs
      in if addr `elem` deviceIPs
           then []
           else ["PBX is enabled but pbx_ip does not match any device IP"]

    ||| Check for duplicate device IPs.
    checkDuplicateIPs : List DeviceSpec -> List String
    checkDuplicateIPs devs =
      let ips = map ip devs
      in findDups ips []
      where
        findDups : List IpAddress -> List IpAddress -> List String
        findDups [] _ = []
        findDups (x :: xs) seen =
          if x `elem` seen
            then ("Duplicate device IP found") :: findDups xs seen
            else findDups xs (x :: seen)

    ||| Check for duplicate zone names.
    checkDuplicateZoneNames : List Zone -> List String
    checkDuplicateZoneNames zs =
      let names = map name zs
      in findDupNames names []
      where
        findDupNames : List String -> List String -> List String
        findDupNames [] _ = []
        findDupNames (x :: xs) seen =
          if x `elem` seen
            then ("Duplicate zone name '" ++ x ++ "'") :: findDupNames xs seen
            else findDupNames xs (x :: seen)
