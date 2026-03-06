// Generated from event.proto by protoc-gen-rescript
// SPDX-License-Identifier: MPL-2.0
// DO NOT EDIT - regenerate from .proto source

// Package: example

module UserCreated = {
  type t = {
    userId: string,
    name: string,
    email: string,
  }

  let make = (
    ~userId,
    ~name,
    ~email
  ): t => {
    userId,
    name,
    email,
  }

  // JSON serialization
  let toJson = (msg: t): Js.Json.t => {
    Json.Encode.object(Json.Encode.fields(
      [
        Json.Encode.required("user_id", msg.userId, Json.Encode.string),
        Json.Encode.required("name", msg.name, Json.Encode.string),
        Json.Encode.required("email", msg.email, Json.Encode.string),
      ],
      [
      ],
    ))
  }

  // JSON deserialization
  let fromJson = (json: Js.Json.t): option<t> => {
    switch Json.Decode.object(json) {
    | Some(obj) =>
        let userId = Json.Decode.required(obj, "user_id", Json.Decode.string)
        let name = Json.Decode.required(obj, "name", Json.Decode.string)
        let email = Json.Decode.required(obj, "email", Json.Decode.string)
        switch (userId, name, email) {
        | (Ok(userId), Ok(name), Ok(email)) =>
          Some({
            userId,
            name,
            email,
          })
        | _ => None
        }
    | None => None
    }
  }
}


module UserUpdated = {
  type t = {
    userId: string,
    name: option<string>,
    email: option<string>,
  }

  let make = (
    ~userId,
    ~name=?,
    ~email=?
  ): t => {
    userId,
    name,
    email,
  }

  // JSON serialization
  let toJson = (msg: t): Js.Json.t => {
    Json.Encode.object(Json.Encode.fields(
      [
        Json.Encode.required("user_id", msg.userId, Json.Encode.string),
      ],
      [
        Json.Encode.optional("name", msg.name, Json.Encode.string),
        Json.Encode.optional("email", msg.email, Json.Encode.string),
      ],
    ))
  }

  // JSON deserialization
  let fromJson = (json: Js.Json.t): option<t> => {
    switch Json.Decode.object(json) {
    | Some(obj) =>
        let userId = Json.Decode.required(obj, "user_id", Json.Decode.string)
        let name = Json.Decode.optional(obj, "name", Json.Decode.string)->Result.getOr(None)
        let email = Json.Decode.optional(obj, "email", Json.Decode.string)->Result.getOr(None)
        switch (userId) {
        | (Ok(userId)) =>
          Some({
            userId,
            name,
            email,
          })
        | _ => None
        }
    | None => None
    }
  }
}


module UserDeleted = {
  type t = {
    userId: string,
    reason: string,
  }

  let make = (
    ~userId,
    ~reason
  ): t => {
    userId,
    reason,
  }

  // JSON serialization
  let toJson = (msg: t): Js.Json.t => {
    Json.Encode.object(Json.Encode.fields(
      [
        Json.Encode.required("user_id", msg.userId, Json.Encode.string),
        Json.Encode.required("reason", msg.reason, Json.Encode.string),
      ],
      [
      ],
    ))
  }

  // JSON deserialization
  let fromJson = (json: Js.Json.t): option<t> => {
    switch Json.Decode.object(json) {
    | Some(obj) =>
        let userId = Json.Decode.required(obj, "user_id", Json.Decode.string)
        let reason = Json.Decode.required(obj, "reason", Json.Decode.string)
        switch (userId, reason) {
        | (Ok(userId), Ok(reason)) =>
          Some({
            userId,
            reason,
          })
        | _ => None
        }
    | None => None
    }
  }
}


module Event = {
  type payload =
    | UserCreated(UserCreated.t)
    | UserUpdated(UserUpdated.t)
    | UserDeleted(UserDeleted.t)

  type t = {
    id: string,
    timestamp: bigint,
    payload: option<payload>,
  }

  let make = (
    ~id,
    ~timestamp,
    ~payload=?
  ): t => {
    id,
    timestamp,
    payload,
  }

  // JSON serialization
  let toJson = (msg: t): Js.Json.t => {
    let payloadFields: array<(string, Js.Json.t)> = switch msg.payload {
    | None => []
    | Some(UserCreated(v)) => [("user_created", UserCreated.toJson(v))]
    | Some(UserUpdated(v)) => [("user_updated", UserUpdated.toJson(v))]
    | Some(UserDeleted(v)) => [("user_deleted", UserDeleted.toJson(v))]
    }
    Json.Encode.object(Json.Encode.fields(
      [
        Json.Encode.required("id", msg.id, Json.Encode.string),
        Json.Encode.required("timestamp", msg.timestamp, Json.Encode.int64),
      ],
      [
        payloadFields,
      ],
    ))
  }

  // JSON deserialization
  let fromJson = (json: Js.Json.t): option<t> => {
    switch Json.Decode.object(json) {
    | Some(obj) =>
        let id = Json.Decode.required(obj, "id", Json.Decode.string)
        let timestamp = Json.Decode.required(obj, "timestamp", Json.Decode.int64)
        let payload = {
          switch Json.Decode.optional(obj, "user_created", UserCreated.fromJson) {
            | Ok(Some(v)) => Some(UserCreated(v))
            | Error(_) => None
          | Ok(None) =>
            switch Json.Decode.optional(obj, "user_updated", UserUpdated.fromJson) {
            | Ok(Some(v)) => Some(UserUpdated(v))
            | Error(_) => None
          | Ok(None) =>
            switch Json.Decode.optional(obj, "user_deleted", UserDeleted.fromJson) {
            | Ok(Some(v)) => Some(UserDeleted(v))
            | Error(_) => None
            | Ok(None) => None
            }
            }
            }
        }
        switch (id, timestamp) {
        | (Ok(id), Ok(timestamp)) =>
          Some({
            id,
            timestamp,
            payload,
          })
        | _ => None
        }
    | None => None
    }
  }
}


