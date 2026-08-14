#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

make

output=$(mktemp)
target=$(mktemp)
expected=$(mktemp)
link_target=$(mktemp)
link_path=$(mktemp)
hardlink_path=$(mktemp)
rm -f "$target"
rm -f "$link_path" "$hardlink_path"
trap 'rm -f "$output" "$target" "$expected" "$link_target" "$link_path" "$hardlink_path" "$target".ved.tmp.* "$link_path".ved.tmp.* "$hardlink_path".ved.tmp.*' EXIT

if ./ved </dev/null >"$output" 2>&1; then
    echo "ved unexpectedly accepted non-terminal stdin" >&2
    exit 1
fi

grep -q "not a usable terminal" "$output"

if command -v script >/dev/null 2>&1; then
    printf 'iabc\033:wq\n' |
        timeout 10 script -qefc "./ved $target" /dev/null >/dev/null 2>&1
    test "$(cat "$target")" = "abc"

    chmod 0600 "$target"
    printf 'i!\033:wq\n' |
        timeout 10 script -qefc "./ved $target" /dev/null >/dev/null 2>&1
    test "$(stat -c '%a' "$target")" = "600"
    test "$(cat "$target")" = "!abc"

    printf 'foo foo\nfoo\n' > "$target"
    printf ':%%s/foo/bar/g\n:wq\n' |
        timeout 10 script -qefc "./ved $target" /dev/null >/dev/null 2>&1
    test "$(sed -n '1p' "$target")" = "bar bar"
    test "$(sed -n '2p' "$target")" = "bar"

    : > "$target"
    printf 'qaiX\033q@a:wq\n' |
        timeout 10 script -qefc "./ved $target" /dev/null >/dev/null 2>&1
    test "$(cat "$target")" = "XX"

    # Leaving insert mode puts the normal-mode cursor on the inserted byte.
    : > "$target"
    printf 'iabc\033x:wq\n' |
        timeout 10 script -qefc "./ved $target" /dev/null >/dev/null 2>&1
    test "$(cat "$target")" = "ab"

    # Horizontal normal-mode movement must not cross a line boundary.
    printf 'a\nb\n' > "$target"
    printf '\nb\n' > "$expected"
    printf '2lx:wq\n' |
        timeout 10 script -qefc "./ved $target" /dev/null >/dev/null 2>&1
    cmp -s "$target" "$expected"

    # A final LF exposes an empty logical segment, but dd there must not delete
    # the preceding real line.
    printf 'a\nb\n' > "$target"
    cp "$target" "$expected"
    printf 'Gdd:wq\n' |
        timeout 10 script -qefc "./ved $target" /dev/null >/dev/null 2>&1
    cmp -s "$target" "$expected"

    # A counted line delete clamps at EOF instead of walking backwards.
    printf 'a\nb\nc' > "$target"
    printf 'a\nb\n' > "$expected"
    printf 'G2dd:wq\n' |
        timeout 10 script -qefc "./ved $target" /dev/null >/dev/null 2>&1
    cmp -s "$target" "$expected"

    # Counts are bounded by useful buffer work, so hostile counts stay quick.
    printf 'a' > "$target"
    printf '999999999lx:wq\n' |
        timeout 10 script -qefc "./ved $target" /dev/null >/dev/null 2>&1
    test ! -s "$target"

    # Arrow bytes may arrive separately, as they often do over SSH.
    printf 'ab' > "$target"
    { printf '\033'; sleep 0.01; printf '[Cx:wq\n'; } |
        timeout 10 script -qefc "./ved $target" /dev/null >/dev/null 2>&1
    test "$(cat "$target")" = "a"

    # Arrow sequences consumed by the parser are retained in macros.
    printf 'abc' > "$target"
    printf 'qa\033[Cxq0@a:wq\n' |
        timeout 10 script -qefc "./ved $target" /dev/null >/dev/null 2>&1
    test "$(cat "$target")" = "a"

    # Rendering never emits control bytes from the edited file verbatim.
    printf '\033]52;c;payload\007\n' > "$target"
    printf ':q!\n' |
        timeout 10 script -qefc "./ved $target" /dev/null >"$output" 2>&1
    grep -Fq '\x1b]52;c;payload\x07' "$output"

    # Saving through symbolic and hard links preserves their inode semantics.
    printf 'abc' > "$link_target"
    ln -s "$link_target" "$link_path"
    printf 'i!\033:wq\n' |
        timeout 10 script -qefc "./ved $link_path" /dev/null >/dev/null 2>&1
    test -L "$link_path"
    test "$(cat "$link_target")" = "!abc"

    ln "$link_target" "$hardlink_path"
    inode_before=$(stat -c '%i' "$hardlink_path")
    printf 'i?\033:wq\n' |
        timeout 10 script -qefc "./ved $hardlink_path" /dev/null >/dev/null 2>&1
    test "$(stat -c '%i' "$link_target")" = "$inode_before"
    test "$(cat "$link_target")" = "?!abc"
fi

echo "smoke tests passed"
