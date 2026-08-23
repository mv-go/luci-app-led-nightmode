#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
CLI=$PROJECT_ROOT/bin/led-nightmode
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/led-nightmode-test.XXXXXX")
SYSFS_ROOT=$TEST_ROOT/sys/class/leds
STATE_DIR=$TEST_ROOT/state

cleanup() {
	rm -rf "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

assert_eq() {
	expected=$1
	actual=$2
	message=$3
	if [ "$expected" != "$actual" ]; then
		printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
		exit 1
	fi
}

assert_contains() {
	haystack=$1
	needle=$2
	message=$3
	case $haystack in
		*"$needle"*) ;;
		*) fail "$message (missing '$needle')" ;;
	esac
}

add_led() {
	led_name=$1
	max_brightness=$2
	brightness=$3
	triggers=$4
	led_dir=$SYSFS_ROOT/$led_name
	mkdir -p "$led_dir"
	printf '%s\n' "$max_brightness" > "$led_dir/max_brightness"
	printf '%s\n' "$brightness" > "$led_dir/brightness"
	printf '%s\n' "$triggers" > "$led_dir/trigger"
}

run_cli() {
	LED_SYSFS_ROOT=$SYSFS_ROOT \
	LED_STATE_DIR=$STATE_DIR \
	LED_SYSFS_EMULATE=1 \
	"$CLI" "$@"
}

mkdir -p "$SYSFS_ROOT"
add_led 'blue:wlan-1' 1 1 'none timer [netdev] pattern'
add_led 'mt76-phy0' 255 0 'none timer pattern [phy0tpt]'
printf '%s\n' 'phy0-ap0' > "$SYSFS_ROOT/blue:wlan-1/device_name"
printf '%s\n' 1 > "$SYSFS_ROOT/blue:wlan-1/link"
printf '%s\n' 1 > "$SYSFS_ROOT/blue:wlan-1/rx"
printf '%s\n' 1 > "$SYSFS_ROOT/blue:wlan-1/tx"
printf '%s\n' 0 > "$SYSFS_ROOT/blue:wlan-1/offloaded"
chmod 444 "$SYSFS_ROOT/blue:wlan-1/offloaded"

list_output=$(run_cli list)
assert_contains "$list_output" 'blue:wlan-1' 'list includes the binary LED'
assert_contains "$list_output" 'mt76-phy0' 'list includes the dimmable LED'
assert_contains "$list_output" 'netdev' 'list reports the active trigger'

status_output=$(run_cli status)
assert_contains "$status_output" 'night_mode	inactive' 'status starts inactive'

dry_run_output=$(run_cli --dry-run night)
assert_contains "$dry_run_output" 'blue:wlan-1: trigger netdev -> none' 'night dry-run reports trigger change'
assert_eq 1 "$(sed -n '1p' "$SYSFS_ROOT/blue:wlan-1/brightness")" 'dry-run preserves brightness'
[ ! -d "$STATE_DIR" ] || fail 'dry-run must not create state'

run_cli night >/dev/null
assert_eq 0 "$(sed -n '1p' "$SYSFS_ROOT/blue:wlan-1/brightness")" 'night switches off a binary LED'
assert_eq 1 "$(sed -n '1p' "$SYSFS_ROOT/mt76-phy0/brightness")" 'night dims a dimmable LED'
assert_contains "$(sed -n '1p' "$SYSFS_ROOT/blue:wlan-1/trigger")" '[none]' 'night selects none trigger'
assert_eq netdev "$(cat "$STATE_DIR/blue:wlan-1/trigger")" 'night saves the original trigger'
assert_eq phy0tpt "$(cat "$STATE_DIR/mt76-phy0/trigger")" 'night saves a throughput trigger'
assert_eq phy0-ap0 "$(cat "$STATE_DIR/blue:wlan-1/attributes/device_name")" 'night saves netdev device name'
[ ! -e "$STATE_DIR/blue:wlan-1/attributes/offloaded" ] || fail 'night must not save a read-only trigger attribute'

run_cli night >/dev/null
assert_eq 1 "$(cat "$STATE_DIR/blue:wlan-1/brightness")" 'repeated night preserves original state'

status_output=$(run_cli status)
assert_contains "$status_output" 'night_mode	active' 'status reports active night mode'
assert_contains "$status_output" 'blue:wlan-1	0	none	yes' 'status marks a managed LED'

day_dry_run=$(run_cli --dry-run day)
assert_contains "$day_dry_run" 'restore brightness 1 and trigger netdev' 'day dry-run reports restoration'
assert_eq 0 "$(sed -n '1p' "$SYSFS_ROOT/blue:wlan-1/brightness")" 'day dry-run preserves night state'

printf '%s\n' 'wrong-device' > "$SYSFS_ROOT/blue:wlan-1/device_name"
printf '%s\n' 0 > "$SYSFS_ROOT/blue:wlan-1/link"
run_cli day >/dev/null
assert_eq 1 "$(sed -n '1p' "$SYSFS_ROOT/blue:wlan-1/brightness")" 'day restores binary brightness'
assert_eq 0 "$(sed -n '1p' "$SYSFS_ROOT/mt76-phy0/brightness")" 'day restores dimmable brightness'
assert_contains "$(sed -n '1p' "$SYSFS_ROOT/blue:wlan-1/trigger")" '[netdev]' 'day restores netdev trigger'
assert_contains "$(sed -n '1p' "$SYSFS_ROOT/mt76-phy0/trigger")" '[phy0tpt]' 'day restores throughput trigger'
assert_eq phy0-ap0 "$(cat "$SYSFS_ROOT/blue:wlan-1/device_name")" 'day restores netdev device name'
assert_eq 1 "$(cat "$SYSFS_ROOT/blue:wlan-1/link")" 'day restores netdev link setting'
[ ! -d "$STATE_DIR" ] || fail 'day removes state after successful restore'

run_cli night >/dev/null
mv "$SYSFS_ROOT/blue:wlan-1" "$TEST_ROOT/missing-led"
if run_cli day >/dev/null 2>&1; then
	fail 'day must fail when a managed LED is missing'
fi
[ -d "$STATE_DIR/blue:wlan-1" ] || fail 'missing LED state must be retained'
mv "$TEST_ROOT/missing-led" "$SYSFS_ROOT/blue:wlan-1"
run_cli day >/dev/null

printf '%s\n' 'All CLI tests passed.'
