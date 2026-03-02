// Generated from streaming.proto by protoc-gen-rescript
// SPDX-License-Identifier: MPL-2.0
// DO NOT EDIT - regenerate from .proto source

// Package: example

module ChatMessage = {
  type t = {
    id: string,
    sender: string,
    content: string,
    timestamp: bigint,
  }

  let make = (
    ~id,
    ~sender,
    ~content,
    ~timestamp
  ): t => {
    id,
    sender,
    content,
    timestamp,
  }

  // JSON serialization
  let toJson = (msg: t): Js.Json.t => {
    Json.Encode.object(Json.Encode.fields(
      [
        Json.Encode.required("id", msg.id, Json.Encode.string),
        Json.Encode.required("sender", msg.sender, Json.Encode.string),
        Json.Encode.required("content", msg.content, Json.Encode.string),
        Json.Encode.required("timestamp", msg.timestamp, Json.Encode.int64),
      ],
      [
      ],
    ))
  }

  // JSON deserialization
  let fromJson = (json: Js.Json.t): option<t> => {
    switch Json.Decode.object(json) {
    | Some(obj) =>
        let id = Json.Decode.required(obj, "id", Json.Decode.string)
        let sender = Json.Decode.required(obj, "sender", Json.Decode.string)
        let content = Json.Decode.required(obj, "content", Json.Decode.string)
        let timestamp = Json.Decode.required(obj, "timestamp", Json.Decode.int64)
        switch (id, sender, content, timestamp) {
        | (Ok(id), Ok(sender), Ok(content), Ok(timestamp)) =>
          Some({
            id,
            sender,
            content,
            timestamp,
          })
        | _ => None
        }
    | None => None
    }
  }
}


module UploadUsersResponse = {
  type t = {
    uploadedCount: int,
    failedIds: array<string>,
  }

  let make = (
    ~uploadedCount,
    ~failedIds=[]
  ): t => {
    uploadedCount,
    failedIds,
  }

  // JSON serialization
  let toJson = (msg: t): Js.Json.t => {
    Json.Encode.object(Json.Encode.fields(
      [
        Json.Encode.required("uploaded_count", msg.uploadedCount, Json.Encode.int),
      ],
      [
        Json.Encode.repeated("failed_ids", msg.failedIds, Json.Encode.string),
      ],
    ))
  }

  // JSON deserialization
  let fromJson = (json: Js.Json.t): option<t> => {
    switch Json.Decode.object(json) {
    | Some(obj) =>
        let uploadedCount = Json.Decode.required(obj, "uploaded_count", Json.Decode.int)
        let failedIds = Json.Decode.repeated(obj, "failed_ids", Json.Decode.string)->Result.getOr([])
        switch (uploadedCount) {
        | (Ok(uploadedCount)) =>
          Some({
            uploadedCount,
            failedIds,
          })
        | _ => None
        }
    | None => None
    }
  }
}


module GetStreamUserRequest = {
  type t = {
    id: int,
  }

  let make = (
    ~id
  ): t => {
    id,
  }

  // JSON serialization
  let toJson = (msg: t): Js.Json.t => {
    Json.Encode.object(Json.Encode.fields(
      [
        Json.Encode.required("id", msg.id, Json.Encode.int),
      ],
      [
      ],
    ))
  }

  // JSON deserialization
  let fromJson = (json: Js.Json.t): option<t> => {
    switch Json.Decode.object(json) {
    | Some(obj) =>
        let id = Json.Decode.required(obj, "id", Json.Decode.int)
        switch (id) {
        | (Ok(id)) =>
          Some({
            id,
          })
        | _ => None
        }
    | None => None
    }
  }
}


module ListUsersStreamRequest = {
  type t = {
    pageSize: int,
    pageToken: string,
  }

  let make = (
    ~pageSize,
    ~pageToken
  ): t => {
    pageSize,
    pageToken,
  }

  // JSON serialization
  let toJson = (msg: t): Js.Json.t => {
    Json.Encode.object(Json.Encode.fields(
      [
        Json.Encode.required("page_size", msg.pageSize, Json.Encode.int),
        Json.Encode.required("page_token", msg.pageToken, Json.Encode.string),
      ],
      [
      ],
    ))
  }

  // JSON deserialization
  let fromJson = (json: Js.Json.t): option<t> => {
    switch Json.Decode.object(json) {
    | Some(obj) =>
        let pageSize = Json.Decode.required(obj, "page_size", Json.Decode.int)
        let pageToken = Json.Decode.required(obj, "page_token", Json.Decode.string)
        switch (pageSize, pageToken) {
        | (Ok(pageSize), Ok(pageToken)) =>
          Some({
            pageSize,
            pageToken,
          })
        | _ => None
        }
    | None => None
    }
  }
}


module StreamUser = {
  type t = {
    id: int,
    name: string,
    email: string,
  }

  let make = (
    ~id,
    ~name,
    ~email
  ): t => {
    id,
    name,
    email,
  }

  // JSON serialization
  let toJson = (msg: t): Js.Json.t => {
    Json.Encode.object(Json.Encode.fields(
      [
        Json.Encode.required("id", msg.id, Json.Encode.int),
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
        let id = Json.Decode.required(obj, "id", Json.Decode.int)
        let name = Json.Decode.required(obj, "name", Json.Decode.string)
        let email = Json.Decode.required(obj, "email", Json.Decode.string)
        switch (id, name, email) {
        | (Ok(id), Ok(name), Ok(email)) =>
          Some({
            id,
            name,
            email,
          })
        | _ => None
        }
    | None => None
    }
  }
}


module UploadUsersRequest = {
  type t = {
    user: option<StreamUser.t>,
  }

  let make = (
    ~user=?
  ): t => {
    user,
  }

  // JSON serialization
  let toJson = (msg: t): Js.Json.t => {
    Json.Encode.object(Json.Encode.fields(
      [
      ],
      [
        Json.Encode.optional("user", msg.user, StreamUser.toJson),
      ],
    ))
  }

  // JSON deserialization
  let fromJson = (json: Js.Json.t): option<t> => {
    switch Json.Decode.object(json) {
    | Some(obj) =>
        let user = Json.Decode.optional(obj, "user", StreamUser.fromJson)->Result.getOr(None)
        Some({
          user,
        })
    | None => None
    }
  }
}


module UserStreamingServiceClient = {
  // gRPC-web client configuration
  type config = {
    baseUrl: string,
    headers: option<Js.Dict.t<string>>,
  }

  let defaultConfig = {
    baseUrl: "http://localhost:8080",
    headers: None,
  }

  type error =
    | NetworkError(string)
    | GrpcError(int, string)
    | DecodeError(string)

  // Internal fetch helper
  let call = async (
    ~config: config,
    ~method: string,
    ~request: Js.Json.t,
  ): result<Js.Json.t, error> => {
    let url = `${config.baseUrl}/${method}`
    let headers = Js.Dict.fromArray([
      ("Content-Type", "application/json"),
      ("Accept", "application/json"),
    ])
    // Merge custom headers
    switch config.headers {
    | Some(h) => Js.Dict.entries(h)->Array.forEach(((k, v)) => Js.Dict.set(headers, k, v))
    | None => ()
    }

    try {
      let response = await Fetch.fetch(
        url,
        {
          method: #POST,
          headers: Fetch.Headers.fromDict(headers),
          body: Fetch.Body.string(Js.Json.stringify(request)),
        },
      )
      if Fetch.Response.ok(response) {
        let json = await Fetch.Response.json(response)
        Ok(json)
      } else {
        let status = Fetch.Response.status(response)
        let text = await Fetch.Response.text(response)
        Error(GrpcError(status, text))
      }
    } catch {
    | Exn.Error(exn) => Error(NetworkError(Exn.message(exn)->Option.getOr("Unknown error")))
    | _ => Error(NetworkError("Unknown error"))
    }
  }

  // Stream handler for server-streaming RPCs
  type streamHandler<'a> = {
    onMessage: 'a => unit,
    onError: error => unit,
    onComplete: unit => unit,
  }

  // Cancellation handle for streaming RPCs
  type streamCancel = {
    cancel: unit => unit,
  }

  // Internal streaming helper for server-streaming RPCs
  let callStream = (
    ~config: config,
    ~method: string,
    ~request: Js.Json.t,
    ~handler: streamHandler<Js.Json.t>,
  ): streamCancel => {
    let cancelled = ref(false)
    let url = `${config.baseUrl}/${method}`
    let headers = Js.Dict.fromArray([
      ("Content-Type", "application/json"),
      ("Accept", "application/x-ndjson"),
    ])
    switch config.headers {
    | Some(h) => Js.Dict.entries(h)->Array.forEach(((k, v)) => Js.Dict.set(headers, k, v))
    | None => ()
    }

    // Start the streaming request
    let _ = Streaming.fetchNdjson(
      ~url,
      ~method=#POST,
      ~headers,
      ~body=Js.Json.stringify(request),
      ~onMessage=json => {
        if !cancelled.contents {
          handler.onMessage(json)
        }
      },
      ~onError=msg => {
        if !cancelled.contents {
          handler.onError(NetworkError(msg))
        }
      },
      ~onComplete=() => {
        if !cancelled.contents {
          handler.onComplete()
        }
      },
    )

    {cancel: () => cancelled := true}
  }

  // GetUser RPC (unary)
  let getUser = async (
    ~config: config=defaultConfig,
    ~request: GetStreamUserRequest.t,
  ): result<StreamUser.t, error> => {
    let requestJson = GetStreamUserRequest.toJson(request)
    let response = await call(~config, ~method="UserStreamingService/GetUser", ~request=requestJson)
    switch response {
    | Ok(json) =>
      switch StreamUser.fromJson(json) {
      | Some(msg) => Ok(msg)
      | None => Error(DecodeError("Failed to decode response"))
      }
    | Error(e) => Error(e)
    }
  }

  // ListUsersStream RPC (server streaming)
  let listUsersStream = (
    ~config: config=defaultConfig,
    ~request: ListUsersStreamRequest.t,
    ~handler: streamHandler<StreamUser.t>,
  ): streamCancel => {
    let requestJson = ListUsersStreamRequest.toJson(request)
    callStream(
      ~config,
      ~method="UserStreamingService/ListUsersStream",
      ~request=requestJson,
      ~handler={
        onMessage: json => {
          switch StreamUser.fromJson(json) {
          | Some(msg) => handler.onMessage(msg)
          | None => handler.onError(DecodeError("Failed to decode stream message"))
          }
        },
        onError: handler.onError,
        onComplete: handler.onComplete,
      },
    )
  }

  // UploadUsers RPC (client streaming - batch mode)
  let uploadUsers = async (
    ~config: config=defaultConfig,
    ~requests: array<UploadUsersRequest.t>,
  ): result<UploadUsersResponse.t, error> => {
    let requestsJson = Js.Json.array(Array.map(requests, UploadUsersRequest.toJson))
    let response = await call(~config, ~method="UserStreamingService/UploadUsers", ~request=requestsJson)
    switch response {
    | Ok(json) =>
      switch UploadUsersResponse.fromJson(json) {
      | Some(msg) => Ok(msg)
      | None => Error(DecodeError("Failed to decode response"))
      }
    | Error(e) => Error(e)
    }
  }

  // Chat RPC (bidirectional streaming - batch/stream mode)
  let chat = (
    ~config: config=defaultConfig,
    ~requests: array<ChatMessage.t>,
    ~handler: streamHandler<ChatMessage.t>,
  ): streamCancel => {
    let requestsJson = Js.Json.array(Array.map(requests, ChatMessage.toJson))
    callStream(
      ~config,
      ~method="UserStreamingService/Chat",
      ~request=requestsJson,
      ~handler={
        onMessage: json => {
          switch ChatMessage.fromJson(json) {
          | Some(msg) => handler.onMessage(msg)
          | None => handler.onError(DecodeError("Failed to decode stream message"))
          }
        },
        onError: handler.onError,
        onComplete: handler.onComplete,
      },
    )
  }

}

module UserStreamingServiceServer = {
  // Server error types
  type grpcStatus =
    | Ok
    | Cancelled
    | Unknown
    | InvalidArgument
    | DeadlineExceeded
    | NotFound
    | AlreadyExists
    | PermissionDenied
    | ResourceExhausted
    | FailedPrecondition
    | Aborted
    | OutOfRange
    | Unimplemented
    | Internal
    | Unavailable
    | DataLoss
    | Unauthenticated

  let statusToCode = (status: grpcStatus): int => {
    switch status {
    | Ok => 0
    | Cancelled => 1
    | Unknown => 2
    | InvalidArgument => 3
    | DeadlineExceeded => 4
    | NotFound => 5
    | AlreadyExists => 6
    | PermissionDenied => 7
    | ResourceExhausted => 8
    | FailedPrecondition => 9
    | Aborted => 10
    | OutOfRange => 11
    | Unimplemented => 12
    | Internal => 13
    | Unavailable => 14
    | DataLoss => 15
    | Unauthenticated => 16
    }
  }

  // Request context with metadata
  type context = {
    headers: Js.Dict.t<string>,
    metadata: Js.Dict.t<string>,
  }

  type serverError = {
    status: grpcStatus,
    message: string,
  }

  // Stream writer for server-streaming responses
  type streamWriter<'a> = {
    send: 'a => promise<unit>,
    complete: unit => unit,
    error: serverError => unit,
  }

  // Handler type definitions
  type getUserHandler = (~request: GetStreamUserRequest.t, ~context: context) => promise<result<StreamUser.t, serverError>>
  type listUsersStreamHandler = (~request: ListUsersStreamRequest.t, ~context: context, ~writer: streamWriter<StreamUser.t>) => unit
  type uploadUsersHandler = (~requests: array<UploadUsersRequest.t>, ~context: context) => promise<result<UploadUsersResponse.t, serverError>>
  type chatHandler = (~requests: array<ChatMessage.t>, ~context: context, ~writer: streamWriter<ChatMessage.t>) => unit

  // Service implementation type
  type service = {
    getUser: getUserHandler,
    listUsersStream: listUsersStreamHandler,
    uploadUsers: uploadUsersHandler,
    chat: chatHandler,
  }

  // Route method name to handler
  let methodNames = [
    "UserStreamingService/GetUser",
    "UserStreamingService/ListUsersStream",
    "UserStreamingService/UploadUsers",
    "UserStreamingService/Chat",
  ]

  // Handle incoming JSON request
  let handleRequest = async (
    ~service: service,
    ~method: string,
    ~body: Js.Json.t,
    ~context: context,
  ): result<Js.Json.t, serverError> => {
    switch method {
    | "UserStreamingService/GetUser" =>
      switch GetStreamUserRequest.fromJson(body) {
      | Some(request) =>
        let response = await service.getUser(~request, ~context)
        switch response {
        | Ok(msg) => Ok(StreamUser.toJson(msg))
        | Error(e) => Error(e)
        }
      | None => Error({status: InvalidArgument, message: "Failed to decode request"})
      }
    | "UserStreamingService/UploadUsers" =>
      switch Js.Json.decodeArray(body) {
      | Some(arr) =>
        let requests = Array.filterMap(arr, UploadUsersRequest.fromJson)
        let response = await service.uploadUsers(~requests, ~context)
        switch response {
        | Ok(msg) => Ok(UploadUsersResponse.toJson(msg))
        | Error(e) => Error(e)
        }
      | None => Error({status: InvalidArgument, message: "Expected array of requests"})
      }
    | _ => Error({status: Unimplemented, message: "Method not found"})
    }
  }

  // Handle streaming request
  let handleStreamingRequest = (
    ~service: service,
    ~method: string,
    ~body: Js.Json.t,
    ~context: context,
    ~writer: streamWriter<Js.Json.t>,
  ): unit => {
    switch method {
    | "UserStreamingService/ListUsersStream" =>
      let typedWriter: streamWriter<StreamUser.t> = {
        send: async msg => await writer.send(StreamUser.toJson(msg)),
        complete: writer.complete,
        error: writer.error,
      }
      switch ListUsersStreamRequest.fromJson(body) {
      | Some(request) =>
        service.listUsersStream(~request, ~context, ~writer=typedWriter)
      | None => writer.error({status: InvalidArgument, message: "Failed to decode request"})
      }
    | "UserStreamingService/Chat" =>
      let typedWriter: streamWriter<ChatMessage.t> = {
        send: async msg => await writer.send(ChatMessage.toJson(msg)),
        complete: writer.complete,
        error: writer.error,
      }
      switch Js.Json.decodeArray(body) {
      | Some(arr) =>
        let requests = Array.filterMap(arr, ChatMessage.fromJson)
        service.chat(~requests, ~context, ~writer=typedWriter)
      | None => writer.error({status: InvalidArgument, message: "Expected array of requests"})
      }
    | _ => writer.error({status: Unimplemented, message: "Method not found"})
    }
  }

  // Check if method requires streaming response
  let isStreamingMethod = (method: string): bool => {
    switch method {
    | "UserStreamingService/ListUsersStream" => true
    | "UserStreamingService/Chat" => true
    | _ => false
    }
  }
}


