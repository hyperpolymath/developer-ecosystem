// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Examples.res
// Demonstration of StringPower tagged template usage

open StringPower

// ============================================================================
// BASIC STRING FORMATTING
// ============================================================================

module FmtExamples = {
  open Fmt

  // Simple interpolation with type safety
  let greeting = (name: string, age: int) => {
    fmt`Hello ${S(name)}, you are ${I(age)} years old!`
  }

  // HTML-safe output (XSS protection)
  let userBio = (name: string, bio: string) => {
    html`<div class="user">
      <h1>${S(name)}</h1>
      <p>${S(bio)}</p>
    </div>`
  }

  // With formatting control
  let invoice = (item: string, price: float, qty: int) => {
    let formattedPrice = format(F(price), Precision(2))
    let total = format(F(price *. Int.toFloat(qty)), Precision(2))
    fmt`${S(item)} x ${I(qty)} @ £${S(formattedPrice)} = £${S(total)}`
  }
}

// ============================================================================
// SQL QUERIES
// ============================================================================

module SqlExamples = {
  open Sql

  // Parameterised query (safe, preferred)
  let findUserById = (userId: int) => {
    parameterized`SELECT * FROM users WHERE id = ${Sql.int(userId)}`
    // Returns: { text: "SELECT * FROM users WHERE id = $1", params: [Int(42)] }
  }

  // Multiple parameters
  let searchUsers = (name: string, minAge: int, maxAge: int) => {
    parameterized`
      SELECT id, name, email 
      FROM users 
      WHERE name ILIKE ${Sql.str("%" ++ name ++ "%")}
        AND age BETWEEN ${Sql.int(minAge)} AND ${Sql.int(maxAge)}
      ORDER BY created_at DESC
    `
  }

  // With raw table name (careful!)
  let findInTable = (tableName: string, id: int) => {
    parameterized`SELECT * FROM ${Sql.raw(tableName)} WHERE id = ${Sql.int(id)}`
  }

  // Named parameters (for libraries that support :name style)
  let namedParams = (_userId: int) => {
    inline`SELECT * FROM users WHERE id = ${Sql.param("userId")}`
    // Returns: "SELECT * FROM users WHERE id = :userId"
  }

  // Safe builder with injection checking
  let safeQuery = (email: string) => {
    switch safe`SELECT * FROM users WHERE email = ${Sql.str(email)}` {
    | Ok(query) => Some(query)
    | Error(InjectionAttempt(msg)) => {
        Console.error("Security: " ++ msg)
        None
      }
    | Error(InvalidParameterCount) => None
    }
  }
}

// ============================================================================
// CSS STYLING
// ============================================================================

module CssExamples = {
  open Css

  // Dynamic CSS values
  let button = (bgColor: string, padding: int) => {
    css`
      background: ${color(bgColor)};
      padding: ${px(padding)};
      border-radius: ${px(4)};
      font-size: ${rem(1.0)};
    `
  }

  // Using CSS variables
  let themed = (spacing: float) => {
    css`
      color: ${var("text-primary")};
      background: ${var("bg-surface")};
      padding: ${rem(spacing)};
      margin-bottom: ${em(1.5)};
    `
  }

  // Scoped styles (generates unique class name)
  let card = () => {
    let styles = scoped`
      display: flex;
      flex-direction: column;
      padding: ${px(16)};
      border: ${raw("1px solid")} ${var("border-color")};
      border-radius: ${px(8)};
    `
    // Returns: { className: "sp_1", styles: ".sp_1 { ... }" }
    styles
  }

  // Responsive values
  let container = (maxWidth: int) => {
    css`
      width: ${pct(100.0)};
      max-width: ${px(maxWidth)};
      margin: ${raw("0 auto")};
    `
  }
}

// ============================================================================
// REACT COMPONENTS
// ============================================================================

module ReactExamples = {
  open StringPower.React

  // Text with inline elements
  let welcomeMessage = (name: string, notificationCount: int) => {
    jsx`Welcome back, ${t(name)}! You have ${i(notificationCount)} new messages.`
  }

  // With React elements embedded
  let richText = (username: string, link: Jsx.element) => {
    jsx`Hello ${t(username)}, click ${el(link)} to continue.`
  }

  // Component-friendly helper content
  let greetingContent = (~name: string, ~items: int) => {
    jsx`Dear ${t(name)}, you have ${i(items)} items in your cart.`
  }
}

// ============================================================================
// INTERNATIONALISATION
// ============================================================================

module I18nExamples = {
  open I18n

  // Define translation keys with slots
  let greetingKey = i18n`Hello ${slot("name")}, welcome to ${slot("appName")}!`
  // Returns: { key: "Hello {name}, welcome to {appName}!", slots: ["name", "appName"], ... }

  let itemCountKey = i18n`You have ${slot("count")} items in your ${slot("location")}.`

  // Apply translations
  let greetUser = (name: string) => {
    apply(greetingKey, Dict.fromArray([("name", name), ("appName", "MyApp")]))
  }

  // In a real app, you'd look up the key in a translation table:
  // let translations = loadTranslations("fr")
  // let translated = translations->Dict.get(greetingKey.key)->Option.getOr(greetingKey.key)
  // then apply the slots
}

// ============================================================================
// URL BUILDING
// ============================================================================

module UrlExamples = {
  open Url

  // Safe URL construction with encoding
  let userProfile = (userId: string) => {
    url`/users/${path(userId)}/profile`
  }

  // With query parameters
  let search = (searchTerm: string, page: int) => {
    url`/search?${Url.query("q", searchTerm)}&${Url.query("page", Int.toString(page))}`
  }

  // API endpoint
  let apiEndpoint = (resource: string, id: string, format: string) => {
    url`/api/v1/${path(resource)}/${path(id)}.${param(format)}`
  }
}

// ============================================================================
// GRAPHQL
// ============================================================================

module GqlExamples = {
  open Gql

  // Extract document metadata
  let findUserQuery = gql`
    query FindUser($id: ID!, $includeProfile: Boolean!) {
      user(id: $id) {
        id
        name
        email
        profile @include(if: $includeProfile) {
          avatar
          bio
        }
      }
    }
  `
  // Returns: {
  //   source: "query FindUser...",
  //   operationName: Some("FindUser"),
  //   variables: ["id", "includeProfile"]
  // }

  let createPostMutation = gql`
    mutation CreatePost($title: String!, $content: String!, $authorId: ID!) {
      createPost(input: { title: $title, content: $content, authorId: $authorId }) {
        id
        title
        createdAt
      }
    }
  `

  // Use the extracted metadata
  let logQuery = (doc: document) => {
    switch doc.operationName {
    | Some(name) => Console.log("Executing: " ++ name)
    | None => Console.log("Executing anonymous operation")
    }
    Console.log("Variables: " ++ doc.variables->Array.join(", "))
  }
}

// ============================================================================
// COMPOSITION PATTERNS
// ============================================================================

module CompositionExamples = {
  // Build your own DSL-specific tag
  module Markdown = {
    type mdValue =
      | Text(string)
      | Bold(string)
      | Italic(string)
      | Code(string)
      | Link(string, string)

    let toString = v =>
      switch v {
      | Text(s) => s
      | Bold(s) => "**" ++ s ++ "**"
      | Italic(s) => "*" ++ s ++ "*"
      | Code(s) => "`" ++ s ++ "`"
      | Link(text, url) => "[" ++ text ++ "](" ++ url ++ ")"
      }

    let md: StringPower.tagged<mdValue, string> = (statics, dynamics) => {
      Utils.interleave(statics, dynamics->Array.map(toString))
    }

    // Helpers
    let t = s => Text(s)
    let b = s => Bold(s)
    let i = s => Italic(s)
    let c = s => Code(s)
    let link = (text, url) => Link(text, url)
  }

  // Usage
  let readme = () => {
    open Markdown
    md`# Project Name

This is a ${b("fantastic")} project written in ${c("ReScript")}.

Check out the ${link("documentation", "https://example.com/docs")} for more info.

Key features:
- ${i("Type-safe")} string handling
- ${b("Zero PPX")} required
- Works with ${c("ReScript v13")}
`
  }
}
