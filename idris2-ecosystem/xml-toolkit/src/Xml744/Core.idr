-- SPDX-License-Identifier: MIT
-- | XML 7/44 Toolkit - Type-safe XML infiltration and exfiltration
-- |
-- | Named after the infamous "Line 7, Column 44" error that occurs
-- | when you put an unescaped & in XML. This toolkit makes that
-- | error impossible by construction.
-- |
-- | Dedicated to Tim Bray, Jean Paoli, C. M. Sperberg-McQueen, and Eve Maler
-- | who created XML and then presumably went into witness protection.
module Xml744.Core

import public Xml744.Escape
import public Xml744.Text
import public Xml744.Attribute
import public Xml744.Element
import public Xml744.Document

%default total

||| The toolkit version
export
version : String
version = "0.1.0"

||| Why this toolkit exists
export
manifesto : String
manifesto = """
  The XML 7/44 Toolkit exists because XML is surprisingly fragile.

  A single unescaped & character can corrupt an entire document.
  A quote in an attribute value can break parsing.
  These errors are silent at creation time and explosive at parse time.

  This toolkit uses Idris2's type system to make these errors impossible:

  - `infiltrate` safely injects content into XML (auto-escapes)
  - `exfiltrate` safely extracts content from XML (auto-unescapes)
  - `XmlText` type guarantees text is safe for XML
  - `XmlAttr` type guarantees attributes are properly escaped
  - `XmlNode` type ensures well-formed element structure

  The "7/44" in the name refers to a specific error encountered while
  injecting Word comments into DOCX files: a SAXParseException at
  word/comments.xml line 7, column 44, caused by "Barr & Hayne" being
  written without escaping the ampersand.

  With this toolkit, that error cannot occur.
  """

||| Quick example of the problem and solution
export
demonstration : IO ()
demonstration = do
  putStrLn "=== XML 7/44 Toolkit Demonstration ==="
  putStrLn ""
  putStrLn "The dangerous string: \"Barr & Hayne\""
  putStrLn ""
  putStrLn "WITHOUT this toolkit (causes Line 7 Col 44 error):"
  putStrLn "  <w:t>Barr & Hayne</w:t>"
  putStrLn ""
  putStrLn "WITH this toolkit (safe):"
  putStrLn $ "  " ++ render (wText "Barr & Hayne")
  putStrLn ""
  putStrLn "The & is automatically escaped to &amp;"
  putStrLn "7/44 errors are now impossible by construction."
