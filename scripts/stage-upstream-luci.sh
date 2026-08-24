#!/bin/sh

set -eu

usage() {
	printf 'Usage: %s <new application directory>\n' "$0" >&2
	exit 2
}

[ "$#" -eq 1 ] || usage

destination=$1
case "$destination" in
	'' | / | . | ..)
		printf 'Refusing unsafe destination: %s\n' "$destination" >&2
		exit 2
		;;
esac

[ ! -e "$destination" ] || {
	printf 'Destination already exists: %s\n' "$destination" >&2
	exit 1
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_root=$(CDPATH= cd -- "$script_dir/.." && pwd)

mkdir -p "$destination"
cp "$project_root/upstream/Makefile" "$destination/Makefile"
cp -R "$project_root/htdocs" "$destination/htdocs"
cp -R "$project_root/po" "$destination/po"
cp -R "$project_root/root" "$destination/root"

printf 'Staged universal LuCI application at %s\n' "$destination"
