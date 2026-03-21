-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-cache protocol.
-- Distributed cache types: cache backends, entries with TTL,
-- CAS tokens, and eviction policies.

module Types

import Data.List

||| Cache backend protocol.
public export
data CacheBackend : Type where
  Memcached : CacheBackend
  Redis     : CacheBackend

||| Eviction policy for memory pressure.
public export
data EvictionPolicy : Type where
  LRU        : EvictionPolicy
  LFU        : EvictionPolicy
  FIFO       : EvictionPolicy
  RandomEvict : EvictionPolicy
  NoEviction : EvictionPolicy

||| Cache entry with metadata.
public export
record CacheEntry where
  constructor MkCacheEntry
  key      : String
  ttlSecs  : Nat
  casToken : Bits64

||| Cache statistics.
public export
record CacheStats where
  constructor MkCacheStats
  hits      : Bits64
  misses    : Bits64
  evictions : Bits64
  memUsed   : Bits64
