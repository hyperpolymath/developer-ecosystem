-- SPDX-License-Identifier: MIT
-- | Type-safe XML elements - properly nested, properly escaped
module Xml744.Element

import Xml744.Escape
import Xml744.Text
import Xml744.Attribute
import Data.String
import Data.List

%default total

||| XML Element tag name (same rules as attribute names)
public export
data TagName : Type where
  MkTagName : (n : String) -> {auto prf : isValidName n = True} -> TagName

export
tagName : String -> Maybe TagName
tagName s = case decEq (isValidName s) True of
  Yes prf => Just (MkTagName s)
  No _ => Nothing

export
unsafeTagName : String -> TagName
-- PROOF_TODO: Replace cast with actual proof
-- PROOF_TODO: Replace cast with actual proof
unsafeTagName s = cast (MkTagName s)

||| Get the string representation of a tag name
export
(.str) : TagName -> String
(.str) (MkTagName n) = n

||| XML Node - either an element or text
public export
data XmlNode : Type where
  ||| Text content (automatically escaped)
  TextNode : XmlText -> XmlNode
  ||| Element with tag, attributes, and children
  Element : (tag : TagName) -> (attrs : List XmlAttr) -> (children : List XmlNode) -> XmlNode
  ||| Self-closing element (no children)
  EmptyElement : (tag : TagName) -> (attrs : List XmlAttr) -> XmlNode
  ||| Raw XML (use with extreme caution - no escaping!)
  RawXml : String -> XmlNode

||| Create a text node from untrusted input
export
txt : String -> XmlNode
txt s = TextNode (text s)

||| Create an element
export
el : String -> List XmlAttr -> List XmlNode -> XmlNode
el tag attrs children = Element (unsafeTagName tag) attrs children

||| Create a self-closing element
export
emptyEl : String -> List XmlAttr -> XmlNode
emptyEl tag attrs = EmptyElement (unsafeTagName tag) attrs

||| Render XML node to string
export
render : XmlNode -> String
render (TextNode t) = toXml t
render (Element tag attrs children) =
  let attrsStr = if null attrs then "" else " " ++ unwords (map renderAttr attrs)
      childrenStr = concatMap render children
  in "<" ++ tag.str ++ attrsStr ++ ">" ++ childrenStr ++ "</" ++ tag.str ++ ">"
render (EmptyElement tag attrs) =
  let attrsStr = if null attrs then "" else " " ++ unwords (map renderAttr attrs)
  in "<" ++ tag.str ++ attrsStr ++ "/>"
render (RawXml s) = s

||| Render with indentation (pretty print)
export
renderPretty : (indent : Nat) -> XmlNode -> String
renderPretty n node = go n node
  where
    spaces : Nat -> String
    spaces k = pack (replicate k ' ')

    go : Nat -> XmlNode -> String
    go i (TextNode t) = toXml t
    go i (Element tag attrs []) =
      let attrsStr = if null attrs then "" else " " ++ unwords (map renderAttr attrs)
      in spaces i ++ "<" ++ tag.str ++ attrsStr ++ "></" ++ tag.str ++ ">"
    go i (Element tag attrs children) =
      let attrsStr = if null attrs then "" else " " ++ unwords (map renderAttr attrs)
          childrenStr = unlines (map (go (i + 2)) children)
      in spaces i ++ "<" ++ tag.str ++ attrsStr ++ ">\n" ++ childrenStr ++ "\n" ++ spaces i ++ "</" ++ tag.str ++ ">"
    go i (EmptyElement tag attrs) =
      let attrsStr = if null attrs then "" else " " ++ unwords (map renderAttr attrs)
      in spaces i ++ "<" ++ tag.str ++ attrsStr ++ "/>"
    go i (RawXml s) = spaces i ++ s

-- OOXML (Word) specific helpers

||| Create w: namespaced element (WordprocessingML)
export
wEl : String -> List XmlAttr -> List XmlNode -> XmlNode
wEl tag = el ("w:" ++ tag)

||| Create w: namespaced empty element
export
wEmptyEl : String -> List XmlAttr -> XmlNode
wEmptyEl tag = emptyEl ("w:" ++ tag)

||| Word text run: <w:r><w:t>content</w:t></w:r>
export
wText : String -> XmlNode
wText content = wEl "r" [] [wEl "t" [] [txt content]]

||| Word paragraph: <w:p>...children...</w:p>
export
wPara : List XmlNode -> XmlNode
wPara = wEl "p" []

||| Word comment reference
export
wCommentRef : String -> XmlNode
wCommentRef commentId = wEl "r" [] [wEmptyEl "commentReference" [wAttr "id" commentId]]

||| Word comment range start
export
wCommentStart : String -> XmlNode
wCommentStart commentId = wEmptyEl "commentRangeStart" [wAttr "id" commentId]

||| Word comment range end
export
wCommentEnd : String -> XmlNode
wCommentEnd commentId = wEmptyEl "commentRangeEnd" [wAttr "id" commentId]
