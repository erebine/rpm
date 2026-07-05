# SPDX-License-Identifier: MIT
# Packages the prebuilt erebine-eem-agent binary from Erebine/binaries
# releases. Built by ../build.sh, which downloads the binary and defines
# pkgver.

%global debug_package %{nil}
%global __os_install_post %{nil}
%{!?_unitdir:%global _unitdir /usr/lib/systemd/system}

Name:           erebine-eem-agent
Version:        %{?pkgver}%{!?pkgver:0}
Release:        1%{?dist}
Summary:        Erebine XEM execution agent
License:        MIT
Vendor:         Erebine
Packager:       Erebine <hello@erebine.ai>
URL:            https://erebine.ai
Source0:        erebine-eem-agent
Source1:        erebine-eem-agent.service
Source2:        eem-agent.env
Source3:        LICENSE

# zeromq and libsodium ship in EPEL on RHEL and friends.
Requires:       zeromq
Requires:       libsodium
Requires:       libzstd
Requires:       libcurl
Requires:       ca-certificates
Requires(pre):  shadow-utils

%description
XEM execution agent for the Erebine platform. Enrolls against a router
with a join key and executes tool calls. Configure
/etc/erebine/eem-agent.env and enable erebine-eem-agent.service.

%prep
# Prebuilt binary release; nothing to unpack.

%build
# Prebuilt binary release; nothing to build.

%install
install -D -m 0755 %{SOURCE0} %{buildroot}%{_bindir}/erebine-eem-agent
install -D -m 0644 %{SOURCE1} %{buildroot}%{_unitdir}/erebine-eem-agent.service
install -D -m 0644 %{SOURCE2} %{buildroot}%{_sysconfdir}/erebine/eem-agent.env
install -D -m 0644 %{SOURCE3} %{buildroot}%{_datadir}/licenses/%{name}/LICENSE

%pre
getent group erebine >/dev/null || groupadd -r erebine
getent passwd erebine >/dev/null || \
    useradd -r -g erebine -d /var/lib/erebine -s /sbin/nologin \
    -c "Erebine service account" erebine
exit 0

%post
systemctl daemon-reload >/dev/null 2>&1 || :

%preun
if [ $1 -eq 0 ]; then
    systemctl --no-reload disable --now erebine-eem-agent.service >/dev/null 2>&1 || :
fi

%postun
systemctl daemon-reload >/dev/null 2>&1 || :

%files
%license %{_datadir}/licenses/%{name}/LICENSE
%{_bindir}/erebine-eem-agent
%{_unitdir}/erebine-eem-agent.service
%dir %{_sysconfdir}/erebine
%config(noreplace) %{_sysconfdir}/erebine/eem-agent.env

%changelog
