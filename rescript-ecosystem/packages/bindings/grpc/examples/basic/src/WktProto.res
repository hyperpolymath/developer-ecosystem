// Generated from wkt.proto by protoc-gen-rescript
// SPDX-License-Identifier: MPL-2.0
// DO NOT EDIT - regenerate from .proto source

// Package: example

module Task = {
  type t = {
    id: string,
    title: string,
    deadline: option<Js.Date.t>,
    estimatedTime: option<float>,
    completed: option<bool>,
  }

  let make = (
    ~id,
    ~title,
    ~deadline=?,
    ~estimatedTime=?,
    ~completed=?
  ): t => {
    id,
    title,
    deadline,
    estimatedTime,
    completed,
  }

  // JSON serialization
  let toJson = (msg: t): Js.Json.t => {
    Json.Encode.object(Json.Encode.fields(
      [
        Json.Encode.required("id", msg.id, Json.Encode.string),
        Json.Encode.required("title", msg.title, Json.Encode.string),
      ],
      [
        Json.Encode.optional("deadline", msg.deadline, WellKnown.Timestamp.toJson),
        Json.Encode.optional("estimated_time", msg.estimatedTime, WellKnown.Duration.toJson),
        Json.Encode.optional("completed", msg.completed, Json.Encode.bool),
      ],
    ))
  }

  // JSON deserialization
  let fromJson = (json: Js.Json.t): option<t> => {
    switch Json.Decode.object(json) {
    | Some(obj) =>
        let id = Json.Decode.required(obj, "id", Json.Decode.string)
        let title = Json.Decode.required(obj, "title", Json.Decode.string)
        let deadline = Json.Decode.optional(obj, "deadline", WellKnown.Timestamp.fromJson)->Result.getOr(None)
        let estimatedTime = Json.Decode.optional(obj, "estimated_time", WellKnown.Duration.fromJson)->Result.getOr(None)
        let completed = Json.Decode.optional(obj, "completed", Json.Decode.bool)->Result.getOr(None)
        switch (id, title) {
        | (Ok(id), Ok(title)) =>
          Some({
            id,
            title,
            deadline,
            estimatedTime,
            completed,
          })
        | _ => None
        }
    | None => None
    }
  }
}


module Metadata = {
  type t = {
    key: string,
    data: option<Js.Dict.t<Js.Json.t>>,
    value: option<Js.Json.t>,
  }

  let make = (
    ~key,
    ~data=?,
    ~value=?
  ): t => {
    key,
    data,
    value,
  }

  // JSON serialization
  let toJson = (msg: t): Js.Json.t => {
    Json.Encode.object(Json.Encode.fields(
      [
        Json.Encode.required("key", msg.key, Json.Encode.string),
      ],
      [
        Json.Encode.optional("data", msg.data, WellKnown.Struct.toJson),
        Json.Encode.optional("value", msg.value, v => v),
      ],
    ))
  }

  // JSON deserialization
  let fromJson = (json: Js.Json.t): option<t> => {
    switch Json.Decode.object(json) {
    | Some(obj) =>
        let key = Json.Decode.required(obj, "key", Json.Decode.string)
        let data = Json.Decode.optional(obj, "data", WellKnown.Struct.fromJson)->Result.getOr(None)
        let value = Json.Decode.optional(obj, "value", json => Some(json))->Result.getOr(None)
        switch (key) {
        | (Ok(key)) =>
          Some({
            key,
            data,
            value,
          })
        | _ => None
        }
    | None => None
    }
  }
}


module AuditLog = {
  type t = {
    id: string,
    action: string,
    createdAt: option<Js.Date.t>,
    duration: option<float>,
    description: option<string>,
    responseCode: option<bigint>,
  }

  let make = (
    ~id,
    ~action,
    ~createdAt=?,
    ~duration=?,
    ~description=?,
    ~responseCode=?
  ): t => {
    id,
    action,
    createdAt,
    duration,
    description,
    responseCode,
  }

  // JSON serialization
  let toJson = (msg: t): Js.Json.t => {
    Json.Encode.object(Json.Encode.fields(
      [
        Json.Encode.required("id", msg.id, Json.Encode.string),
        Json.Encode.required("action", msg.action, Json.Encode.string),
      ],
      [
        Json.Encode.optional("created_at", msg.createdAt, WellKnown.Timestamp.toJson),
        Json.Encode.optional("duration", msg.duration, WellKnown.Duration.toJson),
        Json.Encode.optional("description", msg.description, Json.Encode.string),
        Json.Encode.optional("response_code", msg.responseCode, Json.Encode.int64),
      ],
    ))
  }

  // JSON deserialization
  let fromJson = (json: Js.Json.t): option<t> => {
    switch Json.Decode.object(json) {
    | Some(obj) =>
        let id = Json.Decode.required(obj, "id", Json.Decode.string)
        let action = Json.Decode.required(obj, "action", Json.Decode.string)
        let createdAt = Json.Decode.optional(obj, "created_at", WellKnown.Timestamp.fromJson)->Result.getOr(None)
        let duration = Json.Decode.optional(obj, "duration", WellKnown.Duration.fromJson)->Result.getOr(None)
        let description = Json.Decode.optional(obj, "description", Json.Decode.string)->Result.getOr(None)
        let responseCode = Json.Decode.optional(obj, "response_code", Json.Decode.int64)->Result.getOr(None)
        switch (id, action) {
        | (Ok(id), Ok(action)) =>
          Some({
            id,
            action,
            createdAt,
            duration,
            description,
            responseCode,
          })
        | _ => None
        }
    | None => None
    }
  }
}


