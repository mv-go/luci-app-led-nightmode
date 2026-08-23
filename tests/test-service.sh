#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
CLI=$PROJECT_ROOT/root/usr/sbin/led-nightmode
SERVICE=$PROJECT_ROOT/root/usr/libexec/led-nightmode-service
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/led-nightmode-service-test.XXXXXX")
SYSFS_ROOT=$TEST_ROOT/sys/class/leds
STATE_DIR=$TEST_ROOT/state
SERVICE_PID=

cleanup() {
	if [ -n "$SERVICE_PID" ] && kill -0 "$SERVICE_PID" 2>/dev/null; then
		kill -TERM "$SERVICE_PID" 2>/dev/null || true
		wait "$SERVICE_PID" 2>/dev/null || true
	fi
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

wait_for_path() {
	path=$1
	attempt=0
	while [ ! -e "$path" ] && [ "$attempt" -lt 100 ]; do
		sleep 0.05
		attempt=$((attempt + 1))
	done
	[ -e "$path" ]
}

mkdir -p "$SYSFS_ROOT/green:status" "$SYSFS_ROOT/mt76-phy0"
printf '%s\n' 1 > "$SYSFS_ROOT/green:status/max_brightness"
printf '%s\n' 1 > "$SYSFS_ROOT/green:status/brightness"
printf '%s\n' '[none] timer' > "$SYSFS_ROOT/green:status/trigger"
printf '%s\n' 255 > "$SYSFS_ROOT/mt76-phy0/max_brightness"
printf '%s\n' 0 > "$SYSFS_ROOT/mt76-phy0/brightness"
printf '%s\n' 'none [phy0tpt]' > "$SYSFS_ROOT/mt76-phy0/trigger"

LED_NIGHTMODE_BIN=$CLI \
LED_SYSFS_ROOT=$SYSFS_ROOT \
LED_STATE_DIR=$STATE_DIR \
LED_SYSFS_EMULATE=1 \
"$SERVICE" night 7 >/dev/null &
SERVICE_PID=$!

wait_for_path "$STATE_DIR/green:status" || fail 'service did not apply the night profile'
assert_eq 0 "$(cat "$SYSFS_ROOT/green:status/brightness")" 'service switches off a binary LED'
assert_eq 7 "$(cat "$SYSFS_ROOT/mt76-phy0/brightness")" 'service applies an explicitly configured multi-level target'

kill -TERM "$SERVICE_PID"
wait "$SERVICE_PID"
SERVICE_PID=

assert_eq 1 "$(cat "$SYSFS_ROOT/green:status/brightness")" 'service stop restores binary brightness'
assert_eq 0 "$(cat "$SYSFS_ROOT/mt76-phy0/brightness")" 'service stop restores multi-level brightness'
[ ! -d "$STATE_DIR" ] || fail 'service stop removes restored state'

if LED_NIGHTMODE_BIN=$CLI "$SERVICE" invalid 1 >/dev/null 2>&1; then
	fail 'service must reject an invalid phase'
fi
if LED_NIGHTMODE_BIN=$CLI "$SERVICE" night invalid >/dev/null 2>&1; then
	fail 'service must reject invalid brightness'
fi

printf '%s\n' 'All service tests passed.'
