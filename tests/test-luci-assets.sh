#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
VIEW=$PROJECT_ROOT/htdocs/luci-static/resources/view/led-nightmode.js
ZONE_MAP=$PROJECT_ROOT/htdocs/luci-static/resources/led-nightmode/zone-coordinates.js
ACL=$PROJECT_ROOT/root/usr/share/rpcd/acl.d/luci-app-led-nightmode.json
POT=$PROJECT_ROOT/po/templates/led-nightmode.pot

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
assert_contains "$(cat "$ZONE_MAP")" 'Object.prototype.hasOwnProperty.call(coordinates, zoneName)' 'timezone lookup rejects inherited object properties'
assert_contains "$(cat "$VIEW")" "'data-tab-title': _('Settings')" 'LuCI exposes the simple default settings layer'
assert_contains "$(cat "$VIEW")" "'data-tab-title': _('Advanced')" 'LuCI hides technical controls under Advanced'
assert_contains "$(cat "$VIEW")" 'extractAdvancedOptions(mapNode' 'LuCI rearranges native option widgets without creating synthetic UCI sections'
assert_contains "$(cat "$VIEW")" "[ '_brightness_mode', 'night_brightness' ]" 'LuCI moves calibrated brightness controls under Advanced'
assert_contains "$(cat "$VIEW")" 'When should indicators turn off?' 'LuCI frames scheduling as a user task'
assert_contains "$(cat "$VIEW")" 'Manual override' 'LuCI keeps immediate manual control behind an explicit disclosure'
assert_contains "$(cat "$VIEW")" 'Use this device location' 'LuCI offers browser geolocation'
assert_contains "$(cat "$VIEW")" 'Exact latitude' 'LuCI keeps exact solar coordinates available under Advanced'
assert_contains "$(cat "$VIEW")" "latitudeOption.depends('mode', 'sun')" 'LuCI hides latitude outside the solar schedule'
assert_contains "$(cat "$VIEW")" 'latitudeOption.retain = true' 'LuCI retains a saved latitude when the solar schedule is inactive'
assert_contains "$(cat "$VIEW")" 'latitudeOption.forcewrite = true' 'LuCI persists a displayed timezone-derived latitude'
assert_contains "$(cat "$VIEW")" "longitudeOption.depends('mode', 'sun')" 'LuCI hides longitude outside the solar schedule'
assert_contains "$(cat "$VIEW")" 'longitudeOption.retain = true' 'LuCI retains a saved longitude when the solar schedule is inactive'
assert_contains "$(cat "$VIEW")" 'longitudeOption.forcewrite = true' 'LuCI persists a displayed timezone-derived longitude'
assert_contains "$(cat "$VIEW")" 'brightnessModeOption.write = function() {}' 'LuCI keeps the derived brightness mode out of UCI'
assert_contains "$(cat "$VIEW")" 'Detected LED brightness capabilities' 'LuCI renders device-reported brightness ranges'
assert_contains "$(cat "$VIEW")" 'Test indicator' 'LuCI exposes the provider visual test'
[ "$(grep -F '/dev/ttyUSB3' "$VIEW" || true)" = '' ] || fail 'LuCI must not suggest a device-specific provider endpoint'
assert_contains "$(cat "$ACL")" '"leds"' 'read ACL grants LED inventory access'
assert_contains "$(cat "$ACL")" '"test"' 'write ACL grants provider visual-test access'
[ "$(grep -F '"resolve"' "$ACL" || true)" = '' ] || fail 'read ACL must not grant unused schedule resolution access'
[ "$(grep -F '"reload"' "$ACL" || true)" = '' ] || fail 'write ACL must not grant unused service reload access'
if grep -Eq '^#: (htdocs|root)/' "$POT"; then
	fail 'translation references must be relative to the LuCI repository root'
fi

printf '%s\n' 'All LuCI asset tests passed.'
