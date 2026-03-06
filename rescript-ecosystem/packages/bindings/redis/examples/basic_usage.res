// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

/**
 * Basic usage example for rescript-redis
 *
 * Run with:
 *   deno task build
 *   deno run --allow-net examples/basic_usage.res.js
 */

@@uncurried

let main = async () => {
  Console.log("Connecting to Redis...")

  // Connect to Redis
  let redis = await Redis.make()

  // Ping the server
  let pong = await redis->Redis.ping
  Console.log2("Ping response:", pong)

  // String operations
  Console.log("\n--- String Operations ---")
  await redis->Redis.set("greeting", "Hello from ReScript!")
  let greeting = await redis->Redis.get("greeting")
  switch greeting {
  | Some(msg) => Console.log2("Got greeting:", msg)
  | None => Console.log("No greeting found")
  }

  // With expiration
  await redis->Redis.setex("temp:key", 60, "expires in 60 seconds")
  let ttl = await redis->Redis.ttl("temp:key")
  Console.log2("TTL:", ttl)

  // Hash operations
  Console.log("\n--- Hash Operations ---")
  await redis->Redis.hset("user:1", "name", "Alice")
  await redis->Redis.hset("user:1", "email", "alice@example.com")
  await redis->Redis.hset("user:1", "visits", "0")

  let name = await redis->Redis.hget("user:1", "name")
  switch name {
  | Some(n) => Console.log2("User name:", n)
  | None => Console.log("User not found")
  }

  await redis->Redis.hincrby("user:1", "visits", 1)
  let user = await redis->Redis.hgetallAsDict("user:1")
  Console.log2("Full user:", user)

  // List operations
  Console.log("\n--- List Operations ---")
  await redis->Redis.rpush("tasks", ["task1", "task2", "task3"])
  let tasks = await redis->Redis.lrange("tasks", 0, -1)
  Console.log2("Tasks:", tasks)

  let task = await redis->Redis.lpop("tasks")
  switch task {
  | Some(t) => Console.log2("Popped task:", t)
  | None => Console.log("No tasks")
  }

  // Set operations
  Console.log("\n--- Set Operations ---")
  await redis->Redis.sadd("tags", ["rescript", "redis", "deno"])
  let tags = await redis->Redis.smembers("tags")
  Console.log2("Tags:", tags)

  let isMember = await redis->Redis.sismember("tags", "rescript")
  Console.log2("Is 'rescript' a member:", isMember)

  // Sorted set operations
  Console.log("\n--- Sorted Set Operations ---")
  await redis->Redis.zadd("leaderboard", 100.0, "alice")
  await redis->Redis.zadd("leaderboard", 85.0, "bob")
  await redis->Redis.zadd("leaderboard", 92.0, "charlie")

  let top = await redis->Redis.zrevrange("leaderboard", 0, 2)
  Console.log2("Top players:", top)

  let aliceScore = await redis->Redis.zscore("leaderboard", "alice")
  switch aliceScore {
  | Some(s) => Console.log2("Alice's score:", s)
  | None => Console.log("Score not found")
  }

  // JSON helpers
  Console.log("\n--- JSON Helpers ---")
  let userData = JSON.parseExn(`{"id": 1, "name": "Alice", "active": true}`)
  await redis->Redis.setJson("user:json:1", userData)

  let retrieved = await redis->Redis.getJson("user:json:1")
  switch retrieved {
  | Some(data) => Console.log2("Retrieved JSON:", JSON.stringify(data))
  | None => Console.log("No JSON found")
  }

  // Cleanup
  Console.log("\n--- Cleanup ---")
  let deleted = await redis->Redis.del([
    "greeting",
    "temp:key",
    "user:1",
    "tasks",
    "tags",
    "leaderboard",
    "user:json:1",
  ])
  Console.log2("Deleted keys:", deleted)

  // Close connection
  await redis->Redis.quit
  Console.log("\nDone!")
}

// Run the example
main()->Promise.catch(err => {
  Console.error2("Error:", err)
  Promise.resolve()
})->ignore
