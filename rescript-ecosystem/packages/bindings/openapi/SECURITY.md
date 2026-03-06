# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.x     | :white_check_mark: |

## Reporting a Vulnerability

Please report security vulnerabilities by opening a private security advisory at:
https://github.com/hyperpolymath/rescript-openapi/security/advisories/new

Do NOT open public issues for security vulnerabilities.

## Security Considerations

This tool generates code from OpenAPI specifications. When using it:

1. **Validate your OpenAPI specs** - Malformed specs could generate invalid code
2. **Review generated code** - Especially for APIs you don't control
3. **Keep dependencies updated** - Especially `rescript-schema` for validation

## Code Generation Safety

The generated code:
- Uses `rescript-schema` for runtime validation of API responses
- Does not execute arbitrary code from specs
- Sanitizes identifiers to valid ReScript names
