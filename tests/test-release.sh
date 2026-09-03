#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
PACKAGE_MAKEFILE=$PROJECT_ROOT/Makefile
DEFAULT_CONFIG=$PROJECT_ROOT/core/root/etc/config/led-nightmode

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
grep -Fqx 'LUCI_DEPENDS:=+luci-base +led-nightmode' "$PACKAGE_MAKEFILE" || fail 'LuCI package must depend on the split core'
grep -Fqx 'LUCI_MAINTAINER:=Mv Go <rapture-ribose6k@icloud.com>' "$PACKAGE_MAKEFILE" || fail 'LuCI maintainer identity is incorrect'
[ "$(grep -Fxc '  MAINTAINER:=Mv Go <rapture-ribose6k@icloud.com>' "$PACKAGE_MAKEFILE")" -eq 2 ] || fail 'core/provider maintainer identity is incorrect'
grep -Fq 'define Package/led-nightmode' "$PACKAGE_MAKEFILE" || fail 'core package definition is missing'
grep -Fq 'define Package/led-nightmode/conffiles' "$PACKAGE_MAKEFILE" || fail 'core package must own the UCI conffile'
grep -Fq 'define Package/led-nightmode/postinst' "$PACKAGE_MAKEFILE" || fail 'core package must own rpcd lifecycle reload'
grep -Fq '/etc/init.d/rpcd reload' "$PACKAGE_MAKEFILE" || fail 'core package must reload rpcd after live installation'
if grep -Fq 'define Package/luci-app-led-nightmode/postinst' "$PACKAGE_MAKEFILE"; then
	fail 'LuCI package must inherit the standard luci.mk post-install hook'
fi
if grep -Fq 'define Package/luci-app-led-nightmode/conffiles' "$PACKAGE_MAKEFILE"; then
	fail 'LuCI package must not retain ownership of the core UCI conffile'
fi
grep -Fqx '  DEPENDS:=+led-nightmode +picocom' "$PACKAGE_MAKEFILE" || fail 'provider package must depend on the split core'
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

for core_path in "$PROJECT_ROOT/core/root" "$PROJECT_ROOT/root" "$PROJECT_ROOT/htdocs"; do
	if find "$core_path" -type f -exec grep -EIl 'BPI-R3|RM520|ttyUSB[0-9]|quectel-qnwcfg|mt76-phy' {} + | grep -q .; then
		find "$core_path" -type f -exec grep -EIn 'BPI-R3|RM520|ttyUSB[0-9]|quectel-qnwcfg|mt76-phy' {} + >&2
		fail 'device-specific identifiers leaked into the universal runtime package'
	fi
done

[ "$(readlink "$PROJECT_ROOT/core/root/usr/libexec/led-nightmode-schedule")" = led-nightmode-service ] || fail 'schedule entry point symlink is incorrect'
[ "$(readlink "$PROJECT_ROOT/core/root/usr/libexec/rpcd/luci.led-nightmode")" = ../led-nightmode-service ] || fail 'rpcd entry point symlink is incorrect'

for core_owned_path in \
	etc/config/led-nightmode \
	etc/init.d/led-nightmode \
	etc/uci-defaults/99-led-nightmode \
	usr/libexec/led-nightmode-provider-service \
	usr/libexec/led-nightmode-schedule \
	usr/libexec/led-nightmode-service \
	usr/libexec/rpcd/luci.led-nightmode \
	usr/sbin/led-nightmode
do
	[ -e "$PROJECT_ROOT/core/root/$core_owned_path" ] || [ -L "$PROJECT_ROOT/core/root/$core_owned_path" ] || fail "core-owned path is missing: $core_owned_path"
	[ ! -e "$PROJECT_ROOT/root/$core_owned_path" ] && [ ! -L "$PROJECT_ROOT/root/$core_owned_path" ] || fail "core-owned path leaked into the LuCI package: $core_owned_path"
done

[ -f "$PROJECT_ROOT/root/usr/share/luci/menu.d/luci-app-led-nightmode.json" ] || fail 'LuCI menu metadata is missing'
[ -f "$PROJECT_ROOT/root/usr/share/rpcd/acl.d/luci-app-led-nightmode.json" ] || fail 'LuCI ACL metadata is missing'

[ -s "$PROJECT_ROOT/po/templates/led-nightmode.pot" ] || fail 'LuCI translation template is missing'

for artifact_name in \
	"led-nightmode-$release_id.apk" \
	"luci-app-led-nightmode-$release_id.apk" \
	"led-nightmode-provider-quectel-qnwcfg-ledmode-$release_id.apk"
do
	artifact=$PROJECT_ROOT/dist/$artifact_name
	[ -f "$artifact" ] || continue
	artifact_sha256=$(sha256_file "$artifact")
	grep -Fq "\`$artifact_sha256\`" "$PROJECT_ROOT/docs/building/openwrt-sdk.md" || fail "$artifact_name hash is not recorded in the SDK document"
done

printf 'Release checks passed for %s.\n' "$release_id"
