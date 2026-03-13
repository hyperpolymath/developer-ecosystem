# Release Process

This document describes how to release a new version of Synapse.

## Version Numbering

Synapse follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes to CLI interface or generated output format
- **MINOR**: New features, new supported types, template improvements
- **PATCH**: Bug fixes, documentation updates

Current version: See `VERSION` file.

## Pre-Release Checklist

Before cutting a release:

- [ ] All CI pipelines passing
- [ ] `zig build test` passes locally
- [ ] `just validate` passes (RSR compliance)
- [ ] CHANGELOG.md updated with release date
- [ ] VERSION file updated
- [ ] No uncommitted changes

## Release Steps

### 1. Update Version

```bash
# Edit VERSION file
echo "0.2.0" > VERSION

# Update CHANGELOG.md
# Change [Unreleased] to [0.2.0] - YYYY-MM-DD
```

### 2. Commit Release

```bash
git add VERSION CHANGELOG.md
git commit -m "release: v0.2.0"
```

### 3. Tag Release

```bash
git tag -a v0.2.0 -m "Release v0.2.0"
git push origin main --tags
```

### 4. GitLab Release

The CI pipeline will automatically:
1. Build release binaries
2. Create release artifacts
3. Upload to GitLab releases

### 5. Post-Release

```bash
# Start new development cycle
echo "0.3.0-dev" > VERSION

# Add new [Unreleased] section to CHANGELOG.md
git add VERSION CHANGELOG.md
git commit -m "chore: start v0.3.0 development"
```

## Release Artifacts

Each release includes:

| Artifact | Description |
|----------|-------------|
| `synapse-vX.Y.Z-linux-x86_64.tar.gz` | Linux binary + docs |
| `synapse-vX.Y.Z-macos-arm64.tar.gz` | macOS Apple Silicon |
| `synapse-vX.Y.Z-macos-x86_64.tar.gz` | macOS Intel |

## Hotfix Process

For critical fixes:

1. Branch from release tag: `git checkout -b hotfix/v0.1.1 v0.1.0`
2. Apply fix
3. Update VERSION to `0.1.1`
4. Update CHANGELOG
5. Tag and release
6. Merge fix back to main

## Alpha/Beta Releases

Pre-release versions use suffixes:

- `0.1.0-alpha` - Feature incomplete, API unstable
- `0.1.0-beta` - Feature complete, API stabilizing
- `0.1.0-rc.1` - Release candidate, final testing
- `0.1.0` - Stable release

Tag accordingly: `v0.1.0-alpha`, `v0.1.0-beta`, etc.
