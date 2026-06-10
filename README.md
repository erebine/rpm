# Xerotier.ai RPM Packages

<div style="text-align: center;">
<img src="https://xerotier.ai/xerotier-ogimage.png" alt="Project Logo" width="50%">
</div>

A high-performance, accelerated intelligence platform.

This repository builds RPM packages for the prebuilt Xerotier binaries:
the `xeroctl` CLI, the XIM inference agent, and the XEM execution agent.
The build pulls the latest stable binaries for this host's architecture
from the [Xerotier/binaries](https://github.com/Xerotier/binaries)
releases, and every package declares the runtime libraries it needs, so
installation resolves dependencies the traditional way.

## Getting Started

Build the packages, then install them with dnf:

``` shell
sudo dnf install -y rpm-build
./build.sh
sudo dnf install -y epel-release
sudo dnf install -y build/RPMS/*/*.rpm
```

* The first command installs the RPM build toolchain.
* The second command downloads the latest stable binaries and builds one
  RPM per binary into `build/RPMS/`.
* The third command enables EPEL, which carries the `zeromq` and
  `libsodium` dependencies of the agent packages on RHEL, Rocky, and
  friends.
* The last command installs the packages; dnf resolves the remaining
  dependencies.

To package a specific release instead of the latest, set `TAG`:

``` shell
TAG=v0.0.1 ./build.sh
```

## Packages

| Package | Binary | Dependencies |
| --- | --- | --- |
| `xeroctl` | `/usr/bin/xeroctl` | libzstd, libcurl, ca-certificates |
| `xerotier-xim-agent` | `/usr/bin/xerotier-xim-agent` | zeromq, libsodium, libzstd |
| `xerotier-xem-agent` | `/usr/bin/xerotier-xem-agent` | zeromq, libsodium, libzstd, libcurl, ca-certificates |

## Services

The agent packages install systemd units. Set the join key (and for
XEM the router URL and registration name) in the env file, then enable
the service:

``` shell
sudoedit /etc/xerotier/xim-agent.env
sudo systemctl enable --now xerotier-xim-agent

sudoedit /etc/xerotier/xem-agent.env
sudo systemctl enable --now xerotier-xem-agent
```

Both services run as the `xerotier` system user (created on install)
and keep state under `/var/lib/xerotier`. The agents enroll on first
start using the join key from their env file.

Documentation for running the binaries can be found in the
[docs](https://xerotier.ai/docs/private-agents).
