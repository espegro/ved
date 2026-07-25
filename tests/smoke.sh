#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

make

output=$(mktemp)
target=$(mktemp)
rm -f "$target"
trap 'rm -f "$output" "$target" "$target".ved.tmp.*' EXIT

if ./ved </dev/null >"$output" 2>&1; then
    echo "ved unexpectedly accepted non-terminal stdin" >&2
    exit 1
fi

grep -q "not a usable terminal" "$output"

if command -v script >/dev/null 2>&1; then
    printf 'iabc\033:wq\n' |
        script -qefc "./ved $target" /dev/null >/dev/null 2>&1
    test "$(cat "$target")" = "abc"

    chmod 0600 "$target"
    printf 'i!\033:wq\n' |
        script -qefc "./ved $target" /dev/null >/dev/null 2>&1
    test "$(stat -c '%a' "$target")" = "600"
    test "$(cat "$target")" = "!abc"
fi

echo "smoke tests passed"
