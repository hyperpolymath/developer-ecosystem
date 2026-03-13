# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in Synapse, please report it responsibly.

### Reporting Channel

- **Primary**: Open a confidential issue on GitLab with the `security` label
- **Alternative**: Email the maintainers listed in MAINTAINERS.md

### Response SLA

- **Acknowledgement**: Within 24 hours
- **Initial Assessment**: Within 72 hours
- **Resolution Timeline**: Depends on severity
  - Critical: 7 days
  - High: 14 days
  - Medium: 30 days
  - Low: 90 days

### What to Include

1. Description of the vulnerability
2. Steps to reproduce
3. Potential impact assessment
4. Suggested fix (if any)

### What to Expect

1. We will acknowledge receipt within 24 hours
2. We will provide an initial assessment within 72 hours
3. We will keep you informed of our progress
4. We will credit you in the security advisory (unless you prefer anonymity)

### Security Best Practices

Synapse follows these security principles:

- **Type Safety**: Zig provides compile-time type checking
- **Memory Safety**: Zig's explicit memory management prevents common vulnerabilities
- **No Network Access**: Synapse is a local code generator with no network capabilities
- **Minimal Dependencies**: Reduces supply chain attack surface
- **SPDX Compliance**: All source files include license headers for auditability

### Scope

This security policy covers:

- The Synapse code generator (`src/`)
- Build configuration (`build.zig`)
- Generated Swift code templates

Out of scope:

- User-written Rust structs
- Generated Swift code (user responsibility after generation)
- Third-party tools (Zig compiler, etc.)

## Security Audit History

| Date | Auditor | Scope | Result |
|------|---------|-------|--------|
| 2024-01 | Internal | Initial release | No issues found |

## Disclosure Policy

We follow coordinated disclosure:

1. Reporter notifies us privately
2. We acknowledge and investigate
3. We develop and test a fix
4. We release the fix
5. We publish a security advisory
6. Reporter may publish their findings after advisory
