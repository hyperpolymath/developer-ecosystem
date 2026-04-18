# RPM spec file for czech-file-knife
# Compatible with Fedora (dnf) and openSUSE (zypper)

Name:           czech-file-knife
Version:        0.1.0
Release:        1%{?dist}
Summary:        Universal file management toolkit with cloud provider integration

License:        AGPL-3.0-or-later
URL:            https://github.com/hyperpolymath/czech-file-knife
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust >= 1.75
BuildRequires:  cargo
BuildRequires:  gcc
BuildRequires:  pkg-config
BuildRequires:  fuse3-devel

Requires:       fuse3

%description
Czech File Knife (cfk) is a universal file management toolkit with cloud
provider integration and virtual filesystem support. It provides a unified
interface for managing files across local storage and cloud providers.

Features:
- Virtual filesystem (FUSE) for mounting cloud storage
- Content-addressable caching with Blake3 hashing
- Full-text search indexing with Tantivy
- Multi-provider support (local, S3, GCS, Azure, etc.)
- Streaming copy with progress indication

%prep
%autosetup

%build
cargo build --release --package cfk-cli

%check
cargo test --release

%install
install -D -m 755 target/release/cfk %{buildroot}%{_bindir}/cfk

%files
%license LICENSE
%doc README.adoc
%{_bindir}/cfk

%changelog
* Tue Dec 17 2025 hyperpolymath <packages@hyperpolymath.dev> - 0.1.0-1
- Initial release
