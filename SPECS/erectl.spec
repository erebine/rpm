# SPDX-License-Identifier: MIT
# Packages the prebuilt erectl binary from Erebine/binaries releases.
# Built by ../build.sh, which downloads the binary, the release's
# generated erebine-license.spec.inc, LICENSE and THIRD_PARTY_NOTICES,
# and defines pkgver and erebine_tag.

%global debug_package %{nil}
%global __os_install_post %{nil}

# The licensing metadata generated for the tag being packaged, fetched into
# the source directory by ../build.sh. It defines the project URL, the list
# of license files to install, and one SPDX License expression per binary.
# The binaries link their Swift dependencies statically, so the License tag
# must state those terms too; a flat MIT states only Erebine's own. Macros
# are deliberately not named in these comments: rpm expands macros in spec
# comments.
%include %{_sourcedir}/erebine-license.spec.inc

Name:           erectl
Version:        %{?pkgver}%{!?pkgver:0}
Release:        1%{?dist}
Summary:        Erebine command-line client
License:        %{erebine_license_erectl}
Vendor:         Erebine
Packager:       Erebine <hello@erebine.ai>
URL:            %{erebine_url}
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
%license %{erebine_license_files}
%{_bindir}/erectl

%changelog
