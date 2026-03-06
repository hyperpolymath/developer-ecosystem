;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Current project state for rescript-grpc
;; Media Type: application/vnd.state+scm

(define state
  `((metadata
     (version "0.1.0")
     (schema-version "1.0")
     (created "2025-01-05")
     (updated "2025-01-05")
     (project "rescript-grpc")
     (repo "https://github.com/hyperpolymath/rescript-grpc"))

    (project-context
     (name "rescript-grpc")
     (tagline "Protocol Buffers to ReScript codegen with JSON codecs and gRPC-web client stubs")
     (tech-stack
      (primary "Rust" "ReScript")
      (build "cargo" "rescript")
      (runtime "Deno" "Bun" "Node")))

    (current-position
     (phase "active-development")
     (overall-completion 60)
     (components
      (protoc-gen-rescript
       (status "complete")
       (completion 100)
       (features
        "message-generation"
        "enum-variants"
        "json-codecs"
        "grpc-web-clients"
        "topological-sort"
        "proto3-semantics"))
      (runtime
       (status "complete")
       (completion 100)
       (features
        "json-encode-decode"
        "fetch-bindings"
        "error-types"))
      (examples
       (status "complete")
       (completion 100)
       (features
        "basic-usage"
        "json-roundtrip")))
     (working-features
      "protoc-plugin"
      "message-types"
      "enum-polymorphic-variants"
      "json-toJson"
      "json-fromJson"
      "grpc-web-client-stubs"
      "async-rpc-calls"))

    (route-to-mvp
     (milestones
      ((name "Core Codegen")
       (status "complete")
       (items
        ("protoc plugin" complete)
        ("message generation" complete)
        ("enum generation" complete)
        ("json codecs" complete)))
      ((name "gRPC-web")
       (status "complete")
       (items
        ("service client generation" complete)
        ("fetch bindings" complete)
        ("error handling" complete)))
      ((name "Production Ready")
       (status "in-progress")
       (items
        ("streaming support" pending)
        ("well-known types" pending)
        ("oneof support" pending)
        ("binary protobuf codec" pending)))))

    (blockers-and-issues
     (critical ())
     (high ())
     (medium
      ("Streaming RPC not yet supported"))
     (low
      ("OneOf fields not yet implemented")
      ("Well-known types (google.protobuf.*) not mapped")))

    (critical-next-actions
     (immediate
      ("Add streaming RPC support")
      ("Implement well-known types"))
     (this-week
      ("Add oneof field support")
      ("Publish to cargo and npm"))
     (this-month
      ("Binary protobuf codec via WASM")
      ("Server-side handler generation")))

    (session-history
     ((date "2025-01-05")
      (snapshot "v0.1.0-initial")
      (accomplishments
       "protoc plugin complete"
       "json codecs working"
       "grpc-web clients generated"
       "added to rescript-full-stack ecosystem")))))
