# ved Status

`ved` means Visual EDitor. It is currently a small vi-like editor written in
x86-64 Linux assembly for 64-bit Linux. It uses direct Linux syscalls only, with
no libc and no curses.

## Build and Run

```sh
make
./ved file.txt
```

It can also start with an unnamed empty buffer:

```sh
./ved
```

Use `:w file.txt` to name and save an unnamed buffer.

## Implemented

- Raw terminal mode with terminal restore on normal exit.
- Whole-file editing in a dynamic flat byte buffer backed by `mmap`/`mremap`.
- Dynamic one-level undo and yank buffers.
- Loading an existing file or opening an unnamed empty buffer.
- Saving with `:w`, `:w file`, and `:wq`.
- Quitting with `:q`, `:q!`, `Ctrl-C`, or `Ctrl-Q`.
- Normal, insert, and command-line modes.
- Status line at the bottom of the terminal.
- Terminal-size detection with `TIOCGWINSZ`.
- Vertical viewport scrolling to keep the cursor visible.
- `~` markers after end-of-file, like vi.
- Status display with current line, total lines, and column.
- Terminal-safe rendering of control/non-ASCII bytes as `\xNN`.
- Horizontal clipping at the terminal boundary.
- Movement: `h`, `j`, `k`, `l`, arrow keys, `0`, `^`, `$`, `G`, `nG`,
  `gg`, `ngg`, `w`, `b`, `e`.
- Counts for movement/editing, such as `5j`, `10j`, `3w`, `5G`, `3x`,
  and `2dd`.
- Insert commands: `i`, `a`, `I`, `A`, `o`, `O`.
- Editing commands: `x`, `dd`, `yy`, `p`, `P`, `r`, `s`, `S`, `D`, `C`.
- Operator + motion commands: `dw`, `d$`, `dG`, `yw`, `y$`, `yG`,
  `cw`, `c$`, and `cc`. `cw` changes the current word and enters insert mode.
- One-level undo with `u`.
- Search with `/pattern`, `n`, and `N`.
- Literal substitution with `:s/old/new/`, `:s/old/new/g`, and
  `:%s/old/new/g`.
- Keyboard macros with `qa`, `q`, `@a`, and `@@`, using bounded `a`-`z`
  registers.

## Current Limitations

- The buffer is dynamic but still byte-oriented; there is no UTF-8 awareness.
- Only basic ASCII word movement is implemented. Space, tab, and newline are
  treated as word separators.
- Rendering clips long lines rather than horizontally scrolling them.
- UTF-8 is editable byte-for-byte but displayed as escaped bytes.
- There is no multi-level undo, redo, visual mode, or ex-style substitution.
- File names are limited to 255 bytes.
- Unexpected crashes can still require `stty sane`; common termination signals
  now restore the terminal before exiting.

## Useful Next Steps

- Add `%`, `{`, `}`, and a richer vi word model.
- Add horizontal viewport handling for long lines.
- Add tab/control-character rendering.
