# Erebine.ai RPM Packages

<div style="text-align: center;">
<img src="https://erebine.ai/erebine-ogimage.png" alt="Project Logo" width="50%">
</div>

A high-performance, accelerated intelligence platform.

This repository builds RPM packages for the prebuilt Erebine binaries:
the `erectl` CLI, the XIM inference agent, and the XEM execution agent.
The build pulls the latest stable binaries for this host's architecture
from the [Erebine/binaries](https://github.com/Erebine/binaries)
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

## Licensing

The `License:` tag is not written in the specs. `build.sh` downloads the
`erebine-license.spec.inc` asset attached to the Erebine/binaries release
being packaged into the RPM source directory, and every spec `%include`s it
and takes its `License:` tag from the per-binary SPDX expression it defines.
That expression is generated from the dependency pins that release's
binaries were linked from, so it can never describe a different dependency
set than the binary beside it. The binaries link their Swift dependencies
statically, so the tag names those licenses too, not a flat `MIT`:

``` shell
rpm -qp --qf '%{LICENSE}\n' build/RPMS/*/erectl-*.rpm
# Apache-2.0 AND (Apache-2.0 WITH Swift-exception) AND BSD-3-Clause AND ISC AND MIT AND OpenSSL

rpm -qp --qf '%{URL}\n' build/RPMS/*/erectl-*.rpm
# https://erebine.ai

rpm -qpL build/RPMS/*/erectl-*.rpm
# /usr/share/licenses/erectl/LICENSE
# /usr/share/licenses/erectl/THIRD_PARTY_NOTICES
```

The release's `LICENSE` and `THIRD_PARTY_NOTICES` are downloaded with it and
installed as each package's `%license` files. The directory they land in is
rpm's `%_licensedir`, which follows the host that ran `rpmbuild`, not the host
that installs: `/usr/share/licenses/erectl/` on RHEL and Rocky, as above, and
`/usr/share/licenses/erectl-<version>/` on the Debian rpm build the packaging
workflow runs on. `build.sh` fails if any of the three assets is missing, so a
release cut before the generated metadata existed cannot produce a package
whose `License:` tag states only Erebine's own terms.

## Packages

| Package | Binary | Dependencies |
| --- | --- | --- |
| `erectl` | `/usr/bin/erectl` | libzstd, libcurl, ca-certificates |
| `erebine-eim-agent` | `/usr/bin/erebine-eim-agent` | zeromq, libsodium, libzstd |
| `erebine-eem-agent` | `/usr/bin/erebine-eem-agent` | zeromq, libsodium, libzstd, libcurl, ca-certificates |

## Services

The agent packages install systemd units. Set the join key (and for
XEM the router URL and registration name) in the env file, then enable
the service:

``` shell
sudoedit /etc/erebine/eim-agent.env
sudo systemctl enable --now erebine-eim-agent

sudoedit /etc/erebine/eem-agent.env
sudo systemctl enable --now erebine-eem-agent
```

Both services run as the `erebine` system user (created on install)
and keep state under `/var/lib/erebine`. The agents enroll on first
start using the join key from their env file.

Documentation for running the binaries can be found in the
[docs](https://erebine.ai/docs/private-agents).
