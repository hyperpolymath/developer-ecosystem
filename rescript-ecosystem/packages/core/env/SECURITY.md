# Security Policy

We take security seriously. We appreciate your efforts to responsibly disclose vulnerabilities.

## Reporting a Vulnerability

### Preferred Method: GitHub Security Advisories

Report security vulnerabilities through GitHub's Security Advisory feature:

1. Navigate to [Report a Vulnerability](https://github.com/hyperpolymath/rescript-env/security/advisories/new)
2. Click **"Report a vulnerability"**
3. Complete the form with as much detail as possible
4. Submit — we'll receive a private notification

> **⚠️ Important:** Do not report security vulnerabilities through public GitHub issues, pull requests, or discussions.

### Alternative: Email

If you cannot use GitHub Security Advisories, email: `hyperpolymath@proton.me`

## What to Include

- **Description**: Clear explanation of the vulnerability
- **Impact**: What an attacker could achieve
- **Affected versions**: Which versions are affected
- **Reproduction steps**: How to reproduce the issue
- **Proof of concept**: Code or examples if available

## Response Timeline

| Stage | Timeframe |
|-------|-----------|
| Initial Response | 48 hours |
| Triage | 7 days |
| Status Updates | Every 7 days |
| Resolution Target | 90 days |

## Scope

### In Scope

- The `rescript-env` library code
- Security issues in the API
- Type safety bypasses

### Out of Scope

- Third-party dependencies (report to upstream)
- Theoretical issues without proof of concept
- Social engineering

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.1.x (latest) | ✅ Yes |

## Security Considerations

This library handles environment variables, which may contain secrets. Users should:

- Never log environment variable values in production
- Use `Env.getExn` for required secrets to fail fast
- Consider using a secrets manager for sensitive data

## Safe Harbour

If you conduct security research in good faith following this policy:

- We will not initiate legal action against you
- We will not report your activity to law enforcement
- We will work with you to resolve issues

---

*Thank you for helping keep rescript-env and its users safe.*
