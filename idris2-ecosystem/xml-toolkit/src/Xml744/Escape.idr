-- SPDX-License-Identifier: MPL-2.0
-- | XML Escaping - the first line of defense against 7/44 errors
module Xml744.Escape

import Data.String
import Data.List

%default total

||| Characters that are forbidden raw in XML text content
public export
data XmlDangerous : Char -> Type where
  DangerousAmp  : XmlDangerous '&'
  DangerousLt   : XmlDangerous '<'
  DangerousGt   : XmlDangerous '>'

||| Characters additionally forbidden in attribute values
public export
data AttrDangerous : Char -> Type where
  AttrDangerousQuot : AttrDangerous '"'
  AttrDangerousApos : AttrDangerous '\''
  AttrFromXml       : XmlDangerous c -> AttrDangerous c

||| Escape a single character for XML text content
export
escapeChar : Char -> String
escapeChar '&'  = "&amp;"
escapeChar '<'  = "&lt;"
escapeChar '>'  = "&gt;"
escapeChar c    = singleton c

||| Escape a single character for XML attribute values
export
escapeAttrChar : Char -> String
escapeAttrChar '"'  = "&quot;"
escapeAttrChar '\'' = "&apos;"
escapeAttrChar c    = escapeChar c

||| Infiltrate: safely inject a string into XML text content
||| All dangerous characters are escaped automatically
export
infiltrate : String -> String
infiltrate = concatMap escapeChar . unpack

||| Infiltrate for attributes: escapes quotes too
export
infiltrateAttr : String -> String
infiltrateAttr = concatMap escapeAttrChar . unpack

||| Exfiltrate: safely extract content from XML (unescape entities)
|||
||| The worker `replaceAllChars` recurses on a `Nat` fuel sized to the input.
||| Each step consumes at least one character of the third argument, so the
||| fuel bound is never reached in practice — it exists to make termination
||| structurally obvious to Idris2 without `assert_total` / `assert_smaller`.
export
exfiltrate : String -> String
exfiltrate s =
  let s1 = replaceAll "&amp;" "&" s
      s2 = replaceAll "&lt;" "<" s1
      s3 = replaceAll "&gt;" ">" s2
      s4 = replaceAll "&quot;" "\"" s3
      s5 = replaceAll "&apos;" "'" s4
  in s5
  where
    replaceAllChars : Nat -> List Char -> List Char -> List Char -> List Char
    replaceAllChars _     _         _  []        = []
    replaceAllChars _     []        _  xs        = xs
    replaceAllChars Z     _         _  xs        = xs
    replaceAllChars (S k) (f :: fs) to (x :: xs) =
      if isPrefixOf (f :: fs) (x :: xs)
        then to ++ replaceAllChars k (f :: fs) to (drop (length fs) xs)
        else x :: replaceAllChars k (f :: fs) to xs

    replaceAll : String -> String -> String -> String
    replaceAll from to str =
      let chars = unpack str
      in pack (replaceAllChars (length chars) (unpack from) (unpack to) chars)

||| Check if a string contains any unescaped dangerous characters
export
hasDangerousChars : String -> Bool
hasDangerousChars s = any isDangerous (unpack s)
  where
    isDangerous : Char -> Bool
    isDangerous '&' = True
    isDangerous '<' = True
    isDangerous '>' = True
    isDangerous _   = False

||| Proof that a string has been safely escaped
public export
data SafeXmlText : String -> Type where
  MkSafeXmlText : (raw : String) -> SafeXmlText (infiltrate raw)

||| Create safe XML text from any string
export
makeSafe : (s : String) -> SafeXmlText (infiltrate s)
makeSafe s = MkSafeXmlText s
