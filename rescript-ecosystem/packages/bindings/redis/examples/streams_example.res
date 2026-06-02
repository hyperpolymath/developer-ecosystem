// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2025 Hyperpolymath

/**
 * Redis Streams example for rescript-redis
 *
 * Demonstrates stream operations and consumer groups
 *
 * Run with:
 *   deno task build
 *   deno run --allow-net examples/streams_example.res.js
 */

@@uncurried

open Redis.Streams

let main = async () => {
  Console.log("Connecting to Redis...")
  let redis = await Redis.make()

  let streamKey = "events:demo"

  // Clean up any existing data
  let _ = await redis->Redis.del([streamKey])

  Console.log("\n--- Adding Stream Entries ---")

  // Add some events to the stream
  let id1 = await redis->add(
    streamKey,
    Dict.fromArray([("type", "user.created"), ("userId", "user123"), ("name", "Alice")]),
  )
  Console.log2("Added entry:", id1)

  let id2 = await redis->add(
    streamKey,
    Dict.fromArray([("type", "user.updated"), ("userId", "user123"), ("field", "email")]),
  )
  Console.log2("Added entry:", id2)

  let id3 = await redis->add(
    streamKey,
    Dict.fromArray([("type", "user.login"), ("userId", "user123"), ("ip", "192.168.1.1")]),
  )
  Console.log2("Added entry:", id3)

  // Get stream length
  let len = await redis->xlen(streamKey)
  Console.log2("\nStream length:", len)

  Console.log("\n--- Reading All Entries ---")

  // Read all entries
  let entries = await redis->rangeAll(streamKey)
  entries->Array.forEach(entry => {
    Console.log2("Entry ID:", entry.id)
    Console.log2("Fields:", entry.fields)
    Console.log("")
  })

  Console.log("\n--- Consumer Groups ---")

  // Create a consumer group
  try {
    let _ = await redis->groupCreateFromStart(streamKey, "processors")
    Console.log("Created consumer group: processors")
  } catch {
  | _ => Console.log("Consumer group already exists")
  }

  // Read as a consumer
  Console.log("\nReading as worker-1...")
  let messages = await redis->readGroupNew("processors", "worker-1", streamKey)

  switch messages {
  | Some(entries) => {
      Console.log2("Received messages:", entries->Array.length)

      // Process each message
      entries->Array.forEach(entry => {
        Console.log2("Processing:", entry.id)
        let eventType = entry.fields->Dict.get("type")->Option.getOr("unknown")
        Console.log2("Event type:", eventType)
      })

      // Acknowledge the messages
      let ids = entries->Array.map(e => e.id)
      let acked = await redis->ack(streamKey, "processors", ids)
      Console.log2("Acknowledged:", acked)
    }
  | None => Console.log("No new messages")
  }

  Console.log("\n--- Stream Info ---")

  // Get stream info
  let info = await redis->xinfoStream(streamKey)
  Console.log2("Stream info:", info)

  // Get groups info
  let groups = await redis->xinfoGroups(streamKey)
  Console.log2("Consumer groups:", groups)

  // Cleanup
  Console.log("\n--- Cleanup ---")
  let _ = await redis->Redis.del([streamKey])
  Console.log("Stream deleted")

  await redis->Redis.quit
  Console.log("\nDone!")
}

main()->Promise.catch(err => {
  Console.error2("Error:", err)
  Promise.resolve()
})->ignore
