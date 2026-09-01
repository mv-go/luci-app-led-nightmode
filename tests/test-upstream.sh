#!/bin/sh

set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/led-nightmode-upstream.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT HUP INT TERM

application="$fixture_root/luci/applications/luci-app-led-nightmode"
"$PROJECT_ROOT/scripts/stage-upstream-luci.sh" "$application" >/dev/null

[ -f "$application/Makefile" ] || fail 'upstream Makefile was not staged'
[ -d "$application/htdocs" ] || fail 'LuCI assets were not staged'
[ -d "$application/po" ] || fail 'translation template was not staged'
[ -d "$application/root" ] || fail 'LuCI metadata tree was not staged'
[ ! -e "$application/providers" ] || fail 'device-specific provider leaked into the LuCI application'

diff -r "$PROJECT_ROOT/htdocs" "$application/htdocs" >/dev/null || fail 'staged LuCI assets differ from the source tree'
diff -r "$PROJECT_ROOT/po" "$application/po" >/dev/null || fail 'staged translations differ from the source tree'
diff -r "$PROJECT_ROOT/root" "$application/root" >/dev/null || fail 'staged LuCI metadata differs from the source tree'

grep -Fq 'include ../../luci.mk' "$application/Makefile" || fail 'upstream Makefile does not use the LuCI-tree include'
if grep -Fq 'feeds/luci/luci.mk' "$application/Makefile"; then
	fail 'standalone-feed include leaked into the upstream Makefile'
fi
if grep -Fq 'quectel-qnwcfg-ledmode' "$application/Makefile"; then
	fail 'provider subpackage leaked into the upstream Makefile'
fi
if find "$application" -type f -o -type l | grep -Eq '/(etc/config|etc/init\.d|etc/uci-defaults|usr/libexec|usr/sbin)/'; then
	fail 'core runtime leaked into the LuCI application'
fi
grep -Fqx 'LUCI_DEPENDS:=+luci-base +led-nightmode' "$application/Makefile" || fail 'LuCI package does not depend on the split core'

for field in PKG_NAME PKG_VERSION PKG_RELEASE PKG_LICENSE LUCI_TITLE LUCI_DESCRIPTION LUCI_DEPENDS LUCI_URL; do
	standalone=$(sed -n "s/^$field:=//p" "$PROJECT_ROOT/Makefile")
	upstream=$(sed -n "s/^$field:=//p" "$application/Makefile")
	[ "$standalone" = "$upstream" ] || fail "$field differs between standalone and upstream package definitions"
done

if "$PROJECT_ROOT/scripts/stage-upstream-luci.sh" "$application" >/dev/null 2>&1; then
	fail 'staging unexpectedly overwrote an existing application directory'
fi

printf 'All upstream staging tests passed.\n'
