#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
INIT=$PROJECT_ROOT/root/etc/init.d/led-nightmode
CALLS=
MOCK_ENABLED=0
MOCK_PHASE=day
MOCK_BRIGHTNESS=1
MOCK_VALID=1

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
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

record_call() {
	CALLS="${CALLS}${CALLS:+
}$*"
}

uci_validate_section() {
	[ "$1" = led-nightmode ] || fail 'init validates the correct UCI package'
	[ "$2" = core ] || fail 'init validates the core section type'
	section=$3
	shift 3
	[ "$section" = main ] || [ -z "$section" ] || fail 'init validates only the main section'
	assert_contains "$*" 'enabled:bool:0' 'init validates enabled as boolean'
	assert_contains "$*" 'phase:or("day", "night"):day' 'init restricts the phase'
	assert_contains "$*" 'night_brightness:uinteger:1' 'init validates night brightness'
	enabled=$MOCK_ENABLED
	phase=$MOCK_PHASE
	night_brightness=$MOCK_BRIGHTNESS
	[ "$MOCK_VALID" -eq 1 ]
}

procd_open_instance() { record_call "open $*"; }
procd_set_param() { record_call "param $*"; }
procd_close_instance() { record_call 'close'; }
procd_add_reload_trigger() { record_call "reload $*"; }
procd_add_validation() { record_call "validation $*"; }

. "$INIT"

start_service
[ -z "$CALLS" ] || fail 'disabled default must not register a procd instance'

MOCK_ENABLED=1
MOCK_PHASE=night
MOCK_BRIGHTNESS=7
start_service
assert_contains "$CALLS" 'open main' 'enabled config opens the main instance'
assert_contains "$CALLS" 'param command /usr/libexec/led-nightmode-service night 7' 'init passes validated config to the runner'
assert_contains "$CALLS" 'param file /etc/config/led-nightmode' 'init watches its UCI file'
assert_contains "$CALLS" 'param stdout 1' 'init forwards stdout'
assert_contains "$CALLS" 'param stderr 1' 'init forwards stderr'
assert_contains "$CALLS" 'close' 'init closes the procd instance'

CALLS=
service_triggers
assert_contains "$CALLS" 'reload led-nightmode' 'UCI changes trigger reload'
assert_contains "$CALLS" 'validation validate_core_section' 'init publishes its validation schema'

printf '%s\n' 'All init tests passed.'
