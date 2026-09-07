#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

usage() {
	printf 'Usage: %s <led-nightmode.apk>\n' "$0" >&2
	exit 2
}

[ "$#" -eq 1 ] || usage
command -v docker >/dev/null 2>&1 || fail 'docker is required'

case $1 in
	/*) CORE_APK=$1 ;;
	*) CORE_APK=$PWD/$1 ;;
esac
[ -f "$CORE_APK" ] || fail "core APK not found: $CORE_APK"

APK_TOOLS_IMAGE=${APK_TOOLS_IMAGE:-alpine@sha256:020dfcbaaf4cc1078bf2d9c7ba31a8466e334061dcd2f248001d68f79e52c000}
OPENWRT_RELEASE=${OPENWRT_RELEASE:-25.12.4}
OPENWRT_ARCH=${OPENWRT_ARCH:-aarch64_cortex-a53}
OPENWRT_TARGET=${OPENWRT_TARGET:-mediatek/filogic}

run_scenario() {
	scenario=$1
	printf '\nscenario=%s\n' "$scenario"
	docker run --rm \
		--env "SCENARIO=$scenario" \
		--env "OPENWRT_RELEASE=$OPENWRT_RELEASE" \
		--env "OPENWRT_ARCH=$OPENWRT_ARCH" \
		--env "OPENWRT_TARGET=$OPENWRT_TARGET" \
		--volume "$CORE_APK:/input/led-nightmode.apk:ro" \
		"$APK_TOOLS_IMAGE" sh -c '
set -eu

target_repo=https://downloads.openwrt.org/releases/$OPENWRT_RELEASE/targets/$OPENWRT_TARGET/packages/packages.adb
base_repo=https://downloads.openwrt.org/releases/$OPENWRT_RELEASE/packages/$OPENWRT_ARCH/base/packages.adb
packages_repo=https://downloads.openwrt.org/releases/$OPENWRT_RELEASE/packages/$OPENWRT_ARCH/packages/packages.adb
printf "%s\n" "$target_repo" "$base_repo" "$packages_repo" > /etc/apk/repositories

mkdir -p /tmp/cache
apk --arch "$OPENWRT_ARCH" --allow-untrusted \
	--cache-dir /tmp/cache --cache-packages update >/dev/null

if [ "$SCENARIO" = verify-base ]; then
	mkdir -p /tmp/base-closure
	apk --arch "$OPENWRT_ARCH" --allow-untrusted \
		--cache-dir /tmp/cache --repositories-file /etc/apk/repositories \
		fetch --recursive \
		--output /tmp/base-closure base-files procd-ujail uci >/dev/null
	for package in jshn libc procd uci; do
		find /tmp/base-closure -maxdepth 1 -name "$package-*.apk" -print -quit |
			grep -q . || exit 1
	done
	for package in rpcd sunwait; do
		if find /tmp/base-closure -maxdepth 1 -name "$package-*.apk" -print -quit |
			grep -q .; then
			echo "unexpected_base_package=$package" >&2
			exit 1
		fi
	done
	echo "base_present=jshn libc procd uci"
	echo "base_missing=rpcd sunwait"
	exit 0
fi

mkdir -p /tmp/empty /tmp/dummy /tmp/root
base_packages="jshn libc procd uci libblobmsg-json20260213 libjson-c5 libubox20260213 libubus20251202 libuci20250120"
case $SCENARIO in
	full)
		initdb=--initdb
		;;
	headless-base|luci-base)
		[ "$SCENARIO" = luci-base ] && base_packages="$base_packages rpcd"
		for package in $base_packages; do
			apk mkpkg \
				-o "/tmp/dummy/$package.apk" \
				-I "name:$package" \
				-I version:1-r0 \
				-I arch:noarch \
				-I description:base-image-fixture \
				-F /tmp/empty >/dev/null
		done
		apk add --root /tmp/root --initdb --allow-untrusted --no-scripts \
			/tmp/dummy/*.apk >/dev/null
		initdb=
		;;
	*)
		echo "unknown scenario: $SCENARIO" >&2
		exit 2
		;;
esac

before_bytes=$(du -sb /tmp/root | awk "{ print \$1 }")
apk add --root /tmp/root $initdb --no-scripts --allow-untrusted \
	--arch "$OPENWRT_ARCH" \
	--cache-dir /tmp/cache --cache-packages \
	--repositories-file /etc/apk/repositories \
	/input/led-nightmode.apk >/dev/null
after_bytes=$(du -sb /tmp/root | awk "{ print \$1 }")

apk_total=0
installed_total=0
payload_total=0
package_count=0
printf "packages=name\\tversion\\tapk_bytes\\tinstalled_bytes\\tpayload_regular_bytes\n"
: > /tmp/package-lines
for package_file in /tmp/cache/*.apk; do
	name=$(apk adbdump "$package_file" | sed -n "s/^  name: //p")
	version=$(apk adbdump "$package_file" | sed -n "s/^  version: //p")
	installed=$(apk adbdump "$package_file" | sed -n "s/^  installed-size: //p")
	apk_bytes=$(stat -c %s "$package_file")
	list=/tmp/root/lib/apk/packages/$name.list
	payload=0
	if [ -f "$list" ]; then
		while IFS= read -r path; do
			file=/tmp/root$path
			if [ -f "$file" ] && [ ! -L "$file" ]; then
				file_bytes=$(stat -c %s "$file")
				payload=$((payload + file_bytes))
			fi
		done < "$list"
	fi
	printf "package=%s\\t%s\\t%s\\t%s\\t%s\n" \
		"$name" "$version" "$apk_bytes" "$installed" "$payload" >> /tmp/package-lines
	apk_total=$((apk_total + apk_bytes))
	installed_total=$((installed_total + installed))
	payload_total=$((payload_total + payload))
	package_count=$((package_count + 1))
done
sort /tmp/package-lines

index_total=$(find /tmp/cache -maxdepth 1 -type f ! -name "*.apk" \
	-exec stat -c %s {} \; | awk "{ total += \$1 } END { print total + 0 }")

echo "package_count=$package_count"
echo "apk_download_bytes=$apk_total"
echo "declared_installed_bytes=$installed_total"
echo "payload_regular_bytes=$payload_total"
echo "root_logical_delta_bytes=$((after_bytes - before_bytes))"
echo "repository_index_bytes=$index_total"
if [ -r /sys/fs/cgroup/memory.peak ]; then
	echo "container_memory_peak_bytes=$(cat /sys/fs/cgroup/memory.peak)"
fi
echo "repository_indexes=sha256 bytes file"
for index in /tmp/cache/APKINDEX*; do
	sha256sum "$index"
	stat -c "%s %n" "$index"
done
'
}

printf 'apk=%s\n' "$CORE_APK"
printf 'apk_tools_image=%s\n' "$APK_TOOLS_IMAGE"
printf 'openwrt_release=%s\n' "$OPENWRT_RELEASE"
printf 'openwrt_target=%s\n' "$OPENWRT_TARGET"
printf 'openwrt_arch=%s\n' "$OPENWRT_ARCH"

run_scenario verify-base
run_scenario full
run_scenario headless-base
run_scenario luci-base
