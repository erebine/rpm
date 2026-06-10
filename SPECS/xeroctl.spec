# SPDX-License-Identifier: MIT
# Packages the prebuilt xeroctl binary from Xerotier/binaries releases.
# Built by ../build.sh, which downloads the binary and defines pkgver.

%global debug_package %{nil}
%global __os_install_post %{nil}

Name:           xeroctl
Version:        %{?pkgver}%{!?pkgver:0}
Release:        1%{?dist}
Summary:        Xerotier command-line client
License:        MIT
Vendor:         Xerotier
Packager:       Xerotier <hello@xerotier.ai>
URL:            https://xerotier.ai
Source0:        xeroctl
Source1:        LICENSE

Requires:       libzstd
Requires:       libcurl
Requires:       ca-certificates

%description
Command-line client for the Xerotier API: models, endpoints, embeddings,
batches, and platform management.

%prep
# Prebuilt binary release; nothing to unpack.

%build
# Prebuilt binary release; nothing to build.

%install
install -D -m 0755 %{SOURCE0} %{buildroot}%{_bindir}/xeroctl
install -D -m 0644 %{SOURCE1} %{buildroot}%{_datadir}/licenses/%{name}/LICENSE

%files
%license %{_datadir}/licenses/%{name}/LICENSE
%{_bindir}/xeroctl

%changelog
