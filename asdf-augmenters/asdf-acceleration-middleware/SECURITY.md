# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

**Please DO NOT report security vulnerabilities through public GitHub issues.**

### Reporting Process

1. **Email**: Send details to security contact listed in `.well-known/security.txt`
2. **Encryption**: Use PGP key if available (see `.well-known/security.txt`)
3. **Information**: Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity
  - Critical: 7 days
  - High: 14 days
  - Medium: 30 days
  - Low: 90 days

### Disclosure Policy

- We follow **responsible disclosure** practices
- Security advisories will be published after:
  - Fix is available
  - Users have had time to update (typically 7-14 days)
  - Coordination with affected parties

### Security Best Practices

#### For Users

1. **Keep Updated**: Always use the latest version
2. **Verify Downloads**: Check signatures and checksums
3. **Review Permissions**: Understand what access the tool requires
4. **Audit Configurations**: Review generated configs before use
5. **Report Issues**: Help us identify vulnerabilities

#### For Contributors

1. **Input Validation**: Always validate external input
2. **Avoid Shell Injection**: Use safe subprocess APIs (duct)
3. **No Unsafe Rust**: Avoid `unsafe` blocks unless absolutely necessary
4. **Dependency Audits**: Run `cargo audit` regularly
5. **Secrets Management**: Never commit secrets or credentials
6. **Code Review**: All changes require review

### Security Features

#### Built-In Security

- ✅ **Type Safety**: Rust compile-time guarantees
- ✅ **Memory Safety**: No buffer overflows, use-after-free
- ✅ **Safe Subprocess**: `duct` for shell command execution
- ✅ **Input Validation**: Strict parsing and validation
- ✅ **Audit Logging**: Track all operations
- ✅ **SELinux Support**: Context-aware security

#### Security Checks

```bash
# Run security audit
cargo audit

# Check for unsafe code
cargo geiger

# Dependency tree
cargo tree

# License compliance
cargo license
```

### Known Security Considerations

#### 1. Shell Command Execution

The tool executes `asdf` commands via subprocess. Mitigations:
- Input sanitization
- No shell interpolation
- Allowlist of valid commands
- Audit logging

#### 2. Filesystem Access

Requires read/write to:
- `~/.asdf/` directory
- Cache directory
- Configuration files

Mitigations:
- Path validation
- No symbolic link following
- Permission checks

#### 3. Cache Poisoning

Cache could be manipulated. Mitigations:
- Integrity verification
- TTL enforcement
- Cache validation
- Secure permissions (0600)

#### 4. Dependency Chain

Rust dependencies could introduce vulnerabilities. Mitigations:
- `cargo audit` in CI
- Minimal dependency footprint
- Regular updates
- Review of dependency changes

### Security Tooling

```bash
# Audit dependencies
just audit

# Check for unsafe code
just security-check

# Verify RSR compliance
just rsr-verify

# Run all security checks
just security-full
```

### Threat Model

#### In Scope

- Command injection via asdf arguments
- Path traversal attacks
- Cache poisoning
- Dependency vulnerabilities
- Denial of service (resource exhaustion)

#### Out of Scope

- Vulnerabilities in asdf itself
- OS-level exploits
- Social engineering
- Physical access attacks

### Security Contacts

See `.well-known/security.txt` for current contact information.

### Security Hall of Fame

We acknowledge security researchers who responsibly disclose vulnerabilities:

(None yet - be the first!)

### References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Rust Security Guidelines](https://anssi-fr.github.io/rust-guide/)
- [RFC 9116: security.txt](https://www.rfc-editor.org/rfc/rfc9116.html)
- [CWE Top 25](https://cwe.mitre.org/top25/)

---

**Last Updated**: 2024-11-22
