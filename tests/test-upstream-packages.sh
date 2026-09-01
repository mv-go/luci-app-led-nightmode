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
[ "$(find "$package_dir" -type f | wc -l | tr -d ' ')" -eq 1 ] || fail 'core contribution contains files beyond its Makefile'
grep -Fqx 'PKG_NAME:=led-nightmode' "$package_dir/Makefile" || fail 'core package name is incorrect'
grep -Fqx 'PKG_VERSION:=0.5.1' "$package_dir/Makefile" || fail 'core package version is incorrect'
grep -Fqx "PKG_HASH:=$source_hash" "$package_dir/Makefile" || fail 'source hash was not substituted'
grep -Fq 'archive/refs/tags/v$(PKG_VERSION).tar.gz?' "$package_dir/Makefile" || fail 'immutable source URL is missing'
grep -Fq '$(PKG_BUILD_DIR)/core/root/' "$package_dir/Makefile" || fail 'core source tree is not used'
if grep -Eq 'luci-app-led-nightmode/(install|conffiles)|htdocs|/usr/share/luci|quectel' "$package_dir/Makefile"; then
	fail 'LuCI or hardware-specific provider content leaked into the core contribution'
fi

if "$PROJECT_ROOT/scripts/stage-upstream-packages.sh" "$package_dir" "$source_hash" >/dev/null 2>&1; then
	fail 'staging unexpectedly overwrote an existing package directory'
fi

if "$PROJECT_ROOT/scripts/stage-upstream-packages.sh" "$fixture_root/bad" invalid >/dev/null 2>&1; then
	fail 'staging accepted an invalid source hash'
fi

printf 'All upstream packages staging tests passed.\n'
