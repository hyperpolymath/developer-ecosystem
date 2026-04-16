// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// StringUnionExamples.res
// Examples of @stringUnion usage - run string-union-gen to generate converters

// ============================================================================
// BASIC USAGE
// ============================================================================

// Simple status enum - generates statusToString, stringToStatus, etc.
@stringUnion
type status = [#pending | #active | #completed | #cancelled]

// ============================================================================
// WITH @as OVERRIDES
// ============================================================================

// HTTP methods - uppercase string representation
@stringUnion
type httpMethod = [
  | #get
  | #post
  | #put
  | #patch
  | #delete
  | #head
  | #options
]

// ============================================================================
// DATABASE ENUM MAPPING
// ============================================================================

// Maps to PostgreSQL enum or CHECK constraint values
@stringUnion
type userRole = [
  | #admin
  | #moderator
  | #member
  | #guest
]

// ============================================================================
// API RESPONSE CODES
// ============================================================================

@stringUnion
type errorCode = [
  | #authFailed
  | #notFound
  | #rateLimited
  | #validationError
  | #internalError
]

// ============================================================================
// UI STATE
// ============================================================================

@stringUnion
type theme = [#light | #dark | #system]

@stringUnion
type buttonSize = [#xs | #sm | #md | #lg | #xl]

@stringUnion
type loadingState = [#idle | #loading | #success | #error]

// ============================================================================
// USAGE WITH GENERATED CODE
// ============================================================================

// After running `string-union-gen`, you can use:
//
// // Convert to string for JSON/API
// let statusStr = Status.statusToString(#active)  // "active"
//
// // Parse from string (safe)
// let maybeStatus = Status.stringToStatus("active")  // Some(#active)
// let invalid = Status.stringToStatus("invalid")     // None
//
// // Parse from string (throws)
// let status = Status.stringToStatusExn("active")    // #active
//
// // Get all possible values
// let allStatuses = Status.allStatusValues           // [#pending, #active, ...]
// let allStrings = Status.allStatusStrings           // ["pending", "active", ...]
//
// // Use with HTTP methods
// let method = HttpMethod.httpMethodToString(#get)   // "GET"
// let parsed = HttpMethod.stringToHttpMethod("POST") // Some(#post)

// ============================================================================
// INTEGRATION WITH StringPower.Sql
// ============================================================================

module UserQueries = {
  open StringPower.Sql

  // Use the generated converter for type-safe SQL
  let findByRole = (role: userRole) => {
    // Assuming UserRole__strings.res is generated
    // let roleStr = UserRole.userRoleToString(role)
    let roleStr = switch role {
      | #admin => "ADMIN"
      | #moderator => "MODERATOR"  
      | #member => "MEMBER"
      | #guest => "GUEST"
    }
    parameterized`SELECT * FROM users WHERE role = ${str(roleStr)}`
  }

  let updateStatus = (userId: int, status: status) => {
    let statusStr = switch status {
      | #pending => "pending"
      | #active => "active"
      | #completed => "completed"
      | #cancelled => "cancelled"
    }
    parameterized`UPDATE users SET status = ${str(statusStr)} WHERE id = ${int(userId)}`
  }
}

// ============================================================================
// INTEGRATION WITH JSON
// ============================================================================

module JsonHelpers = {
  // Parse status from JSON with fallback
  let parseStatus = (json: JSON.t): option<status> => {
    switch JSON.Decode.string(json) {
    | Some("pending") => Some(#pending)
    | Some("active") => Some(#active)
    | Some("completed") => Some(#completed)
    | Some("cancelled") => Some(#cancelled)
    | _ => None
    }
  }

  // After codegen, this becomes:
  // let parseStatus = json => 
  //   json->JSON.Decode.string->Option.flatMap(Status.stringToStatus)
}
