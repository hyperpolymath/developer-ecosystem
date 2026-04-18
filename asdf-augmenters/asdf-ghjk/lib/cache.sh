#!/usr/bin/env bash

# GitHub API response caching
# Reduces API calls and improves performance

set -euo pipefail

# Cache configuration
CACHE_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}/cache/ghjk"
CACHE_TTL=${GHJK_CACHE_TTL:-3600}  # 1 hour default

# Initialize cache directory
init_cache() {
  mkdir -p "$CACHE_DIR"
}

# Get cache file path for a URL
get_cache_path() {
  local url="$1"
  local cache_key

  # Create hash of URL for cache key
  cache_key="$(echo -n "$url" | sha256sum 2>/dev/null | awk '{print $1}' || echo -n "$url" | shasum -a 256 | awk '{print $1}')"

  echo "${CACHE_DIR}/${cache_key}.json"
}

# Check if cache is valid
is_cache_valid() {
  local cache_file="$1"

  if [[ ! -f "$cache_file" ]]; then
    return 1
  fi

  # Check age
  local cache_age
  local current_time

  if [[ "$OSTYPE" == "darwin"* ]]; then
    cache_age=$(stat -f %m "$cache_file")
    current_time=$(date +%s)
  else
    cache_age=$(stat -c %Y "$cache_file")
    current_time=$(date +%s)
  fi

  local age_diff=$((current_time - cache_age))

  if [[ $age_diff -gt $CACHE_TTL ]]; then
    return 1
  fi

  return 0
}

# Get cached response
get_cached() {
  local url="$1"
  local cache_file

  cache_file="$(get_cache_path "$url")"

  if is_cache_valid "$cache_file"; then
    cat "$cache_file"
    return 0
  fi

  return 1
}

# Save response to cache
save_to_cache() {
  local url="$1"
  local response="$2"
  local cache_file

  init_cache
  cache_file="$(get_cache_path "$url")"

  echo "$response" > "$cache_file"
}

# Clear all cache
clear_cache() {
  if [[ -d "$CACHE_DIR" ]]; then
    rm -rf "${CACHE_DIR:?}"/*
    echo "Cache cleared"
  fi
}

# Clear old cache entries
clean_cache() {
  if [[ ! -d "$CACHE_DIR" ]]; then
    return 0
  fi

  local current_time
  current_time=$(date +%s)

  find "$CACHE_DIR" -type f -name "*.json" | while read -r cache_file; do
    local cache_age

    if [[ "$OSTYPE" == "darwin"* ]]; then
      cache_age=$(stat -f %m "$cache_file")
    else
      cache_age=$(stat -c %Y "$cache_file")
    fi

    local age_diff=$((current_time - cache_age))

    if [[ $age_diff -gt $CACHE_TTL ]]; then
      rm -f "$cache_file"
    fi
  done
}

# Get cache stats
cache_stats() {
  if [[ ! -d "$CACHE_DIR" ]]; then
    echo "Cache directory does not exist"
    return 0
  fi

  local total_files
  local total_size
  local oldest_file
  local newest_file

  total_files=$(find "$CACHE_DIR" -type f -name "*.json" | wc -l | tr -d ' ')

  if [[ "$total_files" -eq 0 ]]; then
    echo "Cache is empty"
    return 0
  fi

  if command -v du >/dev/null 2>&1; then
    total_size=$(du -sh "$CACHE_DIR" 2>/dev/null | awk '{print $1}')
  else
    total_size="unknown"
  fi

  echo "Cache Statistics:"
  echo "  Location: $CACHE_DIR"
  echo "  Files: $total_files"
  echo "  Size: $total_size"
  echo "  TTL: ${CACHE_TTL}s ($(($CACHE_TTL / 60)) minutes)"
}
