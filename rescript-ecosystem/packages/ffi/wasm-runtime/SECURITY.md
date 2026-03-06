# Security Policy

## Supported Versions

We release patches for security vulnerabilities in the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

**DO NOT** open a public issue for security vulnerabilities.

### Secure Reporting Channels

1. **Email**: security@example.com (encrypted preferred)
2. **GitLab Security**: Use GitLab's confidential issue feature
3. **GPG Key**: Available at .well-known/pgp-key.txt

### What to Include

- Type of vulnerability
- Full paths of source file(s) affected
- Location of affected source code (tag/branch/commit)
- Step-by-step reproduction instructions
- Proof-of-concept or exploit code (if available)
- Impact assessment
- Suggested remediation (if available)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Triage**: Within 7 days
- **Fix Development**: 14-90 days (depending on complexity)
- **Public Disclosure**: After fix is released and users have had 14 days to update

### Security Update Process

1. Vulnerability reported via secure channel
2. Maintainers confirm receipt within 48 hours
3. Vulnerability assessed and triaged
4. Fix developed in private security branch
5. Fix tested and reviewed
6. Security advisory drafted
7. Coordinated disclosure with reporter
8. Patch released with security advisory
9. CVE requested (if applicable)

## Security Architecture

### Threat Model

This project operates under the following threat model:

**Trust Boundaries:**
- **Runtime Environment**: Deno/Bun are trusted
- **ReScript Compiler**: Trusted (build-time only)
- **User Code**: Untrusted (sandboxed)
- **Network Input**: Untrusted (validated)

**Attack Vectors:**
1. Malicious HTTP requests
2. Path traversal attacks
3. Prototype pollution
4. ReDoS (Regular Expression DoS)
5. Memory exhaustion
6. Request smuggling
7. CORS bypass
8. Session fixation

### Security Features

**Type Safety:**
- 100% ReScript type-safe code
- No `any` types or unsafe operations
- Compile-time error detection
- Exhaustive pattern matching

**Memory Safety:**
- Automatic memory management (GC)
- No buffer overflows
- No use-after-free
- No null pointer dereferences

**Input Validation:**
- All external input validated
- Path parameters sanitized
- File paths checked for traversal
- JSON parsing with error handling

**Sandboxing:**
- Deno permissions model
- Explicit capability grants
- No ambient authority
- Principle of least privilege

**Rate Limiting:**
- Token bucket algorithm
- Configurable limits
- Per-client tracking
- DoS prevention

**CORS Protection:**
- Configurable origin validation
- Preflight request handling
- Credential control
- Method/header restrictions

### Security Best Practices

**For Users:**
1. Keep dependencies updated
2. Use specific Deno permissions (avoid --allow-all)
3. Implement authentication for sensitive endpoints
4. Use HTTPS in production
5. Enable rate limiting
6. Configure CORS appropriately
7. Validate all user input
8. Use environment variables for secrets
9. Review security advisories regularly
10. Run security audits on production deployments

**For Contributors:**
1. Never commit secrets or credentials
2. Use type-safe patterns (no `Obj.magic`, no `%raw`)
3. Validate all external input
4. Sanitize path parameters
5. Test error handling paths
6. Review for OWASP Top 10 vulnerabilities
7. Run security linters
8. Document security assumptions
9. Follow secure coding guidelines
10. Report vulnerabilities responsibly

## Known Security Considerations

### WebSocket Implementation
- Current implementation is placeholder only
- Full WebSocket support requires proper upgrade handling
- Do not use in production until complete

### File Upload
- File upload validation is basic
- Production use requires additional checks:
  - File type validation (magic bytes, not just extension)
  - Virus scanning
  - Size limits enforcement
  - Filename sanitization
  - Storage quota management

### Session Management
- In-memory sessions only (not distributed)
- Sessions lost on restart
- No session fixation protection yet
- Use external session store for production

### Static File Serving
- Basic path traversal protection
- No caching headers optimization
- No range request support
- Production use should add:
  - ETag support
  - Content-Security-Policy headers
  - X-Content-Type-Options: nosniff
  - Proper cache control

## Cryptography

**Current Status:**
- No cryptographic operations in core runtime
- JWT authentication is placeholder (verify tokens externally)
- No password hashing (use external library)

**Recommendations:**
- Use Web Crypto API for cryptographic operations
- Use bcrypt/argon2 for password hashing
- Use secure random for session IDs
- Implement proper JWT verification
- Use TLS 1.3 for transport security

## Compliance

### Standards Adherence
- OWASP Top 10 (2021) - Partial
- CWE Top 25 (2023) - Monitoring
- RFC 9116 (security.txt) - Implemented

### Security Scanning
- GitLab SAST - Enabled in CI/CD
- Dependency scanning - npm audit
- Container scanning - Enabled for images

## Security Changelog

### Version 0.1.0 (2025-01)
- Initial security policy
- Type-safe core implementation
- Basic input validation
- CORS middleware
- Rate limiting middleware
- Session management (basic)
- Security documentation

## Bug Bounty

Currently no formal bug bounty program. Security researchers are encouraged to report vulnerabilities responsibly. Recognition will be provided in security advisories and CHANGELOG.

## Contact

- **Security Email**: security@example.com
- **PGP Key**: See .well-known/pgp-key.txt
- **Security.txt**: See .well-known/security.txt

---

**Last Updated**: 2025-01-22
**Version**: 1.0.0
