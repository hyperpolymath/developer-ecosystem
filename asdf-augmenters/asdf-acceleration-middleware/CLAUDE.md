# CLAUDE.md

This document provides context and guidelines for Claude Code when working with the asdf-acceleration-middleware project.

## Project Overview

**asdf-acceleration-middleware** is a middleware project designed to accelerate ASDF (Another System Definition Facility) operations.

### Purpose

This middleware aims to optimize and accelerate ASDF-related workflows by providing caching, parallel processing, or other performance enhancements.

## Project Structure

```
asdf-acceleration-middleware/
├── .git/           # Git repository
└── CLAUDE.md       # This file
```

## Development Guidelines

### Code Style

- Follow consistent naming conventions
- Write clear, self-documenting code
- Include comments for complex logic
- Maintain comprehensive test coverage

### Testing

- Write unit tests for all new features
- Run tests before committing changes
- Ensure all tests pass in CI/CD pipeline

### Commits

- Use clear, descriptive commit messages
- Follow conventional commit format when applicable
- Keep commits focused and atomic

## Common Tasks

### Setting Up Development Environment

```bash
# Clone the repository
git clone <repository-url>
cd asdf-acceleration-middleware

# Install dependencies (when available)
npm install  # or yarn install, pip install -r requirements.txt, etc.
```

### Running Tests

```bash
# Run test suite (update based on actual test framework)
npm test
```

### Building

```bash
# Build the project (update based on actual build process)
npm run build
```

## Architecture Notes

### Key Components

(To be documented as the project develops)

### Dependencies

(To be documented as dependencies are added)

## Working with Claude Code

### Helpful Context

When working on this project with Claude Code:

1. **ASDF Knowledge**: This project relates to ASDF, a build system primarily used in Common Lisp
2. **Middleware Pattern**: Middleware typically sits between systems to enhance or modify behavior
3. **Performance Focus**: The "acceleration" aspect suggests optimization and performance are key concerns

### Common Requests

- "Add caching layer for ASDF operations"
- "Implement parallel processing for build tasks"
- "Create benchmarks to measure acceleration improvements"
- "Add logging and monitoring capabilities"

## Resources

- [ASDF Documentation](https://asdf.common-lisp.dev/)
- Project repository: (add repository URL)
- Issue tracker: (add issue tracker URL)

## Contributing

(To be documented based on team preferences)

## License

(To be specified)

---

**Note**: This is a living document. Update it as the project evolves to help Claude Code better understand the codebase and development practices.
