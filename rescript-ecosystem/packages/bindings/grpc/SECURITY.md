# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in rescript-grpc, please report it by:

1. **Email**: Send details to security@hyperpolymath.org
2. **Private Disclosure**: Use GitHub's private vulnerability reporting feature

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We aim to respond to security reports within 48 hours and will work with you to understand and address the issue promptly.

## Security Considerations

### Code Generation

The protoc plugin (`protoc-gen-rescript`) generates ReScript code from `.proto` definitions. Generated code should be reviewed before use in production, especially when:

- Processing untrusted `.proto` files
- Generated code handles sensitive data

### JSON Parsing

The JSON codec uses standard ReScript JSON parsing. Input validation is handled at the type level, but malformed JSON may cause parsing failures.

### gRPC-web Clients

Generated gRPC-web clients make HTTP requests to configured endpoints. Ensure:

- Use HTTPS in production
- Validate server certificates
- Apply appropriate authentication headers

## Dependencies

This project uses:

- **Rust/Cargo** for the protoc plugin (dependency audit via `cargo audit`)
- **ReScript** for runtime (minimal dependencies)
- **prost** for protobuf parsing (well-maintained, widely used)

Run `cargo audit` periodically to check for known vulnerabilities in Rust dependencies.
