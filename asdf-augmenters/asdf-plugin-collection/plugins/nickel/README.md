# asdf-nickel

[![Build](https://github.com/hyperpolymath/asdf-nickel-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/hyperpolymath/asdf-nickel-plugin/actions/workflows/build.yml)
[![Lint](https://github.com/hyperpolymath/asdf-nickel-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/hyperpolymath/asdf-nickel-plugin/actions/workflows/lint.yml)
image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0,link="https://github.com/hyperpolymath/palimpsest-license"]

[asdf](https://asdf-vm.com) plugin for [Nickel](https://nickel-lang.org).

Configuration language.

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
asdf plugin add nickel https://github.com/hyperpolymath/asdf-nickel-plugin.git
```

nickel:

```bash
# Show all installable versions
asdf list-all nickel

# Install specific version
asdf install nickel latest

# Set a version globally (in your ~/.tool-versions file)
asdf global nickel latest

# Now nickel commands are available
nickel --version
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) readme for more instructions.

## Usage

```bash
# List installed versions
asdf list nickel

# Set local version for current directory
asdf local nickel <version>

# Uninstall a version
asdf uninstall nickel <version>
```

## Contributing

Contributions welcome! Read the [contributing guidelines](CONTRIBUTING.adoc) first.

## License

Licensed under the [Palimpsest-MPL License (PMPL-1.0)](LICENSE).

---

> Maintained by [hyperpolymath](https://github.com/hyperpolymath)
