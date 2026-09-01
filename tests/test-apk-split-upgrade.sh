#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

[ "$#" -eq 2 ] || {
	printf 'Usage: %s <monolithic-r8-apk-directory> <split-apk-directory>\n' "$0" >&2
	exit 2
}

command -v apk >/dev/null 2>&1 || fail 'apk-tools 3 is required'

old_dir=$1
new_dir=$2
old_base=$old_dir/luci-app-led-nightmode-0.5.0-r8.apk
old_provider=$old_dir/led-nightmode-provider-quectel-qnwcfg-ledmode-0.5.0-r8.apk

find_one() {
	pattern=$1
	set -- "$new_dir"/$pattern
	[ "$#" -eq 1 ] && [ -f "$1" ] || fail "expected exactly one split artifact matching $pattern"
	printf '%s\n' "$1"
}

[ -f "$old_base" ] || fail 'monolithic r8 base APK is missing'
[ -f "$old_provider" ] || fail 'monolithic r8 provider APK is missing'

new_core=$(find_one 'led-nightmode-[0-9]*.apk')
new_luci=$(find_one 'luci-app-led-nightmode-[0-9]*.apk')
new_provider=$(find_one 'led-nightmode-provider-quectel-qnwcfg-ledmode-[0-9]*.apk')

fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/led-nightmode-apk-upgrade.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT HUP INT TERM
empty_root=$fixture_root/empty
dummy_dir=$fixture_root/dummy
installed_root=$fixture_root/root
mkdir -p "$empty_root" "$dummy_dir" "$installed_root"

for dependency in jshn libc luci-base picocom procd rpcd sunwait uci; do
	apk mkpkg \
		-o "$dummy_dir/$dependency.apk" \
		-I "name:$dependency" \
		-I version:1-r0 \
		-I arch:noarch \
		-I description:fixture \
		-F "$empty_root"
done

apk add \
	--root "$installed_root" \
	--initdb \
	--allow-untrusted \
	--no-scripts \
	"$dummy_dir"/*.apk \
	"$old_base" \
	"$old_provider" >/dev/null

printf '\n# split-upgrade-marker\n' >> "$installed_root/etc/config/led-nightmode"

apk add \
	--root "$installed_root" \
	--allow-untrusted \
	--no-scripts \
	"$new_core" \
	"$new_luci" \
	"$new_provider" >/dev/null

grep -Fq split-upgrade-marker "$installed_root/etc/config/led-nightmode" || fail 'modified UCI configuration was not preserved'
[ -f "$installed_root/etc/config/led-nightmode.apk-new" ] || fail 'new core default was not retained as apk-new'
cmp "$PROJECT_ROOT/core/root/etc/config/led-nightmode" "$installed_root/etc/config/led-nightmode.apk-new" >/dev/null || fail 'apk-new differs from the split core default'

owner_of() {
	apk --root "$installed_root" info --who-owns "$1"
}

owner_of /usr/sbin/led-nightmode | grep -Fq 'owned by led-nightmode-' || fail 'core CLI ownership did not move to led-nightmode'
owner_of /www/luci-static/resources/view/led-nightmode.js | grep -Fq 'owned by luci-app-led-nightmode-' || fail 'LuCI view ownership is incorrect'
owner_of /usr/libexec/led-nightmode/providers/quectel-qnwcfg-ledmode | grep -Fq 'owned by led-nightmode-provider-quectel-qnwcfg-ledmode-' || fail 'provider ownership is incorrect'

for relative_path in \
	etc/init.d/led-nightmode \
	etc/uci-defaults/99-led-nightmode \
	usr/libexec/led-nightmode-provider-service \
	usr/libexec/led-nightmode-service \
	usr/sbin/led-nightmode
do
	cmp "$PROJECT_ROOT/core/root/$relative_path" "$installed_root/$relative_path" >/dev/null || fail "installed core file differs from source: $relative_path"
done

[ "$(readlink "$installed_root/usr/libexec/led-nightmode-schedule")" = led-nightmode-service ] || fail 'installed schedule symlink is incorrect'
[ "$(readlink "$installed_root/usr/libexec/rpcd/luci.led-nightmode")" = ../led-nightmode-service ] || fail 'installed rpcd symlink is incorrect'
cmp "$PROJECT_ROOT/root/usr/share/luci/menu.d/luci-app-led-nightmode.json" "$installed_root/usr/share/luci/menu.d/luci-app-led-nightmode.json" >/dev/null || fail 'installed LuCI menu differs from source'
cmp "$PROJECT_ROOT/root/usr/share/rpcd/acl.d/luci-app-led-nightmode.json" "$installed_root/usr/share/rpcd/acl.d/luci-app-led-nightmode.json" >/dev/null || fail 'installed LuCI ACL differs from source'
cmp "$PROJECT_ROOT/providers/quectel-qnwcfg-ledmode/root/usr/libexec/led-nightmode/providers/quectel-qnwcfg-ledmode" "$installed_root/usr/libexec/led-nightmode/providers/quectel-qnwcfg-ledmode" >/dev/null || fail 'installed provider differs from source'

core_list=$installed_root/lib/apk/packages/led-nightmode.list
luci_list=$installed_root/lib/apk/packages/luci-app-led-nightmode.list
provider_list=$installed_root/lib/apk/packages/led-nightmode-provider-quectel-qnwcfg-ledmode.list

grep -Fqx '/usr/sbin/led-nightmode' "$core_list" || fail 'core package list does not contain the CLI'
if grep -Eq '^/(etc/config|etc/init\.d|etc/uci-defaults|usr/libexec|usr/sbin)/' "$luci_list"; then
	fail 'core runtime remains in the upgraded LuCI package list'
fi

duplicates=$(cat "$core_list" "$luci_list" "$provider_list" | sort | uniq -d)
[ -z "$duplicates" ] || fail "split packages have overlapping owned paths: $duplicates"

apk adbdump "$new_luci" | grep -Fq '    - led-nightmode' || fail 'LuCI APK does not depend on the core APK'
apk adbdump "$new_provider" | grep -Fq '    - led-nightmode' || fail 'provider APK does not depend on the core APK'

printf 'Split APK upgrade test passed.\n'
