# asdf-yj

[![Build](https://github.com/hyperpolymath/asdf-yj-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/hyperpolymath/asdf-yj-plugin/actions/workflows/build.yml)
[![Lint](https://github.com/hyperpolymath/asdf-yj-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/hyperpolymath/asdf-yj-plugin/actions/workflows/lint.yml)
image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0,link="https://github.com/hyperpolymath/palimpsest-license"]

[asdf](https://asdf-vm.com) plugin for [yj](https://github.com/sclevine/yj).

YAML/JSON/TOML converter.

## Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)

## Dependencies

- `bash`, `curl`, `tar`, and [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/idx/utilities.html)

## Install

Plugin:

```bash
asdf plugin add yj https://github.com/hyperpolymath/asdf-yj-plugin.git
```

yj:

```bash
# Show all installable versions
asdf list-all yj

# Install specific version
asdf install yj latest

# Set a version globally (in your ~/.tool-versions file)
asdf global yj latest

# Now yj commands are available
yj --version
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) readme for more instructions.

## Usage

```bash
# List installed versions
asdf list yj

# Set local version for current directory
asdf local yj <version>

# Uninstall a version
asdf uninstall yj <version>
```

## Contributing

Contributions welcome! Read the [contributing guidelines](CONTRIBUTING.adoc) first.

## License

Licensed under the [Palimpsest-MPL License (PMPL-1.0)](LICENSE).

---

> Maintained by [hyperpolymath](https://github.com/hyperpolymath)
