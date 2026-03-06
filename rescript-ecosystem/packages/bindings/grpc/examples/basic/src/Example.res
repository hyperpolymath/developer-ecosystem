// SPDX-License-Identifier: MPL-2.0
// Example usage of generated protobuf types

open UserProto
open EventProto
open WktProto

// Create a user with the generated make function
// Required fields must be provided, optional fields use ~field=?
let alice = User.make(
  ~name="Alice",
  ~id=1,
  ~email="alice@example.com",  // optional field
  ~status=#StatusActive,
  ~tags=["admin", "developer"],
  ~address=Address.make(
    ~street="123 Main St",
    ~city="San Francisco",
    ~country="USA",
    ~postalCode="94102",  // optional field
  ),
)

// User without optional fields
let bob = User.make(
  ~name="Bob",
  ~id=2,
  ~status=#StatusInactive,
)

// Create a request (required field)
let request = GetUserRequest.make(~id=1)

// Create a list response
let response = ListUsersResponse.make(
  ~users=[alice, bob],
  ~nextPageToken="abc123",
)

// Convert enum to int
let statusCode = Status.toInt(#StatusActive) // 1

// Convert int to enum
let status = Status.fromInt(1) // Some(#StatusActive)

// Test oneof with Event type
let testOneOf = () => {
  Console.log("\n=== OneOf Tests ===")

  // Create event with UserCreated payload
  let createEvent = Event.make(
    ~id="evt-001",
    ~timestamp=1704067200000n,
    ~payload=Event.UserCreated(
      UserCreated.make(~userId="usr-123", ~name="Alice", ~email="alice@example.com"),
    ),
  )

  // Create event with UserUpdated payload
  let updateEvent = Event.make(
    ~id="evt-002",
    ~timestamp=1704067300000n,
    ~payload=Event.UserUpdated(UserUpdated.make(~userId="usr-123", ~name="Alice Smith")),
  )

  // Create event with UserDeleted payload
  let deleteEvent = Event.make(
    ~id="evt-003",
    ~timestamp=1704067400000n,
    ~payload=Event.UserDeleted(UserDeleted.make(~userId="usr-123", ~reason="Account closed")),
  )

  // Encode to JSON and back
  let createJson = Event.toJson(createEvent)
  Console.log("UserCreated event JSON:")
  Console.log(Js.Json.stringify(createJson))

  switch Event.fromJson(createJson) {
  | Some(decoded) =>
    switch decoded.payload {
    | Some(Event.UserCreated(data)) =>
      Console.log2("Decoded UserCreated:", data.name)
      Console.log("OneOf round-trip successful!")
    | _ => Console.error("Wrong payload type decoded")
    }
  | None => Console.error("Failed to decode event")
  }

  // Test update event
  let updateJson = Event.toJson(updateEvent)
  Console.log("\nUserUpdated event JSON:")
  Console.log(Js.Json.stringify(updateJson))

  // Test delete event
  let deleteJson = Event.toJson(deleteEvent)
  Console.log("\nUserDeleted event JSON:")
  Console.log(Js.Json.stringify(deleteJson))
}

// Test JSON encode/decode round-trip
let testJsonCodec = () => {
  // Encode alice to JSON
  let aliceJson = User.toJson(alice)
  Console.log("Alice as JSON:")
  Console.log(Js.Json.stringify(aliceJson))

  // Decode back
  switch User.fromJson(aliceJson) {
  | Some(decoded) =>
    Console.log("Decoded user:")
    Console.log(decoded)
    // Verify fields match
    if decoded.name == alice.name && decoded.id == alice.id {
      Console.log("Round-trip successful!")
    } else {
      Console.error("Round-trip failed: fields don't match")
    }
  | None =>
    Console.error("Failed to decode JSON")
  }
}

// Test well-known types
let testWellKnownTypes = () => {
  Console.log("\n=== Well-Known Types Tests ===")

  // Create audit log with Timestamp and Duration
  let now = Js.Date.make()
  let log = AuditLog.make(
    ~id="audit-001",
    ~action="user.login",
    ~createdAt=now,
    ~duration=1.5,                // 1.5 seconds
    ~description="User logged in",
    ~responseCode=200n,
  )

  let logJson = AuditLog.toJson(log)
  Console.log("AuditLog JSON:")
  Console.log(Js.Json.stringify(logJson))

  switch AuditLog.fromJson(logJson) {
  | Some(decoded) =>
    Console.log2("Decoded action:", decoded.action)
    Console.log("Well-known types round-trip successful!")
  | None => Console.error("Failed to decode AuditLog")
  }

  // Create task with deadline
  let deadline = Js.Date.fromString("2025-12-31T23:59:59Z")
  let task = Task.make(
    ~id="task-001",
    ~title="Complete roadmap",
    ~deadline,
    ~estimatedTime=3600.0,  // 1 hour
    ~completed=false,
  )

  let taskJson = Task.toJson(task)
  Console.log("\nTask JSON:")
  Console.log(Js.Json.stringify(taskJson))

  // Create metadata with Struct
  let metadata = Metadata.make(
    ~key="config",
    ~data={
      let d = Js.Dict.empty()
      Js.Dict.set(d, "version", Js.Json.string("1.0"))
      Js.Dict.set(d, "enabled", Js.Json.boolean(true))
      d
    },
    ~value=Js.Json.array([Js.Json.string("a"), Js.Json.string("b")]),
  )

  let metaJson = Metadata.toJson(metadata)
  Console.log("\nMetadata JSON:")
  Console.log(Js.Json.stringify(metaJson))
}

// Test streaming API types (compile-time verification)
let testStreamingAPI = () => {
  Console.log("\n=== Streaming API Tests ===")

  open StreamingProto

  // Create streaming request types
  let listRequest = ListUsersStreamRequest.make(~pageSize=10, ~pageToken="")
  Console.log2("ListUsersStreamRequest:", Js.Json.stringify(ListUsersStreamRequest.toJson(listRequest)))

  // Create a stream user
  let user = StreamUser.make(~id=1, ~name="Test User", ~email="test@example.com")
  Console.log2("StreamUser:", Js.Json.stringify(StreamUser.toJson(user)))

  // Create upload request
  let uploadReq = UploadUsersRequest.make(~user)
  Console.log2("UploadUsersRequest:", Js.Json.stringify(UploadUsersRequest.toJson(uploadReq)))

  // Create chat message
  let msg = ChatMessage.make(~id="msg-001", ~sender="alice", ~content="Hello!", ~timestamp=1704067200000n)
  Console.log2("ChatMessage:", Js.Json.stringify(ChatMessage.toJson(msg)))

  // Demonstrate streaming service config types
  Console.log("\nStreaming service types available:")
  Console.log("- UserStreamingServiceClient.config (base URL, headers)")
  Console.log("- UserStreamingServiceClient.streamHandler<'a> (onMessage, onError, onComplete)")
  Console.log("- UserStreamingServiceClient.streamCancel (cancel function)")

  // These would be called with a real server:
  // - UserStreamingServiceClient.getUser(~request) - unary RPC
  // - UserStreamingServiceClient.listUsersStream(~request, ~handler) - server streaming
  // - UserStreamingServiceClient.uploadUsers(~requests) - client streaming (batch)
  // - UserStreamingServiceClient.chat(~requests, ~handler) - bidirectional
  Console.log("Streaming client API types verified!")
}

// Test server-side handler types (compile-time verification)
let testServerHandlers = () => {
  Console.log("\n=== Server Handler Tests ===")

  open StreamingProto

  // Demonstrate server handler types
  Console.log("Server handler types:")
  Console.log("- UserStreamingServiceServer.grpcStatus (OK, NotFound, Internal, ...)")
  Console.log("- UserStreamingServiceServer.context (headers, metadata)")
  Console.log("- UserStreamingServiceServer.serverError (status, message)")
  Console.log("- UserStreamingServiceServer.streamWriter<'a> (send, complete, error)")
  Console.log("- UserStreamingServiceServer.service (all handlers)")

  // Test status code conversion
  let statusCode = UserStreamingServiceServer.statusToCode(NotFound)
  Console.log2("NotFound status code:", statusCode)

  // Test isStreamingMethod
  Console.log2("IsStreaming GetUser:", UserStreamingServiceServer.isStreamingMethod("UserStreamingService/GetUser"))
  Console.log2("IsStreaming ListUsersStream:", UserStreamingServiceServer.isStreamingMethod("UserStreamingService/ListUsersStream"))

  // List available methods
  Console.log2("Available methods:", UserStreamingServiceServer.methodNames)

  // Example server implementation (type-only, doesn't run)
  let _exampleService: UserStreamingServiceServer.service = {
    getUser: async (~request, ~context as _) => {
      // Look up user by ID
      if request.id == 1 {
        Ok(StreamUser.make(~id=1, ~name="Alice", ~email="alice@example.com"))
      } else {
        let err: UserStreamingServiceServer.serverError = {status: NotFound, message: "User not found"}
        Error(err)
      }
    },
    listUsersStream: (~request as _, ~context as _, ~writer) => {
      // Stream multiple users
      let _ = writer.send(StreamUser.make(~id=1, ~name="Alice", ~email="alice@example.com"))
      let _ = writer.send(StreamUser.make(~id=2, ~name="Bob", ~email="bob@example.com"))
      writer.complete()
    },
    uploadUsers: async (~requests, ~context as _) => {
      // Process uploaded users
      Ok(UploadUsersResponse.make(~uploadedCount=Array.length(requests)))
    },
    chat: (~requests as _, ~context as _, ~writer) => {
      // Echo chat messages
      let _ = writer.send(ChatMessage.make(~id="echo-1", ~sender="server", ~content="Hello!", ~timestamp=0n))
      writer.complete()
    },
  }

  Console.log("Server handler types verified!")
}

// Log for testing
let main = () => {
  Console.log("=== Proto Type Tests ===")
  Console.log("Users created:")
  Console.log(alice)
  Console.log(bob)
  Console.log2("Status code:", statusCode)
  Console.log2("Status from int:", status)

  Console.log("\n=== JSON Codec Tests ===")
  testJsonCodec()

  testOneOf()

  testWellKnownTypes()

  testStreamingAPI()

  testServerHandlers()
}

// Run main
main()
