#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
MIGRATION=$PROJECT_ROOT/core/root/etc/uci-defaults/99-led-nightmode
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/led-nightmode-uci-defaults-test.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

mkdir -p "$TEST_ROOT/bin"
cat > "$TEST_ROOT/bin/uci" <<'EOF'
#!/bin/sh
if [ "$1" = -q ] && [ "$2" = get ]; then
	[ "${SCHEDULE_PRESENT:-0}" -eq 1 ]
	exit
fi
if [ "$1" = -q ] && [ "$2" = batch ]; then
	cat > "$UCI_LOG"
	exit
fi
exit 1
EOF
chmod +x "$TEST_ROOT/bin/uci"

UCI_LOG=$TEST_ROOT/uci.log
INIT_LOG=$TEST_ROOT/init.log
export UCI_LOG
export INIT_LOG
PATH=$TEST_ROOT/bin:$PATH
export PATH

mkdir -p "$TEST_ROOT/rc.d"
ln -s ../init.d/led-nightmode "$TEST_ROOT/rc.d/S95led-nightmode"
cat > "$TEST_ROOT/bin/led-nightmode-init" <<'EOF'
#!/bin/sh
printf '%s\n' "$1" >> "$INIT_LOG"
EOF
chmod +x "$TEST_ROOT/bin/led-nightmode-init"
LED_NIGHTMODE_RC_D=$TEST_ROOT/rc.d
LED_NIGHTMODE_INIT=$TEST_ROOT/bin/led-nightmode-init
export LED_NIGHTMODE_RC_D LED_NIGHTMODE_INIT

SCHEDULE_PRESENT=1
export SCHEDULE_PRESENT
"$MIGRATION"
[ ! -e "$UCI_LOG" ] || fail 'existing schedule must remain untouched'
grep -Fqx disable "$INIT_LOG" || fail 'legacy priority migration must disable the old rc.d link'
grep -Fqx enable "$INIT_LOG" || fail 'legacy priority migration must enable the new rc.d link'

rm -f "$TEST_ROOT/rc.d/S95led-nightmode" "$INIT_LOG"

SCHEDULE_PRESENT=0
export SCHEDULE_PRESENT
"$MIGRATION"
[ -s "$UCI_LOG" ] || fail 'missing schedule was not created'
[ ! -e "$INIT_LOG" ] || fail 'current rc.d priority must not be rewritten'

for expected in \
	"set led-nightmode.schedule='schedule'" \
	"set led-nightmode.schedule.mode='manual'" \
	"set led-nightmode.schedule.night_start='23:00'" \
	"set led-nightmode.schedule.day_start='07:00'" \
	"set led-nightmode.schedule.twilight='daylight'" \
	"commit led-nightmode"
do
	grep -Fqx "$expected" "$UCI_LOG" || fail "migration is missing: $expected"
done

printf '%s\n' 'All UCI migration tests passed.'
