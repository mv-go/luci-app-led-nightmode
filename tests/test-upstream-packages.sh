#!/bin/sh

set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/led-nightmode-packages-upstream.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT HUP INT TERM

package_dir=$fixture_root/packages/utils/led-nightmode
source_hash=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
"$PROJECT_ROOT/scripts/stage-upstream-packages.sh" "$package_dir" "$source_hash" >/dev/null

[ -f "$package_dir/Makefile" ] || fail 'packages Makefile was not staged'
[ -x "$package_dir/test-version.sh" ] || fail 'executable version-check override was not staged'
[ "$(find "$package_dir" -type f | wc -l | tr -d ' ')" -eq 2 ] || fail 'core contribution contains unexpected files'
grep -Fqx 'PKG_NAME:=led-nightmode' "$package_dir/Makefile" || fail 'core package name is incorrect'
grep -Fqx 'PKG_MAINTAINER:=Mv Go <rapture-ribose6k@icloud.com>' "$package_dir/Makefile" || fail 'core maintainer identity is incorrect'
grep -Fqx 'PKG_VERSION:=0.5.1' "$package_dir/Makefile" || fail 'core package version is incorrect'
grep -Fqx "PKG_HASH:=$source_hash" "$package_dir/Makefile" || fail 'source hash was not substituted'
grep -Fq 'archive/refs/tags/v$(PKG_VERSION).tar.gz?' "$package_dir/Makefile" || fail 'immutable source URL is missing'
grep -Fq '$(PKG_BUILD_DIR)/core/root/' "$package_dir/Makefile" || fail 'core source tree is not used'
grep -Fq 'define Build/Compile' "$package_dir/Makefile" || fail 'core contribution does not suppress the default source-tree compile'
grep -Fq 'define Package/led-nightmode/postinst' "$package_dir/Makefile" || fail 'core contribution does not own its rpcd lifecycle reload'
grep -Fq '/etc/init.d/rpcd reload' "$package_dir/Makefile" || fail 'core contribution does not reload rpcd after live installation'
if grep -Eq 'luci-app-led-nightmode/(install|conffiles)|htdocs|/usr/share/luci|quectel' "$package_dir/Makefile"; then
	fail 'LuCI or hardware-specific provider content leaked into the core contribution'
fi
PKG_NAME=led-nightmode PKG_VERSION=0.5.1 \
	"$package_dir/test-version.sh" led-nightmode 0.5.1 || fail 'version-check override rejected the core package'
if PKG_NAME=unexpected PKG_VERSION=0.5.1 \
	"$package_dir/test-version.sh" unexpected 0.5.1 >/dev/null 2>&1; then
	fail 'version-check override accepted an unexpected package'
fi

if "$PROJECT_ROOT/scripts/stage-upstream-packages.sh" "$package_dir" "$source_hash" >/dev/null 2>&1; then
	fail 'staging unexpectedly overwrote an existing package directory'
fi

if "$PROJECT_ROOT/scripts/stage-upstream-packages.sh" "$fixture_root/bad" invalid >/dev/null 2>&1; then
	fail 'staging accepted an invalid source hash'
fi

printf 'All upstream packages staging tests passed.\n'
