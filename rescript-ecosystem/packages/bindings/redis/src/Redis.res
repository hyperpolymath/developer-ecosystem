// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@uncurried

/**
 * Type-safe Redis client for ReScript using Deno's redis library.
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

// FFI Bindings
@module("https://deno.land/x/redis@v0.32.4/mod.ts")
external connect: connectOptions => promise<t> = "connect"

@send external ping: t => promise<string> = "ping"
@send external quit: t => promise<unit> = "quit"
@send external close: t => unit = "close"

// String operations
@send external get: (t, string) => promise<option<string>> = "get"
@send external set: (t, string, string) => promise<string> = "set"
@send external setex: (t, string, int, string) => promise<string> = "setex"
@send external setnx: (t, string, string) => promise<int> = "setnx"
@send external del: (t, array<string>) => promise<int> = "del"
@send external exists: (t, array<string>) => promise<int> = "exists"
@send external expire: (t, string, int) => promise<int> = "expire"
@send external ttl: (t, string) => promise<int> = "ttl"
@send external incr: (t, string) => promise<int> = "incr"
@send external incrby: (t, string, int) => promise<int> = "incrby"
@send external decr: (t, string) => promise<int> = "decr"
@send external decrby: (t, string, int) => promise<int> = "decrby"

// Hash operations
@send external hget: (t, string, string) => promise<option<string>> = "hget"
@send external hset: (t, string, string, string) => promise<int> = "hset"
@send external hdel: (t, string, array<string>) => promise<int> = "hdel"
@send external hgetall: (t, string) => promise<array<string>> = "hgetall"
@send external hexists: (t, string, string) => promise<int> = "hexists"
@send external hincrby: (t, string, string, int) => promise<int> = "hincrby"
@send external hkeys: (t, string) => promise<array<string>> = "hkeys"
@send external hvals: (t, string) => promise<array<string>> = "hvals"
@send external hlen: (t, string) => promise<int> = "hlen"

// List operations
@send external lpush: (t, string, array<string>) => promise<int> = "lpush"
@send external rpush: (t, string, array<string>) => promise<int> = "rpush"
@send external lpop: (t, string) => promise<option<string>> = "lpop"
@send external rpop: (t, string) => promise<option<string>> = "rpop"
@send external lrange: (t, string, int, int) => promise<array<string>> = "lrange"
@send external llen: (t, string) => promise<int> = "llen"
@send external lindex: (t, string, int) => promise<option<string>> = "lindex"
@send external lset: (t, string, int, string) => promise<string> = "lset"

// Set operations
@send external sadd: (t, string, array<string>) => promise<int> = "sadd"
@send external srem: (t, string, array<string>) => promise<int> = "srem"
@send external smembers: (t, string) => promise<array<string>> = "smembers"
@send external sismember: (t, string, string) => promise<int> = "sismember"
@send external scard: (t, string) => promise<int> = "scard"

// Sorted set operations
@send external zadd: (t, string, float, string) => promise<int> = "zadd"
@send external zrem: (t, string, array<string>) => promise<int> = "zrem"
@send external zscore: (t, string, string) => promise<option<string>> = "zscore"
@send external zrank: (t, string, string) => promise<option<int>> = "zrank"
@send external zrange: (t, string, int, int) => promise<array<string>> = "zrange"
@send external zrevrange: (t, string, int, int) => promise<array<string>> = "zrevrange"
@send external zcard: (t, string) => promise<int> = "zcard"

// Pub/Sub
@send external subscribe: (t, array<string>) => promise<subscription> = "subscribe"
@send external publish: (t, string, string) => promise<int> = "publish"

// Subscription iteration
@send external receive: subscription => AsyncIterator.t<pubSubMessage> = "receive"

/** Connect with defaults (localhost:6379) */
let make = (): promise<t> => {
  connect({hostname: "localhost", port: 6379})
}

/** Connect with connection string */
let makeFromUrl = (url: string): promise<t> => {
  // Parse redis://password@host:port/db format
  let url = url->String.replace("redis://", "")
  let (password, rest) = switch url->String.split("@") {
  | [p, r] => (Some(p), r)
  | _ => (None, url)
  }
  let (hostPort, db) = switch rest->String.split("/") {
  | [hp, d] => (hp, Int.fromString(d, ~radix=10))
  | _ => (rest, None)
  }
  let (hostname, port) = switch hostPort->String.split(":") {
  | [h, p] => (h, Int.fromString(p, ~radix=10)->Option.getOr(6379))
  | _ => (hostPort, 6379)
  }

  connect({
    hostname,
    port,
    password: ?password,
    db: ?db,
  })
}

/** Get a JSON value */
let getJson = async (redis: t, key: string): option<JSON.t> => {
  let value = await get(redis, key)
  value->Option.flatMap(s => {
    try {
      Some(JSON.parseExn(s))
    } catch {
    | _ => None
    }
  })
}

/** Set a JSON value */
let setJson = async (redis: t, key: string, value: JSON.t): string => {
  await set(redis, key, JSON.stringify(value))
}

/** Set JSON with expiry */
let setJsonEx = async (redis: t, key: string, seconds: int, value: JSON.t): string => {
  await setex(redis, key, seconds, JSON.stringify(value))
}

/** Parse hgetall result into a dictionary */
let hgetallAsDict = async (redis: t, key: string): Dict.t<string> => {
  let arr = await hgetall(redis, key)
  let dict = Dict.make()
  let rec loop = (i: int) => {
    if i < arr->Array.length - 1 {
      let k = arr->Array.getUnsafe(i)
      let v = arr->Array.getUnsafe(i + 1)
      dict->Dict.set(k, v)
      loop(i + 2)
    }
  }
  loop(0)
  dict
}

/** Delete a single key */
let delOne = async (redis: t, key: string): int => {
  await del(redis, [key])
}

/** Check if a single key exists */
let existsOne = async (redis: t, key: string): bool => {
  let count = await exists(redis, [key])
  count > 0
}

// =============================================================================
// Streams Support
// =============================================================================

module Streams = {
  /** Stream entry ID */
  type entryId = string

  /** Stream entry */
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

  /** XADD - Add entry to stream */
  @send external xadd: (t, string, string, array<string>) => promise<string> = "xadd"

  /** XADD with auto ID (*) */
  let add = async (redis: t, stream: string, fields: Dict.t<string>): entryId => {
    let fieldPairs = fields->Dict.toArray->Array.flatMap(((k, v)) => [k, v])
    await xadd(redis, stream, "*", fieldPairs)
  }

  /** XADD with specific ID */
  let addWithId = async (redis: t, stream: string, id: string, fields: Dict.t<string>): entryId => {
    let fieldPairs = fields->Dict.toArray->Array.flatMap(((k, v)) => [k, v])
    await xadd(redis, stream, id, fieldPairs)
  }

  /** XLEN - Get stream length */
  @send external xlen: (t, string) => promise<int> = "xlen"

  /** XRANGE - Get entries in range */
  @send external xrange: (t, string, string, string) => promise<array<(string, array<string>)>> = "xrange"

  /** XREVRANGE - Get entries in reverse range */
  @send external xrevrange: (t, string, string, string) => promise<array<(string, array<string>)>> = "xrevrange"

  /** Parse raw stream entry to structured format */
  let parseEntry = ((id, fields): (string, array<string>)): entry => {
    let dict = Dict.make()
    let rec loop = (i: int) => {
      if i < fields->Array.length - 1 {
        let k = fields->Array.getUnsafe(i)
        let v = fields->Array.getUnsafe(i + 1)
        dict->Dict.set(k, v)
        loop(i + 2)
      }
    }
    loop(0)
    {id, fields: dict}
  }

  /** Get entries in range with parsed output */
  let range = async (redis: t, stream: string, start: string, end_: string): array<entry> => {
    let raw = await xrange(redis, stream, start, end_)
    raw->Array.map(parseEntry)
  }

  /** Get all entries */
  let rangeAll = async (redis: t, stream: string): array<entry> => {
    await range(redis, stream, "-", "+")
  }

  /** Get entries in reverse range with parsed output */
  let revRange = async (redis: t, stream: string, end_: string, start: string): array<entry> => {
    let raw = await xrevrange(redis, stream, end_, start)
    raw->Array.map(parseEntry)
  }

  /** XREAD - Read from streams (blocking) */
  @send external xread: (t, array<string>, array<string>) => promise<option<array<(string, array<(string, array<string>)>)>>> = "xread"

  /** XREAD with BLOCK */
  @send external xreadBlock: (t, int, array<string>, array<string>) => promise<option<array<(string, array<(string, array<string>)>)>>> = "xreadBlock"

  /** Read new entries from a stream */
  let read = async (redis: t, streams: array<(string, string)>): option<Dict.t<array<entry>>> => {
    let streamNames = streams->Array.map(((name, _)) => name)
    let ids = streams->Array.map(((_, id)) => id)
    let result = await xread(redis, streamNames, ids)
    result->Option.map(arr => {
      let dict = Dict.make()
      arr->Array.forEach(((stream, entries)) => {
        dict->Dict.set(stream, entries->Array.map(parseEntry))
      })
      dict
    })
  }

  /** XTRIM - Trim stream to max length */
  @send external xtrim: (t, string, string, int) => promise<int> = "xtrim"

  /** Trim stream to max length */
  let trim = async (redis: t, stream: string, maxLen: int): int => {
    await xtrim(redis, stream, "MAXLEN", maxLen)
  }

  /** Trim stream approximately */
  let trimApprox = async (redis: t, stream: string, maxLen: int): int => {
    await xtrim(redis, stream, "MAXLEN", maxLen)
  }

  /** XDEL - Delete entries */
  @send external xdel: (t, string, array<string>) => promise<int> = "xdel"

  /** Delete entries by ID */
  let del = async (redis: t, stream: string, ids: array<entryId>): int => {
    await xdel(redis, stream, ids)
  }

  // Consumer Groups

  /** XGROUP CREATE - Create consumer group */
  @send external xgroupCreate: (t, string, string, string) => promise<string> = "xgroupCreate"

  /** Create consumer group starting from ID */
  let groupCreate = async (redis: t, stream: string, group: string, id: string): string => {
    await xgroupCreate(redis, stream, group, id)
  }

  /** Create consumer group starting from beginning */
  let groupCreateFromStart = async (redis: t, stream: string, group: string): string => {
    await xgroupCreate(redis, stream, group, "0")
  }

  /** Create consumer group starting from end */
  let groupCreateFromEnd = async (redis: t, stream: string, group: string): string => {
    await xgroupCreate(redis, stream, group, "$")
  }

  /** XGROUP DESTROY - Delete consumer group */
  @send external xgroupDestroy: (t, string, string) => promise<int> = "xgroupDestroy"

  /** XGROUP DELCONSUMER - Remove consumer from group */
  @send external xgroupDelconsumer: (t, string, string, string) => promise<int> = "xgroupDelconsumer"

  /** XGROUP SETID - Set group's last delivered ID */
  @send external xgroupSetid: (t, string, string, string) => promise<string> = "xgroupSetid"

  /** XREADGROUP - Read as consumer group */
  @send external xreadgroup: (t, string, string, array<string>, array<string>) => promise<option<array<(string, array<(string, array<string>)>)>>> = "xreadgroup"

  /** Read from consumer group */
  let readGroup = async (
    redis: t,
    group: string,
    consumer: string,
    streams: array<(string, string)>,
  ): option<Dict.t<array<entry>>> => {
    let streamNames = streams->Array.map(((name, _)) => name)
    let ids = streams->Array.map(((_, id)) => id)
    let result = await xreadgroup(redis, group, consumer, streamNames, ids)
    result->Option.map(arr => {
      let dict = Dict.make()
      arr->Array.forEach(((stream, entries)) => {
        dict->Dict.set(stream, entries->Array.map(parseEntry))
      })
      dict
    })
  }

  /** Read new messages for consumer group */
  let readGroupNew = async (
    redis: t,
    group: string,
    consumer: string,
    stream: string,
  ): option<array<entry>> => {
    let result = await readGroup(redis, group, consumer, [(stream, ">")])
    result->Option.flatMap(dict => dict->Dict.get(stream))
  }

  /** XACK - Acknowledge message */
  @send external xack: (t, string, string, array<string>) => promise<int> = "xack"

  /** Acknowledge messages */
  let ack = async (redis: t, stream: string, group: string, ids: array<entryId>): int => {
    await xack(redis, stream, group, ids)
  }

  /** XPENDING - Get pending entries summary */
  @send external xpending: (t, string, string) => promise<(int, option<string>, option<string>, option<array<(string, int)>>)> = "xpending"

  /** XCLAIM - Claim pending messages */
  @send external xclaim: (t, string, string, string, int, array<string>) => promise<array<(string, array<string>)>> = "xclaim"

  /** Claim pending messages for this consumer */
  let claim = async (
    redis: t,
    stream: string,
    group: string,
    consumer: string,
    minIdleTime: int,
    ids: array<entryId>,
  ): array<entry> => {
    let raw = await xclaim(redis, stream, group, consumer, minIdleTime, ids)
    raw->Array.map(parseEntry)
  }

  /** XINFO STREAM - Get stream info */
  @send external xinfoStream: (t, string) => promise<Dict.t<JSON.t>> = "xinfoStream"

  /** XINFO GROUPS - Get groups info */
  @send external xinfoGroups: (t, string) => promise<array<Dict.t<JSON.t>>> = "xinfoGroups"

  /** XINFO CONSUMERS - Get consumers info */
  @send external xinfoConsumers: (t, string, string) => promise<array<Dict.t<JSON.t>>> = "xinfoConsumers"
}

// =============================================================================
// Sentinel Support
// =============================================================================

module Sentinel = {
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
  @module("https://deno.land/x/redis@v0.32.4/mod.ts")
  external connect: options => promise<t> = "createLazyClient"

  /** Create a Sentinel-aware connection */
  let make = async (options: options): t => {
    await connect(options)
  }

  /** Sentinel INFO command - get info about monitored masters */
  @send external sentinelMasters: t => promise<array<Dict.t<string>>> = "sentinelMasters"

  /** Get info about a specific master */
  @send external sentinelMaster: (t, string) => promise<Dict.t<string>> = "sentinelMaster"

  /** Get replicas for a master */
  @send external sentinelReplicas: (t, string) => promise<array<Dict.t<string>>> = "sentinelReplicas"

  /** Get sentinels for a master */
  @send external sentinelSentinels: (t, string) => promise<array<Dict.t<string>>> = "sentinelSentinels"

  /** Get master address */
  @send external sentinelGetMasterAddrByName: (t, string) => promise<option<(string, int)>> = "sentinelGetMasterAddrByName"

  /** Failover a master */
  @send external sentinelFailover: (t, string) => promise<string> = "sentinelFailover"

  /** Check if master is down */
  @send external sentinelCkquorum: (t, string) => promise<string> = "sentinelCkquorum"

  /** Force failover without agreement */
  @send external sentinelFlushconfig: t => promise<string> = "sentinelFlushconfig"

  /** Reset sentinel state */
  @send external sentinelReset: (t, string) => promise<int> = "sentinelReset"
}

// =============================================================================
// Cluster Support
// =============================================================================

module Cluster = {
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

  /** Cluster slot range */
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
  @module("https://deno.land/x/redis@v0.32.4/mod.ts")
  external connect: options => promise<t> = "createCluster"

  /** Create a Cluster connection */
  let make = async (options: options): t => {
    await connect(options)
  }

  /** CLUSTER INFO - get cluster state info */
  @send external clusterInfo: t => promise<string> = "clusterInfo"

  /** CLUSTER NODES - get cluster nodes */
  @send external clusterNodes: t => promise<string> = "clusterNodes"

  /** CLUSTER SLOTS - get slot assignments */
  @send external clusterSlots: t => promise<array<JSON.t>> = "clusterSlots"

  /** CLUSTER KEYSLOT - get slot for a key */
  @send external clusterKeyslot: (t, string) => promise<int> = "clusterKeyslot"

  /** CLUSTER GETKEYSINSLOT - get keys in a slot */
  @send external clusterGetkeysinslot: (t, int, int) => promise<array<string>> = "clusterGetkeysinslot"

  /** CLUSTER COUNTKEYSINSLOT - count keys in a slot */
  @send external clusterCountkeysinslot: (t, int) => promise<int> = "clusterCountkeysinslot"

  /** CLUSTER MEET - add a node to cluster */
  @send external clusterMeet: (t, string, int) => promise<string> = "clusterMeet"

  /** CLUSTER FORGET - remove a node from cluster */
  @send external clusterForget: (t, string) => promise<string> = "clusterForget"

  /** CLUSTER REPLICATE - make node a replica of another */
  @send external clusterReplicate: (t, string) => promise<string> = "clusterReplicate"

  /** CLUSTER FAILOVER - manual failover */
  @send external clusterFailover: t => promise<string> = "clusterFailover"

  /** CLUSTER FAILOVER FORCE */
  @send external clusterFailoverForce: t => promise<string> = "clusterFailoverForce"

  /** CLUSTER RESET - reset cluster config */
  @send external clusterReset: t => promise<string> = "clusterReset"

  /** CLUSTER SAVECONFIG - save cluster config */
  @send external clusterSaveconfig: t => promise<string> = "clusterSaveconfig"

  /** CLUSTER SETSLOT - assign slot to node */
  @send external clusterSetslot: (t, int, string, option<string>) => promise<string> = "clusterSetslot"

  /** CLUSTER ADDSLOTS - add slots to this node */
  @send external clusterAddslots: (t, array<int>) => promise<string> = "clusterAddslots"

  /** CLUSTER DELSLOTS - remove slots from this node */
  @send external clusterDelslots: (t, array<int>) => promise<string> = "clusterDelslots"

  /** READONLY - enable reads from replicas */
  @send external readonly: t => promise<string> = "readonly"

  /** READWRITE - disable reads from replicas */
  @send external readwrite: t => promise<string> = "readwrite"

  /** Parse cluster nodes output into structured data */
  let parseNodes = (nodesStr: string): array<nodeInfo> => {
    nodesStr
    ->String.split("\n")
    ->Array.filter(line => line->String.trim != "")
    ->Array.map(line => {
      let parts = line->String.split(" ")
      {
        id: parts->Array.get(0)->Option.getOr(""),
        address: parts->Array.get(1)->Option.getOr(""),
        flags: parts->Array.get(2)->Option.getOr(""),
        master: parts->Array.get(3)->Option.flatMap(s => s == "-" ? None : Some(s)),
        pingSent: parts->Array.get(4)->Option.flatMap(Int.fromString(_, ~radix=10))->Option.getOr(0),
        pongRecv: parts->Array.get(5)->Option.flatMap(Int.fromString(_, ~radix=10))->Option.getOr(0),
        configEpoch: parts->Array.get(6)->Option.flatMap(Int.fromString(_, ~radix=10))->Option.getOr(0),
        linkState: parts->Array.get(7)->Option.getOr(""),
        slots: parts->Array.get(8),
      }
    })
  }

  /** Check cluster health */
  let isHealthy = async (redis: t): bool => {
    let info = await clusterInfo(redis)
    info->String.includes("cluster_state:ok")
  }

  /** Get number of slots this node owns */
  let getMySlotCount = async (redis: t): int => {
    let nodes = await clusterNodes(redis)
    let parsed = parseNodes(nodes)
    parsed
    ->Array.find(n => n.flags->String.includes("myself"))
    ->Option.flatMap(n => n.slots)
    ->Option.map(slots => {
      // Count slots from ranges like "0-5460"
      slots
      ->String.split("-")
      ->Array.map(s => Int.fromString(s, ~radix=10)->Option.getOr(0))
      ->(arr => {
        switch arr {
        | [start, end_] => end_ - start + 1
        | _ => 0
        }
      })
    })
    ->Option.getOr(0)
  }
}
