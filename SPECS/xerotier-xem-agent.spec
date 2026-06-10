# SPDX-License-Identifier: MIT
# Packages the prebuilt xerotier-xem-agent binary from Xerotier/binaries
# releases. Built by ../build.sh, which downloads the binary and defines
# pkgver.

%global debug_package %{nil}
%global __os_install_post %{nil}
%{!?_unitdir:%global _unitdir /usr/lib/systemd/system}

Name:           xerotier-xem-agent
Version:        %{?pkgver}%{!?pkgver:0}
Release:        1%{?dist}
Summary:        Xerotier XEM execution agent
License:        MIT
Vendor:         Xerotier
Packager:       Xerotier <hello@xerotier.ai>
URL:            https://xerotier.ai
Source0:        xerotier-xem-agent
Source1:        xerotier-xem-agent.service
Source2:        xem-agent.env
Source3:        LICENSE

# zeromq and libsodium ship in EPEL on RHEL and friends.
Requires:       zeromq
Requires:       libsodium
Requires:       libzstd
Requires:       libcurl
Requires:       ca-certificates
Requires(pre):  shadow-utils

%description
XEM execution agent for the Xerotier platform. Enrolls against a router
with a join key and executes tool calls. Configure
/etc/xerotier/xem-agent.env and enable xerotier-xem-agent.service.

%prep
# Prebuilt binary release; nothing to unpack.

%build
# Prebuilt binary release; nothing to build.

%install
install -D -m 0755 %{SOURCE0} %{buildroot}%{_bindir}/xerotier-xem-agent
install -D -m 0644 %{SOURCE1} %{buildroot}%{_unitdir}/xerotier-xem-agent.service
install -D -m 0644 %{SOURCE2} %{buildroot}%{_sysconfdir}/xerotier/xem-agent.env
install -D -m 0644 %{SOURCE3} %{buildroot}%{_datadir}/licenses/%{name}/LICENSE

%pre
getent group xerotier >/dev/null || groupadd -r xerotier
getent passwd xerotier >/dev/null || \
    useradd -r -g xerotier -d /var/lib/xerotier -s /sbin/nologin \
    -c "Xerotier service account" xerotier
exit 0

%post
systemctl daemon-reload >/dev/null 2>&1 || :

%preun
if [ $1 -eq 0 ]; then
    systemctl --no-reload disable --now xerotier-xem-agent.service >/dev/null 2>&1 || :
fi

%postun
systemctl daemon-reload >/dev/null 2>&1 || :

%files
%license %{_datadir}/licenses/%{name}/LICENSE
%{_bindir}/xerotier-xem-agent
%{_unitdir}/xerotier-xem-agent.service
%dir %{_sysconfdir}/xerotier
%config(noreplace) %{_sysconfdir}/xerotier/xem-agent.env

%changelog
