# SPDX-License-Identifier: MIT
# Packages the prebuilt erebine-eim-agent binary from Erebine/binaries
# releases. Built by ../build.sh, which downloads the binary and defines
# pkgver.

%global debug_package %{nil}
%global __os_install_post %{nil}
%{!?_unitdir:%global _unitdir /usr/lib/systemd/system}

Name:           erebine-eim-agent
Version:        %{?pkgver}%{!?pkgver:0}
Release:        1%{?dist}
Summary:        Erebine XIM inference agent
License:        MIT
Vendor:         Erebine
Packager:       Erebine <hello@erebine.ai>
URL:            https://erebine.ai
Source0:        erebine-eim-agent
Source1:        erebine-eim-agent.service
Source2:        eim-agent.env
Source3:        LICENSE

# zeromq and libsodium ship in EPEL on RHEL and friends.
Requires:       zeromq
Requires:       libsodium
Requires:       libzstd
Requires(pre):  shadow-utils

%description
XIM inference agent for the Erebine platform. Enrolls against a router
with a join key and serves inference traffic. Set the join key in
/etc/erebine/eim-agent.env and enable erebine-eim-agent.service.

%prep
# Prebuilt binary release; nothing to unpack.

%build
# Prebuilt binary release; nothing to build.

%install
install -D -m 0755 %{SOURCE0} %{buildroot}%{_bindir}/erebine-eim-agent
install -D -m 0644 %{SOURCE1} %{buildroot}%{_unitdir}/erebine-eim-agent.service
install -D -m 0644 %{SOURCE2} %{buildroot}%{_sysconfdir}/erebine/eim-agent.env
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
    systemctl --no-reload disable --now erebine-eim-agent.service >/dev/null 2>&1 || :
fi

%postun
systemctl daemon-reload >/dev/null 2>&1 || :

%files
%license %{_datadir}/licenses/%{name}/LICENSE
%{_bindir}/erebine-eim-agent
%{_unitdir}/erebine-eim-agent.service
%dir %{_sysconfdir}/erebine
%config(noreplace) %{_sysconfdir}/erebine/eim-agent.env

%changelog
