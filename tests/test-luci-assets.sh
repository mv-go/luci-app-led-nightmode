#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
VIEW=$PROJECT_ROOT/htdocs/luci-static/resources/view/led-nightmode.js
ZONE_MAP=$PROJECT_ROOT/htdocs/luci-static/resources/led-nightmode/zone-coordinates.js
ACL=$PROJECT_ROOT/root/usr/share/rpcd/acl.d/luci-app-led-nightmode.json

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

zone_count=$(sed -n "s/^[[:space:]]*'\([^']*\)'.*/\1/p" "$ZONE_MAP" | wc -l | tr -d ' ')
[ "$zone_count" -ge 300 ] || fail 'timezone coordinate map is unexpectedly incomplete'
duplicate_zone=$(sed -n "s/^[[:space:]]*'\([^']*\)'.*/\1/p" "$ZONE_MAP" | sort | uniq -d | head -n 1)
[ -z "$duplicate_zone" ] || fail "timezone coordinate map contains duplicate '$duplicate_zone'"

assert_contains "$(cat "$ZONE_MAP")" "'Asia/Tbilisi': [41.7167, 44.8167]" 'timezone map contains the first live-validation location'
assert_contains "$(cat "$ZONE_MAP")" "'require baseclass'" 'timezone map declares the LuCI base-class dependency'
assert_contains "$(cat "$ZONE_MAP")" 'return baseclass.extend({' 'timezone map exports a LuCI class constructor'
assert_contains "$(cat "$VIEW")" 'Quick actions are saved and applied immediately' 'LuCI explains immediate manual persistence'
assert_contains "$(cat "$VIEW")" 'Use current location' 'LuCI offers browser geolocation'
assert_contains "$(cat "$VIEW")" 'Detected LED brightness capabilities' 'LuCI renders device-reported brightness ranges'
assert_contains "$(cat "$VIEW")" 'Test indicator' 'LuCI exposes the provider visual test'
assert_contains "$(cat "$ACL")" '"leds"' 'read ACL grants LED inventory access'
assert_contains "$(cat "$ACL")" '"test"' 'write ACL grants provider visual-test access'

printf '%s\n' 'All LuCI asset tests passed.'
