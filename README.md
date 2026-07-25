# ved

`ved` means Visual EDitor. It is a tiny vi-like editor written in x86-64 Linux
assembly. It uses raw Linux syscalls only: no libc, no curses, no terminal
library.

## Build

```sh
make
```

Run the smoke tests with:

```sh
make check
```

## Run

```sh
./ved file.txt
```

You can also start with an unnamed empty buffer:

```sh
./ved
```

## Keys

- `i` enters insert mode before the cursor.
- `a` enters insert mode after the cursor.
- `I` enters insert mode at the start of the current line.
- `A` enters insert mode at the end of the current line.
- `o` opens a new line below the current line and enters insert mode.
- `O` opens a new line above the current line and enters insert mode.
- `Esc` returns to normal mode.
- `h`, `j`, `k`, `l` move in normal mode.
- `w` moves to the start of the next word.
- `b` moves to the start of the previous word.
- `e` moves to the end of the current/next word.
- Arrow keys move in normal mode and insert mode.
- Counts work with movement and editing commands, for example `5j`, `3x`,
  `3w`, `2dd`, and `5G`.
- `0` moves to the start of the current line.
- `^` moves to the first non-blank character of the current line.
- `$` moves to the end of the current line.
- `G` moves to the last line.
- `nG` moves to line `n`, for example `5G`.
- `gg` moves to the first line.
- `ngg` moves to line `n`, for example `5gg`.
- `x` deletes the byte under the cursor.
- `dd` deletes the current line.
- `dw`, `d$`, and `dG` delete by motion.
- `D` deletes to the end of the current line.
- `cw`, `c$`, and `cc` change by motion or line.
- `C` changes to the end of the current line.
- `s` substitutes characters and enters insert mode.
- `S` changes the current line.
- `r` replaces the byte under the cursor.
- `yy` yanks the current line.
- `yw`, `y$`, and `yG` yank by motion.
- `p` pastes yanked lines after the current line.
- `P` pastes yanked lines before the current line.
- `u` undoes the last edit operation.
- `/pattern` searches forward.
- `n` repeats the last search forward.
- `N` repeats the last search backward.
- `:w` writes the file.
- `:w file.txt` writes to a filename and makes it the current file.
- `:q` quits if there are no unsaved changes.
- `:q!` quits without saving.
- `:wq` writes and quits.
- `Ctrl-C` or `Ctrl-Q` quits immediately without saving.

This is intentionally small: it keeps the file in a dynamic flat byte buffer
backed by `mmap`/`mremap`, and editing is still byte-oriented. The display uses
the terminal height, shows `~` markers after the end of the file, keeps a
single-line status bar at the bottom with line/column position, and scrolls
vertically to keep the cursor visible.
