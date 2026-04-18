# Architecture

## Overview

asdf-acceleration-middleware is built as a modular Rust workspace with separation of concerns across multiple crates.

## Crate Structure

### Library Crates

#### asdf-core
**Purpose**: Core abstractions for asdf integration

**Responsibilities**:
- Type-safe wrappers around asdf operations
- Plugin management
- Runtime version management
- Semantic version parsing

**Key Types**:
- `Plugin`: Represents an asdf plugin
- `Runtime`: Represents an installed runtime version
- `Version`: Semantic version with parsing and comparison

#### asdf-cache
**Purpose**: Multi-level caching system

**Architecture**:
```
L1 (Memory) → L2 (Disk) → Source
  LRU Cache     Sled DB      asdf
```

**Components**:
- `MemoryCache`: In-memory LRU cache for hot data
- `DiskCache`: Sled embedded database for persistence
- `CacheManager`: Coordinator managing both levels

**Performance**: O(1) average for L1 hits, O(log n) for L2

#### asdf-parallel
**Purpose**: Parallel execution engine using Rayon

**Features**:
- Multiple execution strategies (sequential, auto, fixed, max)
- Fail-fast or collect-all error handling
- Retry logic with configurable attempts
- Progress tracking integration

**Key Types**:
- `Executor`: Main parallel execution coordinator
- `Strategy`: Execution strategy enumeration
- `ExecutorConfig`: Configuration for execution behavior

#### asdf-config
**Purpose**: Configuration management

**Features**:
- Multiple format support (TOML, JSON, Nickel)
- Environment variable overrides
- Hierarchical configuration loading
- Type-safe schema with validation

**Loading Priority**:
1. Environment variables (highest)
2. Config file
3. Defaults (lowest)

#### asdf-metrics
**Purpose**: Metrics collection and reporting

**Features**:
- Operation timing and counting
- Success/failure rate tracking
- System resource monitoring
- Multiple export formats (text, JSON, Prometheus)

### CLI Crates

#### asdf-accelerate
**Purpose**: Main CLI tool for accelerating asdf operations

**Commands**:
- `update`: Update plugins in parallel
- `install`: Install runtimes with acceleration
- `sync`: Sync plugin repositories
- `list`: List plugins with formatting options
- `cache`: Manage cache (clear, stats)

**Architecture**:
```
CLI → Commands → Libraries
        ↓
    Executor → asdf-core
        ↓
    Progress Bar
        ↓
    Metrics
```

#### asdf-bench
**Purpose**: Benchmarking tool

**Features**:
- Operation timing
- Baseline comparisons
- Multiple output formats
- Performance profiling

#### asdf-discover
**Purpose**: Auto-discovery of runtimes

**Features**:
- System scanning for installed runtimes
- Configuration generation (Nickel, JSON, TOML)
- Setup validation

**Use Cases**:
- Onboarding new systems
- Generating `.tool-versions` equivalents
- Auditing installed runtimes

#### asdf-monitor
**Purpose**: Monitoring and health checking

**Features**:
- Real-time metrics dashboard (planned TUI)
- Health checks
- Prometheus metrics export
- System resource monitoring

## Data Flow

### Plugin Update Flow

```
User Command
    ↓
asdf-accelerate
    ↓
Load Config
    ↓
Query Plugins (asdf-core)
    ↓
Check Cache (asdf-cache)
    ├─ Hit → Return cached
    └─ Miss → Fetch from asdf
        ↓
    Update Plugins (asdf-parallel)
        ├─ Executor spawns threads
        ├─ Each thread updates plugin
        └─ Collect results
    ↓
Update Cache
    ↓
Report Metrics
```

### Caching Strategy

```
Get Plugin Info
    ↓
Check L1 (Memory LRU)
    ├─ Hit → Return (fast path)
    └─ Miss
        ↓
    Check L2 (Disk Sled)
        ├─ Hit → Promote to L1 → Return
        └─ Miss
            ↓
        Fetch from asdf
            ↓
        Store in L2 and L1
            ↓
        Return
```

## Performance Targets

### Benchmarks

| Operation | Baseline (bash) | Sequential | Parallel (4) | Parallel (8) |
|-----------|----------------|------------|--------------|--------------|
| Plugin Update | 100s | 40s (2.5x) | 13s (7.7x) | 9s (11x) |
| Plugin List | 5s | 2s (2.5x) | 0.8s (6.2x) | 0.5s (10x) |

### Memory Usage

- L1 Cache: ~10MB (1000 entries)
- L2 Cache: ~100MB (typical)
- Total: <150MB resident

### Scalability

- **Plugins**: Tested with 50+ plugins
- **Parallel Jobs**: Scales to CPU count
- **Cache Size**: Handles 10k+ entries

## Security Considerations

### Input Validation

- All external input sanitized
- No shell interpolation
- Path traversal prevention

### Cache Security

- Cache files: 0600 permissions
- Integrity verification on load
- TTL enforcement

### Subprocess Execution

- Uses `duct` for safe subprocess management
- No shell=true
- Argument array passing (no string interpolation)

## Error Handling

### Strategy

- Type-safe errors with `thiserror`
- Context preservation with `anyhow`
- Graceful degradation when possible

### Error Types

1. **Recoverable**: Retry with backoff
2. **User Errors**: Clear messages and suggestions
3. **System Errors**: Detailed context for debugging

## Testing Strategy

### Unit Tests

- Each crate has `#[cfg(test)]` modules
- Test coverage target: >80%
- Property-based testing for parsers

### Integration Tests

- Cross-crate integration
- End-to-end CLI testing with `assert_cmd`
- Fixture-based testing

### Benchmarks

- Criterion-based performance tests
- Regression detection
- Profiling integration

## Future Architecture

### Planned Enhancements

1. **Async I/O**: Tokio integration for I/O-bound operations
2. **Plugin System**: Dynamic plugin loading
3. **Distributed Caching**: Redis backend option
4. **Web Dashboard**: Browser-based monitoring
5. **gRPC API**: Programmatic access

### Nickel Integration (Phase 2)

- Type-safe configuration generation
- Contract-based validation
- Smart defaults with overrides

## RSR Compliance

### Type Safety

- Zero `unsafe` blocks in core libraries
- Compile-time guarantees via Rust type system
- Newtype pattern for semantic clarity

### Memory Safety

- Ownership model prevents use-after-free
- No buffer overflows
- RAII for resource management

### Offline-First

- No mandatory network calls
- All data cached locally
- Graceful handling of offline mode

## Dependencies

### Philosophy

- Minimal but powerful
- Well-maintained crates only
- Regular `cargo audit` checks
- Security-first selection

### Key Dependencies

- **rayon**: Data parallelism
- **sled**: Embedded database
- **clap**: CLI parsing
- **serde**: Serialization
- **duct**: Subprocess management

---

**Last Updated**: 2024-11-22
