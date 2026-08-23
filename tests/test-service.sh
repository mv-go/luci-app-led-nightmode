#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
CLI=$PROJECT_ROOT/root/usr/sbin/led-nightmode
SERVICE=$PROJECT_ROOT/root/usr/libexec/led-nightmode-service
SCHEDULE=$SERVICE
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/led-nightmode-service-test.XXXXXX")
SYSFS_ROOT=$TEST_ROOT/sys/class/leds
STATE_DIR=$TEST_ROOT/state
RUNTIME_DIR=$TEST_ROOT/runtime
FAKE_BIN=$TEST_ROOT/bin
FAKE_TIME=$TEST_ROOT/local-time
FAKE_SUNWAIT=$TEST_ROOT/sunwait
SUNWAIT_ARGS=$TEST_ROOT/sunwait-args
RPC_ROOT=$TEST_ROOT/rpc-root
RPC_BIN=$TEST_ROOT/rpc-bin
RPC_UCI_LOG=$TEST_ROOT/uci-log
RPC_INIT_LOG=$TEST_ROOT/init-log
RPC_PHASE_FILE=$TEST_ROOT/rpc-phase
RPC_PROVIDER_DIR=$TEST_ROOT/providers
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

assert_contains() {
	haystack=$1
	needle=$2
	message=$3
	case $haystack in
		*"$needle"*) ;;
		*) fail "$message (missing '$needle')" ;;
	esac
}

assert_fails() {
	message=$1
	shift
	if "$@" >/dev/null 2>&1; then
		fail "$message"
	fi
}

run_schedule() {
	LED_SUNWAIT_BIN=$FAKE_SUNWAIT "$SCHEDULE" "$@"
}

run_rpc() {
	IPKG_INSTROOT=$RPC_ROOT \
	LED_NIGHTMODE_NOW=12:00 \
	LED_RPCD_UCI_BIN=$RPC_BIN/uci \
	LED_RPCD_INIT_BIN=$RPC_BIN/init \
	LED_RPCD_SCHEDULE_BIN=$SCHEDULE \
	LED_RPCD_PHASE_FILE=$RPC_PHASE_FILE \
	LED_RPCD_RUNTIME_DIR=$TEST_ROOT/rpc-runtime \
	LED_RPCD_PROVIDER_DIR=$RPC_PROVIDER_DIR \
	LED_TEST_UCI_LOG=$RPC_UCI_LOG \
	LED_TEST_INIT_LOG=$RPC_INIT_LOG \
		"$SERVICE" "$@"
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

printf '%s\n' '#!/bin/sh' > "$FAKE_SUNWAIT"
printf '%s\n' 'printf "%s\n" "$*" > "$LED_TEST_SUNWAIT_ARGS"' >> "$FAKE_SUNWAIT"
printf '%s\n' 'exit "${LED_TEST_SUNWAIT_STATUS:-2}"' >> "$FAKE_SUNWAIT"
chmod +x "$FAKE_SUNWAIT"
export LED_TEST_SUNWAIT_ARGS=$SUNWAIT_ARGS

assert_eq day "$(run_schedule resolve manual day 23:00 07:00 '' '' daylight)" 'manual mode returns the configured day phase'
assert_eq night "$(run_schedule resolve manual night 23:00 07:00 '' '' daylight)" 'manual mode returns the configured night phase'
assert_eq day "$(LED_NIGHTMODE_NOW=12:00 run_schedule resolve fixed day 23:00 07:00 '' '' daylight)" 'fixed mode is day between morning and evening boundaries'
assert_eq night "$(LED_NIGHTMODE_NOW=23:00 run_schedule resolve fixed day 23:00 07:00 '' '' daylight)" 'fixed mode switches to night at night_start'
assert_eq night "$(LED_NIGHTMODE_NOW=06:59 run_schedule resolve fixed day 23:00 07:00 '' '' daylight)" 'fixed mode remains night before day_start'
assert_eq day "$(LED_NIGHTMODE_NOW=07:00 run_schedule resolve fixed night 23:00 07:00 '' '' daylight)" 'fixed mode switches to day at day_start'
assert_eq night "$(LED_NIGHTMODE_NOW=02:00 run_schedule resolve fixed day 01:00 07:00 '' '' daylight)" 'fixed mode supports a same-day night interval'
assert_eq day "$(LED_NIGHTMODE_NOW=23:00 run_schedule resolve fixed night 01:00 07:00 '' '' daylight)" 'same-day interval is day outside its bounds'

assert_fails 'fixed mode rejects equal boundaries' run_schedule validate fixed day 07:00 07:00 '' '' daylight
assert_fails 'fixed mode rejects non-padded times' run_schedule validate fixed day 7:00 07:00 '' '' daylight
assert_fails 'solar mode requires coordinates' run_schedule validate sun day 23:00 07:00 '' '' daylight
assert_fails 'solar mode rejects latitude outside its range' run_schedule validate sun day 23:00 07:00 91 44 daylight
assert_fails 'solar mode rejects longitude outside its range' run_schedule validate sun day 23:00 07:00 41 181 daylight
assert_fails 'solar mode rejects an unknown twilight type' run_schedule validate sun day 23:00 07:00 41 44 blue

LED_TEST_SUNWAIT_STATUS=2
export LED_TEST_SUNWAIT_STATUS
assert_eq day "$(run_schedule resolve sun day 23:00 07:00 41.7151 44.8271 civil)" 'sunwait day status maps to day phase'
assert_eq 'poll civil 41.7151N 44.8271E' "$(cat "$SUNWAIT_ARGS")" 'solar mode passes positive coordinates with cardinal suffixes'

LED_TEST_SUNWAIT_STATUS=3
export LED_TEST_SUNWAIT_STATUS
assert_eq night "$(run_schedule resolve sun day 23:00 07:00 -33.8688 -151.2093 daylight)" 'sunwait night status maps to night phase'
assert_eq 'poll daylight 33.8688S 151.2093W' "$(cat "$SUNWAIT_ARGS")" 'solar mode converts negative coordinates to south and west'

LED_TEST_SUNWAIT_STATUS=1
export LED_TEST_SUNWAIT_STATUS
assert_fails 'solar mode propagates sunwait errors' run_schedule resolve sun day 23:00 07:00 41 44 daylight

mkdir -p "$RPC_ROOT/usr/share/libubox" "$RPC_BIN" "$RPC_PROVIDER_DIR"
printf '%s\n' 'json_init() { JSON_OUT=; }' > "$RPC_ROOT/usr/share/libubox/jshn.sh"
printf '%s\n' 'json_add_object() { JSON_OUT="$JSON_OUT object:$1"; }' >> "$RPC_ROOT/usr/share/libubox/jshn.sh"
printf '%s\n' 'json_close_object() { :; }' >> "$RPC_ROOT/usr/share/libubox/jshn.sh"
printf '%s\n' 'json_add_array() { JSON_OUT="$JSON_OUT array:$1"; }' >> "$RPC_ROOT/usr/share/libubox/jshn.sh"
printf '%s\n' 'json_close_array() { :; }' >> "$RPC_ROOT/usr/share/libubox/jshn.sh"
printf '%s\n' 'json_add_string() { JSON_OUT="$JSON_OUT $1=$2"; }' >> "$RPC_ROOT/usr/share/libubox/jshn.sh"
printf '%s\n' 'json_add_boolean() { JSON_OUT="$JSON_OUT $1=$2"; }' >> "$RPC_ROOT/usr/share/libubox/jshn.sh"
printf '%s\n' 'json_dump() { printf "%s\n" "$JSON_OUT"; }' >> "$RPC_ROOT/usr/share/libubox/jshn.sh"
printf '%s\n' 'json_cleanup() { :; }' >> "$RPC_ROOT/usr/share/libubox/jshn.sh"
printf '%s\n' 'json_load() { JSON_INPUT=$1; }' >> "$RPC_ROOT/usr/share/libubox/jshn.sh"
printf '%s\n' 'json_get_var() { JSON_NAME=$1; JSON_KEY=$2; JSON_VALUE=$(printf "%s\n" "$JSON_INPUT" | sed -n "s/.*\\\"$JSON_KEY\\\"[ ]*:[ ]*\\\"\\([^\\\"]*\\)\\\".*/\\1/p"); eval "$JSON_NAME=\\$JSON_VALUE"; }' >> "$RPC_ROOT/usr/share/libubox/jshn.sh"

printf '%s\n' '#!/bin/sh' > "$RPC_BIN/uci"
printf '%s\n' 'if [ "$1" = -q ] && [ "$2" = get ]; then' >> "$RPC_BIN/uci"
printf '%s\n' 'case $3 in' >> "$RPC_BIN/uci"
printf '%s\n' 'led-nightmode.main.enabled) printf "%s\n" 1 ;;' >> "$RPC_BIN/uci"
printf '%s\n' 'led-nightmode.main.phase) printf "%s\n" day ;;' >> "$RPC_BIN/uci"
printf '%s\n' 'led-nightmode.schedule.mode) printf "%s\n" fixed ;;' >> "$RPC_BIN/uci"
printf '%s\n' 'led-nightmode.schedule.night_start) printf "%s\n" 23:00 ;;' >> "$RPC_BIN/uci"
printf '%s\n' 'led-nightmode.schedule.day_start) printf "%s\n" 07:00 ;;' >> "$RPC_BIN/uci"
printf '%s\n' 'led-nightmode.schedule.twilight) printf "%s\n" daylight ;;' >> "$RPC_BIN/uci"
printf '%s\n' '*) exit 1 ;;' >> "$RPC_BIN/uci"
printf '%s\n' 'esac' >> "$RPC_BIN/uci"
printf '%s\n' 'elif [ "$1" = -q ] && [ "$2" = batch ]; then' >> "$RPC_BIN/uci"
printf '%s\n' 'cat > "$LED_TEST_UCI_LOG"' >> "$RPC_BIN/uci"
printf '%s\n' 'else exit 1; fi' >> "$RPC_BIN/uci"
chmod +x "$RPC_BIN/uci"

printf '%s\n' '#!/bin/sh' > "$RPC_BIN/init"
printf '%s\n' 'case $1 in' >> "$RPC_BIN/init"
printf '%s\n' 'running) exit 0 ;;' >> "$RPC_BIN/init"
printf '%s\n' 'reload) printf "%s\n" reload >> "$LED_TEST_INIT_LOG" ;;' >> "$RPC_BIN/init"
printf '%s\n' '*) exit 1 ;;' >> "$RPC_BIN/init"
printf '%s\n' 'esac' >> "$RPC_BIN/init"
chmod +x "$RPC_BIN/init"

printf '%s\n' '#!/bin/sh' > "$RPC_PROVIDER_DIR/test-driver"
printf '%s\n' '[ "$1" = probe ] || exit 1' >> "$RPC_PROVIDER_DIR/test-driver"
printf '%s\n' 'printf "test-driver\\tsupported\\t%s\\n" "$LED_PROVIDER_DEVICE"' >> "$RPC_PROVIDER_DIR/test-driver"
chmod +x "$RPC_PROVIDER_DIR/test-driver"
printf '%s\n' night > "$RPC_PHASE_FILE"

rpc_list_output=$(run_rpc list)
assert_contains "$rpc_list_output" 'object:status' 'rpcd lists the status method'
assert_contains "$rpc_list_output" 'object:resolve' 'rpcd lists the resolve method'
assert_contains "$rpc_list_output" 'object:drivers' 'rpcd lists the installed-driver method'
assert_contains "$rpc_list_output" 'object:probe' 'rpcd lists the provider probe method'
assert_contains "$rpc_list_output" 'object:set_manual' 'rpcd lists the manual phase method'
assert_contains "$rpc_list_output" 'object:reload' 'rpcd lists the reload method'

rpc_status_output=$(run_rpc call status)
assert_contains "$rpc_status_output" 'enabled=1' 'rpcd status reports enabled configuration'
assert_contains "$rpc_status_output" 'running=1' 'rpcd status reports a running service'
assert_contains "$rpc_status_output" 'mode=fixed' 'rpcd status reports the configured mode'
assert_contains "$rpc_status_output" 'effective_phase=night' 'rpcd status reports the applied runtime phase'
assert_contains "$rpc_status_output" 'desired_phase=day' 'rpcd status resolves the desired phase independently'

rpc_resolve_output=$(run_rpc call resolve)
assert_contains "$rpc_resolve_output" 'success=1' 'rpcd resolve succeeds for valid configuration'
assert_contains "$rpc_resolve_output" 'phase=day' 'rpcd resolve returns the calculated phase'

rpc_drivers_output=$(run_rpc call drivers)
assert_contains "$rpc_drivers_output" 'test-driver' 'rpcd lists installed provider drivers'

rpc_manual_output=$(printf '%s\n' '{"phase":"night"}' | run_rpc call set_manual)
assert_contains "$rpc_manual_output" 'success=1' 'rpcd accepts a valid manual phase'
assert_contains "$(cat "$RPC_UCI_LOG")" "set led-nightmode.schedule.mode='manual'" 'manual RPC switches the schedule to manual mode'
assert_contains "$(cat "$RPC_UCI_LOG")" "set led-nightmode.main.phase='night'" 'manual RPC saves the selected phase'
assert_contains "$(cat "$RPC_INIT_LOG")" reload 'manual RPC reloads the service after saving'

if printf '%s\n' '{"phase":"invalid"}' | run_rpc call set_manual >/dev/null 2>&1; then
	fail 'rpcd rejects an invalid manual phase'
fi

rpc_probe_output=$(printf '%s\n' '{"driver":"test-driver","device":"/dev/test","instance":"test"}' | run_rpc call probe)
assert_contains "$rpc_probe_output" 'success=1' 'rpcd accepts a safe explicit provider probe'
assert_contains "$rpc_probe_output" 'test-driver' 'rpcd returns provider probe output'
if printf '%s\n' '{"driver":"../bad","device":"/dev/test"}' | run_rpc call probe >/dev/null 2>&1; then
	fail 'rpcd rejects provider path traversal'
fi

mkdir -p "$SYSFS_ROOT/green:status" "$SYSFS_ROOT/mt76-phy0"
printf '%s\n' 1 > "$SYSFS_ROOT/green:status/max_brightness"
printf '%s\n' 1 > "$SYSFS_ROOT/green:status/brightness"
printf '%s\n' '[none] timer' > "$SYSFS_ROOT/green:status/trigger"
printf '%s\n' 255 > "$SYSFS_ROOT/mt76-phy0/max_brightness"
printf '%s\n' 0 > "$SYSFS_ROOT/mt76-phy0/brightness"
printf '%s\n' 'none [phy0tpt]' > "$SYSFS_ROOT/mt76-phy0/trigger"

LED_NIGHTMODE_BIN=$CLI \
LED_NIGHTMODE_SCHEDULE_BIN=$SCHEDULE \
LED_SYSFS_ROOT=$SYSFS_ROOT \
LED_STATE_DIR=$STATE_DIR \
LED_NIGHTMODE_RUNTIME_DIR=$RUNTIME_DIR \
LED_SYSFS_EMULATE=1 \
"$SERVICE" night 7 >/dev/null &
SERVICE_PID=$!

wait_for_path "$STATE_DIR/green:status" || fail 'service did not apply the night profile'
assert_eq 0 "$(cat "$SYSFS_ROOT/green:status/brightness")" 'service switches off a binary LED'
assert_eq 7 "$(cat "$SYSFS_ROOT/mt76-phy0/brightness")" 'service applies an explicitly configured multi-level target'
assert_eq night "$(cat "$RUNTIME_DIR/phase")" 'service publishes its current phase'

kill -TERM "$SERVICE_PID"
wait "$SERVICE_PID"
SERVICE_PID=

assert_eq 1 "$(cat "$SYSFS_ROOT/green:status/brightness")" 'service stop restores binary brightness'
assert_eq 0 "$(cat "$SYSFS_ROOT/mt76-phy0/brightness")" 'service stop restores multi-level brightness'
[ ! -d "$STATE_DIR" ] || fail 'service stop removes restored state'
[ ! -e "$RUNTIME_DIR/phase" ] || fail 'service stop removes stale runtime phase'

mkdir -p "$FAKE_BIN"
printf '%s\n' '#!/bin/sh' > "$FAKE_BIN/date"
printf '%s\n' 'cat "$LED_TEST_TIME_FILE"' >> "$FAKE_BIN/date"
chmod +x "$FAKE_BIN/date"
printf '%s\n' '12:00' > "$FAKE_TIME"

PATH=$FAKE_BIN:$PATH \
LED_TEST_TIME_FILE=$FAKE_TIME \
LED_NIGHTMODE_BIN=$CLI \
LED_NIGHTMODE_SCHEDULE_BIN=$SCHEDULE \
LED_SCHEDULE_INTERVAL=0.05 \
LED_SYSFS_ROOT=$SYSFS_ROOT \
LED_STATE_DIR=$STATE_DIR \
LED_NIGHTMODE_RUNTIME_DIR=$RUNTIME_DIR \
LED_SYSFS_EMULATE=1 \
"$SERVICE" day 7 fixed 23:00 07:00 '' '' daylight >/dev/null &
SERVICE_PID=$!

wait_for_value "$RUNTIME_DIR/phase" day || fail 'fixed schedule did not start in the calculated day phase'
printf '%s\n' '23:00' > "$FAKE_TIME"
wait_for_value "$RUNTIME_DIR/phase" night || fail 'fixed schedule did not switch to night at night_start'
assert_eq 0 "$(cat "$SYSFS_ROOT/green:status/brightness")" 'scheduled night switches off a binary LED'
assert_eq 7 "$(cat "$SYSFS_ROOT/mt76-phy0/brightness")" 'scheduled night applies the configured multi-level target'

printf '%s\n' '07:00' > "$FAKE_TIME"
wait_for_value "$RUNTIME_DIR/phase" day || fail 'fixed schedule did not switch back to day at day_start'
assert_eq 1 "$(cat "$SYSFS_ROOT/green:status/brightness")" 'scheduled day restores binary brightness'
assert_eq 0 "$(cat "$SYSFS_ROOT/mt76-phy0/brightness")" 'scheduled day restores multi-level brightness'

kill -TERM "$SERVICE_PID"
wait "$SERVICE_PID"
SERVICE_PID=

if LED_NIGHTMODE_BIN=$CLI LED_NIGHTMODE_SCHEDULE_BIN=$SCHEDULE "$SERVICE" invalid 1 >/dev/null 2>&1; then
	fail 'service must reject an invalid phase'
fi
if LED_NIGHTMODE_BIN=$CLI LED_NIGHTMODE_SCHEDULE_BIN=$SCHEDULE "$SERVICE" night invalid >/dev/null 2>&1; then
	fail 'service must reject invalid brightness'
fi

printf '%s\n' 'All service tests passed.'
