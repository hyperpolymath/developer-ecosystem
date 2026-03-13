-- SPDX-License-Identifier: MIT
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
    replaceAll : String -> String -> String -> String
    replaceAll from to str =
      case break (== (assert_total $ strHead from)) (unpack str) of
        (before, []) => str
        (before, rest) =>
          if isPrefixOf (unpack from) rest
            then pack before ++ to ++ replaceAll from to (pack $ drop (length from) rest)
            else pack before ++ singleton (assert_total $ head rest) ++
                 replaceAll from to (pack $ assert_total $ tail rest)

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
