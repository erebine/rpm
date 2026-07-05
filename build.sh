#!/bin/bash
# SPDX-License-Identifier: MIT
# Build RPMs from the latest stable Erebine binaries.
#
# Resolves the latest release of Erebine/binaries, downloads the Linux
# binaries for this host architecture, and packages them with rpmbuild.
#
# Env:
#   TAG       release tag to package (default: latest stable release)
#   GH_TOKEN  optional GitHub token for API/download requests
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="Erebine/binaries"
ARCH="$(uname -m)"

AUTH=()
[ -n "${GH_TOKEN:-}" ] && AUTH=(-H "Authorization: Bearer ${GH_TOKEN}")

if [ -z "${TAG:-}" ]; then
  TAG="$(curl -fsSL ${AUTH[@]+"${AUTH[@]}"} \
    "https://api.github.com/repos/${REPO}/releases/latest" \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
fi
[ -n "$TAG" ] || { echo "could not resolve the latest release tag"; exit 1; }
VERSION="${TAG#v}"

WORK="$HERE/build"
SOURCES="$WORK/SOURCES"
mkdir -p "$SOURCES"

for bin in erectl erebine-eim-agent erebine-eem-agent; do
  echo "==> ${bin}-Linux-${ARCH} (${TAG})"
  curl -fSL ${AUTH[@]+"${AUTH[@]}"} -o "$SOURCES/$bin" \
    "https://github.com/${REPO}/releases/download/${TAG}/${bin}-Linux-${ARCH}"
  chmod 0755 "$SOURCES/$bin"
done

# Systemd units, env-file templates, and the license text.
cp "$HERE"/systemd/* "$HERE/LICENSE" "$SOURCES"/

for spec in "$HERE"/SPECS/*.spec; do
  echo "==> rpmbuild $(basename "$spec")"
  rpmbuild -bb "$spec" \
    --define "pkgver $VERSION" \
    --define "_topdir $WORK" \
    --define "_sourcedir $SOURCES"
done

echo "==> packages:"
find "$WORK/RPMS" -name '*.rpm'
