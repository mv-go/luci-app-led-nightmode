#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
INIT=$PROJECT_ROOT/root/etc/init.d/led-nightmode
LED_NIGHTMODE_SCHEDULE_BIN=$PROJECT_ROOT/root/usr/libexec/led-nightmode-service
export LED_NIGHTMODE_SCHEDULE_BIN
CALLS=
MOCK_ENABLED=0
MOCK_PHASE=day
MOCK_BRIGHTNESS=0
MOCK_SCHEDULE_MODE=manual
MOCK_NIGHT_START=23:00
MOCK_DAY_START=07:00
MOCK_LATITUDE=
MOCK_LONGITUDE=
MOCK_TWILIGHT=daylight
MOCK_VALID=1
MOCK_PROVIDER_PRESENT=0
MOCK_PROVIDER_ENABLED=0
MOCK_PROVIDER_DRIVER=quectel-qnwcfg-ledmode
MOCK_PROVIDER_DEVICE=/dev/ttyUSB3

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
	section_type=$2
	section=$3
	shift 3
	case $section_type in
		core)
			[ "$section" = main ] || [ -z "$section" ] || fail 'init validates only the main section'
			assert_contains "$*" 'enabled:bool:0' 'init validates enabled as boolean'
			assert_contains "$*" 'phase:or("day", "night"):day' 'init restricts the phase'
			assert_contains "$*" 'night_brightness:uinteger:0' 'init validates night brightness'
			enabled=$MOCK_ENABLED
			phase=$MOCK_PHASE
			night_brightness=$MOCK_BRIGHTNESS
			;;
		schedule)
			[ "$section" = main ] || fail 'init validates only the main schedule section'
			assert_contains "$*" 'mode:or("manual", "fixed", "sun"):manual' 'init restricts the schedule mode'
			assert_contains "$*" 'night_start:string:23:00' 'init validates the night boundary'
			assert_contains "$*" 'day_start:string:07:00' 'init validates the day boundary'
			assert_contains "$*" 'twilight:or("daylight", "civil", "nautical", "astronomical"):daylight' 'init restricts twilight type'
			mode=$MOCK_SCHEDULE_MODE
			night_start=$MOCK_NIGHT_START
			day_start=$MOCK_DAY_START
			latitude=$MOCK_LATITUDE
			longitude=$MOCK_LONGITUDE
			twilight=$MOCK_TWILIGHT
			;;
		provider)
			assert_contains "$*" 'enabled:bool:0' 'init validates provider enabled as boolean'
			assert_contains "$*" 'driver:string' 'init validates provider driver as string'
			assert_contains "$*" 'device:string' 'init validates provider device as string'
			enabled=$MOCK_PROVIDER_ENABLED
			driver=$MOCK_PROVIDER_DRIVER
			device=$MOCK_PROVIDER_DEVICE
			;;
		*) fail 'init validates only known section types' ;;
	esac
	[ "$MOCK_VALID" -eq 1 ]
}

config_load() {
	[ "$1" = led-nightmode ] || fail 'init loads the correct UCI package'
}

config_foreach() {
	callback=$1
	section_type=$2
	shift 2
	[ "$section_type" = provider ] || fail 'init iterates provider sections only'
	[ "$MOCK_PROVIDER_PRESENT" -eq 1 ] || return 0
	"$callback" lte "$@"
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
assert_contains "$CALLS" 'param command /usr/libexec/led-nightmode-service night 7 manual 23:00 07:00   daylight' 'init passes validated core and schedule config to the runner'
assert_contains "$CALLS" 'param file /etc/config/led-nightmode' 'init watches its UCI file'
assert_contains "$CALLS" 'param stdout 1' 'init forwards stdout'
assert_contains "$CALLS" 'param stderr 1' 'init forwards stderr'
assert_contains "$CALLS" 'param respawn 3600 30 0' 'init retries transient startup failures without a tight loop'
assert_contains "$CALLS" 'close' 'init closes the procd instance'

CALLS=
MOCK_PROVIDER_PRESENT=1
MOCK_PROVIDER_ENABLED=1
start_service
assert_contains "$CALLS" 'open main' 'provider config keeps the core instance'
assert_contains "$CALLS" 'open provider-lte' 'enabled provider gets its own procd instance'
assert_contains "$CALLS" 'param command /usr/libexec/led-nightmode-provider-service quectel-qnwcfg-ledmode /dev/ttyUSB3 lte night manual 23:00 07:00   daylight' 'init passes generic provider and schedule configuration to the provider runner'

CALLS=
service_triggers
assert_contains "$CALLS" 'reload led-nightmode' 'UCI changes trigger reload'
assert_contains "$CALLS" 'validation validate_core_section validate_schedule_section validate_provider_section' 'init publishes core, schedule, and provider validation schemas'

printf '%s\n' 'All init tests passed.'
