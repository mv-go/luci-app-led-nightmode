#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
PACKAGE_MAKEFILE=$PROJECT_ROOT/Makefile
DEFAULT_CONFIG=$PROJECT_ROOT/root/etc/config/led-nightmode

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

make_value() {
	sed -n "s/^$1:=//p" "$PACKAGE_MAKEFILE"
}

sha256_file() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{ print $1 }'
	else
		shasum -a 256 "$1" | awk '{ print $1 }'
	fi
}

package_version=$(make_value PKG_VERSION)
package_release=$(make_value PKG_RELEASE)
release_id=$package_version-r$package_release

[ -n "$package_version" ] || fail 'PKG_VERSION is missing'
case $package_release in
	''|*[!0-9]*) fail 'PKG_RELEASE must be a positive integer' ;;
esac
[ "$package_release" -gt 0 ] || fail 'PKG_RELEASE must be greater than zero'

grep -Fqx 'PKG_LICENSE:=Apache-2.0' "$PACKAGE_MAKEFILE" || fail 'package license metadata is missing'
grep -Fqx 'PKG_LICENSE_FILES:=LICENSE' "$PACKAGE_MAKEFILE" || fail 'package license file metadata is missing'
grep -Fqx 'LUCI_NAME:=luci-app-led-nightmode' "$PACKAGE_MAKEFILE" || fail 'standalone SDK builds require an explicit LuCI package name'
[ -s "$PROJECT_ROOT/LICENSE" ] || fail 'LICENSE is missing or empty'

grep -Fq "\`$release_id\`" "$PROJECT_ROOT/README.md" || fail "README does not identify package revision $release_id"
grep -Fq "\`$release_id\`" "$PROJECT_ROOT/docs/compatibility.md" || fail "compatibility matrix does not identify release $release_id"
grep -Fq "\`$release_id\`" "$PROJECT_ROOT/docs/releasing.md" || fail "release checklist does not identify release $release_id"
grep -Fq "## $package_version" "$PROJECT_ROOT/CHANGELOG.md" || fail "changelog does not contain version $package_version"
grep -Fq "metadata reported version \`$release_id\`" "$PROJECT_ROOT/docs/building/openwrt-sdk.md" || fail "SDK document does not identify artifact metadata version $release_id"

grep -Eq "^[[:space:]]*option enabled '0'$" "$DEFAULT_CONFIG" || fail 'fresh installs must remain disabled'
if grep -Eq "^[[:space:]]*config provider" "$DEFAULT_CONFIG"; then
	fail 'the universal default config must not preconfigure a hardware provider'
fi

for core_path in "$PROJECT_ROOT/root" "$PROJECT_ROOT/htdocs"; do
	if find "$core_path" -type f -exec grep -EIl 'BPI-R3|RM520|ttyUSB[0-9]|quectel-qnwcfg|mt76-phy' {} + | grep -q .; then
		find "$core_path" -type f -exec grep -EIn 'BPI-R3|RM520|ttyUSB[0-9]|quectel-qnwcfg|mt76-phy' {} + >&2
		fail 'device-specific identifiers leaked into the universal runtime package'
	fi
done

[ "$(readlink "$PROJECT_ROOT/root/usr/libexec/led-nightmode-schedule")" = led-nightmode-service ] || fail 'schedule entry point symlink is incorrect'
[ "$(readlink "$PROJECT_ROOT/root/usr/libexec/rpcd/luci.led-nightmode")" = ../led-nightmode-service ] || fail 'rpcd entry point symlink is incorrect'

[ -s "$PROJECT_ROOT/po/templates/led-nightmode.pot" ] || fail 'LuCI translation template is missing'

for artifact_name in \
	"luci-app-led-nightmode-$release_id.apk" \
	"led-nightmode-provider-quectel-qnwcfg-ledmode-$release_id.apk"
do
	artifact=$PROJECT_ROOT/dist/$artifact_name
	[ -f "$artifact" ] || continue
	artifact_sha256=$(sha256_file "$artifact")
	grep -Fq "\`$artifact_sha256\`" "$PROJECT_ROOT/docs/building/openwrt-sdk.md" || fail "$artifact_name hash is not recorded in the SDK document"
done

printf 'Release checks passed for %s.\n' "$release_id"
