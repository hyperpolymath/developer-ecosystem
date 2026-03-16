// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

/**
 * Redis Pub/Sub example for rescript-redis
 *
 * Demonstrates publish/subscribe messaging
 *
 * Note: This example uses two separate connections - one for subscribing
 * and one for publishing, as Redis requires this for Pub/Sub.
 *
 * Run with:
 *   deno task build
 *   deno run --allow-net examples/pubsub_example.res.js
 */

@@uncurried

@val external setTimeout: (unit => unit, int) => int = "setTimeout"

let main = async () => {
  Console.log("Connecting to Redis...")

  // Create two connections - one for sub, one for pub
  let subscriber = await Redis.make()
  let publisher = await Redis.make()

  let channel = "notifications"

  Console.log2("Subscribing to channel:", channel)

  // Subscribe to channel
  let subscription = await subscriber->Redis.subscribe([channel])

  // Get the message iterator
  let iterator = subscription->Redis.receive

  Console.log("Subscribed! Waiting for messages...")
  Console.log("(Will auto-close after 3 messages)\n")

  // Publish some messages after a delay
  setTimeout(
    () => {
      Console.log("Publishing messages...")
      let _ = publisher->Redis.publish(channel, "Hello from ReScript!")
      let _ = publisher->Redis.publish(channel, "Redis Pub/Sub is working!")
      let _ = publisher->Redis.publish(channel, "Goodbye!")
    },
    1000,
  )->ignore

  // Process messages (simplified - in practice you'd use async iteration)
  // Note: This is a simplified example. In real code, you'd properly iterate
  // the async iterator using for-await or a recursive async function.

  Console.log("\nNote: Full async iteration requires runtime support.")
  Console.log("See the README for complete Pub/Sub patterns.\n")

  // For demonstration, we'll just show the API
  Console.log("API Usage:")
  Console.log("  let subscription = await redis->Redis.subscribe([\"channel\"])")
  Console.log("  let iterator = subscription->Redis.receive")
  Console.log("  // Then iterate using for-await or manual next() calls")

  // Give time for messages
  await Promise.make((resolve, _) => {
    setTimeout(() => resolve(), 2000)->ignore
  })

  // Cleanup
  Console.log("\n--- Cleanup ---")
  subscriber->Redis.close
  await publisher->Redis.quit
  Console.log("Connections closed")
  Console.log("\nDone!")
}

main()->Promise.catch(err => {
  Console.error2("Error:", err)
  Promise.resolve()
})->ignore
