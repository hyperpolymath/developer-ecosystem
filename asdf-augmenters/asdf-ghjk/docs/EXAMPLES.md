# Usage Examples

This document provides real-world examples of using asdf-ghjk.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Project Setup](#project-setup)
- [CI/CD Integration](#cicd-integration)
- [Multiple Projects](#multiple-projects)
- [Advanced Workflows](#advanced-workflows)

## Basic Usage

### Install and Use Latest Version

```bash
# Install the plugin
asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git

# Install latest ghjk
asdf install ghjk latest

# Set as global default
asdf global ghjk latest

# Verify installation
ghjk --version
```

### Install Specific Version

```bash
# List all available versions
asdf list all ghjk

# Install a specific version
asdf install ghjk 0.3.2

# Use it globally
asdf global ghjk 0.3.2
```

## Project Setup

### Initialize a New Project

```bash
# Create project directory
mkdir my-project
cd my-project

# Set local ghjk version
asdf local ghjk 0.3.2

# Initialize ghjk with TypeScript support
ghjk init ts

# View generated configuration
cat ghjk.ts
```

### Basic Project Configuration

Create a `ghjk.ts` file:

```typescript
// ghjk.ts
export { sophon } from "https://deno.land/x/ghjk/mod.ts";

sophon({
  // Define environment variables
  env: {
    NODE_ENV: "development",
    API_URL: "http://localhost:3000",
  },

  // Install development tools
  installs: [
    { name: "node", version: "20.0.0" },
    { name: "python", version: "3.11" },
  ],

  // Define tasks
  tasks: {
    dev: "npm run dev",
    test: "npm test",
    build: "npm run build",
    lint: "npm run lint",
  },
});
```

### Activate Environment

```bash
# Load the ghjk environment
ghjk env

# Or run tasks directly
ghjk run dev
ghjk run test
```

## CI/CD Integration

### GitHub Actions

`.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install asdf
        uses: asdf-vm/actions/setup@v3

      - name: Add ghjk plugin
        run: |
          asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git

      - name: Install ghjk from .tool-versions
        run: |
          asdf install ghjk

      - name: Run tests with ghjk
        run: |
          ghjk run test

      - name: Build with ghjk
        run: |
          ghjk run build
```

### GitLab CI

`.gitlab-ci.yml`:

```yaml
image: ubuntu:latest

variables:
  ASDF_DIR: "${CI_PROJECT_DIR}/.asdf"
  ASDF_DATA_DIR: "${CI_PROJECT_DIR}/.asdf"

before_script:
  - apt-get update && apt-get install -y git curl tar unzip zstd
  - git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
  - echo '. $HOME/.asdf/asdf.sh' >> ~/.bashrc
  - source ~/.bashrc
  - asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git
  - asdf install

test:
  script:
    - ghjk run test

build:
  script:
    - ghjk run build
  artifacts:
    paths:
      - dist/
```

### CircleCI

`.circleci/config.yml`:

```yaml
version: 2.1

jobs:
  test:
    docker:
      - image: cimg/base:stable
    steps:
      - checkout

      - run:
          name: Install asdf
          command: |
            git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
            echo '. $HOME/.asdf/asdf.sh' >> $BASH_ENV

      - run:
          name: Install ghjk
          command: |
            asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git
            asdf install ghjk

      - run:
          name: Run tests
          command: ghjk run test

workflows:
  version: 2
  test:
    jobs:
      - test
```

## Multiple Projects

### Different Versions per Project

```bash
# Project A uses ghjk 0.3.2
cd ~/projects/project-a
asdf local ghjk 0.3.2
cat .tool-versions
# ghjk 0.3.2

# Project B uses latest ghjk
cd ~/projects/project-b
asdf local ghjk latest
cat .tool-versions
# ghjk 0.3.2

# asdf automatically switches versions when you cd
```

### Shared Configuration

`~/.tool-versions` (global defaults):

```
ghjk 0.3.2
nodejs 20.0.0
python 3.11.0
```

Project-specific overrides:

```bash
cd my-project
asdf local ghjk 0.3.1  # Override just ghjk
# Other tools (nodejs, python) inherited from global
```

## Advanced Workflows

### Multi-Environment Setup

```typescript
// ghjk.ts
export { sophon } from "https://deno.land/x/ghjk/mod.ts";

const baseConfig = {
  installs: [
    { name: "node", version: "20.0.0" },
  ],
};

const developmentConfig = {
  ...baseConfig,
  env: {
    NODE_ENV: "development",
    DEBUG: "true",
  },
  tasks: {
    dev: "npm run dev",
    test: "npm test",
  },
};

const productionConfig = {
  ...baseConfig,
  env: {
    NODE_ENV: "production",
  },
  tasks: {
    start: "npm start",
  },
};

// Use based on environment variable
const config = Deno.env.get("ENV") === "production"
  ? productionConfig
  : developmentConfig;

sophon(config);
```

Usage:

```bash
# Development
ghjk run dev

# Production
ENV=production ghjk run start
```

### Monorepo Setup

```typescript
// ghjk.ts (root)
export { sophon } from "https://deno.land/x/ghjk/mod.ts";

sophon({
  installs: [
    { name: "node", version: "20.0.0" },
    { name: "python", version: "3.11" },
  ],

  tasks: {
    // Root tasks
    "test:all": "npm run test --workspaces",
    "build:all": "npm run build --workspaces",
    "lint:all": "npm run lint --workspaces",

    // Frontend tasks
    "dev:frontend": "npm run dev --workspace=packages/frontend",
    "build:frontend": "npm run build --workspace=packages/frontend",

    // Backend tasks
    "dev:backend": "npm run dev --workspace=packages/backend",
    "build:backend": "npm run build --workspace=packages/backend",

    // Run both
    dev: "concurrently 'ghjk run dev:frontend' 'ghjk run dev:backend'",
  },
});
```

### Docker Integration

`Dockerfile`:

```dockerfile
FROM ubuntu:22.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git curl tar unzip zstd \
    && rm -rf /var/lib/apt/lists/*

# Install asdf
RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
ENV PATH="/root/.asdf/bin:/root/.asdf/shims:${PATH}"

# Install ghjk plugin
RUN asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git

# Copy project files
WORKDIR /app
COPY .tool-versions ./
COPY ghjk.ts ./

# Install ghjk from .tool-versions
RUN asdf install

# Install project dependencies
COPY package*.json ./
RUN ghjk run install

# Copy application code
COPY . .

# Build application
RUN ghjk run build

# Run application
CMD ["ghjk", "run", "start"]
```

### Testing Multiple Versions

Test your project against multiple ghjk versions:

```bash
#!/bin/bash
# test-versions.sh

set -e

versions=("0.3.0" "0.3.1" "0.3.2")

for version in "${versions[@]}"; do
  echo "Testing with ghjk $version"

  # Install version
  asdf install ghjk "$version"
  asdf local ghjk "$version"

  # Run tests
  if ghjk run test; then
    echo "✅ Tests passed with $version"
  else
    echo "❌ Tests failed with $version"
    exit 1
  fi
done

echo "All versions tested successfully!"
```

### Automatic Version Installation

Add to your project's setup script:

```bash
#!/bin/bash
# setup.sh

set -e

echo "Setting up project..."

# Check if asdf is installed
if ! command -v asdf &> /dev/null; then
  echo "Error: asdf is not installed"
  echo "Install from: https://asdf-vm.com"
  exit 1
fi

# Install ghjk plugin if not present
if ! asdf plugin list | grep -q ghjk; then
  echo "Adding ghjk plugin..."
  asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git
fi

# Install tools from .tool-versions
echo "Installing tools..."
asdf install

# Verify ghjk is working
echo "Verifying ghjk installation..."
ghjk --version

# Install project dependencies
echo "Installing dependencies..."
ghjk run install

echo "Setup complete! Run 'ghjk run dev' to start development"
```

### Shell Integration

Add to your shell profile for convenience:

```bash
# ~/.bashrc or ~/.zshrc

# ghjk aliases
alias gd='ghjk run dev'
alias gt='ghjk run test'
alias gb='ghjk run build'
alias gl='ghjk run lint'

# Quick ghjk version switching
ghjk-use() {
  asdf local ghjk "$1"
  echo "Switched to ghjk $1"
  ghjk --version
}

# List installed ghjk versions
alias ghjk-versions='asdf list ghjk'

# Update to latest ghjk
ghjk-update() {
  local latest
  latest=$(asdf list all ghjk | tr ' ' '\n' | tail -1)
  echo "Installing ghjk $latest..."
  asdf install ghjk "$latest"
  asdf global ghjk "$latest"
  echo "Updated to ghjk $latest"
}
```

## Tips and Tricks

### Cache GitHub API Responses

Reduce API calls by caching:

```bash
# Set a long-lived GitHub token
export GITHUB_API_TOKEN="ghp_your_token_here"

# Or use conditional requests (plugin handles this)
```

### Parallel Installation

Install multiple versions in parallel:

```bash
# In separate terminals or with GNU parallel
asdf install ghjk 0.3.0 &
asdf install ghjk 0.3.1 &
asdf install ghjk 0.3.2 &
wait
```

### Backup and Restore

Export your tool versions:

```bash
# Backup
cp .tool-versions .tool-versions.backup

# Restore
cp .tool-versions.backup .tool-versions
asdf install  # Install all tools
```

### Automate Updates

Create a cron job to check for updates:

```bash
# check-ghjk-updates.sh
#!/bin/bash

latest=$(asdf list all ghjk | tr ' ' '\n' | tail -1)
current=$(asdf current ghjk | awk '{print $2}')

if [ "$latest" != "$current" ]; then
  echo "New ghjk version available: $latest (current: $current)"
  # Optionally auto-install or send notification
fi
```

## Real-World Examples

### Full-Stack Web Application

```typescript
// ghjk.ts
export { sophon } from "https://deno.land/x/ghjk/mod.ts";

sophon({
  env: {
    DATABASE_URL: "postgresql://localhost/myapp_dev",
    REDIS_URL: "redis://localhost:6379",
    NODE_ENV: "development",
  },

  installs: [
    { name: "node", version: "20.0.0" },
    { name: "python", version: "3.11" },
    { name: "postgres", version: "15" },
    { name: "redis", version: "7" },
  ],

  tasks: {
    // Database
    "db:setup": "npm run db:migrate && npm run db:seed",
    "db:reset": "npm run db:drop && npm run db:setup",

    // Development
    dev: "concurrently 'npm run dev:frontend' 'npm run dev:backend'",
    "dev:frontend": "cd frontend && npm run dev",
    "dev:backend": "cd backend && npm run dev",

    // Testing
    test: "npm run test:unit && npm run test:integration",
    "test:unit": "npm run test --workspaces",
    "test:e2e": "playwright test",

    // Production
    build: "npm run build --workspaces",
    start: "node backend/dist/server.js",
  },
});
```

### Data Science Project

```typescript
// ghjk.ts
export { sophon } from "https://deno.land/x/ghjk/mod.ts";

sophon({
  env: {
    JUPYTER_PORT: "8888",
    PYTHONPATH: "${PWD}/src",
  },

  installs: [
    { name: "python", version: "3.11" },
    { name: "jupyter", version: "latest" },
  ],

  tasks: {
    notebook: "jupyter lab --port=$JUPYTER_PORT",
    train: "python src/train.py",
    evaluate: "python src/evaluate.py",
    "export:model": "python src/export.py",
  },
});
```

## Conclusion

These examples demonstrate the flexibility and power of using ghjk with asdf. Adapt these patterns to your specific needs and workflow.

For more information:
- [ghjk documentation](https://github.com/metatypedev/ghjk)
- [asdf documentation](https://asdf-vm.com)
- [Plugin README](https://github.com/Hyperpolymath/asdf-ghjk)
