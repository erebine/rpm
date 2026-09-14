# SPDX-License-Identifier: MIT
# Packages the prebuilt erectl binary from Erebine/binaries releases.
# Built by ../build.sh, which downloads the binary and the release's
# LICENSE and THIRD_PARTY_NOTICES and defines pkgver and erebine_tag.

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
Source100:      https://github.com/Erebine/binaries/releases/download/%{erebine_tag}/LICENSE
Source101:      https://github.com/Erebine/binaries/releases/download/%{erebine_tag}/THIRD_PARTY_NOTICES

Requires:       libzstd
Requires:       libcurl
Requires:       ca-certificates

%description
Command-line client for the Erebine API: models, endpoints, embeddings,
batches, and platform management.

%prep
# Prebuilt binary release; nothing to unpack.
cp -p %{SOURCE100} LICENSE
cp -p %{SOURCE101} THIRD_PARTY_NOTICES

%build
# Prebuilt binary release; nothing to build.

%install
install -D -m 0755 %{SOURCE0} %{buildroot}%{_bindir}/erectl

%files
%license LICENSE THIRD_PARTY_NOTICES
%{_bindir}/erectl

%changelog
