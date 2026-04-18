# asdf-serum

[![Build](https://github.com/hyperpolymath/asdf-serum-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/hyperpolymath/asdf-serum-plugin/actions/workflows/build.yml)
[![Lint](https://github.com/hyperpolymath/asdf-serum-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/hyperpolymath/asdf-serum-plugin/actions/workflows/lint.yml)
image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0,link="https://github.com/hyperpolymath/palimpsest-license"]

[asdf](https://asdf-vm.com) plugin for [Serum](https://dalgona.github.io/Serum).

Elixir static site generator.

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
asdf plugin add serum https://github.com/hyperpolymath/asdf-serum-plugin.git
```

serum:

```bash
# Show all installable versions
asdf list-all serum

# Install specific version
asdf install serum latest

# Set a version globally (in your ~/.tool-versions file)
asdf global serum latest

# Now serum commands are available
serum --version
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) readme for more instructions.

## Usage

```bash
# List installed versions
asdf list serum

# Set local version for current directory
asdf local serum <version>

# Uninstall a version
asdf uninstall serum <version>
```

## Contributing

Contributions welcome! Read the [contributing guidelines](CONTRIBUTING.adoc) first.

## License

Licensed under the [Palimpsest-MPL License (PMPL-1.0)](LICENSE).

---

> Maintained by [hyperpolymath](https://github.com/hyperpolymath)
