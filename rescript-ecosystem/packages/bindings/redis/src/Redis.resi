// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

/**
 * Type-safe Redis client for ReScript.
 *
 * Provides bindings to Deno's redis library with full support for:
 * - String, Hash, List, Set, and Sorted Set operations
 * - Pub/Sub messaging
 * - Redis Streams with consumer groups
 * - Sentinel for high availability
 * - Cluster for horizontal scaling
 */

/** A Redis connection */
type t

/** Redis connection options */
type connectOptions = {
  hostname?: string,
  port?: int,
  password?: string,
  db?: int,
  tls?: bool,
  maxRetryCount?: int,
}

/** Pub/Sub channel */
type subscription

/** Pub/Sub message */
type pubSubMessage = {
  channel: string,
  message: string,
}

// =============================================================================
// Connection
// =============================================================================

/** Connect to Redis with custom options */
let connect: connectOptions => promise<t>

/** Connect to Redis with defaults (localhost:6379) */
let make: unit => promise<t>

/** Connect to Redis using a connection string (redis://password@host:port/db) */
let makeFromUrl: string => promise<t>

/** Ping the server */
let ping: t => promise<string>

/** Gracefully close the connection */
let quit: t => promise<unit>

/** Immediately close the connection */
let close: t => unit

// =============================================================================
// String Operations
// =============================================================================

/** Get the value of a key */
let get: (t, string) => promise<option<string>>

/** Set the value of a key */
let set: (t, string, string) => promise<string>

/** Set the value with an expiration (seconds) */
let setex: (t, string, int, string) => promise<string>

/** Set the value only if the key does not exist */
let setnx: (t, string, string) => promise<int>

/** Delete one or more keys */
let del: (t, array<string>) => promise<int>

/** Delete a single key */
let delOne: (t, string) => promise<int>

/** Check if keys exist */
let exists: (t, array<string>) => promise<int>

/** Check if a single key exists */
let existsOne: (t, string) => promise<bool>

/** Set a timeout on a key (seconds) */
let expire: (t, string, int) => promise<int>

/** Get the remaining time to live for a key */
let ttl: (t, string) => promise<int>

/** Increment the integer value of a key by one */
let incr: (t, string) => promise<int>

/** Increment the integer value of a key by the given amount */
let incrby: (t, string, int) => promise<int>

/** Decrement the integer value of a key by one */
let decr: (t, string) => promise<int>

/** Decrement the integer value of a key by the given amount */
let decrby: (t, string, int) => promise<int>

// =============================================================================
// JSON Helpers
// =============================================================================

/** Get a JSON value from a key */
let getJson: (t, string) => promise<option<JSON.t>>

/** Set a JSON value */
let setJson: (t, string, JSON.t) => promise<string>

/** Set a JSON value with expiry (seconds) */
let setJsonEx: (t, string, int, JSON.t) => promise<string>

// =============================================================================
// Hash Operations
// =============================================================================

/** Get the value of a hash field */
let hget: (t, string, string) => promise<option<string>>

/** Set the value of a hash field */
let hset: (t, string, string, string) => promise<int>

/** Delete one or more hash fields */
let hdel: (t, string, array<string>) => promise<int>

/** Get all fields and values in a hash (as flat array) */
let hgetall: (t, string) => promise<array<string>>

/** Get all fields and values in a hash as a dictionary */
let hgetallAsDict: (t, string) => promise<Dict.t<string>>

/** Check if a hash field exists */
let hexists: (t, string, string) => promise<int>

/** Increment the integer value of a hash field */
let hincrby: (t, string, string, int) => promise<int>

/** Get all field names in a hash */
let hkeys: (t, string) => promise<array<string>>

/** Get all values in a hash */
let hvals: (t, string) => promise<array<string>>

/** Get the number of fields in a hash */
let hlen: (t, string) => promise<int>

// =============================================================================
// List Operations
// =============================================================================

/** Prepend values to a list */
let lpush: (t, string, array<string>) => promise<int>

/** Append values to a list */
let rpush: (t, string, array<string>) => promise<int>

/** Remove and get the first element of a list */
let lpop: (t, string) => promise<option<string>>

/** Remove and get the last element of a list */
let rpop: (t, string) => promise<option<string>>

/** Get a range of elements from a list */
let lrange: (t, string, int, int) => promise<array<string>>

/** Get the length of a list */
let llen: (t, string) => promise<int>

/** Get an element from a list by its index */
let lindex: (t, string, int) => promise<option<string>>

/** Set the value of an element by its index */
let lset: (t, string, int, string) => promise<string>

// =============================================================================
// Set Operations
// =============================================================================

/** Add members to a set */
let sadd: (t, string, array<string>) => promise<int>

/** Remove members from a set */
let srem: (t, string, array<string>) => promise<int>

/** Get all members of a set */
let smembers: (t, string) => promise<array<string>>

/** Check if a member exists in a set */
let sismember: (t, string, string) => promise<int>

/** Get the number of members in a set */
let scard: (t, string) => promise<int>

// =============================================================================
// Sorted Set Operations
// =============================================================================

/** Add a member with a score to a sorted set */
let zadd: (t, string, float, string) => promise<int>

/** Remove members from a sorted set */
let zrem: (t, string, array<string>) => promise<int>

/** Get the score of a member */
let zscore: (t, string, string) => promise<option<string>>

/** Get the rank of a member */
let zrank: (t, string, string) => promise<option<int>>

/** Get members in a range by index (low to high) */
let zrange: (t, string, int, int) => promise<array<string>>

/** Get members in a range by index (high to low) */
let zrevrange: (t, string, int, int) => promise<array<string>>

/** Get the number of members in a sorted set */
let zcard: (t, string) => promise<int>

// =============================================================================
// Pub/Sub
// =============================================================================

/** Subscribe to one or more channels */
let subscribe: (t, array<string>) => promise<subscription>

/** Publish a message to a channel */
let publish: (t, string, string) => promise<int>

/** Get an async iterator of messages from a subscription */
let receive: subscription => AsyncIterator.t<pubSubMessage>

// =============================================================================
// Streams Module
// =============================================================================

module Streams: {
  /** Stream entry ID */
  type entryId = string

  /** Stream entry with parsed fields */
  type entry = {
    id: entryId,
    fields: Dict.t<string>,
  }

  /** Consumer group info */
  type groupInfo = {
    name: string,
    consumers: int,
    pending: int,
    lastDeliveredId: string,
  }

  /** Consumer info */
  type consumerInfo = {
    name: string,
    pending: int,
    idle: int,
  }

  /** Pending entry info */
  type pendingEntry = {
    id: entryId,
    consumer: string,
    idleTime: int,
    deliveryCount: int,
  }

  /** Add an entry to a stream with auto-generated ID */
  let add: (t, string, Dict.t<string>) => promise<entryId>

  /** Add an entry to a stream with a specific ID */
  let addWithId: (t, string, string, Dict.t<string>) => promise<entryId>

  /** Get the length of a stream */
  let xlen: (t, string) => promise<int>

  /** Get entries in a range */
  let range: (t, string, string, string) => promise<array<entry>>

  /** Get all entries in a stream */
  let rangeAll: (t, string) => promise<array<entry>>

  /** Get entries in reverse range */
  let revRange: (t, string, string, string) => promise<array<entry>>

  /** Read new entries from streams */
  let read: (t, array<(string, string)>) => promise<option<Dict.t<array<entry>>>>

  /** Trim a stream to a maximum length */
  let trim: (t, string, int) => promise<int>

  /** Trim a stream approximately */
  let trimApprox: (t, string, int) => promise<int>

  /** Delete entries by ID */
  let del: (t, string, array<entryId>) => promise<int>

  // Consumer Groups

  /** Create a consumer group starting from a specific ID */
  let groupCreate: (t, string, string, string) => promise<string>

  /** Create a consumer group starting from the beginning */
  let groupCreateFromStart: (t, string, string) => promise<string>

  /** Create a consumer group starting from the end */
  let groupCreateFromEnd: (t, string, string) => promise<string>

  /** Destroy a consumer group */
  let xgroupDestroy: (t, string, string) => promise<int>

  /** Remove a consumer from a group */
  let xgroupDelconsumer: (t, string, string, string) => promise<int>

  /** Set the last delivered ID for a group */
  let xgroupSetid: (t, string, string, string) => promise<string>

  /** Read from a consumer group */
  let readGroup: (t, string, string, array<(string, string)>) => promise<option<Dict.t<array<entry>>>>

  /** Read new messages for a consumer group */
  let readGroupNew: (t, string, string, string) => promise<option<array<entry>>>

  /** Acknowledge messages */
  let ack: (t, string, string, array<entryId>) => promise<int>

  /** Claim pending messages */
  let claim: (t, string, string, string, int, array<entryId>) => promise<array<entry>>

  /** Get stream info */
  let xinfoStream: (t, string) => promise<Dict.t<JSON.t>>

  /** Get consumer groups info */
  let xinfoGroups: (t, string) => promise<array<Dict.t<JSON.t>>>

  /** Get consumers info for a group */
  let xinfoConsumers: (t, string, string) => promise<array<Dict.t<JSON.t>>>
}

// =============================================================================
// Sentinel Module
// =============================================================================

module Sentinel: {
  /** Sentinel node configuration */
  type node = {
    hostname: string,
    port: int,
  }

  /** Sentinel connection options */
  type options = {
    masterName: string,
    sentinels: array<node>,
    password?: string,
    sentinelPassword?: string,
    db?: int,
    tls?: bool,
  }

  /** Connect via Sentinel for automatic failover */
  let make: options => promise<t>

  /** Get info about all monitored masters */
  let sentinelMasters: t => promise<array<Dict.t<string>>>

  /** Get info about a specific master */
  let sentinelMaster: (t, string) => promise<Dict.t<string>>

  /** Get replicas for a master */
  let sentinelReplicas: (t, string) => promise<array<Dict.t<string>>>

  /** Get sentinels for a master */
  let sentinelSentinels: (t, string) => promise<array<Dict.t<string>>>

  /** Get the address of a master by name */
  let sentinelGetMasterAddrByName: (t, string) => promise<option<(string, int)>>

  /** Force a failover */
  let sentinelFailover: (t, string) => promise<string>

  /** Check if a quorum can be reached */
  let sentinelCkquorum: (t, string) => promise<string>

  /** Force Sentinel to rewrite its config */
  let sentinelFlushconfig: t => promise<string>

  /** Reset Sentinel state for a master pattern */
  let sentinelReset: (t, string) => promise<int>
}

// =============================================================================
// Cluster Module
// =============================================================================

module Cluster: {
  /** Cluster node info */
  type nodeInfo = {
    id: string,
    address: string,
    flags: string,
    master: option<string>,
    pingSent: int,
    pongRecv: int,
    configEpoch: int,
    linkState: string,
    slots: option<string>,
  }

  /** Cluster slot range info */
  type slotRange = {
    startSlot: int,
    endSlot: int,
    master: {hostname: string, port: int, nodeId: string},
    replicas: array<{hostname: string, port: int, nodeId: string}>,
  }

  /** Cluster node configuration */
  type node = {
    hostname: string,
    port: int,
  }

  /** Cluster connection options */
  type options = {
    nodes: array<node>,
    password?: string,
    tls?: bool,
    maxRedirections?: int,
    retryCount?: int,
    retryDelayMs?: int,
  }

  /** Connect to a Redis Cluster */
  let make: options => promise<t>

  /** Get cluster state info */
  let clusterInfo: t => promise<string>

  /** Get cluster nodes */
  let clusterNodes: t => promise<string>

  /** Get slot assignments */
  let clusterSlots: t => promise<array<JSON.t>>

  /** Get the slot for a key */
  let clusterKeyslot: (t, string) => promise<int>

  /** Get keys in a slot */
  let clusterGetkeysinslot: (t, int, int) => promise<array<string>>

  /** Count keys in a slot */
  let clusterCountkeysinslot: (t, int) => promise<int>

  /** Add a node to the cluster */
  let clusterMeet: (t, string, int) => promise<string>

  /** Remove a node from the cluster */
  let clusterForget: (t, string) => promise<string>

  /** Make this node a replica of another */
  let clusterReplicate: (t, string) => promise<string>

  /** Trigger a manual failover */
  let clusterFailover: t => promise<string>

  /** Force a failover without agreement */
  let clusterFailoverForce: t => promise<string>

  /** Reset the cluster configuration */
  let clusterReset: t => promise<string>

  /** Save cluster config to disk */
  let clusterSaveconfig: t => promise<string>

  /** Assign a slot to a node */
  let clusterSetslot: (t, int, string, option<string>) => promise<string>

  /** Add slots to this node */
  let clusterAddslots: (t, array<int>) => promise<string>

  /** Remove slots from this node */
  let clusterDelslots: (t, array<int>) => promise<string>

  /** Enable reads from replica nodes */
  let readonly: t => promise<string>

  /** Disable reads from replica nodes */
  let readwrite: t => promise<string>

  /** Parse cluster nodes output into structured data */
  let parseNodes: string => array<nodeInfo>

  /** Check if the cluster is healthy */
  let isHealthy: t => promise<bool>

  /** Get the number of slots owned by this node */
  let getMySlotCount: t => promise<int>
}
