// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// StringPower.res
// A tagged template library for ReScript
// Pure library, zero PPX, works with native tagged template syntax

// ============================================================================
// CORE TYPES
// ============================================================================

// The fundamental building block: a tagged template receives static strings
// and dynamic values separately, enabling DSL construction
type tagged<'value, 'result> = (array<string>, array<'value>) => 'result

// For templates that might fail (SQL injection checks, etc.)
type taggedResult<'value, 'result, 'error> = (array<string>, array<'value>) => result<'result, 'error>

// ============================================================================
// INTERPOLATION VALUE TYPES
// ============================================================================

// Universal interpolation - handles any JS primitive cleanly
type universal =
  | S(string)
  | I(int)
  | F(float)
  | B(bool)
  | N // null/none

// SQL-specific value types with escaping metadata
type sqlValue =
  | Str(string)
  | Int(int)
  | Float(float)
  | Bool(bool)
  | Null
  | Param(string) // Named parameter :name
  | Raw(string) // Unsafe, unescaped (table names, etc.)

// CSS value types
type cssValue =
  | Px(int)
  | Rem(float)
  | Em(float)
  | Pct(float)
  | Color(string)
  | Var(string) // CSS variable reference
  | Raw(string)

// ============================================================================
// CORE UTILITIES
// ============================================================================

module Utils = {
  // Interleave statics and dynamics: ["a", "b", "c"] + [1, 2] => "a1b2c"
  let interleave = (statics: array<string>, dynamics: array<string>): string => {
    let result = ref(statics->RescriptCore.Array.getUnsafe(0))
    for i in 0 to Array.length(dynamics) - 1 {
      result :=
        result.contents ++ dynamics->RescriptCore.Array.getUnsafe(i) ++ statics->RescriptCore.Array.getUnsafe(i + 1)
    }
    result.contents
  }

  // Same but with separator control
  let interleaveWith = (
    statics: array<string>,
    dynamics: array<string>,
    ~before: string="",
    ~after: string="",
  ): string => {
    let result = ref(statics->RescriptCore.Array.getUnsafe(0))
    for i in 0 to Array.length(dynamics) - 1 {
      result :=
        result.contents
        ++ before
        ++ dynamics->RescriptCore.Array.getUnsafe(i)
        ++ after
        ++ statics->RescriptCore.Array.getUnsafe(i + 1)
    }
    result.contents
  }

  // Escape utilities
  let escapeHtml = (s: string): string => {
    s
    ->String.replaceAll("&", "&amp;")
    ->String.replaceAll("<", "&lt;")
    ->String.replaceAll(">", "&gt;")
    ->String.replaceAll("\"", "&quot;")
    ->String.replaceAll("'", "&#39;")
  }

  let escapeSqlString = (s: string): string => {
    s->String.replaceAll("'", "''")
  }
}

// ============================================================================
// STRING INTERPOLATION (fmt)
// ============================================================================

module Fmt = {
  // Basic string formatting with universal values
  let toString = (v: universal): string => {
    switch v {
    | S(s) => s
    | I(i) => Int.toString(i)
    | F(f) => Float.toString(f)
    | B(b) => b ? "true" : "false"
    | N => ""
    }
  }

  // The main fmt tag - simple string interpolation
  let fmt: tagged<universal, string> = (statics, dynamics) => {
    Utils.interleave(statics, dynamics->Array.map(toString))
  }

  // HTML-safe interpolation
  let html: tagged<universal, string> = (statics, dynamics) => {
    Utils.interleave(statics, dynamics->Array.map(v => toString(v)->Utils.escapeHtml))
  }

  // Printf-style with explicit format control
  type formatSpec =
    | Default
    | Precision(int)
    | PadLeft(int, string)
    | PadRight(int, string)
    | Uppercase
    | Lowercase

  let format = (v: universal, spec: formatSpec): string => {
    let base = toString(v)
    switch spec {
    | Default => base
    | Precision(n) =>
      switch v {
      | F(f) => Float.toFixed(f, ~digits=n)
      | _ => base
      }
    | PadLeft(width, char) => String.padStart(base, width, char)
    | PadRight(width, char) => String.padEnd(base, width, char)
    | Uppercase => String.toUpperCase(base)
    | Lowercase => String.toLowerCase(base)
    }
  }
}

// ============================================================================
// SQL TEMPLATES
// ============================================================================

module Sql = {
  type query = {
    text: string,
    params: array<sqlValue>,
  }

  type error =
    | InjectionAttempt(string)
    | InvalidParameterCount

  let valueToString = (v: sqlValue): string => {
    switch v {
    | Str(s) => "'" ++ Utils.escapeSqlString(s) ++ "'"
    | Int(i) => Int.toString(i)
    | Float(f) => Float.toString(f)
    | Bool(b) => b ? "TRUE" : "FALSE"
    | Null => "NULL"
    | Param(name) => ":" ++ name
    | Raw(s) => s
    }
  }

  // Parameterised query builder (PostgreSQL $1, $2 style)
  let parameterized: tagged<sqlValue, query> = (statics, dynamics) => {
    let params = []
    let parts = [statics->RescriptCore.Array.getUnsafe(0)]

    dynamics->Array.forEachWithIndex((value, i) => {
      switch value {
      | Raw(s) => {
          let last = parts->RescriptCore.Array.pop->RescriptCore.Option.getOr("")
          parts->Array.push(last ++ s ++ statics->RescriptCore.Array.getUnsafe(i + 1))->ignore
        }
      | _ => {
          params->Array.push(value)->ignore
          parts->Array.push("$" ++ Int.toString(Array.length(params)))->ignore
          parts->Array.push(statics->RescriptCore.Array.getUnsafe(i + 1))->ignore
        }
      }
    })

    {
      text: parts->Array.join(""),
      params: params,
    }
  }

  // Inline query (values escaped and embedded directly)
  // Use with caution - parameterized is preferred
  let inline: tagged<sqlValue, string> = (statics, dynamics) => {
    Utils.interleave(statics, dynamics->Array.map(valueToString))
  }

  // Safe query builder that checks for obvious injection patterns
  let safe: taggedResult<sqlValue, query, error> = (statics, dynamics) => {
    // Check statics for suspicious patterns that might indicate
    // the user is trying to build dynamic SQL unsafely
    let suspicious =
      statics->Array.some(s =>
        String.includes(s, "--") || String.includes(s, ";") && String.includes(s, "DROP")
      )

    if suspicious {
      Error(InjectionAttempt("Suspicious SQL pattern detected in template"))
    } else {
      Ok(parameterized(statics, dynamics))
    }
  }

  // Helpers for common value wrapping
  let str = (s: string): sqlValue => Str(s)
  let int = (i: int): sqlValue => Int(i)
  let float = (f: float): sqlValue => Float(f)
  let bool = (b: bool): sqlValue => Bool(b)
  let null: sqlValue = Null
  let param = (name: string): sqlValue => Param(name)
  let raw = (s: string): sqlValue => Raw(s)
}

// ============================================================================
// CSS TEMPLATES
// ============================================================================

module Css = {
  let valueToString = (v: cssValue): string => {
    switch v {
    | Px(n) => Int.toString(n) ++ "px"
    | Rem(n) => Float.toString(n) ++ "rem"
    | Em(n) => Float.toString(n) ++ "em"
    | Pct(n) => Float.toString(n) ++ "%"
    | Color(c) => c
    | Var(name) => "var(--" ++ name ++ ")"
    | Raw(s) => s
    }
  }

  // Basic CSS template
  let css: tagged<cssValue, string> = (statics, dynamics) => {
    Utils.interleave(statics, dynamics->Array.map(valueToString))
  }

  // Scoped CSS with unique class name generation
  type scopedCss = {
    className: string,
    styles: string,
  }

  let counter = ref(0)

  let scoped: tagged<cssValue, scopedCss> = (statics, dynamics) => {
    counter := counter.contents + 1
    let className = "sp_" ++ Int.toString(counter.contents)
    let rawCss = Utils.interleave(statics, dynamics->Array.map(valueToString))

    {
      className: className,
      styles: "." ++ className ++ " { " ++ rawCss ++ " }",
    }
  }

  // Value helpers
  let px = (n: int): cssValue => Px(n)
  let rem = (n: float): cssValue => Rem(n)
  let em = (n: float): cssValue => Em(n)
  let pct = (n: float): cssValue => Pct(n)
  let color = (c: string): cssValue => Color(c)
  let var = (name: string): cssValue => Var(name)
  let raw = (s: string): cssValue => Raw(s)
}

// ============================================================================
// REACT ELEMENT INTERPOLATION
// ============================================================================

module React = {
  // For use inside React components - outputs React.element
  type reactValue =
    | Text(string)
    | Int(int)
    | Float(float)
    | Element(Jsx.element)
    | Fragment(array<Jsx.element>)

  let toElement = (v: reactValue): Jsx.element => {
    switch v {
    | Text(s) => React.string(s)
    | Int(i) => React.int(i)
    | Float(f) => React.float(f)
    | Element(e) => e
    | Fragment(arr) => React.array(arr)
    }
  }

  // React-safe interpolation
  let jsx: tagged<reactValue, Jsx.element> = (statics, dynamics) => {
    let children = []
    children->Array.push(React.string(statics->RescriptCore.Array.getUnsafe(0)))->ignore

    dynamics->Array.forEachWithIndex((value, i) => {
      children->Array.push(toElement(value))->ignore
      children->Array.push(React.string(statics->RescriptCore.Array.getUnsafe(i + 1)))->ignore
    })

    React.array(children)
  }

  // Helpers
  let t = s => Text(s)
  let i = n => Int(n)
  let f = n => Float(n)
  let el = e => Element(e)
  let frag = arr => Fragment(arr)
}

// ============================================================================
// i18n TEMPLATES
// ============================================================================

module I18n = {
  // Translation key with interpolation slots
  type translationKey = {
    key: string,
    slots: array<string>,
    defaults: array<string>,
  }

  // Extract a translation key from a template
  // Usage: let greeting = i18n`Hello ${slot("name")}, welcome!`
  type slot = Slot(string)

  let slot = name => Slot(name)

  let i18n: tagged<slot, translationKey> = (statics, dynamics) => {
    let fullTemplate = ref(statics->RescriptCore.Array.getUnsafe(0))
    let slots = []

    dynamics->Array.forEachWithIndex((Slot(name), i) => {
      slots->Array.push(name)->ignore
      fullTemplate :=
        fullTemplate.contents ++ "{" ++ name ++ "}" ++ statics->RescriptCore.Array.getUnsafe(i + 1)
    })

    {
      key: fullTemplate.contents,
      slots: slots,
      defaults: statics,
    }
  }

  // Apply values to a translation
  let apply = (key: translationKey, values: RescriptCore.Dict.t<string>): string => {
    let result = ref(key.defaults->RescriptCore.Array.getUnsafe(0))
    key.slots->Array.forEachWithIndex((slotName, i) => {
      let value =
        values->RescriptCore.Dict.get(slotName)->RescriptCore.Option.getOr("{" ++ slotName ++ "}")
      result := result.contents ++ value ++ key.defaults->RescriptCore.Array.getUnsafe(i + 1)
    })
    result.contents
  }
}

// ============================================================================
// URL/QUERY STRING TEMPLATES
// ============================================================================

module Url = {
  type urlValue =
    | Path(string)
    | Param(string)
    | Query(string, string)

  // URL-encode a string
  @val external encodeURIComponent: string => string = "encodeURIComponent"
  let encode = (s: string): string => encodeURIComponent(s)

  // Build URL with safe encoding
  let url: tagged<urlValue, string> = (statics, dynamics) => {
    Utils.interleave(
      statics,
      dynamics->Array.map(v => {
        switch v {
        | Path(s) => encode(s)
        | Param(s) => encode(s)
        | Query(k, v) => encode(k) ++ "=" ++ encode(v)
        }
      }),
    )
  }

  let path = s => Path(s)
  let param = s => Param(s)
  let query = (k, v) => Query(k, v)
}

// ============================================================================
// GRAPHQL TEMPLATES (document extraction)
// ============================================================================

module Gql = {
  // GraphQL document with operation metadata
  type document = {
    source: string,
    operationName: option<string>,
    variables: array<string>,
  }

  // Extract variable names from a GraphQL template
  let extractVariables = (source: string): array<string> => {
    // Simple regex-free extraction: find $varName patterns
    let vars = []
    let chars = source->String.split("")
    let i = ref(0)
    
    while i.contents < Array.length(chars) {
      if chars->RescriptCore.Array.getUnsafe(i.contents) == "$" {
        let varStart = i.contents + 1
        i := i.contents + 1
        while (
          i.contents < Array.length(chars) && {
            let c = chars->RescriptCore.Array.getUnsafe(i.contents)
            (c >= "a" && c <= "z") ||
              (c >= "A" && c <= "Z") ||
              (c >= "0" && c <= "9") ||
              c == "_"
          }
        ) {
          i := i.contents + 1
        }
        if i.contents > varStart {
          let varName = chars->Array.slice(~start=varStart, ~end=i.contents)->Array.join("")
          if !(vars->Array.includes(varName)) {
            vars->Array.push(varName)->ignore
          }
        }
      } else {
        i := i.contents + 1
      }
    }
    vars
  }

  // Extract operation name from query/mutation
  let extractOperationName = (source: string): option<string> => {
    // Look for "query Name" or "mutation Name"
    let patterns = ["query ", "mutation ", "subscription "]
    patterns->Array.reduce(None, (acc, pattern) => {
      switch acc {
      | Some(_) => acc
      | None =>
        switch String.indexOf(source, pattern) {
        | -1 => None
        | idx => {
            let start = idx + String.length(pattern)
            let rest = String.slice(source, ~start, ~end=String.length(source))
            let endIdx =
              rest
              ->String.split("")
              ->Array.findIndexOpt(c => c == "(" || c == "{" || c == " ")
              ->RescriptCore.Option.getOr(String.length(rest))
            let name = String.slice(rest, ~start=0, ~end=endIdx)->String.trim
            name == "" ? None : Some(name)
          }
        }
      }
    })
  }

  // GraphQL template - no interpolation, just document parsing
  let gql: tagged<unit, document> = (statics, _dynamics) => {
    let source = statics->Array.join("")
    {
      source: source,
      operationName: extractOperationName(source),
      variables: extractVariables(source),
    }
  }
}
