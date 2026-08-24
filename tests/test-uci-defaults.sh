#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
MIGRATION=$PROJECT_ROOT/root/etc/uci-defaults/99-led-nightmode
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
export UCI_LOG
PATH=$TEST_ROOT/bin:$PATH
export PATH

SCHEDULE_PRESENT=1
export SCHEDULE_PRESENT
"$MIGRATION"
[ ! -e "$UCI_LOG" ] || fail 'existing schedule must remain untouched'

SCHEDULE_PRESENT=0
export SCHEDULE_PRESENT
"$MIGRATION"
[ -s "$UCI_LOG" ] || fail 'missing schedule was not created'

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
