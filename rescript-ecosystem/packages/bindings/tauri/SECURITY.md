# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

Please report security vulnerabilities by opening a private security advisory on GitHub.

Do not report security vulnerabilities through public GitHub issues.

## Security Considerations

### Tauri IPC Security

- Always validate command inputs on the Rust side
- Use Tauri's capability system to restrict API access
- Never trust data from the frontend without validation

### Plugin Permissions

- Filesystem plugin: Scope paths appropriately in tauri.conf.json
- Dialog plugin: Consider what file types users can select
- Shell plugin: Be careful with command execution

## Best Practices

1. Keep Tauri and dependencies updated
2. Use the command bridge pattern for type-safe IPC
3. Validate all user input on both frontend and backend
4. Follow Tauri's security recommendations: https://tauri.app/security/
