-- SPDX-License-Identifier: MIT
-- | Type-safe XML attributes - no more quote injection
module Xml744.Attribute

import Xml744.Escape
import Xml744.Text
import Data.String
import Data.List

%default total

||| Valid XML name characters (simplified - ASCII subset)
isNameStartChar : Char -> Bool
isNameStartChar c = isAlpha c || c == '_' || c == ':'

isNameChar : Char -> Bool
isNameChar c = isNameStartChar c || isDigit c || c == '-' || c == '.'

||| Check if a string is a valid XML name
export
isValidName : String -> Bool
isValidName s = case unpack s of
  [] => False
  (x :: xs) => isNameStartChar x && all isNameChar xs

||| XML Attribute name - validated at construction
public export
data AttrName : Type where
  MkAttrName : (n : String) -> {auto prf : isValidName n = True} -> AttrName

||| Try to create an attribute name (returns Nothing if invalid)
export
attrName : (s : String) -> Maybe AttrName
attrName s = case decEq (isValidName s) True of
  Yes prf => Just (MkAttrName s)
  No _ => Nothing

||| Unsafe attribute name creation (use only for known-good literals)
export
unsafeAttrName : String -> AttrName
-- PROOF_TODO: Replace cast with actual proof
-- PROOF_TODO: Replace cast with actual proof
unsafeAttrName s = cast (MkAttrName s)

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

||| Convenience for common w: namespace attributes (OOXML)
export
wAttr : String -> String -> XmlAttr
wAttr n v = attr (unsafeAttrName ("w:" ++ n)) v

||| Example: attribute that would break with raw quotes
export
exampleAttrSafety : XmlAttr
exampleAttrSafety = attr name "value \"with\" quotes"
-- renderAttr exampleAttrSafety == "name=\"value &quot;with&quot; quotes\""
