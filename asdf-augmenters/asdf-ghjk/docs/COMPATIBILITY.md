# Compatibility Matrix

This document outlines the compatibility of asdf-ghjk across different platforms, asdf versions, and ghjk versions.

## Platform Support

| Platform | Architecture | Status | Tested | Notes |
|----------|-------------|---------|--------|-------|
| Linux | x86_64 | ✅ Supported | ✅ Yes | All major distributions |
| Linux | aarch64 (ARM64) | ✅ Supported | ✅ Yes | Including Raspberry Pi 4+ |
| macOS | x86_64 (Intel) | ✅ Supported | ✅ Yes | macOS 10.15+ |
| macOS | arm64 (Apple Silicon) | ✅ Supported | ✅ Yes | M1, M2, M3 chips |
| Windows | x86_64 | ❌ Not Supported | ❌ No | May work with WSL |
| Windows | WSL2 | ⚠️ Experimental | ⚠️ Limited | Use Linux x86_64 build |
| FreeBSD | x86_64 | ❌ Not Supported | ❌ No | ghjk doesn't support |

### Linux Distributions

Tested and working:

- ✅ Ubuntu 20.04, 22.04, 24.04
- ✅ Debian 11, 12
- ✅ Fedora 38, 39, 40
- ✅ CentOS Stream 8, 9
- ✅ RHEL 8, 9
- ✅ Arch Linux (latest)
- ✅ Alpine Linux 3.18+ (with bash installed)
- ✅ Amazon Linux 2, 2023

Should work but untested:
- ⚠️ openSUSE
- ⚠️ Gentoo
- ⚠️ Void Linux

### macOS Versions

| macOS Version | Intel | Apple Silicon | Status |
|---------------|-------|---------------|---------|
| 14 (Sonoma) | ✅ | ✅ | Fully supported |
| 13 (Ventura) | ✅ | ✅ | Fully supported |
| 12 (Monterey) | ✅ | ✅ | Fully supported |
| 11 (Big Sur) | ✅ | ✅ | Fully supported |
| 10.15 (Catalina) | ✅ | N/A | Should work |
| 10.14 and older | ⚠️ | N/A | May work, untested |

## asdf Versions

| asdf Version | Status | Notes |
|--------------|---------|-------|
| 0.14.x | ✅ Recommended | Latest stable |
| 0.13.x | ✅ Supported | Tested |
| 0.12.x | ✅ Supported | Tested |
| 0.11.x | ⚠️ May work | Untested |
| 0.10.x | ⚠️ May work | Untested |
| < 0.10 | ❌ Not supported | Too old |

## ghjk Versions

All ghjk versions published on GitHub releases are supported.

| Version Range | Status | Notes |
|---------------|---------|-------|
| 0.3.x | ✅ Fully supported | Current stable series |
| 0.2.x | ✅ Supported | Older stable |
| 0.1.x | ✅ Supported | Early releases |
| Pre-releases | ✅ Supported | Alpha, beta, rc versions |

### Known Issues by Version

- **< 0.3.0**: Some versions may have different binary naming
- **RC versions**: May have different archive structures

## Shell Compatibility

| Shell | Status | Notes |
|-------|---------|-------|
| Bash 4.0+ | ✅ Required | Primary shell |
| Bash 3.x | ❌ Not supported | Too old |
| Zsh | ✅ Supported | Via asdf |
| Fish | ✅ Supported | Via asdf |
| Dash | ⚠️ Limited | asdf may not work |
| sh | ❌ Not supported | Bash required |

## Dependencies

### Required Dependencies

| Tool | Minimum Version | Status | Notes |
|------|----------------|---------|-------|
| bash | 4.0 | Required | Script interpreter |
| curl | 7.0 | Required | Downloads |
| tar | 1.0 | Required | Archive extraction |
| grep | 2.5 | Required | Text processing |
| sort | 8.0 | Required | Version sorting |

### ghjk Runtime Dependencies

These are checked at install time and warned if missing:

| Tool | Required For | Notes |
|------|-------------|-------|
| git | ghjk operation | Version control |
| curl | ghjk operation | HTTP requests |
| tar | ghjk operation | Archive handling |
| unzip | ghjk operation | ZIP extraction |
| zstd | ghjk operation | Compression |

### Optional Dependencies

| Tool | Purpose | Notes |
|------|---------|-------|
| sha256sum | Checksum verification | Or shasum on macOS |
| shellcheck | Development/linting | Not required for usage |

## CI/CD Compatibility

| Platform | Status | Tested | Notes |
|----------|---------|--------|-------|
| GitHub Actions | ✅ Supported | ✅ Yes | Ubuntu, macOS runners |
| GitLab CI | ✅ Supported | ✅ Yes | Docker images |
| CircleCI | ✅ Supported | ✅ Yes | Linux, macOS |
| Travis CI | ✅ Should work | ⚠️ Limited | Similar to others |
| Jenkins | ✅ Should work | ⚠️ Limited | Via shell |
| Buildkite | ✅ Should work | ⚠️ Limited | Via shell |
| Azure Pipelines | ✅ Should work | ⚠️ Limited | Linux, macOS agents |

## Container Compatibility

| Base Image | Status | Notes |
|------------|---------|-------|
| ubuntu:22.04 | ✅ Recommended | Well tested |
| ubuntu:20.04 | ✅ Supported | Tested |
| debian:12 | ✅ Supported | Tested |
| debian:11 | ✅ Supported | Should work |
| alpine:3.18+ | ⚠️ Limited | Requires bash install |
| fedora:latest | ✅ Supported | Should work |
| amazonlinux:2023 | ✅ Supported | Should work |

## Known Incompatibilities

### Operating Systems

- ❌ Windows native (cmd, PowerShell)
- ❌ FreeBSD
- ❌ Solaris
- ❌ AIX

### Architectures

- ❌ 32-bit systems (i386, i686, armv7l)
- ❌ RISC-V (ghjk doesn't provide builds)
- ❌ PowerPC
- ❌ s390x

### Environments

- ❌ BusyBox (limited shell features)
- ❌ Minimal containers without basic tools

## Performance Characteristics

### Download Speeds

Typical download times for ghjk binary (~10-50 MB):

- Good connection (100 Mbps): 1-5 seconds
- Average connection (10 Mbps): 10-30 seconds
- Slow connection (1 Mbps): 1-5 minutes

### Installation Time

- Download: 1-30 seconds (depending on connection)
- Extraction: 1-2 seconds
- Verification: < 1 second
- **Total**: ~2-35 seconds

### Disk Space

Per version installed:
- Downloaded archive: 10-50 MB
- Extracted binary: 10-50 MB
- **Total per version**: ~20-100 MB

With 5 versions installed: ~100-500 MB

## Compatibility Testing

### How We Test

- ✅ Unit tests on multiple platforms (GitHub Actions)
- ✅ Integration tests with real installations
- ✅ Manual testing on developer machines
- ⚠️ Community reports for less common platforms

### Report Compatibility Issues

If you encounter compatibility issues:

1. Check this document
2. Check [existing issues](https://github.com/Hyperpolymath/asdf-ghjk/issues)
3. Report new issues with:
   - OS and version
   - Architecture
   - asdf version
   - Error messages
   - Steps to reproduce

## Version Support Policy

- **Current stable ghjk versions**: Fully supported
- **Old ghjk versions**: Best effort support
- **Pre-release ghjk versions**: Supported but may have issues
- **asdf versions**: Support latest 3 minor versions

## Future Compatibility

### Planned Support

- 🔄 Continued support for new ghjk releases
- 🔄 Continued support for new asdf releases
- 🔄 Platform support as ghjk adds them

### No Plans For

- ❌ Windows native support (unless ghjk adds it)
- ❌ 32-bit architecture support
- ❌ Non-Unix operating systems

---

**Last Updated**: 2024-11-22

For the latest compatibility information, check:
- [ghjk releases](https://github.com/metatypedev/ghjk/releases)
- [asdf compatibility](https://asdf-vm.com)
- [Plugin issues](https://github.com/Hyperpolymath/asdf-ghjk/issues)
