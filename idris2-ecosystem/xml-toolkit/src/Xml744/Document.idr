-- SPDX-License-Identifier: MIT
-- | XML Document handling - declarations, namespaces, the works
module Xml744.Document

import Xml744.Escape
import Xml744.Text
import Xml744.Attribute
import Xml744.Element
import Data.String

%default total

||| XML Declaration
public export
record XmlDecl where
  constructor MkXmlDecl
  version    : String
  encoding   : String
  standalone : Maybe String

||| Default XML declaration
export
defaultDecl : XmlDecl
defaultDecl = MkXmlDecl "1.0" "UTF-8" (Just "yes")

||| Render XML declaration
export
renderDecl : XmlDecl -> String
renderDecl d =
  let standaloneAttr = maybe "" (\s => " standalone=\"" ++ s ++ "\"") d.standalone
  in "<?xml version=\"" ++ d.version ++ "\" encoding=\"" ++ d.encoding ++ "\"" ++ standaloneAttr ++ "?>"

||| Namespace declaration
public export
record Namespace where
  constructor MkNs
  prefix : String
  uri    : String

||| Common OOXML namespaces
export
nsWordML : Namespace
nsWordML = MkNs "w" "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

export
nsRelationships : Namespace
nsRelationships = MkNs "r" "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

export
nsMarkupCompat : Namespace
nsMarkupCompat = MkNs "mc" "http://schemas.openxmlformats.org/markup-compatibility/2006"

||| Render namespace as attribute
export
renderNs : Namespace -> String
renderNs ns = "xmlns:" ++ ns.prefix ++ "=\"" ++ ns.uri ++ "\""

||| Full XML document
public export
record XmlDocument where
  constructor MkDoc
  declaration : XmlDecl
  root        : XmlNode

||| Create a document with default declaration
export
document : XmlNode -> XmlDocument
document = MkDoc defaultDecl

||| Render full document
export
renderDocument : XmlDocument -> String
renderDocument doc = renderDecl doc.declaration ++ "\n" ++ render doc.root

-- OOXML Word Comments helper

||| Build a Word comment element
||| Automatically escapes the comment text!
export
wordComment : (id : String) -> (author : String) -> (date : String) -> (initials : String) -> (commentText : String) -> XmlNode
wordComment cid author date initials content =
  wEl "comment"
    [ wAttr "id" cid
    , wAttr "author" author
    , wAttr "date" date
    , wAttr "initials" initials
    ]
    [ wPara [wText content] ]  -- content is automatically escaped by wText!

||| Build a Word comments.xml document
export
wordCommentsDoc : List XmlNode -> XmlDocument
wordCommentsDoc comments =
  let root = el "w:comments"
               [ attr (unsafeAttrName "xmlns:w") "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
               , attr (unsafeAttrName "xmlns:r") "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
               ]
               comments
  in MkDoc defaultDecl root

||| Example: creating the comment that caused our 7/44 error
||| Note how the & in "Barr & Hayne" is automatically escaped!
export
exampleComment : XmlDocument
exampleComment =
  wordCommentsDoc
    [ wordComment "0" "Jonathan Jewell" "2026-01-06T02:00:00Z" "JJ"
        "This should be 'Barr & Hayne' - check your spelling of researcher names."
        -- The & is automatically escaped to &amp; - no 7/44 error possible!
    ]
