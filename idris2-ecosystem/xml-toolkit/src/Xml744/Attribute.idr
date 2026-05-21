-- SPDX-License-Identifier: MIT
-- | Type-safe XML attributes - no more quote injection
module Xml744.Attribute

import Xml744.Escape
import Xml744.Text
import Data.String
import Data.List

%default total

||| Valid XML name characters (simplified - ASCII subset).
|||
||| `public export` so cross-module callers of `unsafeAttrName` / `wAttr` on
||| string literals can have the auto-implicit `isValidName s = True` proof
||| discharged by elaboration-time reduction. With plain `export` only the
||| name is visible and reduction is blocked.
public export
isNameStartChar : Char -> Bool
isNameStartChar c = isAlpha c || c == '_' || c == ':'

public export
isNameChar : Char -> Bool
isNameChar c = isNameStartChar c || isDigit c || c == '-' || c == '.'

||| Check if a string is a valid XML name.
public export
isValidName : String -> Bool
isValidName s = case unpack s of
  [] => False
  (x :: xs) => isNameStartChar x && all isNameChar xs

||| XML Attribute name - validated at construction
public export
data AttrName : Type where
  MkAttrName : (n : String) -> {auto prf : isValidName n = True} -> AttrName

||| Try to create an attribute name (returns Nothing if invalid).
|||
||| The `with proof` form binds `prf : isValidName s = True` in the matched
||| branch, which discharges `MkAttrName`'s auto-implicit. Replaces the
||| previous `decEq (isValidName s) True` form — `decEq` for `Bool` is not in
||| scope on Idris2 0.8.0 with the current imports.
export
attrName : (s : String) -> Maybe AttrName
attrName s with (isValidName s) proof prf
  attrName s | True  = Just (MkAttrName s)
  attrName s | False = Nothing

||| Attribute-name constructor for string literals whose validity Idris2
||| can verify at elaboration time. The auto-implicit `isValidName s = True`
||| is discharged by `Refl` for any literal (or compile-time-known) string.
||| Replaces the previous `cast (MkAttrName s)` placeholder, which never
||| compiled (no matching `Cast` instance, and `MkAttrName` needs the proof).
export
unsafeAttrName : (s : String) -> {auto prf : isValidName s = True} -> AttrName
unsafeAttrName s = MkAttrName s

||| Common attribute names as constants
export
id : AttrName
id = unsafeAttrName "id"

export
name : AttrName
name = unsafeAttrName "name"

export
value : AttrName
value = unsafeAttrName "value"

||| XML Attribute - name and escaped value
public export
record XmlAttr where
  constructor MkAttr
  attrName  : AttrName
  attrValue : String  -- stored escaped

||| Create an attribute with automatic escaping
export
attr : AttrName -> String -> XmlAttr
attr n v = MkAttr n (infiltrateAttr v)

||| Render an attribute to XML string
export
renderAttr : XmlAttr -> String
renderAttr (MkAttr (MkAttrName n) v) = n ++ "=\"" ++ v ++ "\""

||| Get the unescaped value
export
getAttrValue : XmlAttr -> String
getAttrValue (MkAttr _ v) = exfiltrate v

||| Convenience for common w: namespace attributes (OOXML).
|||
||| The auto-implicit proof obligation `isValidName ("w:" ++ n) = True` is
||| discharged at the call site by `Refl` for any literal `n` (the elaborator
||| reduces both the string concatenation and `isValidName` on closed terms).
export
wAttr : (n : String) -> {auto prf : isValidName ("w:" ++ n) = True} -> String -> XmlAttr
wAttr n v = attr (unsafeAttrName ("w:" ++ n)) v

||| Example: attribute that would break with raw quotes
export
exampleAttrSafety : XmlAttr
exampleAttrSafety = attr name "value \"with\" quotes"
-- renderAttr exampleAttrSafety == "name=\"value &quot;with&quot; quotes\""
