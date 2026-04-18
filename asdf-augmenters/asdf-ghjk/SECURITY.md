# Security Policy

## Supported Versions

Currently supported versions of asdf-ghjk:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x:                |

## Security Considerations

### Download Security

This plugin downloads ghjk binaries from GitHub releases. Security measures:

1. **HTTPS Only**: All downloads use HTTPS
2. **Checksum Verification**: SHA256 checksums are verified when available
3. **Official Sources**: Only downloads from official `metatypedev/ghjk` repository
4. **Retry Logic**: Failed downloads are retried to prevent partial downloads

### GitHub API Token

If you use `GITHUB_API_TOKEN`:

- **Minimal Permissions**: Token only needs public repository read access
- **Storage**: Store in environment variables, never commit to version control
- **Rotation**: Rotate tokens regularly
- **Scope**: Create tokens with minimal required scopes

Creating a secure token:
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Set expiration (recommended: 90 days)
4. **Don't select any scopes** (public repo access is default)
5. Generate and store securely

### Script Security

All shell scripts follow security best practices:

- **Strict Mode**: `set -euo pipefail` in all scripts
- **Input Validation**: All user inputs are validated
- **Path Safety**: Paths are properly quoted and validated
- **No `eval`**: No use of `eval` or similar dangerous constructs
- **ShellCheck**: All scripts pass ShellCheck security checks

### Dependencies

This plugin has minimal dependencies:

**Required (assumed to be system-provided):**
- bash
- curl
- tar
- grep
- sort

**Runtime (for ghjk itself):**
- git
- curl
- tar
- unzip
- zstd

All dependencies should be installed from trusted sources (official package managers).

## Reporting a Vulnerability

### Where to Report

**DO NOT** open public issues for security vulnerabilities.

Instead, please report security issues via one of these methods:

1. **GitHub Security Advisories** (preferred)
   - Go to https://github.com/Hyperpolymath/asdf-ghjk/security/advisories
   - Click "Report a vulnerability"
   - Fill out the form with details

2. **Private Email**
   - Email: [security contact needed]
   - Subject: "[SECURITY] asdf-ghjk vulnerability report"
   - Include: Detailed description, steps to reproduce, impact assessment

### What to Include

Please include as much information as possible:

- **Description**: Clear description of the vulnerability
- **Impact**: What can an attacker do? What is the risk?
- **Reproduction**: Step-by-step instructions to reproduce
- **Affected Versions**: Which versions are affected?
- **Suggested Fix**: If you have ideas for fixing it
- **Disclosure Timeline**: Your preferred disclosure timeline

### Response Timeline

We will acknowledge your report within **48 hours** and provide:

1. Confirmation of the issue
2. Assessment of severity
3. Estimated timeline for a fix
4. Communication plan for disclosure

### Security Update Process

When a security issue is confirmed:

1. **Fix Development**: Develop and test fix privately
2. **CVE Assignment**: Request CVE if applicable
3. **Release**: Create security release
4. **Disclosure**: Publish security advisory
5. **Notification**: Notify users via GitHub and documentation

### Disclosure Policy

We follow **responsible disclosure**:

- **Coordinated Disclosure**: Work with reporter on timeline
- **Typical Timeline**: 90 days from report to public disclosure
- **Early Disclosure**: If actively exploited or fix is available
- **Credit**: Security researchers are credited (unless they prefer anonymity)

## Security Best Practices for Users

### Installation Security

```bash
# Verify plugin source
asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git

# Verify it was added correctly
asdf plugin list --urls | grep ghjk
```

### Token Security

```bash
# Store in shell profile, not in scripts
echo 'export GITHUB_API_TOKEN="ghp_..."' >> ~/.bashrc

# Never commit tokens
echo 'GITHUB_API_TOKEN' >> .gitignore

# Use environment-specific tokens in CI
# GitHub Actions: Use secrets
# GitLab CI: Use protected variables
```

### Verification

```bash
# After installation, verify the binary
ghjk --version

# Check where it's installed
which ghjk
ls -la ~/.asdf/installs/ghjk/

# Verify checksum if you saved it
sha256sum ~/.asdf/installs/ghjk/<version>/ghjk
```

### Update Regularly

```bash
# Update plugin
asdf plugin update ghjk

# Update ghjk itself
asdf install ghjk latest
asdf global ghjk latest
```

## Known Security Considerations

### GitHub API Rate Limiting

- **Risk**: Unauthenticated requests limited to 60/hour
- **Mitigation**: Use `GITHUB_API_TOKEN` for higher limits
- **Impact**: Low (only affects listing/downloading)

### Man-in-the-Middle (MITM)

- **Risk**: Network interception during download
- **Mitigation**: HTTPS only, checksum verification
- **Impact**: Low (checksums detect tampering)

### Supply Chain

- **Risk**: Compromised ghjk releases
- **Mitigation**: Verify checksums, download from official sources
- **Impact**: Medium (depends on ghjk project security)
- **Note**: This plugin does not control ghjk releases, only facilitates installation

### Local File Permissions

- **Risk**: Installed files readable by all users
- **Mitigation**: Follow asdf default permissions (user-only)
- **Impact**: Low (asdf handles permissions)

## Security Checklist for Contributors

Before submitting code:

- [ ] All user inputs are validated
- [ ] All file paths are properly quoted
- [ ] No use of `eval`, `source` on untrusted input, or `exec` with user data
- [ ] ShellCheck passes with no warnings
- [ ] Dependencies are from trusted sources
- [ ] Secrets are not hardcoded
- [ ] Error messages don't leak sensitive information
- [ ] Tests include security-relevant cases

## Third-Party Security

### asdf

This plugin depends on asdf:
- **Security**: https://github.com/asdf-vm/asdf/security
- **Updates**: Keep asdf updated

### ghjk

This plugin installs ghjk:
- **Security**: https://github.com/metatypedev/ghjk/security
- **Note**: We don't control ghjk security, only facilitate installation

## Compliance

This plugin:
- ✅ Follows OWASP secure coding practices
- ✅ Uses HTTPS for all downloads
- ✅ Validates all inputs
- ✅ Follows principle of least privilege
- ✅ Provides clear error messages without leaking sensitive data
- ✅ Uses secure random generation (when applicable)
- ✅ Properly handles file permissions

## Contact

For security concerns:
- Security Issues: Use GitHub Security Advisories
- General Security Questions: Open a discussion
- Urgent Issues: [Contact method needed]

---

**Last Updated**: 2025-12-18
**Next Review**: Before v0.2.0 release
