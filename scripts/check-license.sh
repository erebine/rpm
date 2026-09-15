#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# check-license.sh -- build the RPMs against a fixture release and fail unless
# each one's License: tag is the expression generated for the binary inside it.
#
# Why this exists
# ---------------
# No spec here writes a License: tag. The binaries link their Swift
# dependencies statically, so a flat `MIT` would state only Erebine's own
# terms and none of the terms of the code actually inside the package. The
# real expression is generated per release -- erebine-license.spec.inc,
# attached to the Erebine/binaries release being packaged -- and every spec
# %includes it and takes its tag from the per-binary macro it defines.
#
# That indirection is what makes the tag correct, and it is also what makes it
# fail quietly. An undefined RPM macro is not an error: it expands to its own
# name. So a spec that misspells the macro, or one whose %include was dropped,
# still builds -- and produces a package whose License: tag reads literally
# `%{erebine_license_erectl}`. Nothing short of looking at the built package
# catches that, which is what this check does:
#
#   - each package's License: tag is the expression the release's spec include
#     defines for that binary, and the tag names the binary's own macro rather
#     than a sibling's,
#   - LICENSE and THIRD_PARTY_NOTICES are marked %license, not merely
#     installed, and are byte-identical to the release assets,
#   - the URL tag comes from the same include,
#   - and packaging a release with no spec include fails, rather than
#     producing packages whose tags state only Erebine's own terms.
#
# Nothing here touches the network. The fixture release is written to a
# temporary directory and a stand-in `curl` on PATH serves it, so the check
# does not depend on any Erebine/binaries release or tag existing.
#
# Requires: rpmbuild and rpm (the CI job installs the `rpm` package, as the
# packaging workflow does).
#
# Usage
# -----
#   scripts/check-license.sh              # check the repository
#   scripts/check-license.sh --self-test  # prove the check fails on bad input
#
# Exit status: 0 pass, 1 check failed, 2 usage error.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The %license files every package must carry, as they are named both in the
# release and under /usr/share/licenses/<package>/.
LICENSE_FILES=(LICENSE THIRD_PARTY_NOTICES)

# The URL the fixture spec include defines, and which each package must
# report. Matches the generator's %global erebine_url.
FIXTURE_URL="https://erebine.ai"

# Writes a stand-in curl into DIR that serves release assets from
# $FIXTURE_RELEASE and 404s on anything else. It understands only the
# argument shapes build.sh uses.
make_curl_shim() {
  local dir="$1"
  mkdir -p "$dir"
  cat >"$dir/curl" <<'SHIM'
#!/usr/bin/env bash
set -u
out=""
url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -H) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
src="${FIXTURE_RELEASE}/${url##*/}"
if [ ! -f "$src" ]; then
  echo "curl: (22) The requested URL returned error: 404" >&2
  exit 22
fi
if [ -n "$out" ]; then cp "$src" "$out"; else cat "$src"; fi
SHIM
  chmod +x "$dir/curl"
}

# Writes a fixture Erebine/binaries release into DIR: the generated spec
# include, the two license texts, and a stub binary per name given after DIR.
# The include has the shape packaging-license.py produces, with a distinct
# expression per binary so a spec that reads a sibling's macro is visible.
make_fixture_release() {
  local dir="$1" arch bin
  shift
  arch="$(uname -m)"
  mkdir -p "$dir"
  cat >"$dir/erebine-license.spec.inc" <<'INC'
# Erebine licensing for RPM packaging. GENERATED -- do not edit by hand.
# Fixture copy for scripts/check-license.sh: same shape as the released
# asset, with a deliberately different expression per binary.

%global erebine_url https://erebine.ai
%global erebine_component_license MIT
%global erebine_license_files LICENSE THIRD_PARTY_NOTICES

%global erebine_license_erectl Apache-2.0 AND BSD-3-Clause AND MIT
%global erebine_license_erebine_eim_agent Apache-2.0 AND ISC AND MIT
%global erebine_license_erebine_eem_agent Apache-2.0 AND MIT AND OpenSSL
INC
  cat >"$dir/LICENSE" <<'TXT'
MIT License

Fixture license text for the packaging check.
TXT
  cat >"$dir/THIRD_PARTY_NOTICES" <<'TXT'
THIRD-PARTY NOTICES

Fixture notices for the packaging check.
TXT
  for bin in "$@"; do
    printf '#!/bin/true\nfixture %s\n' "$bin" >"$dir/${bin}-Linux-${arch}"
  done
}

# Prints the binary names build.sh downloads, one per line.
declared_binaries() {
  sed -n 's/^for bin in \(.*\); do$/\1/p' "$1" | head -1 | tr ' ' '\n' | grep -v '^$'
}

# Prints the macro name a package's License: tag must reference: the package
# name with dashes turned into underscores, as the generator writes it.
license_macro() { printf 'erebine_license_%s' "${1//-/_}"; }

# Prints the expression the fixture include defines for MACRO.
fixture_expression() {
  sed -n "s/^%global $1 \(.*\)$/\1/p" "$2" | head -1
}

# Copies the packaging into a scratch tree and runs build.sh there against
# FIXTURE, with the curl shim on PATH. Prints build.sh's output and returns
# its exit status. The repository is never written to.
#   run_packaging ROOT STAGE FIXTURE
run_packaging() {
  local root="$1" stage="$2" fixture="$3"
  mkdir -p "$stage"
  cp -r "$root/build.sh" "$root/SPECS" "$root/systemd" "$stage/"
  ( cd "$stage" \
    && PATH="$stage/../bin:$PATH" FIXTURE_RELEASE="$fixture" TAG=v9.9.9 \
       bash ./build.sh ) 2>&1
}

# Runs every check under ROOT. Prints one line per check and returns 0 when
# all of them pass.
check_tree() {
  local root="$1" failed=0 tmp spec name macro

  if ! command -v rpmbuild >/dev/null 2>&1 || ! command -v rpm >/dev/null 2>&1; then
    echo "FAIL rpmbuild or rpm is not installed; the packaging check cannot run"
    return 1
  fi

  if [ ! -f "$root/build.sh" ] || ! compgen -G "$root/SPECS/*.spec" >/dev/null; then
    echo "FAIL build.sh or SPECS/*.spec: missing"
    return 1
  fi

  if [ -s "$root/LICENSE" ]; then
    echo "ok   LICENSE: present and non-empty"
  else
    echo "FAIL LICENSE: missing or empty"
    failed=1
  fi

  local binaries
  binaries="$(declared_binaries "$root/build.sh")"
  if [ -z "$binaries" ]; then
    echo "FAIL build.sh: no binary list found"
    return 1
  fi

  # Static: each spec must take its License: from its own generated macro.
  # erectl and the EIM agent can share an expression, so a spec that reads a
  # sibling's macro is invisible to the built package and only visible here.
  for spec in "$root"/SPECS/*.spec; do
    name="$(sed -n 's/^Name:[[:space:]]*\(.*\)$/\1/p' "$spec" | head -1)"
    macro="$(license_macro "$name")"
    if grep -qE "^License:[[:space:]]+%\{$macro\}[[:space:]]*$" "$spec"; then
      echo "ok   SPECS/${spec##*/}: License: is %{$macro}"
    else
      echo "FAIL SPECS/${spec##*/}: License: is not %{$macro}"
      grep -n '^License:' "$spec" | sed 's/^/     /' || true
      echo "     The tag must come from this binary's own generated macro."
      failed=1
    fi
    if ! grep -q '^%include %{_sourcedir}/erebine-license.spec.inc$' "$spec"; then
      echo "FAIL SPECS/${spec##*/}: does not %include the release's spec include"
      failed=1
    fi
    if ! printf '%s\n' "$binaries" | grep -qx "$name"; then
      echo "FAIL SPECS/${spec##*/}: $name is not in build.sh's binary list"
      echo "     Its binary is never downloaded, so the package cannot build."
      failed=1
    fi
  done

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_curl_shim "$tmp/bin"

  local fixture="$tmp/release" out
  # shellcheck disable=SC2086
  make_fixture_release "$fixture" $binaries
  if ! out="$(run_packaging "$root" "$tmp/stage" "$fixture")"; then
    echo "FAIL packaging a complete release failed"
    printf '%s\n' "$out" | tail -30 | sed 's/^/     /'
    return 1
  fi
  echo "ok   packaging: build.sh completed against a fixture release"

  for spec in "$root"/SPECS/*.spec; do
    name="$(sed -n 's/^Name:[[:space:]]*\(.*\)$/\1/p' "$spec" | head -1)"
    macro="$(license_macro "$name")"
    local rpm_file wanted got file
    rpm_file="$(find "$tmp/stage/build/RPMS" -name "${name}-9.9.9-*.rpm" 2>/dev/null | head -1)"
    if [ -z "$rpm_file" ]; then
      echo "FAIL $name: no RPM was produced"
      failed=1
      continue
    fi

    wanted="$(fixture_expression "$macro" "$fixture/erebine-license.spec.inc")"
    got="$(rpm -qp --qf '%{LICENSE}' "$rpm_file" 2>/dev/null)"
    if [ "$got" = "$wanted" ]; then
      echo "ok   $name: License: tag is the generated expression ($got)"
    else
      echo "FAIL $name: License: tag is not the generated expression"
      echo "     wanted: $wanted"
      echo "     got:    $got"
      failed=1
    fi

    got="$(rpm -qp --qf '%{URL}' "$rpm_file" 2>/dev/null)"
    if [ "$got" = "$FIXTURE_URL" ]; then
      echo "ok   $name: URL tag comes from the generated include"
    else
      echo "FAIL $name: URL tag is \"$got\", not \"$FIXTURE_URL\""
      failed=1
    fi

    # %license, not merely installed: rpm -qpL lists only files marked as
    # licenses, which is what keeps them when documentation is excluded.
    #
    # The directory is matched loosely on purpose. rpm's %_licensedir differs
    # between builds -- /usr/share/licenses/<name>/ on RHEL and Rocky, where
    # these packages are installed, and /usr/share/licenses/<name>-<version>/
    # on the Debian rpm build that the packaging workflow runs on. Both are
    # correct; pinning either would fail on the other host.
    local marked path
    marked="$(rpm -qpL "$rpm_file" 2>/dev/null)"
    for file in "${LICENSE_FILES[@]}"; do
      path="$(printf '%s\n' "$marked" \
                | grep -E "^/usr/share/licenses/[^/]+/${file}$" | head -1)"
      if [ -n "$path" ]; then
        echo "ok   $name: $file is marked %license ($path)"
      else
        echo "FAIL $name: $file is not marked %license"
        printf '%s\n' "$marked" | sed 's/^/     /'
        failed=1
        continue
      fi
      rm -rf "$tmp/x"
      mkdir -p "$tmp/x"
      ( cd "$tmp/x" && rpm2cpio "$rpm_file" | cpio -idmu --quiet )
      if diff -q "$fixture/$file" "$tmp/x/$path" >/dev/null; then
        echo "ok   $name: $file is the release's $file"
      else
        echo "FAIL $name: $file is not the release's $file"
        failed=1
      fi
    done
  done

  # A release without the generated include must fail the build, not produce
  # packages whose License: tags state only Erebine's own terms.
  local short="$tmp/release-no-include"
  cp -r "$fixture" "$short"
  rm -f "$short/erebine-license.spec.inc"
  rm -rf "$tmp/stage-short"
  if run_packaging "$root" "$tmp/stage-short" "$short" >/dev/null 2>&1; then
    echo "FAIL build.sh packaged a release with no erebine-license.spec.inc"
    failed=1
  elif find "$tmp/stage-short/build/RPMS" -name '*.rpm' 2>/dev/null | grep -q .; then
    echo "FAIL build.sh produced an RPM from a release with no spec include"
    failed=1
  else
    echo "ok   build.sh: refuses a release with no erebine-license.spec.inc"
  fi

  local f
  for f in "$root/build.sh" "$root/README.md" "$root/LICENSE" "$root"/SPECS/*.spec; do
    [ -f "$f" ] || continue
    if LC_ALL=C grep -q '[^[:print:][:space:]]' "$f"; then
      echo "FAIL ${f#"$root"/}: non-ASCII bytes"
      failed=1
    fi
  done

  return "$failed"
}

# Sabotages copies of the repository and proves the check notices. Each case
# is a change someone could plausibly make and that a passing rpmbuild would
# otherwise hide.
self_test() {
  local tmp status=0 case_name
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  if ! command -v rpmbuild >/dev/null 2>&1; then
    echo "self-test FAIL rpmbuild is not installed"
    return 1
  fi

  local good="$tmp/good"
  mkdir -p "$good"
  cp -r "$REPO_ROOT/build.sh" "$REPO_ROOT/SPECS" "$REPO_ROOT/systemd" \
        "$REPO_ROOT/LICENSE" "$REPO_ROOT/README.md" "$good/"

  if check_tree "$good" >/dev/null; then
    echo "self-test ok   the packaging as it stands passes"
  else
    echo "self-test FAIL the packaging as it stands should pass"
    check_tree "$good" || true
    status=1
  fi

  for case_name in literal-mit-license misspelled-macro siblings-macro no-include \
                   license-not-marked tolerates-missing-include spec-not-in-binary-list; do
    local bad="$tmp/$case_name"
    cp -r "$good" "$bad"
    case "$case_name" in
      literal-mit-license)
        sed -i 's/^License:.*$/License:        MIT/' "$bad/SPECS/erectl.spec" ;;
      misspelled-macro)
        # An undefined RPM macro is not an error: it expands to its own name,
        # so this builds and ships a License: tag reading the macro text.
        sed -i 's/%{erebine_license_erectl}/%{erebine_license_erect}/' \
          "$bad/SPECS/erectl.spec" ;;
      siblings-macro)
        # erectl taking the EIM agent's expression: a copy-paste that rpm
        # resolves happily.
        sed -i 's/%{erebine_license_erectl}/%{erebine_license_erebine_eim_agent}/' \
          "$bad/SPECS/erectl.spec" ;;
      no-include)
        sed -i '/^%include %{_sourcedir}\/erebine-license.spec.inc$/d' \
          "$bad/SPECS/erectl.spec" ;;
      license-not-marked)
        sed -i 's/^%license %{erebine_license_files}$/%doc %{erebine_license_files}/' \
          "$bad/SPECS/erectl.spec" ;;
      tolerates-missing-include)
        # The fetch guard no longer exits, and the spec tolerates a missing
        # include, so a release without it still produces packages.
        sed -i 's/; exit 1; }/; }/' "$bad/build.sh"
        sed -i 's|^%include %{_sourcedir}/erebine-license.spec.inc$|%{load:%{_sourcedir}/erebine-license.spec.inc}|' \
          "$bad"/SPECS/*.spec ;;
      spec-not-in-binary-list)
        sed -i 's/^for bin in erectl /for bin in /' "$bad/build.sh" ;;
    esac
    if check_tree "$bad" >/dev/null 2>&1; then
      echo "self-test FAIL $case_name should fail"
      status=1
    else
      echo "self-test ok   $case_name fails"
    fi
  done
  return "$status"
}

case "${1:-}" in
  "") check_tree "$REPO_ROOT" ;;
  --self-test) self_test ;;
  *) echo "usage: $0 [--self-test]" >&2; exit 2 ;;
esac
