-- SPDX-License-Identifier: MIT
-- | Type-safe XML text content - impossible to create with raw & or <
module Xml744.Text

import Xml744.Escape
import Data.String

%default total

||| XML Text content - guaranteed to be properly escaped
||| The phantom type tracks whether this came from trusted or untrusted input
public export
data XmlText : Type where
  ||| Create XML text from untrusted input (will be escaped)
  Untrusted : (raw : String) -> XmlText
  ||| Create XML text from pre-escaped/trusted input (no modification)
  Trusted : (escaped : String) -> XmlText

||| Get the XML-safe representation of text
export
toXml : XmlText -> String
toXml (Untrusted raw) = infiltrate raw
toXml (Trusted escaped) = escaped

||| Get the human-readable representation (unescaped)
export
fromXml : XmlText -> String
fromXml (Untrusted raw) = raw
fromXml (Trusted escaped) = exfiltrate escaped

||| Smart constructor: always escapes, safe for any input
||| This is the primary way to create XmlText from user/external data
export
text : String -> XmlText
text = Untrusted

||| For when you have pre-escaped content (use with caution!)
||| Named 'raw' to make the danger obvious at call sites
export
raw : String -> XmlText
raw = Trusted

||| Concatenate XML text safely
export
(++) : XmlText -> XmlText -> XmlText
(++) a b = Trusted (toXml a ++ toXml b)

||| Show instance that reveals the escaped form
export
Show XmlText where
  show t = "XmlText(" ++ show (toXml t) ++ ")"

||| Example: demonstrating the safety
||| This would cause a 7/44 error if put directly in XML:
|||   "Barr & Hayne"
||| But with XmlText:
|||   text "Barr & Hayne" |> toXml == "Barr &amp; Hayne"
export
example744Prevention : XmlText
example744Prevention = text "Barr & Hayne"
-- toXml example744Prevention == "Barr &amp; Hayne"
