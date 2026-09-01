#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
PROVIDER_DIR=$PROJECT_ROOT/providers/quectel-qnwcfg-ledmode/root/usr/libexec/led-nightmode/providers
PROVIDER=$PROVIDER_DIR/quectel-qnwcfg-ledmode
RUNNER=$PROJECT_ROOT/core/root/usr/libexec/led-nightmode-provider-service
SCHEDULE=$PROJECT_ROOT/core/root/usr/libexec/led-nightmode-service
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/led-nightmode-provider-test.XXXXXX")
EMULATE_FILE=$TEST_ROOT/modem-ledmode
STATE_DIR=$TEST_ROOT/state
LOCK_DIR=$TEST_ROOT/lock
FAKE_BIN=$TEST_ROOT/bin
FAKE_TIME=$TEST_ROOT/local-time
FLAKY_PROVIDER_DIR=$TEST_ROOT/providers
FLAKY_MARKER=$TEST_ROOT/flaky-first-failure
FLAKY_STATE=$TEST_ROOT/flaky-state
RUNNER_PID=

cleanup() {
	if [ -n "$RUNNER_PID" ] && kill -0 "$RUNNER_PID" 2>/dev/null; then
		kill -TERM "$RUNNER_PID" 2>/dev/null || true
		wait "$RUNNER_PID" 2>/dev/null || true
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

assert_contains() {
	haystack=$1
	needle=$2
	message=$3
	case $haystack in
		*"$needle"*) ;;
		*) fail "$message (missing '$needle')" ;;
	esac
}

wait_for_value() {
	path=$1
	wanted=$2
	attempt=0
	while [ "$attempt" -lt 100 ]; do
		if [ -f "$path" ] && [ "$(cat "$path")" = "$wanted" ]; then
			return 0
		fi
		sleep 0.05
		attempt=$((attempt + 1))
	done
	return 1
}

run_provider() {
	LED_PROVIDER_DEVICE=/dev/emulated \
	LED_PROVIDER_INSTANCE=lte \
	LED_PROVIDER_STATE_DIR=$STATE_DIR \
	LED_PROVIDER_LOCK_DIR=$LOCK_DIR \
	LED_PROVIDER_TEST_SECONDS=${LED_TEST_SECONDS:-0} \
	LED_QUECTEL_EMULATE_FILE=$EMULATE_FILE \
		"$PROVIDER" "$@"
}

printf '%s\n' '0,0' > "$EMULATE_FILE"
probe_output=$(run_provider probe)
assert_contains "$probe_output" "$(printf 'quectel-qnwcfg-ledmode\tsupported\t0,0')" 'probe reports a supported response'

test_output=$(run_provider test)
assert_contains "$test_output" '0,0 -> 0,1 -> 0,0' 'visual test reports the temporary indicator transition'
assert_eq '0,0' "$(cat "$EMULATE_FILE")" 'visual test restores the exact original modem LED mode'
[ ! -e "$STATE_DIR" ] || fail 'successful visual test removes its temporary state'

run_provider night >/dev/null
assert_eq '0,1' "$(cat "$EMULATE_FILE")" 'night disables the modem indicator'
assert_eq '0,0' "$(cat "$STATE_DIR/ledmode")" 'night preserves the original modem LED mode'

run_provider night >/dev/null
assert_eq '0,0' "$(cat "$STATE_DIR/ledmode")" 'repeated night does not replace original state'
status_output=$(run_provider status)
assert_contains "$status_output" "$(printf 'quectel-qnwcfg-ledmode\t0,1\tyes')" 'status reports managed night state'

test_output=$(run_provider test)
assert_contains "$test_output" '0,1 -> 0,0 -> 0,1' 'visual test changes a currently disabled indicator in the visible direction'
assert_eq '0,1' "$(cat "$EMULATE_FILE")" 'visual test restores the managed night state'
assert_eq '0,0' "$(cat "$STATE_DIR/ledmode")" 'visual test does not replace the saved day state'

run_provider day >/dev/null
assert_eq '0,0' "$(cat "$EMULATE_FILE")" 'day restores the original modem LED mode'
[ ! -e "$STATE_DIR" ] || fail 'day removes restored provider state'

LED_PROVIDER_DEVICE=/dev/emulated \
LED_PROVIDER_INSTANCE=lte \
LED_PROVIDER_STATE_DIR=$STATE_DIR \
LED_PROVIDER_LOCK_DIR=$LOCK_DIR \
LED_PROVIDER_TEST_SECONDS=2 \
LED_QUECTEL_EMULATE_FILE=$EMULATE_FILE \
"$PROVIDER" test >/dev/null &
TEST_PID=$!
wait_for_value "$EMULATE_FILE" '0,1' || fail 'interruptible visual test did not change the indicator'
kill -TERM "$TEST_PID"
if wait "$TEST_PID"; then
	fail 'interrupted visual test must report failure'
fi
assert_eq '0,0' "$(cat "$EMULATE_FILE")" 'signal cleanup restores the visual-test state'
[ ! -e "$STATE_DIR" ] || fail 'signal cleanup removes restored visual-test state'

printf '%s\n' 'broken' > "$EMULATE_FILE"
if run_provider probe >/dev/null 2>&1; then
	fail 'probe must reject an unsupported modem response'
fi

printf '%s\n' '0,0' > "$EMULATE_FILE"
LED_PROVIDER_DIR=$PROVIDER_DIR \
LED_NIGHTMODE_SCHEDULE_BIN=$SCHEDULE \
LED_PROVIDER_STATE_DIR=$STATE_DIR \
LED_PROVIDER_LOCK_DIR=$LOCK_DIR \
LED_QUECTEL_EMULATE_FILE=$EMULATE_FILE \
"$RUNNER" quectel-qnwcfg-ledmode /dev/emulated lte night >/dev/null &
RUNNER_PID=$!

wait_for_value "$EMULATE_FILE" '0,1' || fail 'provider runner did not apply night state'
kill -TERM "$RUNNER_PID"
wait "$RUNNER_PID"
RUNNER_PID=
assert_eq '0,0' "$(cat "$EMULATE_FILE")" 'provider runner stop restores day state'
[ ! -e "$STATE_DIR" ] || fail 'provider runner stop removes restored state'

mkdir -p "$FLAKY_PROVIDER_DIR"
printf '%s\n' '#!/bin/sh' > "$FLAKY_PROVIDER_DIR/flaky-driver"
printf '%s\n' 'case $1 in' >> "$FLAKY_PROVIDER_DIR/flaky-driver"
printf '%s\n' 'night)' >> "$FLAKY_PROVIDER_DIR/flaky-driver"
printf '%s\n' '  if [ ! -e "$LED_TEST_FLAKY_MARKER" ]; then' >> "$FLAKY_PROVIDER_DIR/flaky-driver"
printf '%s\n' '    : > "$LED_TEST_FLAKY_MARKER"' >> "$FLAKY_PROVIDER_DIR/flaky-driver"
printf '%s\n' '    exit 1' >> "$FLAKY_PROVIDER_DIR/flaky-driver"
printf '%s\n' '  fi' >> "$FLAKY_PROVIDER_DIR/flaky-driver"
printf '%s\n' '  printf "%s\n" night > "$LED_TEST_FLAKY_STATE"' >> "$FLAKY_PROVIDER_DIR/flaky-driver"
printf '%s\n' '  ;;' >> "$FLAKY_PROVIDER_DIR/flaky-driver"
printf '%s\n' 'day) printf "%s\n" day > "$LED_TEST_FLAKY_STATE" ;;' >> "$FLAKY_PROVIDER_DIR/flaky-driver"
printf '%s\n' '*) exit 1 ;;' >> "$FLAKY_PROVIDER_DIR/flaky-driver"
printf '%s\n' 'esac' >> "$FLAKY_PROVIDER_DIR/flaky-driver"
chmod +x "$FLAKY_PROVIDER_DIR/flaky-driver"

LED_PROVIDER_DIR=$FLAKY_PROVIDER_DIR \
LED_NIGHTMODE_SCHEDULE_BIN=$SCHEDULE \
LED_PROVIDER_RETRY_INTERVAL=0.05 \
LED_TEST_FLAKY_MARKER=$FLAKY_MARKER \
LED_TEST_FLAKY_STATE=$FLAKY_STATE \
"$RUNNER" flaky-driver /dev/emulated flaky night >/dev/null 2>&1 &
RUNNER_PID=$!

wait_for_value "$FLAKY_STATE" night || fail 'provider runner did not retry a transient initial failure'
kill -0 "$RUNNER_PID" 2>/dev/null || fail 'provider runner exited after a transient initial failure'
kill -TERM "$RUNNER_PID"
wait "$RUNNER_PID"
RUNNER_PID=
assert_eq day "$(cat "$FLAKY_STATE")" 'retried provider runner restores day state when stopped'

mkdir -p "$FAKE_BIN"
printf '%s\n' '#!/bin/sh' > "$FAKE_BIN/date"
printf '%s\n' 'cat "$LED_TEST_TIME_FILE"' >> "$FAKE_BIN/date"
chmod +x "$FAKE_BIN/date"
printf '%s\n' '12:00' > "$FAKE_TIME"

PATH=$FAKE_BIN:$PATH \
LED_TEST_TIME_FILE=$FAKE_TIME \
LED_PROVIDER_DIR=$PROVIDER_DIR \
LED_NIGHTMODE_SCHEDULE_BIN=$SCHEDULE \
LED_SCHEDULE_INTERVAL=0.05 \
LED_PROVIDER_STATE_DIR=$STATE_DIR \
LED_PROVIDER_LOCK_DIR=$LOCK_DIR \
LED_QUECTEL_EMULATE_FILE=$EMULATE_FILE \
"$RUNNER" quectel-qnwcfg-ledmode /dev/emulated lte day fixed 23:00 07:00 '' '' daylight >/dev/null &
RUNNER_PID=$!

printf '%s\n' '23:00' > "$FAKE_TIME"
wait_for_value "$EMULATE_FILE" '0,1' || fail 'provider runner did not follow the scheduled night transition'
printf '%s\n' '07:00' > "$FAKE_TIME"
wait_for_value "$EMULATE_FILE" '0,0' || fail 'provider runner did not follow the scheduled day transition'

kill -TERM "$RUNNER_PID"
wait "$RUNNER_PID"
RUNNER_PID=

if LED_PROVIDER_DIR=$PROVIDER_DIR LED_NIGHTMODE_SCHEDULE_BIN=$SCHEDULE "$RUNNER" '../bad' /dev/emulated lte night >/dev/null 2>&1; then
	fail 'provider runner must reject path traversal in driver names'
fi
if LED_PROVIDER_DIR=$PROVIDER_DIR LED_NIGHTMODE_SCHEDULE_BIN=$SCHEDULE "$RUNNER" missing /dev/emulated lte night >/dev/null 2>&1; then
	fail 'provider runner must reject an unavailable driver'
fi

printf '%s\n' 'All modem provider tests passed.'
