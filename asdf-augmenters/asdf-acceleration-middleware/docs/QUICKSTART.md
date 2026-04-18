# Quick Start Guide

Get started with asdf-acceleration-middleware in 5 minutes.

## Prerequisites

- Rust 1.70.0 or later
- asdf version manager installed
- Git

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/Hyperpolymath/asdf-acceleration-middleware
cd asdf-acceleration-middleware

# Build and install
cargo install --path crates/asdf-accelerate
cargo install --path crates/asdf-bench
cargo install --path crates/asdf-discover
cargo install --path crates/asdf-monitor

# Or use just
just install
```

### Using Cargo

```bash
cargo install asdf-accelerate
cargo install asdf-bench
cargo install asdf-discover
cargo install asdf-monitor
```

## Basic Usage

### Update Plugins

```bash
# Update all plugins in parallel
asdf-accelerate update --all --jobs 8

# Update specific plugins
asdf-accelerate update nodejs ruby python

# Exclude certain plugins
asdf-accelerate update --all --exclude rust golang
```

### Install Runtimes

```bash
# Install single runtime
asdf-accelerate install nodejs@20.0.0

# Install multiple runtimes in parallel
asdf-accelerate install nodejs@20.0.0 ruby@3.2.0 --parallel
```

### List Plugins

```bash
# List all plugins
asdf-accelerate list

# List with URLs
asdf-accelerate list --urls

# JSON output
asdf-accelerate list --format json
```

### Cache Management

```bash
# Show cache statistics
asdf-accelerate cache --stats

# Clear cache
asdf-accelerate cache --clear
```

### Benchmarking

```bash
# Run benchmarks
asdf-bench --all

# Generate HTML report
asdf-bench --all --format html --output benchmark.html
```

### Discovery

```bash
# Scan system for runtimes
asdf-discover scan

# Generate Nickel configuration
asdf-discover generate --format nickel --output asdf-config.ncl

# Validate setup
asdf-discover validate
```

### Monitoring

```bash
# Health check
asdf-monitor health

# Export metrics
asdf-monitor metrics --format json

# Launch dashboard
asdf-monitor dashboard
```

## Configuration

### Create Configuration File

```bash
# Copy example configuration
cp examples/config.toml ~/.config/asdf-acceleration/config.toml

# Edit as needed
$EDITOR ~/.config/asdf-acceleration/config.toml
```

### Example Configuration

```toml
[cache]
enabled = true
ttl_secs = 3600
max_size_mb = 500

[parallel]
strategy = "auto"
fail_fast = false

[notifications]
enabled = true
level = "errors_only"

[plugins]
exclude = []
auto_update = true
```

### Environment Variables

Override configuration with environment variables:

```bash
# Set cache TTL
export ASDF_ACCEL__CACHE__TTL_SECS=7200

# Set parallel jobs
export ASDF_ACCEL__PARALLEL__MAX_JOBS=4

# Disable notifications
export ASDF_ACCEL__NOTIFICATIONS__ENABLED=false
```

## Common Workflows

### Daily Update Routine

```bash
# Morning routine: update all plugins
asdf-accelerate update --all --jobs 8

# Check for new versions
asdf-discover scan
```

### Setting Up New Machine

```bash
# Validate asdf installation
asdf-discover validate

# Scan existing runtimes
asdf-discover scan --deep

# Generate configuration
asdf-discover generate --format nickel > asdf-config.ncl
```

### Performance Optimization

```bash
# Benchmark current performance
asdf-bench --all

# Clear cache to free space
asdf-accelerate cache --clear

# Monitor system resources
asdf-monitor health
```

## Performance Tips

1. **Use parallel jobs**: `--jobs 8` can speed up operations 7-11x
2. **Enable caching**: Reduces redundant asdf calls
3. **Background mode**: Run long operations in background
4. **Exclude inactive plugins**: Faster updates

## Troubleshooting

### asdf not found

```bash
# Ensure asdf is in PATH
which asdf

# Or set ASDF_DIR
export ASDF_DIR=$HOME/.asdf
```

### Cache issues

```bash
# Clear cache
asdf-accelerate cache --clear

# Check cache location
asdf-accelerate cache --stats
```

### Permission errors

```bash
# Check cache directory permissions
ls -la ~/.cache/asdf-acceleration

# Fix if needed
chmod 700 ~/.cache/asdf-acceleration
```

## Next Steps

- Read [Architecture Documentation](ARCHITECTURE.md)
- Review [Contributing Guidelines](../CONTRIBUTING.md)
- Explore [Example Configurations](../examples/)
- Join [Discussions](https://github.com/Hyperpolymath/asdf-acceleration-middleware/discussions)

## Getting Help

- 📖 [Full Documentation](README.md)
- 🐛 [Report Issues](https://github.com/Hyperpolymath/asdf-acceleration-middleware/issues)
- 💬 [Ask Questions](https://github.com/Hyperpolymath/asdf-acceleration-middleware/discussions)

---

**Happy accelerating!** 🚀
