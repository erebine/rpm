# SPDX-License-Identifier: MIT
# Packages the prebuilt erectl binary from Erebine/binaries releases.
# Built by ../build.sh, which downloads the binary and defines pkgver.

%global debug_package %{nil}
%global __os_install_post %{nil}

Name:           erectl
Version:        %{?pkgver}%{!?pkgver:0}
Release:        1%{?dist}
Summary:        Erebine command-line client
License:        MIT
Vendor:         Erebine
Packager:       Erebine <hello@erebine.ai>
URL:            https://erebine.ai
Source0:        erectl
Source1:        LICENSE

Requires:       libzstd
Requires:       libcurl
Requires:       ca-certificates

%description
Command-line client for the Erebine API: models, endpoints, embeddings,
batches, and platform management.

%prep
# Prebuilt binary release; nothing to unpack.

%build
# Prebuilt binary release; nothing to build.

%install
install -D -m 0755 %{SOURCE0} %{buildroot}%{_bindir}/erectl
install -D -m 0644 %{SOURCE1} %{buildroot}%{_datadir}/licenses/%{name}/LICENSE

%files
%license %{_datadir}/licenses/%{name}/LICENSE
%{_bindir}/erectl

%changelog
