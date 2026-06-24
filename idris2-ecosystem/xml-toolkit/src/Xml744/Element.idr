-- SPDX-License-Identifier: MPL-2.0
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

||| Try to create a tag name (returns Nothing if invalid).
|||
||| Mirrors `Xml744.Attribute.attrName` — uses `with proof` so the matched
||| branch binds `prf : isValidName s = True` for `MkTagName`'s auto-implicit.
||| Replaces the previous `decEq (isValidName s) True` form (`decEq` for
||| `Bool` is not in scope on Idris2 0.8.0 with the current imports).
export
tagName : (s : String) -> Maybe TagName
tagName s with (isValidName s) proof prf
  tagName s | True  = Just (MkTagName s)
  tagName s | False = Nothing

||| Tag-name constructor for strings whose validity Idris2 can verify at
||| elaboration time. Replaces the previous `cast (MkTagName s)` placeholder,
||| which never compiled. The auto-implicit `isValidName s = True` discharges
||| by `Refl` for any literal.
export
unsafeTagName : (s : String) -> {auto prf : isValidName s = True} -> TagName
unsafeTagName s = MkTagName s

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

||| Create an element. Tag validity is discharged at elaboration time for
||| any literal (or compile-time-reducible) tag string.
export
el : (tag : String) -> {auto prf : isValidName tag = True} ->
     List XmlAttr -> List XmlNode -> XmlNode
el tag attrs children = Element (unsafeTagName tag) attrs children

||| Create a self-closing element.
export
emptyEl : (tag : String) -> {auto prf : isValidName tag = True} ->
          List XmlAttr -> XmlNode
emptyEl tag attrs = EmptyElement (unsafeTagName tag) attrs

-- Render XML node to string. Mutually recursive with `renderList` over
-- `List XmlNode` so Idris2's size-change termination checker sees the
-- structural decrease — the earlier `concatMap render children` opaqued
-- the recursion through a higher-order call and failed totality on
-- Idris2 0.8.0.
mutual
  ||| Render XML node to string.
  export
  render : XmlNode -> String
  render (TextNode t)                       = toXml t
  render (Element tag attrs children)       =
    let attrsStr = if null attrs then "" else " " ++ unwords (map renderAttr attrs)
    in "<" ++ tag.str ++ attrsStr ++ ">" ++
       renderList children ++
       "</" ++ tag.str ++ ">"
  render (EmptyElement tag attrs)           =
    let attrsStr = if null attrs then "" else " " ++ unwords (map renderAttr attrs)
    in "<" ++ tag.str ++ attrsStr ++ "/>"
  render (RawXml s)                         = s

  renderList : List XmlNode -> String
  renderList []        = ""
  renderList (n :: ns) = render n ++ renderList ns

||| Indentation helper used by `renderPretty`.
spaces : Nat -> String
spaces k = pack (replicate k ' ')

-- Render with indentation (pretty print). Mutually recursive with
-- `renderPrettyList` for the same structural-termination reason as
-- `render` / `renderList`. The child-separator semantics match the
-- previous `unlines (map (go (i+2)) children)`: trailing newline after
-- each rendered child.
mutual
  ||| Render XML node with indentation (pretty print).
  export
  renderPretty : (indent : Nat) -> XmlNode -> String
  renderPretty _ (TextNode t)                = toXml t
  renderPretty i (Element tag attrs [])      =
    let attrsStr = if null attrs then "" else " " ++ unwords (map renderAttr attrs)
    in spaces i ++ "<" ++ tag.str ++ attrsStr ++ "></" ++ tag.str ++ ">"
  renderPretty i (Element tag attrs (c :: cs)) =
    let attrsStr    = if null attrs then "" else " " ++ unwords (map renderAttr attrs)
        childrenStr = renderPrettyList (i + 2) (c :: cs)
    in spaces i ++ "<" ++ tag.str ++ attrsStr ++ ">\n" ++
       childrenStr ++ "\n" ++
       spaces i ++ "</" ++ tag.str ++ ">"
  renderPretty i (EmptyElement tag attrs)    =
    let attrsStr = if null attrs then "" else " " ++ unwords (map renderAttr attrs)
    in spaces i ++ "<" ++ tag.str ++ attrsStr ++ "/>"
  renderPretty i (RawXml s)                  = spaces i ++ s

  renderPrettyList : (indent : Nat) -> List XmlNode -> String
  renderPrettyList _ []        = ""
  renderPrettyList i (n :: ns) = renderPretty i n ++ "\n" ++ renderPrettyList i ns

-- OOXML (Word) specific helpers

||| Create w: namespaced element (WordprocessingML). The auto-implicit
||| proof obligation `isValidName ("w:" ++ tag) = True` discharges by
||| `Refl` for any literal `tag`.
export
wEl : (tag : String) ->
      {auto prf : isValidName ("w:" ++ tag) = True} ->
      List XmlAttr -> List XmlNode -> XmlNode
wEl tag = el ("w:" ++ tag)

||| Create w: namespaced empty element
export
wEmptyEl : (tag : String) ->
           {auto prf : isValidName ("w:" ++ tag) = True} ->
           List XmlAttr -> XmlNode
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
