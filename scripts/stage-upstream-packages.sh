#!/bin/sh

set -eu

usage() {
	printf 'Usage: %s <new package directory> <source archive SHA-256>\n' "$0" >&2
	exit 2
}

[ "$#" -eq 2 ] || usage

destination=$1
source_hash=$2

case "$destination" in
	'' | / | . | ..)
		printf 'Refusing unsafe destination: %s\n' "$destination" >&2
		exit 2
		;;
esac

[ "${#source_hash}" -eq 64 ] || {
	printf 'Source hash must be exactly 64 lowercase hexadecimal characters.\n' >&2
	exit 2
}
case "$source_hash" in
	*[!0-9a-f]*)
		printf 'Source hash must be exactly 64 lowercase hexadecimal characters.\n' >&2
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
sed "s/@PKG_HASH@/$source_hash/" \
	"$project_root/upstream/packages/Makefile.in" \
	> "$destination/Makefile"

printf 'Staged immutable-source core package at %s\n' "$destination"
