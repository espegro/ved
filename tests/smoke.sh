#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

make

output=$(mktemp)
trap 'rm -f "$output"' EXIT

if ./ved </dev/null >"$output" 2>&1; then
    echo "ved unexpectedly accepted non-terminal stdin" >&2
    exit 1
fi

grep -q "not a usable terminal" "$output"
echo "smoke tests passed"
