.intel_syntax noprefix
.global _start

# Linux x86-64 syscall numbers used directly by this program.
.equ SYS_READ, 0
.equ SYS_WRITE, 1
.equ SYS_OPEN, 2
.equ SYS_CLOSE, 3
.equ SYS_STAT, 4
.equ SYS_MMAP, 9
.equ SYS_MUNMAP, 11
.equ SYS_EXIT, 60
.equ SYS_IOCTL, 16
.equ SYS_MREMAP, 25
.equ SYS_RT_SIGACTION, 13
.equ SYS_RT_SIGRETURN, 15
.equ SYS_GETPID, 39
.equ SYS_FSTAT, 5
.equ SYS_FCHMOD, 91
.equ SYS_FSYNC, 74
.equ SYS_RENAME, 82
.equ SYS_UNLINK, 87

.equ ERRNO_ENOENT, 2
.equ ERRNO_EINTR, 4

.equ O_RDONLY, 0
.equ O_WRONLY, 1
.equ O_CREAT, 64
.equ O_TRUNC, 512
.equ O_EXCL, 128

.equ SA_RESTORER, 0x04000000

.equ PROT_READ, 1
.equ PROT_WRITE, 2
.equ MAP_PRIVATE, 2
.equ MAP_ANONYMOUS, 32
.equ MREMAP_MAYMOVE, 1

.equ TCGETS, 0x5401
.equ TCSETS, 0x5402
.equ FIONREAD, 0x541B
.equ TIOCGWINSZ, 0x5413

# Initial allocations for the dynamic flat buffers.
.equ BUF_INIT_CAP, 1048576
.equ NAME_CAP, 256
.equ CMD_CAP, 128
.equ SEARCH_CAP, 128
.equ MACRO_CAP, 256

.section .rodata
# Terminal escape sequences and short messages.
clear_screen:
    .ascii "\033[2J\033[H"
clear_screen_len = . - clear_screen

hide_cursor:
    .ascii "\033[?25l"
hide_cursor_len = . - hide_cursor

show_cursor:
    .ascii "\033[?25h"
show_cursor_len = . - show_cursor

status_normal:
    .ascii "\033[7m NORMAL  "
status_normal_len = . - status_normal

status_insert:
    .ascii "\033[7m INSERT  "
status_insert_len = . - status_insert

status_cmd:
    .ascii "\033[7m :"
status_cmd_len = . - status_cmd

status_search:
    .ascii "\033[7m /"
status_search_len = . - status_search

status_dirty:
    .ascii " [+]"
status_dirty_len = . - status_dirty

status_clean:
    .ascii "    "
status_clean_len = . - status_clean

status_pos_prefix:
    .ascii "  Ln "
status_pos_prefix_len = . - status_pos_prefix

status_pos_sep:
    .ascii "/"

status_col_prefix:
    .ascii " Col "
status_col_prefix_len = . - status_col_prefix

status_end:
    .ascii "\033[m\033[K\r"
status_end_len = . - status_end

status_newline:
    .ascii "\r\n"
status_newline_len = . - status_newline

tilde_line:
    .ascii "~\r\n"
tilde_line_len = . - tilde_line

msg_no_file:
    .ascii "usage: ved <file>\n"
msg_no_file_len = . - msg_no_file

msg_unsaved:
    .ascii "\033[7m Unsaved changes: use :q! or :wq \033[m\r"
msg_unsaved_len = . - msg_unsaved

msg_write_error:
    .ascii "\033[7m Write failed \033[m\r"
msg_write_error_len = . - msg_write_error

msg_load_error:
    .ascii "\033[7m Read failed \033[m\r\n"
msg_load_error_len = . - msg_load_error

msg_terminal_error:
    .ascii "ved: stdin is not a usable terminal\n"
msg_terminal_error_len = . - msg_terminal_error

msg_filename_error:
    .ascii "ved: filename too long\n"
msg_filename_error_len = . - msg_filename_error

msg_substitute_error:
    .ascii "\033[7m Usage: :[range]s/old/new/[g] \033[m\r"
msg_substitute_error_len = . - msg_substitute_error

msg_no_name:
    .ascii "\033[7m No file name: use :w <file> \033[m\r"
msg_no_name_len = . - msg_no_name

status_no_name:
    .ascii "[No Name]"
status_no_name_len = . - status_no_name

temp_suffix:
    .ascii ".ved.tmp."
temp_suffix_len = . - temp_suffix

hex_digits:
    .ascii "0123456789abcdef"

seq_cursor_prefix:
    .ascii "\033["
seq_cursor_prefix_len = . - seq_cursor_prefix

seq_cursor_sep:
    .ascii ";"

seq_cursor_suffix:
    .ascii "H"

.section .data
# Main loop flag. Set to zero to restore the terminal and exit cleanly.
running:
    .quad 1

# Current terminal size and viewport state. top_line is zero-based.
screen_rows:
    .quad 24
screen_cols:
    .quad 80
visible_rows:
    .quad 23
top_line:
    .quad 0
cursor_line:
    .quad 0
cursor_col:
    .quad 0
total_lines:
    .quad 1
raw_enabled:
    .quad 0
io_error:
    .quad 0

# Dynamic buffer pointers/capacities. The main text buffer is mirrored in r14.
buf_ptr:
    .quad 0
buf_cap:
    .quad 0
undo_ptr:
    .quad 0
undo_cap:
    .quad 0
yank_ptr:
    .quad 0
yank_cap:
    .quad 0

.section .bss
.align 8
undo_len:
    .quad 0
undo_cursor:
    .quad 0
undo_dirty:
    .quad 0
undo_valid:
    .quad 0
yank_len:
    .quad 0
yank_valid:
    .quad 0
yank_type:
    .quad 0

# Current file path copied from argv[1].
file_name:
    .skip NAME_CAP
file_name_len:
    .quad 0
file_name_error:
    .quad 0
temp_name:
    .skip NAME_CAP
temp_name_len:
    .quad 0
temp_mode:
    .quad 0
stat_buf:
    .skip 144

# Buffer state. cursor is a byte offset into buf, not a screen coordinate.
buf_len:
    .quad 0
cursor:
    .quad 0

# mode: 0 = normal, 1 = insert, 2 = command-line.
mode:
    .quad 0
insert_undo_saved:
    .quad 0

# Dirty means the buffer has unsaved changes.
dirty:
    .quad 0

# Temporary state for vertical movement and two-key commands such as dd.
last_col:
    .quad 0
op_pending:
    .quad 0
g_pending:
    .quad 0
replace_pending:
    .quad 0
count_accum:
    .quad 0
count_active:
    .quad 0

# Input state. pending_key lets Escape peek for arrow-key sequences without
# losing the next normal command, such as Esc followed by :wq.
bytes_avail:
    .quad 0
pending_valid:
    .quad 0
keybuf:
    .skip 1
pending_key:
    .skip 1
cmdbuf:
    .skip CMD_CAP
cmdlen:
    .quad 0
search_buf:
    .skip SEARCH_CAP
search_len:
    .quad 0
replace_buf:
    .skip SEARCH_CAP
replace_len:
    .quad 0
substitute_global:
    .quad 0
substitute_all:
    .quad 0
substitute_start:
    .quad 0
substitute_end:
    .quad 0

# Macro storage. Each register holds a bounded sequence of raw key bytes.
macro_data:
    .skip 26 * MACRO_CAP
macro_lengths:
    .skip 26 * 8
macro_recording:
    .quad 0
macro_pending:
    .quad 0
macro_replaying:
    .quad 0
macro_replay_reg:
    .quad 0
macro_replay_pos:
    .quad 0
macro_last_reg:
    .quad 0
orig_termios:
    .skip 64
raw_termios:
    .skip 64
signal_action:
    .skip 152

# struct winsize storage: rows, cols, x pixels, y pixels.
winsize:
    .skip 8

# Scratch space used when formatting cursor row/column numbers.
num_buf:
    .skip 32

.section .text

# Program entry. With argv[1] it loads that file; with no filename it opens an
# unnamed empty buffer. Then it switches the terminal to raw mode and dispatches
# every key through the active mode.
_start:
    mov rbx, [rsp]              # argc
    cmp rbx, 2
    jae have_arg
    jmp start_editor

have_arg:
    mov rsi, [rsp + 16]         # argv[1]
    call copy_file_name
    cmp qword ptr [file_name_error], 0
    je start_editor
    jmp filename_error_exit

start_editor:
    call init_main_buffer
    call load_file
    test rax, rax
    jz start_editor_terminal
    mov rsi, offset msg_load_error
    mov rdx, msg_load_error_len
    call write_stdout
    mov rdi, 1
    jmp exit_now

start_editor_terminal:
    call enable_raw
    test rax, rax
    jz main_loop
    mov rsi, offset msg_terminal_error
    mov rdx, msg_terminal_error_len
    call write_stdout
    mov rdi, 1
    jmp exit_now

filename_error_exit:
    mov rsi, offset msg_filename_error
    mov rdx, msg_filename_error_len
    call write_stdout
    mov rdi, 1
    jmp exit_now

main_loop:
    cmp qword ptr [running], 0
    je done
    call redraw
    cmp qword ptr [io_error], 0
    jne force_quit
    call read_key
    cmp rax, 0
    jl main_loop
    je force_quit
    movzx eax, byte ptr [keybuf]
    cmp al, 3                  # Ctrl-C: emergency quit
    je force_quit
    cmp al, 17                 # Ctrl-Q: emergency quit
    je force_quit
    # Record dispatched keys, except the single q that terminates recording.
    # Playback is deliberately not recorded, which prevents recursive growth.
    cmp qword ptr [macro_recording], 0
    je dispatch_key
    cmp qword ptr [macro_replaying], 0
    jne dispatch_key
    cmp al, 'q'
    je dispatch_key
    mov r15b, al
    mov rax, [macro_recording]
    dec rax
    imul rax, rax, MACRO_CAP
    mov rcx, [macro_recording]
    dec rcx
    imul rcx, 8
    mov rdx, [macro_lengths + rcx]
    cmp rdx, MACRO_CAP
    jae dispatch_key
    mov byte ptr [macro_data + rax + rdx], r15b
    inc rdx
    mov [macro_lengths + rcx], rdx
    mov al, r15b
dispatch_key:
    cmp qword ptr [mode], 1
    je dispatch_insert
    cmp qword ptr [mode], 2
    je dispatch_command
    cmp qword ptr [mode], 3
    je dispatch_search
    call handle_normal
    jmp main_loop
dispatch_insert:
    call handle_insert
    jmp main_loop
dispatch_command:
    call handle_command
    jmp main_loop
dispatch_search:
    call handle_search
    jmp main_loop
force_quit:
    mov qword ptr [running], 0
    jmp main_loop

done:
    call disable_raw
    mov rdi, 0
    jmp exit_now

exit_now:
    mov rax, SYS_EXIT
    syscall

# Copy argv[1] into a bounded, NUL-terminated filename buffer.
copy_file_name:
    xor rcx, rcx
copy_name_loop:
    cmp rcx, NAME_CAP - 1
    jb copy_name_byte
    cmp byte ptr [rsi + rcx], 0
    je copy_name_done
    mov qword ptr [file_name_error], 1
    jmp copy_name_done
copy_name_byte:
    mov al, byte ptr [rsi + rcx]
    mov byte ptr [file_name + rcx], al
    test al, al
    je copy_name_done
    inc rcx
    jmp copy_name_loop
copy_name_done:
    mov qword ptr [file_name_len], rcx
    mov byte ptr [file_name + rcx], 0
    ret

# Ensure a dynamic mmap-backed buffer has at least rdx bytes of capacity.
# rdi points to the qword holding the buffer address and rsi to the qword
# holding its capacity. On success rax=0 and both slots are updated.
ensure_dynamic_buffer:
    push rbx
    push rcx
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r15
    mov r12, rdi
    mov r13, rsi
    mov rbx, rdx
    mov rax, [r13]
    cmp rax, rbx
    jae ensure_dynamic_done
    mov rcx, rax
    test rcx, rcx
    jne ensure_dynamic_have_cap
    mov rcx, BUF_INIT_CAP
ensure_dynamic_have_cap:
    cmp rcx, rbx
    jae ensure_dynamic_target
ensure_dynamic_grow:
    mov rax, 0x4000000000000000
    cmp rcx, rax
    jae ensure_dynamic_fail
    shl rcx, 1
    cmp rcx, rbx
    jb ensure_dynamic_grow
ensure_dynamic_target:
    mov r15, rcx
    mov r8, [r12]
    test r8, r8
    je ensure_dynamic_first_alloc
    mov rax, SYS_MREMAP
    mov rdi, r8
    mov rsi, [r13]
    mov rdx, r15
    mov r10, MREMAP_MAYMOVE
    xor r8, r8
    xor r9, r9
    syscall
    test rax, rax
    js ensure_dynamic_fail
    mov [r12], rax
    mov [r13], r15
    xor rax, rax
    jmp ensure_dynamic_done
ensure_dynamic_first_alloc:
    mov rax, SYS_MMAP
    xor rdi, rdi
    mov rsi, r15
    mov rdx, PROT_READ | PROT_WRITE
    mov r10, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    syscall
    test rax, rax
    js ensure_dynamic_fail
    mov [r12], rax
    mov [r13], r15
    xor rax, rax
    jmp ensure_dynamic_done
ensure_dynamic_fail:
    mov rax, 1
ensure_dynamic_done:
    pop r15
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rcx
    pop rbx
    ret

init_main_buffer:
    lea rdi, [buf_ptr]
    lea rsi, [buf_cap]
    mov rdx, BUF_INIT_CAP
    call ensure_dynamic_buffer
    cmp rax, 0
    jne init_main_buffer_fail
    mov r14, [buf_ptr]
    ret
init_main_buffer_fail:
    mov rdi, 1
    jmp exit_now

# Load the file into the dynamic main buffer. A missing file is treated as an
# empty buffer.
load_file:
    mov rax, SYS_OPEN
    mov rdi, offset file_name
    mov rsi, O_RDONLY
    xor rdx, rdx
    syscall
    test rax, rax
    jns load_file_opened
    cmp rax, -ERRNO_ENOENT
    je load_empty
    jmp load_open_error
load_file_opened:
    mov r12, rax
    mov qword ptr [buf_len], 0
    mov qword ptr [cursor], 0
load_file_read:
    mov rbx, [buf_len]
    mov rax, [buf_cap]
    sub rax, rbx
    cmp rax, 1
    jae load_file_have_space
    mov rdx, rbx
    inc rdx
    lea rdi, [buf_ptr]
    lea rsi, [buf_cap]
    call ensure_dynamic_buffer
    test rax, rax
    jne load_file_error
    mov r14, [buf_ptr]
    jmp load_file_read
load_file_have_space:
    mov rax, SYS_READ
    mov rdi, r12
    lea rsi, [r14 + rbx]
    mov rdx, [buf_cap]
    sub rdx, rbx
    syscall
    cmp rax, -ERRNO_EINTR
    je load_file_read
    test rax, rax
    js load_file_error
    je close_loaded
    add qword ptr [buf_len], rax
    cmp rax, rdx
    je load_file_read
close_loaded:
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall
    xor rax, rax
    ret
load_file_error:
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall
    mov rax, 1
    ret
load_open_error:
    mov rax, 1
    ret
load_empty:
    xor rax, rax
    ret

# Put stdin in raw mode so keys arrive one byte at a time. The original
# termios bytes are saved and restored on exit.
enable_raw:
    mov rax, SYS_IOCTL
    mov rdi, 0
    mov rsi, TCGETS
    mov rdx, offset orig_termios
    syscall
    test rax, rax
    js enable_raw_fail

    xor rcx, rcx
copy_termios:
    cmp rcx, 64
    jae raw_flags
    mov al, byte ptr [orig_termios + rcx]
    mov byte ptr [raw_termios + rcx], al
    inc rcx
    jmp copy_termios

raw_flags:
    and dword ptr [raw_termios + 0], 0xfffffacd  # clear BRKINT, ICRNL, INPCK, ISTRIP, IXON
    and dword ptr [raw_termios + 4], 0xfffffffe  # clear OPOST
    and dword ptr [raw_termios + 12], 0xffff7ff4 # clear ECHO, ICANON, IEXTEN, ISIG
    mov byte ptr [raw_termios + 17 + 6], 1       # VMIN
    mov byte ptr [raw_termios + 17 + 5], 0       # VTIME

    call install_signals
    test rax, rax
    js enable_raw_fail

    mov rax, SYS_IOCTL
    mov rdi, 0
    mov rsi, TCSETS
    mov rdx, offset raw_termios
    syscall
    test rax, rax
    js enable_raw_fail
    mov qword ptr [raw_enabled], 1
    xor rax, rax
    ret
enable_raw_fail:
    mov rax, 1
    ret

# Restore the terminal settings that were active when the editor started.
disable_raw:
    mov rsi, offset show_cursor
    mov rdx, show_cursor_len
    call write_stdout
    mov rax, SYS_IOCTL
    mov rdi, 0
    mov rsi, TCSETS
    mov rdx, offset orig_termios
    syscall
    mov qword ptr [raw_enabled], 0
    mov rsi, offset clear_screen
    mov rdx, clear_screen_len
    call write_stdout
    ret

# Install a minimal restorable handler for signals that commonly terminate the
# editor. The kernel sigaction layout is handler, flags, restorer, mask[16].
install_signals:
    mov qword ptr [signal_action + 0], offset signal_handler
    mov qword ptr [signal_action + 8], SA_RESTORER
    mov qword ptr [signal_action + 16], offset signal_restorer
    lea rdi, [signal_action + 24]
    xor eax, eax
    mov ecx, 16
    rep stosq
    mov r10, 8
    mov rax, SYS_RT_SIGACTION
    mov rdi, 1                  # SIGHUP
    mov rsi, offset signal_action
    xor rdx, rdx
    syscall
    test rax, rax
    js install_signals_fail
    mov rax, SYS_RT_SIGACTION
    mov rdi, 2                  # SIGINT
    syscall
    test rax, rax
    js install_signals_fail
    mov rax, SYS_RT_SIGACTION
    mov rdi, 15                 # SIGTERM
    syscall
    test rax, rax
    js install_signals_fail
    xor rax, rax
    ret
install_signals_fail:
    mov rax, -1
    ret

signal_handler:
    cmp qword ptr [raw_enabled], 0
    je signal_exit
    mov qword ptr [raw_enabled], 0
    call disable_raw
signal_exit:
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall
signal_restorer:
    mov rax, SYS_RT_SIGRETURN
    syscall

# Read one logical key into keybuf. If escape parsing pushed one byte back,
# return that byte before doing another read syscall.
read_key:
    # Replay is injected before stdin, so macro playback follows exactly the
    # same dispatch path as keys typed by the user.
    cmp qword ptr [macro_replaying], 0
    je read_key_pending
    mov rax, [macro_replay_reg]
    imul rax, rax, MACRO_CAP
    add rax, [macro_replay_pos]
    mov rcx, [macro_replay_reg]
    imul rcx, 8
    mov rdx, [macro_lengths + rcx]
    cmp qword ptr [macro_replay_pos], rdx
    jb read_macro_byte
    mov qword ptr [macro_replaying], 0
    jmp read_key_pending
read_macro_byte:
    movzx eax, byte ptr [macro_data + rax]
    mov byte ptr [keybuf], al
    inc qword ptr [macro_replay_pos]
    mov rax, 1
    ret
read_key_pending:
    cmp qword ptr [pending_valid], 0
    je read_key_syscall
    mov al, byte ptr [pending_key]
    mov byte ptr [keybuf], al
    mov qword ptr [pending_valid], 0
    mov rax, 1
    ret
read_key_syscall:
    mov rax, SYS_READ
    mov rdi, 0
    mov rsi, offset keybuf
    mov rdx, 1
    syscall
    ret

# Ask the tty how many input bytes are queued. This distinguishes a lone Esc
# from an arrow-key sequence like ESC [ A.
check_input_available:
    mov qword ptr [bytes_avail], 0
    mov rax, SYS_IOCTL
    mov rdi, 0
    mov rsi, FIONREAD
    mov rdx, offset bytes_avail
    syscall
    ret

# Normal mode: vi-like movement/editing commands and pending operators.
handle_normal:
    # q stops an active recording before it can be interpreted as a command.
    cmp qword ptr [macro_recording], 0
    je normal_macro_pending
    cmp al, 'q'
    jne normal_macro_pending
    mov qword ptr [macro_recording], 0
    ret
normal_macro_pending:
    cmp qword ptr [macro_pending], 0
    je normal_macro_ready
    mov rbx, [macro_pending]
    cmp al, '@'
    je macro_repeat_last
    cmp al, 'a'
    jb macro_pending_cancel
    cmp al, 'z'
    ja macro_pending_cancel
    sub al, 'a'
    movzx rax, al
    cmp rbx, 1
    je macro_begin_record
    mov [macro_replay_reg], rax
    mov qword ptr [macro_replay_pos], 0
    mov qword ptr [macro_replaying], 1
    mov [macro_last_reg], rax
    mov qword ptr [macro_pending], 0
    ret
macro_repeat_last:
    cmp rbx, 2
    jne macro_pending_cancel
    mov rax, [macro_last_reg]
    mov [macro_replay_reg], rax
    mov qword ptr [macro_replay_pos], 0
    mov qword ptr [macro_replaying], 1
    mov qword ptr [macro_pending], 0
    ret
macro_begin_record:
    inc rax
    mov [macro_recording], rax
    dec rax
    imul rax, 8
    mov qword ptr [macro_lengths + rax], 0
    mov qword ptr [macro_pending], 0
    ret
macro_pending_cancel:
    mov qword ptr [macro_pending], 0
    ret
normal_macro_ready:
    cmp qword ptr [replace_pending], 0
    jne normal_replace_char
    cmp qword ptr [g_pending], 0
    jne normal_pending_g
    cmp qword ptr [op_pending], 0
    je normal_no_pending
    cmp qword ptr [op_pending], 1
    je normal_pending_delete
    cmp qword ptr [op_pending], 2
    je normal_pending_yank
    cmp qword ptr [op_pending], 3
    je normal_pending_change
    mov qword ptr [op_pending], 0
    jmp normal_no_pending
normal_pending_delete:
    mov qword ptr [op_pending], 0
    cmp al, 'd'
    je delete_line_counted
    jmp operator_motion_delete
normal_pending_yank:
    mov qword ptr [op_pending], 0
    cmp al, 'y'
    je yank_line_counted
    jmp operator_motion_yank
normal_pending_change:
    mov qword ptr [op_pending], 0
    cmp al, 'c'
    je change_line_counted
    jmp operator_motion_change
normal_pending_g:
    mov qword ptr [g_pending], 0
    cmp al, 'g'
    je goto_top_counted
    call clear_count
    ret
normal_no_pending:
    cmp al, '0'
    jne normal_count_nonzero
    cmp qword ptr [count_active], 0
    jne normal_add_count
    jmp normal_not_count
normal_count_nonzero:
    cmp al, '1'
    jb normal_not_count
    cmp al, '9'
    jbe normal_add_count
    jmp normal_not_count
normal_add_count:
    sub al, '0'
    movzx rbx, al
    mov rax, [count_accum]
    imul rax, rax, 10
    add rax, rbx
    mov [count_accum], rax
    mov qword ptr [count_active], 1
    ret
normal_not_count:
    cmp al, 27
    je normal_escape
    cmp al, 'i'
    je normal_insert
    cmp al, 'a'
    je normal_append
    cmp al, 'A'
    je normal_append_line
    cmp al, 'I'
    je normal_insert_line
    cmp al, 'o'
    je normal_open_below
    cmp al, 'O'
    je normal_open_above
    cmp al, 'h'
    je move_left_counted
    cmp al, 'l'
    je move_right_counted
    cmp al, 'w'
    je move_word_counted
    cmp al, 'b'
    je move_back_word_counted
    cmp al, 'e'
    je move_word_end_counted
    cmp al, 'j'
    je move_down_counted
    cmp al, 'k'
    je move_up_counted
    cmp al, '0'
    je move_line_start
    cmp al, '^'
    je move_line_first_nonblank
    cmp al, '$'
    je move_line_end
    cmp al, 'x'
    je delete_char_counted
    cmp al, 's'
    je substitute_char_counted
    cmp al, 'S'
    je change_line_counted
    cmp al, 'D'
    je delete_to_line_end
    cmp al, 'C'
    je change_to_line_end
    cmp al, 'r'
    je start_replace_char
    cmp al, 'u'
    je undo_last_change
    cmp al, 'd'
    je normal_delete_pending
    cmp al, 'c'
    je normal_change_pending
    cmp al, 'y'
    je normal_yank_pending
    cmp al, 'p'
    je paste_after_line
    cmp al, 'P'
    je paste_before_line
    cmp al, '/'
    je start_search
    cmp al, 'n'
    je repeat_search_forward
    cmp al, 'N'
    je repeat_search_backward
    cmp al, 'G'
    je goto_line_counted
    cmp al, 'g'
    je normal_g_pending
    cmp al, 'q'
    je normal_macro_record
    cmp al, '@'
    je normal_macro_play
    cmp al, ':'
    je start_command
    call clear_count
    ret

normal_escape:
    call read_escape_arrow
    ret

# First d/y/c waits for the next normal-mode key.
normal_delete_pending:
    mov qword ptr [op_pending], 1
    ret

normal_yank_pending:
    mov qword ptr [op_pending], 2
    ret

normal_change_pending:
    mov qword ptr [op_pending], 3
    ret

normal_g_pending:
    mov qword ptr [g_pending], 1
    ret

normal_macro_record:
    # The next letter selects the register; the actual q key is not recorded.
    mov qword ptr [macro_pending], 1
    ret

normal_macro_play:
    # @ followed by a register starts playback; @@ repeats the last one.
    mov qword ptr [macro_pending], 2
    ret

normal_insert:
    mov qword ptr [op_pending], 0
    mov qword ptr [g_pending], 0
    call clear_count
    jmp enter_insert_mode

normal_append:
    mov rax, [cursor]
    cmp rax, [buf_len]
    jae append_mode_set
    inc qword ptr [cursor]
append_mode_set:
    mov qword ptr [op_pending], 0
    mov qword ptr [g_pending], 0
    call clear_count
    jmp enter_insert_mode

normal_append_line:
    call move_line_end
    call move_right
    jmp normal_insert

normal_insert_line:
    call move_line_start
    jmp normal_insert

# Open a new line below the current line and enter insert mode.
normal_open_below:
    mov rbx, [cursor]
find_line_end:
    cmp rbx, [buf_len]
    jae open_at_end
    cmp byte ptr [r14 + rbx], 10
    je open_before_newline
    inc rbx
    jmp find_line_end
open_before_newline:
    mov [cursor], rbx
    mov al, 10
    call insert_byte
    mov qword ptr [op_pending], 0
    mov qword ptr [g_pending], 0
    call clear_count
    jmp enter_insert_mode_undo_saved
open_at_end:
    mov [cursor], rbx
    cmp rbx, 0
    je open_empty
    mov rcx, rbx
    dec rcx
    cmp byte ptr [r14 + rcx], 10
    je open_empty
    mov al, 10
    call insert_byte
    mov qword ptr [op_pending], 0
    mov qword ptr [g_pending], 0
    call clear_count
    jmp enter_insert_mode_undo_saved
open_empty:
    mov qword ptr [op_pending], 0
    mov qword ptr [g_pending], 0
    call clear_count
    jmp enter_insert_mode

# Open a new line above the current line and enter insert mode.
normal_open_above:
    mov rbx, [cursor]
find_line_start_for_open:
    test rbx, rbx
    je open_above_at_start
    cmp byte ptr [r14 + rbx - 1], 10
    je open_above_at_line_start
    dec rbx
    jmp find_line_start_for_open
open_above_at_start:
    mov qword ptr [cursor], 0
    mov al, 10
    call insert_byte
    dec qword ptr [cursor]
    mov qword ptr [op_pending], 0
    mov qword ptr [g_pending], 0
    call clear_count
    jmp enter_insert_mode_undo_saved
open_above_at_line_start:
    mov [cursor], rbx
    mov al, 10
    call insert_byte
    dec qword ptr [cursor]
    mov qword ptr [op_pending], 0
    mov qword ptr [g_pending], 0
    call clear_count
    jmp enter_insert_mode_undo_saved

start_command:
    mov qword ptr [op_pending], 0
    mov qword ptr [g_pending], 0
    call clear_count
    mov qword ptr [mode], 2
    mov qword ptr [cmdlen], 0
    ret

start_search:
    mov qword ptr [op_pending], 0
    mov qword ptr [g_pending], 0
    call clear_count
    mov qword ptr [mode], 3
    mov qword ptr [cmdlen], 0
    ret

clear_count:
    mov qword ptr [count_accum], 0
    mov qword ptr [count_active], 0
    ret

enter_insert_mode:
    mov qword ptr [insert_undo_saved], 0
    mov qword ptr [mode], 1
    ret

enter_insert_mode_undo_saved:
    mov qword ptr [insert_undo_saved], 1
    mov qword ptr [mode], 1
    ret

get_count_or_one:
    cmp qword ptr [count_active], 0
    je count_default_one
    mov rax, [count_accum]
    call clear_count
    ret
count_default_one:
    mov rax, 1
    ret

# Save the current buffer state before a mutating operation.
save_undo:
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    mov rax, [buf_len]
    mov [undo_len], rax
    mov rax, [cursor]
    mov [undo_cursor], rax
    mov rax, [dirty]
    mov [undo_dirty], rax
    mov rdx, [buf_len]
    cmp rdx, [undo_cap]
    jbe save_undo_have_space
    lea rdi, [undo_ptr]
    lea rsi, [undo_cap]
    call ensure_dynamic_buffer
    test rax, rax
    jne save_undo_fail
save_undo_have_space:
    mov rdi, [undo_ptr]
    xor rbx, rbx
save_undo_loop:
    cmp rbx, [buf_len]
    jae save_undo_done
    mov al, byte ptr [r14 + rbx]
    mov byte ptr [rdi + rbx], al
    inc rbx
    jmp save_undo_loop
save_undo_done:
    mov qword ptr [undo_valid], 1
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    ret
save_undo_fail:
    mov qword ptr [undo_valid], 0
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    ret

save_insert_undo_once:
    cmp qword ptr [insert_undo_saved], 0
    jne save_insert_undo_done
    call save_undo
    mov qword ptr [insert_undo_saved], 1
save_insert_undo_done:
    ret

save_edit_undo:
    cmp qword ptr [mode], 1
    je save_insert_undo_once
    call save_undo
    ret

undo_last_change:
    cmp qword ptr [undo_valid], 0
    je undo_done
    mov rsi, [undo_ptr]
    xor rbx, rbx
undo_copy_loop:
    cmp rbx, [undo_len]
    jae undo_copy_done
    mov al, byte ptr [rsi + rbx]
    mov byte ptr [r14 + rbx], al
    inc rbx
    jmp undo_copy_loop
undo_copy_done:
    mov rax, [undo_len]
    mov [buf_len], rax
    mov rax, [undo_cursor]
    mov [cursor], rax
    mov rax, [undo_dirty]
    mov [dirty], rax
    mov qword ptr [undo_valid], 0
    call clear_count
undo_done:
    ret

move_left_counted:
    call get_count_or_one
    mov r15, rax
move_left_count_loop:
    test r15, r15
    je move_left_count_done
    call move_left
    dec r15
    jmp move_left_count_loop
move_left_count_done:
    ret

move_right_counted:
    call get_count_or_one
    mov r15, rax
move_right_count_loop:
    test r15, r15
    je move_right_count_done
    call move_right
    dec r15
    jmp move_right_count_loop
move_right_count_done:
    ret

move_down_counted:
    call get_count_or_one
    mov r15, rax
move_down_count_loop:
    test r15, r15
    je move_down_count_done
    call move_down
    dec r15
    jmp move_down_count_loop
move_down_count_done:
    ret

move_up_counted:
    call get_count_or_one
    mov r15, rax
move_up_count_loop:
    test r15, r15
    je move_up_count_done
    call move_up
    dec r15
    jmp move_up_count_loop
move_up_count_done:
    ret

move_word_counted:
    call get_count_or_one
    mov r15, rax
move_word_count_loop:
    test r15, r15
    je move_word_count_done
    call move_word
    dec r15
    jmp move_word_count_loop
move_word_count_done:
    ret

move_back_word_counted:
    call get_count_or_one
    mov r15, rax
move_back_word_count_loop:
    test r15, r15
    je move_back_word_count_done
    call move_back_word
    dec r15
    jmp move_back_word_count_loop
move_back_word_count_done:
    ret

move_word_end_counted:
    call get_count_or_one
    mov r15, rax
move_word_end_count_loop:
    test r15, r15
    je move_word_end_count_done
    call move_word_end
    dec r15
    jmp move_word_end_count_loop
move_word_end_count_done:
    ret

delete_char_counted:
    call get_count_or_one
    mov r15, rax
    call save_undo
delete_char_count_loop:
    test r15, r15
    je delete_char_count_done
    call delete_char
    dec r15
    jmp delete_char_count_loop
delete_char_count_done:
    ret

delete_line_counted:
    call get_count_or_one
    mov r15, rax
    call yank_lines_from_r15
    call save_undo
delete_line_count_loop:
    test r15, r15
    je delete_line_count_done
    call delete_line
    dec r15
    jmp delete_line_count_loop
delete_line_count_done:
    ret

change_line_counted:
    call delete_line_counted
    mov r8, [cursor]
    mov rbx, [buf_len]
change_line_make_blank_shift:
    cmp rbx, r8
    je change_line_make_blank_store
    dec rbx
    mov al, byte ptr [r14 + rbx]
    mov byte ptr [r14 + rbx + 1], al
    jmp change_line_make_blank_shift
change_line_make_blank_store:
    mov byte ptr [r14 + r8], 10
    inc qword ptr [buf_len]
    mov [cursor], r8
    mov qword ptr [dirty], 1
    jmp enter_insert_mode_undo_saved

delete_to_line_end:
    call clear_count
    mov r8, [cursor]
    call move_line_end
    call move_right
    mov r9, [cursor]
    mov [cursor], r8
    cmp r9, r8
    jbe delete_to_line_end_done
    call save_undo
    push r8
    push r9
    call yank_range
    pop r9
    pop r8
    call delete_range
    mov rax, 1
    ret
delete_to_line_end_done:
    xor rax, rax
    ret

change_to_line_end:
    call delete_to_line_end
    cmp rax, 1
    je change_to_line_end_keep_undo
    jmp enter_insert_mode
change_to_line_end_keep_undo:
    jmp enter_insert_mode_undo_saved

substitute_char_counted:
    call delete_char_counted
    jmp enter_insert_mode_undo_saved

start_replace_char:
    call clear_count
    mov qword ptr [replace_pending], 1
    ret

normal_replace_char:
    mov qword ptr [replace_pending], 0
    cmp al, 27
    je replace_done
    cmp al, 32
    jb replace_done
    mov rbx, [cursor]
    cmp rbx, [buf_len]
    jae replace_done
    cmp byte ptr [r14 + rbx], 10
    je replace_done
    mov r8b, al
    call save_undo
    mov rbx, [cursor]
    mov byte ptr [r14 + rbx], r8b
    mov qword ptr [dirty], 1
replace_done:
    ret

yank_line_counted:
    call get_count_or_one
    mov r15, rax
yank_lines_from_r15:
    mov rbx, [cursor]
    cmp rbx, [buf_len]
    jb yank_cursor_ok
    cmp rbx, 0
    je yank_no_data
    dec rbx
yank_cursor_ok:
    mov r8, rbx
yank_find_start:
    test r8, r8
    je yank_start_found
    cmp byte ptr [r14 + r8 - 1], 10
    je yank_start_found
    dec r8
    jmp yank_find_start
yank_start_found:
    mov r9, r8
    mov r10, r15
yank_find_end:
    test r10, r10
    je yank_range_found
    cmp r9, [buf_len]
    jae yank_range_found
    cmp byte ptr [r14 + r9], 10
    je yank_next_line
    inc r9
    jmp yank_find_end
yank_next_line:
    inc r9
    dec r10
    jmp yank_find_end
yank_range_found:
    mov r11, r9
    sub r11, r8
    inc r11
    cmp r11, [yank_cap]
    jbe yank_len_ok
    lea rdi, [yank_ptr]
    lea rsi, [yank_cap]
    mov rdx, r11
    call ensure_dynamic_buffer
    test rax, rax
    jne yank_no_data
yank_len_ok:
    mov rdi, [yank_ptr]
    dec r11
    xor rbx, rbx
yank_copy_loop:
    cmp rbx, r11
    jae yank_copy_done
    mov rcx, r8
    add rcx, rbx
    add rcx, r14
    mov al, byte ptr [rcx]
    mov byte ptr [rdi + rbx], al
    inc rbx
    jmp yank_copy_loop
yank_copy_done:
    test r11, r11
    je yank_no_data
    mov rax, r11
    dec rax
    cmp byte ptr [rdi + rax], 10
    je yank_store_len
    mov byte ptr [rdi + r11], 10
    inc r11
yank_store_len:
    mov [yank_len], r11
    mov qword ptr [yank_valid], 1
    mov qword ptr [yank_type], 1
    ret
yank_no_data:
    mov qword ptr [yank_valid], 0
    ret

paste_after_line:
    call clear_count
    cmp qword ptr [yank_valid], 0
    je paste_done
    cmp qword ptr [yank_type], 2
    je paste_after_char
    call save_undo
    mov r8, [cursor]
paste_find_line_end:
    cmp r8, [buf_len]
    jae paste_at_insert_point
    cmp byte ptr [r14 + r8], 10
    je paste_after_newline
    inc r8
    jmp paste_find_line_end
paste_after_newline:
    inc r8
paste_at_insert_point:
    jmp paste_common

paste_before_line:
    call clear_count
    cmp qword ptr [yank_valid], 0
    je paste_done
    cmp qword ptr [yank_type], 2
    je paste_before_char
    call save_undo
    mov r8, [cursor]
paste_before_find_start:
    test r8, r8
    je paste_common
    cmp byte ptr [r14 + r8 - 1], 10
    je paste_common
    dec r8
    jmp paste_before_find_start

paste_common:
    xor r9, r9                  # separator byte count
    cmp r8, [buf_len]
    jne paste_have_size
    cmp qword ptr [buf_len], 0
    je paste_have_size
    mov rax, [buf_len]
    dec rax
    cmp byte ptr [r14 + rax], 10
    je paste_have_size
    mov r9, 1
paste_have_size:
    mov r10, [yank_len]
    add r10, r9
    mov rax, [buf_len]
    add rax, r10
    inc rax
    cmp rax, [buf_cap]
    jbe paste_have_capacity
    lea rdi, [buf_ptr]
    lea rsi, [buf_cap]
    mov rdx, rax
    call ensure_dynamic_buffer
    test rax, rax
    jne paste_done
    mov r14, [buf_ptr]
paste_have_capacity:
    mov rbx, [buf_len]
paste_shift_loop:
    cmp rbx, r8
    je paste_shift_done
    dec rbx
    mov al, byte ptr [r14 + rbx]
    mov rcx, rbx
    add rcx, r10
    add rcx, r14
    mov byte ptr [rcx], al
    jmp paste_shift_loop
paste_shift_done:
    mov rbx, r8
    test r9, r9
    je paste_copy_yank
    mov byte ptr [r14 + rbx], 10
    inc rbx
paste_copy_yank:
    xor r11, r11
    mov rdi, [yank_ptr]
paste_copy_loop:
    cmp r11, [yank_len]
    jae paste_copy_done
    mov al, byte ptr [rdi + r11]
    mov rcx, rbx
    add rcx, r11
    add rcx, r14
    mov byte ptr [rcx], al
    inc r11
    jmp paste_copy_loop
paste_copy_done:
    add qword ptr [buf_len], r10
    mov [cursor], rbx
    mov qword ptr [dirty], 1
paste_done:
    ret

paste_after_char:
    call save_undo
    mov r8, [cursor]
    cmp r8, [buf_len]
    jae paste_char_common
    inc r8
    jmp paste_char_common

paste_before_char:
    call save_undo
    mov r8, [cursor]
    jmp paste_char_common

paste_char_common:
    mov r10, [yank_len]
    mov rax, [buf_len]
    add rax, r10
    inc rax
    cmp rax, [buf_cap]
    jbe paste_char_have_capacity
    lea rdi, [buf_ptr]
    lea rsi, [buf_cap]
    mov rdx, rax
    call ensure_dynamic_buffer
    test rax, rax
    jne paste_done
    mov r14, [buf_ptr]
paste_char_have_capacity:
    mov rbx, [buf_len]
paste_char_shift:
    cmp rbx, r8
    je paste_char_shift_done
    dec rbx
    mov al, byte ptr [r14 + rbx]
    mov rcx, rbx
    add rcx, r10
    add rcx, r14
    mov byte ptr [rcx], al
    jmp paste_char_shift
paste_char_shift_done:
    xor r11, r11
    mov rdi, [yank_ptr]
paste_char_copy:
    cmp r11, [yank_len]
    jae paste_char_done
    mov al, byte ptr [rdi + r11]
    mov rcx, r8
    add rcx, r11
    add rcx, r14
    mov byte ptr [rcx], al
    inc r11
    jmp paste_char_copy
paste_char_done:
    add qword ptr [buf_len], r10
    mov [cursor], r8
    mov qword ptr [dirty], 1
    ret

operator_motion_delete:
    call compute_operator_range
    test rax, rax
    je operator_done
    call save_undo
    push r8
    push r9
    call yank_range
    pop r9
    pop r8
    call delete_range
    ret

operator_motion_yank:
    call compute_operator_range
    test rax, rax
    je operator_done
    call yank_range
    ret

operator_motion_change:
    cmp al, 'w'
    je operator_motion_change_word
    call compute_operator_range
    test rax, rax
    je operator_done
    call save_undo
    call delete_range
    call enter_insert_mode_undo_saved
operator_done:
    ret

operator_motion_change_word:
    mov r12, [cursor]
    call get_count_or_one
    mov r15, rax
    mov rbx, r12
change_word_loop:
    test r15, r15
    je change_word_range_done
change_word_skip_spaces:
    cmp rbx, [buf_len]
    jae change_word_range_done
    call byte_is_space_at_rbx
    cmp rax, 0
    je change_word_take_word
    inc rbx
    jmp change_word_skip_spaces
change_word_take_word:
    cmp rbx, [buf_len]
    jae change_word_range_done
    call byte_is_space_at_rbx
    cmp rax, 1
    je change_word_one_done
    inc rbx
    jmp change_word_take_word
change_word_one_done:
    dec r15
    test r15, r15
    je change_word_range_done
change_word_include_between:
    cmp rbx, [buf_len]
    jae change_word_range_done
    call byte_is_space_at_rbx
    cmp rax, 0
    je change_word_loop
    inc rbx
    jmp change_word_include_between
change_word_range_done:
    mov r8, r12
    mov r9, rbx
    cmp r9, r8
    jbe operator_done
    mov [cursor], r12
    call save_undo
    call delete_range
    jmp enter_insert_mode_undo_saved

compute_operator_range:
    mov r13b, al
    mov r12, [cursor]
    cmp r13b, 'w'
    je op_range_word
    cmp r13b, '$'
    je op_range_line_end
    cmp r13b, 'G'
    je op_range_g
    call clear_count
    xor rax, rax
    ret
op_range_word:
    call get_count_or_one
    mov r15, rax
op_range_word_loop:
    test r15, r15
    je op_range_from_cursor
    call move_word
    dec r15
    jmp op_range_word_loop
op_range_line_end:
    call clear_count
    call move_line_end
    call move_right
    jmp op_range_from_cursor
op_range_g:
    call goto_line_counted
    mov rax, [cursor]
    cmp rax, r12
    jb op_range_from_cursor
    call move_line_end
    call move_right
op_range_from_cursor:
    mov r8, r12
    mov r9, [cursor]
    mov [cursor], r12
    cmp r9, r8
    ja op_range_ok
    cmp r9, r8
    je op_range_fail
    mov r10, r8
    mov r8, r9
    mov r9, r10
op_range_ok:
    mov rax, 1
    ret
op_range_fail:
    xor rax, rax
    ret

yank_range:
    mov r11, r9
    sub r11, r8
yank_range_len_ok:
    inc r11
    cmp r11, [yank_cap]
    jbe yank_range_have_space
    lea rdi, [yank_ptr]
    lea rsi, [yank_cap]
    mov rdx, r11
    call ensure_dynamic_buffer
    test rax, rax
    jne yank_no_data
yank_range_have_space:
    mov rdi, [yank_ptr]
    dec r11
    xor rbx, rbx
yank_range_copy:
    cmp rbx, r11
    jae yank_range_done
    mov rcx, r8
    add rcx, rbx
    add rcx, r14
    mov al, byte ptr [rcx]
    mov byte ptr [rdi + rbx], al
    inc rbx
    jmp yank_range_copy
yank_range_done:
    mov [yank_len], r11
    mov qword ptr [yank_valid], 1
    mov qword ptr [yank_type], 2
    ret

delete_range:
    cmp r9, r8
    jbe delete_range_done
    mov r10, r9
    sub r10, r8
    mov r11, r8
    mov r12, r9
delete_range_loop:
    cmp r12, [buf_len]
    jae delete_range_shift_done
    mov al, byte ptr [r14 + r12]
    mov byte ptr [r14 + r11], al
    inc r11
    inc r12
    jmp delete_range_loop
delete_range_shift_done:
    sub qword ptr [buf_len], r10
    mov [cursor], r8
    mov qword ptr [dirty], 1
delete_range_done:
    ret

goto_line_counted:
    cmp qword ptr [count_active], 0
    je goto_last_line
    mov rax, [count_accum]
    call clear_count
    jmp goto_line_number
goto_last_line:
    mov rax, [total_lines]
    jmp goto_line_number

# Move cursor to a 1-based line number in rax, clamped to the file.
goto_line_number:
    cmp rax, 1
    jae goto_line_min_ok
    mov rax, 1
goto_line_min_ok:
    cmp rax, [total_lines]
    jbe goto_line_max_ok
    mov rax, [total_lines]
goto_line_max_ok:
    dec rax
    call find_line_offset
    mov [cursor], rax
    ret

goto_top_counted:
    cmp qword ptr [count_active], 0
    je goto_top_first
    mov rax, [count_accum]
    call clear_count
    jmp goto_line_number
goto_top_first:
    mov rax, 1
    jmp goto_line_number

# Horizontal movement changes the byte cursor directly.
move_left:
    cmp qword ptr [cursor], 0
    je move_left_done
    dec qword ptr [cursor]
move_left_done:
    ret

move_right:
    mov rax, [cursor]
    cmp rax, [buf_len]
    jae move_right_done
    inc qword ptr [cursor]
move_right_done:
    ret

# Move to the start of the next word. Words are byte runs separated by space,
# tab, or newline.
move_word:
    mov rbx, [cursor]
    cmp rbx, [buf_len]
    jae move_word_done
    call byte_is_space_at_rbx
    cmp rax, 1
    je word_skip_spaces
word_skip_current:
    cmp rbx, [buf_len]
    jae set_word_cursor
    call byte_is_space_at_rbx
    cmp rax, 1
    je word_skip_spaces
    inc rbx
    jmp word_skip_current
word_skip_spaces:
    cmp rbx, [buf_len]
    jae set_word_cursor
    call byte_is_space_at_rbx
    cmp rax, 0
    je set_word_cursor
    inc rbx
    jmp word_skip_spaces
set_word_cursor:
    mov [cursor], rbx
move_word_done:
    ret

move_back_word:
    mov rbx, [cursor]
    test rbx, rbx
    je move_back_word_done
    dec rbx
back_word_skip_spaces:
    test rbx, rbx
    je set_back_word_cursor
    call byte_is_space_at_rbx
    cmp rax, 0
    je back_word_skip_word
    dec rbx
    jmp back_word_skip_spaces
back_word_skip_word:
    test rbx, rbx
    je set_back_word_cursor
    dec rbx
    call byte_is_space_at_rbx
    cmp rax, 1
    je back_word_after_space
    jmp back_word_skip_word
back_word_after_space:
    inc rbx
set_back_word_cursor:
    mov [cursor], rbx
move_back_word_done:
    ret

move_word_end:
    mov rbx, [cursor]
    cmp rbx, [buf_len]
    jae move_word_end_done
    call byte_is_space_at_rbx
    cmp rax, 1
    je word_end_skip_spaces
    inc rbx
word_end_skip_spaces:
    cmp rbx, [buf_len]
    jae set_word_end_cursor
    call byte_is_space_at_rbx
    cmp rax, 0
    je word_end_in_word
    inc rbx
    jmp word_end_skip_spaces
word_end_in_word:
    cmp rbx, [buf_len]
    jae set_word_end_cursor
    call byte_is_space_at_rbx
    cmp rax, 1
    je word_end_prev
    inc rbx
    jmp word_end_in_word
word_end_prev:
    dec rbx
set_word_end_cursor:
    cmp rbx, [buf_len]
    jb word_end_set
    cmp rbx, 0
    je word_end_set
    dec rbx
word_end_set:
    mov [cursor], rbx
move_word_end_done:
    ret

byte_is_space_at_rbx:
    mov al, byte ptr [r14 + rbx]
    cmp al, ' '
    je byte_space_yes
    cmp al, 9
    je byte_space_yes
    cmp al, 10
    je byte_space_yes
    xor rax, rax
    ret
byte_space_yes:
    mov rax, 1
    ret

# Move to the first byte in the current line.
move_line_start:
    mov rbx, [cursor]
line_start_loop:
    test rbx, rbx
    je line_start_done
    cmp byte ptr [r14 + rbx - 1], 10
    je line_start_done
    dec rbx
    jmp line_start_loop
line_start_done:
    mov [cursor], rbx
    ret

# Move to the first non-blank byte in the current line. Spaces and tabs are
# skipped; if the line is empty, the cursor stays at line start.
move_line_first_nonblank:
    call move_line_start
    mov rbx, [cursor]
first_nonblank_loop:
    cmp rbx, [buf_len]
    jae first_nonblank_done
    cmp byte ptr [r14 + rbx], 10
    je first_nonblank_done
    cmp byte ptr [r14 + rbx], ' '
    je first_nonblank_advance
    cmp byte ptr [r14 + rbx], 9
    je first_nonblank_advance
    jmp first_nonblank_done
first_nonblank_advance:
    inc rbx
    jmp first_nonblank_loop
first_nonblank_done:
    mov [cursor], rbx
    ret

# Move to the last visible byte in the current line. This stops before the
# newline so x after $ does not accidentally join lines.
move_line_end:
    mov rbx, [cursor]
line_end_loop:
    cmp rbx, [buf_len]
    jae line_end_done
    cmp byte ptr [r14 + rbx], 10
    je line_end_done
    inc rbx
    jmp line_end_loop
line_end_done:
    test rbx, rbx
    je line_end_set
    cmp byte ptr [r14 + rbx - 1], 10
    je line_end_set
    dec rbx
line_end_set:
    mov [cursor], rbx
    ret

# Move down by preserving the current byte column where possible.
move_down:
    call compute_col
    mov [last_col], rax
    mov rbx, [cursor]
find_next_line:
    cmp rbx, [buf_len]
    jae move_down_done
    cmp byte ptr [r14 + rbx], 10
    je next_line_found
    inc rbx
    jmp find_next_line
next_line_found:
    inc rbx
    mov rcx, [last_col]
seek_down_col:
    test rcx, rcx
    je set_down_cursor
    cmp rbx, [buf_len]
    jae set_down_cursor
    cmp byte ptr [r14 + rbx], 10
    je set_down_cursor
    inc rbx
    dec rcx
    jmp seek_down_col
set_down_cursor:
    mov [cursor], rbx
move_down_done:
    ret

# Move up by finding the previous line start, then seeking to the saved column.
move_up:
    call compute_col
    mov [last_col], rax
    mov rbx, [cursor]
    test rbx, rbx
    je move_up_done
    dec rbx
skip_current_line_back:
    test rbx, rbx
    je at_file_start_up
    cmp byte ptr [r14 + rbx], 10
    je found_prev_line_end
    dec rbx
    jmp skip_current_line_back
found_prev_line_end:
    test rbx, rbx
    je at_file_start_up
    dec rbx
find_prev_line_start:
    test rbx, rbx
    je at_prev_line_start
    cmp byte ptr [r14 + rbx], 10
    je after_prev_newline
    dec rbx
    jmp find_prev_line_start
after_prev_newline:
    inc rbx
    jmp seek_up_target
at_file_start_up:
    xor rbx, rbx
    jmp seek_up_target
at_prev_line_start:
    xor rbx, rbx
seek_up_target:
    mov rcx, [last_col]
seek_up_col:
    test rcx, rcx
    je set_up_cursor
    cmp rbx, [buf_len]
    jae set_up_cursor
    cmp byte ptr [r14 + rbx], 10
    je set_up_cursor
    inc rbx
    dec rcx
    jmp seek_up_col
set_up_cursor:
    mov [cursor], rbx
move_up_done:
    ret

# Compute the cursor's zero-based byte column inside the current line.
compute_col:
    mov rbx, [cursor]
    xor rax, rax
col_loop:
    test rbx, rbx
    je col_done
    dec rbx
    cmp byte ptr [r14 + rbx], 10
    je col_done
    inc rax
    jmp col_loop
col_done:
    ret

# Delete the byte under cursor by shifting the buffer tail left.
delete_char:
    mov rax, [cursor]
    cmp rax, [buf_len]
    jae delete_done
    mov rbx, rax
shift_delete:
    inc rbx
    cmp rbx, [buf_len]
    jae delete_finish
    mov cl, byte ptr [r14 + rbx]
    mov byte ptr [r14 + rbx - 1], cl
    jmp shift_delete
delete_finish:
    dec qword ptr [buf_len]
    mov qword ptr [dirty], 1
delete_done:
    ret

# Delete the whole current line, including its trailing newline when present.
# The remaining tail is shifted left over the removed byte range.
delete_line:
    cmp qword ptr [buf_len], 0
    je delete_line_done

    mov rbx, [cursor]
    cmp rbx, [buf_len]
    jb delete_line_cursor_ok
    cmp rbx, 0
    je delete_line_done
    dec rbx
delete_line_cursor_ok:
    mov r8, rbx                 # line start
delete_line_start_loop:
    test r8, r8
    je delete_line_start_done
    cmp byte ptr [r14 + r8 - 1], 10
    je delete_line_start_done
    dec r8
    jmp delete_line_start_loop
delete_line_start_done:
    mov r9, rbx                 # one past line end
delete_line_end_loop:
    cmp r9, [buf_len]
    jae delete_line_end_done
    cmp byte ptr [r14 + r9], 10
    je delete_line_include_newline
    inc r9
    jmp delete_line_end_loop
delete_line_include_newline:
    inc r9
delete_line_end_done:
    mov r10, r9
    sub r10, r8                 # bytes to remove
    mov r11, r8                 # destination
    mov r12, r9                 # source
delete_line_shift_loop:
    cmp r12, [buf_len]
    jae delete_line_shift_done
    mov al, byte ptr [r14 + r12]
    mov byte ptr [r14 + r11], al
    inc r11
    inc r12
    jmp delete_line_shift_loop
delete_line_shift_done:
    sub qword ptr [buf_len], r10
    mov [cursor], r8
    mov rax, [buf_len]
    cmp qword ptr [cursor], rax
    jbe delete_line_mark
    mov [cursor], rax
delete_line_mark:
    mov qword ptr [dirty], 1
delete_line_done:
    ret

# Insert mode: printable bytes are inserted, Enter inserts LF, backspace
# deletes the previous byte, and Esc either handles an arrow key or leaves mode.
handle_insert:
    cmp al, 27
    je insert_escape
    cmp al, 127
    je insert_backspace
    cmp al, 8
    je insert_backspace
    cmp al, 13
    je insert_newline
    cmp al, 10
    je insert_newline
    cmp al, 32
    jb insert_done
    call insert_byte
insert_done:
    ret

insert_escape:
    call read_escape_arrow
    cmp rax, 1
    je insert_done
    jmp leave_insert

leave_insert:
    mov qword ptr [mode], 0
    ret

# Parse a simple terminal arrow-key sequence after Esc. Returns rax=1 when an
# arrow was consumed and handled; otherwise returns rax=0. Non-arrow bytes are
# pushed back so the main loop can handle them as normal commands.
read_escape_arrow:
    call check_input_available
    cmp qword ptr [bytes_avail], 2
    jb escape_not_arrow
    call read_key
    cmp rax, 1
    jne escape_not_arrow
    movzx eax, byte ptr [keybuf]
    cmp al, '['
    je escape_read_final
    cmp al, 'O'
    je escape_read_final
    mov byte ptr [pending_key], al
    mov qword ptr [pending_valid], 1
    jmp escape_not_arrow
escape_read_final:
    call read_key
    cmp rax, 1
    jne escape_not_arrow
    movzx eax, byte ptr [keybuf]
    cmp al, 'A'
    je escape_up
    cmp al, 'B'
    je escape_down
    cmp al, 'C'
    je escape_right
    cmp al, 'D'
    je escape_left
    mov byte ptr [pending_key], al
    mov qword ptr [pending_valid], 1
    jmp escape_not_arrow
escape_up:
    call move_up_counted
    mov rax, 1
    ret
escape_down:
    call move_down_counted
    mov rax, 1
    ret
escape_right:
    call move_right_counted
    mov rax, 1
    ret
escape_left:
    call move_left_counted
    mov rax, 1
    ret
escape_not_arrow:
    xor rax, rax
    ret

# Store LF in the file buffer. Screen rendering later expands it to CRLF.
insert_newline:
    mov al, 10
    call insert_byte
    ret

insert_backspace:
    cmp qword ptr [cursor], 0
    je insert_done
    call save_insert_undo_once
    dec qword ptr [cursor]
    call delete_char
    ret

# Insert one byte at cursor by shifting the buffer tail right.
insert_byte:
    mov r8b, al
    mov rax, [buf_len]
    inc rax
    cmp rax, [buf_cap]
    jbe insert_byte_have_capacity
    lea rdi, [buf_ptr]
    lea rsi, [buf_cap]
    mov rdx, rax
    call ensure_dynamic_buffer
    test rax, rax
    jne insert_byte_done
    mov r14, [buf_ptr]
insert_byte_have_capacity:
    call save_edit_undo
    mov rax, [buf_len]
    mov rbx, rax
insert_shift:
    cmp rbx, [cursor]
    jbe insert_store
    mov cl, byte ptr [r14 + rbx - 1]
    mov byte ptr [r14 + rbx], cl
    dec rbx
    jmp insert_shift
insert_store:
    mov rbx, [cursor]
    mov byte ptr [r14 + rbx], r8b
    inc qword ptr [buf_len]
    inc qword ptr [cursor]
    mov qword ptr [dirty], 1
insert_byte_done:
    ret

# Command-line mode after ':'. Accepted commands are w, q, q!, and wq.
handle_command:
    cmp al, 27
    je cancel_command
    cmp al, 127
    je command_backspace
    cmp al, 8
    je command_backspace
    cmp al, 13
    je run_command
    cmp al, 10
    je run_command
    cmp al, 32
    jb command_done
    mov rbx, [cmdlen]
    cmp rbx, CMD_CAP - 1
    jae command_done
    mov byte ptr [cmdbuf + rbx], al
    inc qword ptr [cmdlen]
command_done:
    ret

handle_search:
    cmp al, 27
    je cancel_command
    cmp al, 127
    je command_backspace
    cmp al, 8
    je command_backspace
    cmp al, 13
    je run_search_command
    cmp al, 10
    je run_search_command
    cmp al, 32
    jb command_done
    mov rbx, [cmdlen]
    cmp rbx, SEARCH_CAP - 1
    jae command_done
    mov byte ptr [cmdbuf + rbx], al
    inc qword ptr [cmdlen]
    ret

cancel_command:
    mov qword ptr [mode], 0
    ret

command_backspace:
    cmp qword ptr [cmdlen], 0
    je command_done
    dec qword ptr [cmdlen]
    ret

run_search_command:
    mov qword ptr [mode], 0
    cmp qword ptr [cmdlen], 0
    je repeat_search_forward
    xor rbx, rbx
copy_search_loop:
    cmp rbx, [cmdlen]
    jae copy_search_done
    cmp rbx, SEARCH_CAP - 1
    jae copy_search_done
    mov al, byte ptr [cmdbuf + rbx]
    mov byte ptr [search_buf + rbx], al
    inc rbx
    jmp copy_search_loop
copy_search_done:
    mov [search_len], rbx
    jmp repeat_search_forward

repeat_search_forward:
    cmp qword ptr [search_len], 0
    je search_ret
    mov rax, [cursor]
    cmp rax, [buf_len]
    jae search_forward_from_zero
    inc rax
    cmp rax, [buf_len]
    jb search_forward_have_start
search_forward_from_zero:
    xor rax, rax
search_forward_have_start:
    mov r8, rax
    call search_forward_from
    cmp rax, -1
    jne search_set_cursor
    xor r8, r8
    call search_forward_from
    cmp rax, -1
    jne search_set_cursor
    ret

repeat_search_backward:
    cmp qword ptr [search_len], 0
    je search_ret
    mov r8, [cursor]
    call search_backward_from
    cmp rax, -1
    jne search_set_cursor
    mov r8, [buf_len]
    call search_backward_from
    cmp rax, -1
    jne search_set_cursor
    ret

search_set_cursor:
    mov [cursor], rax
search_ret:
    ret

search_forward_from:
    mov rbx, r8
search_forward_pos:
    cmp rbx, [buf_len]
    jae search_not_found
    mov rcx, 0
search_forward_match:
    cmp rcx, [search_len]
    jae search_found
    mov rax, rbx
    add rax, rcx
    cmp rax, [buf_len]
    jae search_not_found
    mov al, byte ptr [r14 + rax]
    cmp al, byte ptr [search_buf + rcx]
    jne search_forward_next
    inc rcx
    jmp search_forward_match
search_forward_next:
    inc rbx
    jmp search_forward_pos

search_backward_from:
    cmp qword ptr [buf_len], 0
    je search_not_found
    mov rbx, r8
    test rbx, rbx
    je search_not_found
    dec rbx
search_backward_pos:
    mov rcx, 0
search_backward_match:
    cmp rcx, [search_len]
    jae search_found
    mov rax, rbx
    add rax, rcx
    cmp rax, [buf_len]
    jae search_backward_prev
    mov al, byte ptr [r14 + rax]
    cmp al, byte ptr [search_buf + rcx]
    jne search_backward_prev
    inc rcx
    jmp search_backward_match
search_backward_prev:
    test rbx, rbx
    je search_not_found
    dec rbx
    jmp search_backward_pos

search_found:
    mov rax, rbx
    ret
search_not_found:
    mov rax, -1
    ret

# Interpret the command buffer.
run_command:
    mov qword ptr [mode], 0
    mov rax, [cmdlen]
    cmp rax, 0
    je command_done_ret
    cmp byte ptr [cmdbuf], 's'
    je run_substitute_command
    cmp byte ptr [cmdbuf], '%'
    je run_substitute_command
    cmp byte ptr [cmdbuf], 'w'
    je command_maybe_write
    cmp rax, 1
    je maybe_q
    cmp rax, 2
    je maybe_wq
    ret
maybe_q:
    cmp byte ptr [cmdbuf], 'q'
    je command_quit
    ret
command_maybe_write:
    cmp rax, 1
    je command_write
    cmp byte ptr [cmdbuf + 1], 'q'
    je maybe_wq
    cmp byte ptr [cmdbuf + 1], ' '
    je command_write_named
    ret
maybe_wq:
    cmp byte ptr [cmdbuf], 'w'
    jne maybe_qbang
    cmp byte ptr [cmdbuf + 1], 'q'
    jne command_done_ret
    call save_file
    cmp rax, 0
    jne command_done_ret
    mov qword ptr [running], 0
command_done_ret:
    ret

# Parse and execute a small, literal subset of vi's substitute command:
#   :s/old/new/       first match on the current line
#   :s/old/new/g      all matches on the current line
#   :%s/old/new/g     all matches in the buffer
# Regexes and flags other than g are intentionally left for a later phase.
run_substitute_command:
    mov qword ptr [substitute_global], 0
    mov qword ptr [substitute_all], 0
    xor rbx, rbx
    cmp byte ptr [cmdbuf], '%'
    jne substitute_prefix_s
    cmp byte ptr [cmdbuf + 1], 's'
    jne substitute_syntax_error
    mov qword ptr [substitute_global], 1
    mov rbx, 1
substitute_prefix_s:
    cmp byte ptr [cmdbuf + rbx], 's'
    jne substitute_syntax_error
    inc rbx
    cmp rbx, [cmdlen]
    jae substitute_syntax_error
    mov r15b, byte ptr [cmdbuf + rbx]
    inc rbx
    xor rcx, rcx
substitute_parse_old:
    cmp rbx, [cmdlen]
    jae substitute_syntax_error
    cmp rcx, SEARCH_CAP - 1
    jae substitute_syntax_error
    mov al, byte ptr [cmdbuf + rbx]
    cmp al, r15b
    je substitute_old_done
    mov byte ptr [search_buf + rcx], al
    inc rcx
    inc rbx
    jmp substitute_parse_old
substitute_old_done:
    mov [search_len], rcx
    test rcx, rcx
    je substitute_syntax_error
    mov byte ptr [search_buf + rcx], 0
    inc rbx
    xor rcx, rcx
substitute_parse_new:
    cmp rbx, [cmdlen]
    jae substitute_new_done
    cmp rcx, SEARCH_CAP - 1
    jae substitute_syntax_error
    mov al, byte ptr [cmdbuf + rbx]
    cmp al, r15b
    je substitute_new_delimited
    mov byte ptr [replace_buf + rcx], al
    inc rcx
    inc rbx
    jmp substitute_parse_new
substitute_new_delimited:
    inc rbx
substitute_new_done:
    mov [replace_len], rcx
    mov byte ptr [replace_buf + rcx], 0
    cmp rbx, [cmdlen]
    jae substitute_execute
    cmp byte ptr [cmdbuf + rbx], 'g'
    jne substitute_syntax_error
    mov qword ptr [substitute_all], 1
    inc rbx
    cmp rbx, [cmdlen]
    jne substitute_syntax_error
substitute_execute:
    call substitute_set_range
    call save_undo
    mov r8, [substitute_start]
    mov r9, [substitute_end]
    call substitute_matches
    mov qword ptr [mode], 0
    ret
substitute_syntax_error:
    mov rsi, offset msg_substitute_error
    mov rdx, msg_substitute_error_len
    call write_stdout
    call read_key
    ret

# Return the replacement range as [r8, r9). The whole buffer is used for %s;
# otherwise the range is the current logical line without its newline.
substitute_set_range:
    cmp qword ptr [substitute_global], 0
    je substitute_current_line
    xor r8, r8
    mov r9, [buf_len]
    mov [substitute_start], r8
    mov [substitute_end], r9
    ret
substitute_current_line:
    mov r8, [cursor]
substitute_line_start:
    test r8, r8
    je substitute_line_end
    cmp byte ptr [r14 + r8 - 1], 10
    je substitute_line_end
    dec r8
    jmp substitute_line_start
substitute_line_end:
    mov r9, [cursor]
substitute_line_end_loop:
    cmp r9, [buf_len]
    jae substitute_range_done
    cmp byte ptr [r14 + r9], 10
    je substitute_range_done
    inc r9
    jmp substitute_line_end_loop
substitute_range_done:
    mov [substitute_start], r8
    mov [substitute_end], r9
    ret

# Replace literal matches in the range. The tail is shifted in-place, and the
# range end is adjusted after every replacement so global replacement remains
# correct when old and new strings have different lengths.
substitute_matches:
    mov r10, [search_len]
    mov r11, [replace_len]
    mov rbx, r8
substitute_find:
    mov rax, rbx
    add rax, r10
    cmp rax, r9
    ja substitute_done
    xor rcx, rcx
substitute_compare:
    cmp rcx, r10
    jae substitute_match
    mov rax, rbx
    add rax, rcx
    mov al, byte ptr [r14 + rax]
    cmp al, byte ptr [search_buf + rcx]
    jne substitute_next
    inc rcx
    jmp substitute_compare
substitute_match:
    call substitute_replace_at
    cmp qword ptr [substitute_all], 0
    je substitute_done
    jmp substitute_find
substitute_next:
    inc rbx
    jmp substitute_find
substitute_done:
    ret

# Replace search_len bytes at rbx with replace_len bytes.
substitute_replace_at:
    mov r10, [search_len]
    mov r11, [replace_len]
    mov r12, r11
    sub r12, r10
    cmp r12, 0
    jle substitute_shrink_or_equal
    mov rax, [buf_len]
    add rax, r12
    lea rdi, [buf_ptr]
    lea rsi, [buf_cap]
    mov rdx, rax
    call ensure_dynamic_buffer
    test rax, rax
    jne substitute_done
    mov r14, [buf_ptr]
    mov rax, [buf_len]
    mov rcx, rbx
    add rcx, r10
    mov rdx, rax
    add rdx, r12
substitute_grow_tail:
    cmp rax, rcx
    jbe substitute_copy_new
    dec rax
    dec rdx
    mov r8b, byte ptr [r14 + rax]
    mov byte ptr [r14 + rdx], r8b
    jmp substitute_grow_tail
substitute_shrink_or_equal:
    je substitute_copy_new
    mov rax, rbx
    add rax, r10
    mov rcx, rax
    mov rdx, rbx
substitute_shrink_tail:
    cmp rcx, [buf_len]
    jae substitute_shrink_done
    mov r8b, byte ptr [r14 + rcx]
    mov byte ptr [r14 + rdx], r8b
    inc rcx
    inc rdx
    jmp substitute_shrink_tail
substitute_shrink_done:
substitute_copy_new:
    xor rcx, rcx
substitute_copy_new_loop:
    cmp rcx, r11
    jae substitute_update_lengths
    mov r8b, byte ptr [replace_buf + rcx]
    mov rax, rbx
    add rax, rcx
    mov byte ptr [r14 + rax], r8b
    inc rcx
    jmp substitute_copy_new_loop
substitute_update_lengths:
    add qword ptr [buf_len], r12
    add r9, r12
    add rbx, r11
    mov qword ptr [dirty], 1
    ret
maybe_qbang:
    cmp byte ptr [cmdbuf], 'q'
    jne command_done_ret
    cmp byte ptr [cmdbuf + 1], '!'
    jne command_done_ret
    mov qword ptr [running], 0
    ret
command_write:
    call save_file
    ret
command_write_named:
    call copy_command_filename
    cmp rax, 0
    je command_write_named_save
    cmp rax, 2
    jne command_done_ret
    mov rsi, offset msg_filename_error
    mov rdx, msg_filename_error_len
    call write_stdout
    call read_key
    ret
command_write_named_save:
    call save_file
    ret
command_quit:
    cmp qword ptr [dirty], 0
    je quit_clean
    mov rsi, offset msg_unsaved
    mov rdx, msg_unsaved_len
    call write_stdout
    call read_key
    ret
quit_clean:
    mov qword ptr [running], 0
    ret

# Copy the filename argument from :w <file> into file_name.
copy_command_filename:
    mov rbx, 2
skip_write_name_spaces:
    cmp rbx, [cmdlen]
    jae copy_command_no_name
    cmp byte ptr [cmdbuf + rbx], ' '
    jne copy_command_name_start
    inc rbx
    jmp skip_write_name_spaces
copy_command_name_start:
    xor rcx, rcx
copy_command_name_loop:
    cmp rbx, [cmdlen]
    jae copy_command_name_done
    cmp rcx, NAME_CAP - 1
    jb copy_command_name_byte
    mov rax, 2
    ret
copy_command_name_byte:
    mov al, byte ptr [cmdbuf + rbx]
    mov byte ptr [file_name + rcx], al
    inc rbx
    inc rcx
    jmp copy_command_name_loop
copy_command_name_done:
    test rcx, rcx
    je copy_command_no_name
    mov byte ptr [file_name + rcx], 0
    mov [file_name_len], rcx
    xor rax, rax
    ret
copy_command_no_name:
    mov rax, 1
    ret

# Write the whole buffer to a temporary file, fsync it, and atomically replace
# the current file. write(2) is allowed to complete partially, so keep going
# until every byte has been written.
save_file:
    cmp qword ptr [file_name_len], 0
    jne save_have_name
    mov rsi, offset msg_no_name
    mov rdx, msg_no_name_len
    call write_stdout
    call read_key
    mov rax, 1
    ret
save_have_name:
    call copy_temp_filename
    test rax, rax
    jne save_failed
    mov rax, SYS_STAT
    mov rdi, offset file_name
    mov rsi, offset stat_buf
    syscall
    test rax, rax
    js save_default_mode
    movzx eax, word ptr [stat_buf + 24]
    and eax, 07777
    mov [temp_mode], rax
    jmp save_open_temp
save_default_mode:
    mov qword ptr [temp_mode], 0644
save_open_temp:
    mov rax, SYS_OPEN
    mov rdi, offset temp_name
    mov rsi, O_WRONLY | O_CREAT | O_TRUNC | O_EXCL
    mov rdx, [temp_mode]
    syscall
    test rax, rax
    js save_failed
    mov r12, rax
    mov rax, SYS_FCHMOD
    mov rdi, r12
    mov rsi, [temp_mode]
    syscall
    test rax, rax
    js save_write_failed
    xor r13, r13
save_write_loop:
    cmp r13, [buf_len]
    jae save_write_done
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [r14 + r13]
    mov rdx, [buf_len]
    sub rdx, r13
    syscall
    cmp rax, -ERRNO_EINTR
    je save_write_loop
    cmp rax, 0
    jle save_write_failed
    add r13, rax
    jmp save_write_loop
save_write_done:
save_fsync:
    mov rax, SYS_FSYNC
    mov rdi, r12
    syscall
    cmp rax, -ERRNO_EINTR
    je save_fsync
    test rax, rax
    js save_write_failed
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall
    test rax, rax
    js save_unlink_failed
    mov rax, SYS_RENAME
    mov rdi, offset temp_name
    mov rsi, offset file_name
    syscall
    test rax, rax
    js save_unlink_failed
    mov qword ptr [dirty], 0
    xor rax, rax
    ret
save_write_failed:
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall
save_unlink_failed:
    mov rax, SYS_UNLINK
    mov rdi, offset temp_name
    syscall
    jmp save_failed
save_failed:
    mov rsi, offset msg_write_error
    mov rdx, msg_write_error_len
    call write_stdout
    call read_key
    mov rax, 1
    ret

# Build a temporary path next to the target file for atomic replacement.
copy_temp_filename:
    mov rax, [file_name_len]
    add rax, temp_suffix_len + 8
    cmp rax, NAME_CAP - 1
    ja copy_temp_filename_fail
    xor rcx, rcx
copy_temp_name_loop:
    cmp rcx, [file_name_len]
    jae copy_temp_suffix
    mov al, byte ptr [file_name + rcx]
    mov byte ptr [temp_name + rcx], al
    inc rcx
    jmp copy_temp_name_loop
copy_temp_suffix:
    xor rbx, rbx
copy_temp_suffix_loop:
    cmp rbx, temp_suffix_len
    jae copy_temp_pid
    mov al, byte ptr [temp_suffix + rbx]
    mov byte ptr [temp_name + rcx], al
    inc rcx
    inc rbx
    jmp copy_temp_suffix_loop
copy_temp_pid:
    push rcx
    mov rax, SYS_GETPID
    syscall
    pop rcx
    mov rbx, 8
    lea rdi, [temp_name + rcx + 8]
copy_temp_pid_loop:
    mov rdx, rax
    and edx, 15
    mov dl, byte ptr [hex_digits + rdx]
    dec rdi
    mov byte ptr [rdi], dl
    shr rax, 4
    dec rbx
    jnz copy_temp_pid_loop
    add rcx, 8
copy_temp_filename_done:
    mov byte ptr [temp_name + rcx], 0
    mov [temp_name_len], rcx
    xor rax, rax
    ret
copy_temp_filename_fail:
    mov rax, 1
    ret

# Redraw the whole screen on every key. This is simple but wasteful; acceptable
# for the editor's small flat-buffer model.
redraw:
    call compute_total_lines
    call update_window_size
    call ensure_cursor_visible

    mov rsi, offset hide_cursor
    mov rdx, hide_cursor_len
    call write_stdout
    mov rsi, offset clear_screen
    mov rdx, clear_screen_len
    call write_stdout

    call write_buffer_view
    call move_to_status_row

    cmp qword ptr [mode], 1
    je draw_insert_status
    cmp qword ptr [mode], 2
    je draw_command_status
    cmp qword ptr [mode], 3
    je draw_search_status
    mov rsi, offset status_normal
    mov rdx, status_normal_len
    call write_stdout
    jmp draw_status_file
draw_insert_status:
    mov rsi, offset status_insert
    mov rdx, status_insert_len
    call write_stdout
    jmp draw_status_file
draw_command_status:
    mov rsi, offset status_cmd
    mov rdx, status_cmd_len
    call write_stdout
    mov rsi, offset cmdbuf
    mov rdx, [cmdlen]
    call write_stdout
    jmp finish_status_line
draw_search_status:
    mov rsi, offset status_search
    mov rdx, status_search_len
    call write_stdout
    mov rsi, offset cmdbuf
    mov rdx, [cmdlen]
    call write_stdout
    jmp finish_status_line

draw_status_file:
    cmp qword ptr [file_name_len], 0
    je draw_status_no_name
    mov rsi, offset file_name
    mov rdx, [file_name_len]
    call write_stdout
    jmp draw_status_dirty
draw_status_no_name:
    mov rsi, offset status_no_name
    mov rdx, status_no_name_len
    call write_stdout
draw_status_dirty:
    cmp qword ptr [dirty], 0
    je draw_clean
    mov rsi, offset status_dirty
    mov rdx, status_dirty_len
    call write_stdout
    jmp finish_status_line
draw_clean:
    mov rsi, offset status_clean
    mov rdx, status_clean_len
    call write_stdout

finish_status_line:
    cmp qword ptr [mode], 2
    je finish_status_no_pos
    cmp qword ptr [mode], 3
    je finish_status_no_pos
    call draw_cursor_status
finish_status_no_pos:
    mov rsi, offset status_end
    mov rdx, status_end_len
    call write_stdout
    call place_cursor
    mov rsi, offset show_cursor
    mov rdx, show_cursor_len
    call write_stdout
    ret

# Count logical lines for the status display. Empty buffers still report one
# editable line.
compute_total_lines:
    mov qword ptr [total_lines], 1
    xor rbx, rbx
count_lines_loop:
    cmp rbx, [buf_len]
    jae count_lines_done
    cmp byte ptr [r14 + rbx], 10
    jne count_lines_next
    inc qword ptr [total_lines]
count_lines_next:
    inc rbx
    jmp count_lines_loop
count_lines_done:
    ret

# Append "Ln current/total Col current" to the status line.
draw_cursor_status:
    mov rsi, offset status_pos_prefix
    mov rdx, status_pos_prefix_len
    call write_stdout
    mov rax, [cursor_line]
    inc rax
    call write_decimal
    mov rsi, offset status_pos_sep
    mov rdx, 1
    call write_stdout
    mov rax, [total_lines]
    call write_decimal
    mov rsi, offset status_col_prefix
    mov rdx, status_col_prefix_len
    call write_stdout
    mov rax, [cursor_col]
    inc rax
    call write_decimal
    ret

# Read the terminal window size. If ioctl fails or reports zero rows/cols,
# keep the conservative defaults from .data.
update_window_size:
    mov rax, SYS_IOCTL
    mov rdi, 1
    mov rsi, TIOCGWINSZ
    mov rdx, offset winsize
    syscall
    test rax, rax
    js update_window_done

    movzx rax, word ptr [winsize]
    test rax, rax
    je update_cols
    mov [screen_rows], rax
update_cols:
    movzx rax, word ptr [winsize + 2]
    test rax, rax
    je update_visible
    mov [screen_cols], rax
update_visible:
    mov rax, [screen_rows]
    cmp rax, 2
    jae update_visible_sub
    mov rax, 2
    mov [screen_rows], rax
update_visible_sub:
    dec rax
    mov [visible_rows], rax
update_window_done:
    ret

# Compute zero-based logical line and column for the byte cursor.
compute_cursor_pos:
    xor r8, r8                  # line
    xor r9, r9                  # column
    xor rcx, rcx
    mov rbx, [cursor]
cursor_pos_loop:
    cmp rcx, rbx
    jae cursor_pos_done
    cmp byte ptr [r14 + rcx], 10
    je cursor_pos_newline
    inc r9
    inc rcx
    jmp cursor_pos_loop
cursor_pos_newline:
    inc r8
    xor r9, r9
    inc rcx
    jmp cursor_pos_loop
cursor_pos_done:
    mov [cursor_line], r8
    mov [cursor_col], r9
    ret

# Keep the cursor inside the visible line window by adjusting top_line.
ensure_cursor_visible:
    call compute_cursor_pos
    mov rax, [cursor_line]
    cmp rax, [top_line]
    jae ensure_not_above
    mov [top_line], rax
    ret
ensure_not_above:
    mov rbx, [top_line]
    add rbx, [visible_rows]
    cmp rax, rbx
    jb ensure_done
    sub rax, [visible_rows]
    inc rax
    mov [top_line], rax
ensure_done:
    ret

# Return in rax the byte offset for zero-based line number rax.
find_line_offset:
    mov r8, rax
    xor rax, rax
    test r8, r8
    je find_line_done
find_line_loop:
    cmp rax, [buf_len]
    jae find_line_done
    cmp byte ptr [r14 + rax], 10
    je find_line_newline
    inc rax
    jmp find_line_loop
find_line_newline:
    inc rax
    dec r8
    test r8, r8
    jne find_line_loop
find_line_done:
    ret

# Render only the visible viewport. Files store LF, but raw terminal mode has
# output processing disabled, so LF must be displayed as CRLF.
write_buffer_view:
    mov rax, [top_line]
    call find_line_offset
    mov rbx, rax                # current byte offset
    xor r13, r13                # rendered lines
    mov r15, [visible_rows]
    mov r12, rbx                # start of pending byte span
screen_loop:
    cmp r13, r15
    jae screen_flush_tail
    cmp rbx, [buf_len]
    jae screen_flush_tail
    cmp byte ptr [r14 + rbx], 10
    je screen_newline
    inc rbx
    jmp screen_loop
screen_newline:
    mov rsi, r14
    add rsi, r12
    mov rdx, rbx
    sub rdx, r12
    call write_stdout
    mov rsi, offset status_newline
    mov rdx, status_newline_len
    call write_stdout
    inc r13
    inc rbx
    mov r12, rbx
    jmp screen_loop
screen_flush_tail:
    mov rsi, r14
    add rsi, r12
    mov rdx, rbx
    sub rdx, r12
    call write_stdout
    test rdx, rdx
    je screen_tilde_loop
    inc r13
screen_tilde_loop:
    cmp r13, r15
    jae screen_done
    mov rsi, offset tilde_line
    mov rdx, tilde_line_len
    call write_stdout
    inc r13
    jmp screen_tilde_loop
screen_done:
    ret

# Move the terminal cursor to the left edge of the status row.
move_to_status_row:
    mov rsi, offset seq_cursor_prefix
    mov rdx, seq_cursor_prefix_len
    call write_stdout
    mov rax, [screen_rows]
    call write_decimal
    mov rsi, offset seq_cursor_sep
    mov rdx, 1
    call write_stdout
    mov rax, 1
    call write_decimal
    mov rsi, offset seq_cursor_suffix
    mov rdx, 1
    call write_stdout
    ret

# Convert the byte cursor offset to a 1-based terminal row/column and emit an
# ANSI cursor-position sequence.
place_cursor:
    mov rsi, offset seq_cursor_prefix
    mov rdx, seq_cursor_prefix_len
    call write_stdout
    mov rax, [cursor_line]
    sub rax, [top_line]
    inc rax
    call write_decimal
    mov rsi, offset seq_cursor_sep
    mov rdx, 1
    call write_stdout
    mov rax, [cursor_col]
    inc rax
    call write_decimal
    mov rsi, offset seq_cursor_suffix
    mov rdx, 1
    call write_stdout
    ret

# Write unsigned decimal rax to stdout. Used for cursor-position numbers.
write_decimal:
    mov rbx, 10
    lea rsi, [num_buf + 31]
    xor rcx, rcx
    cmp rax, 0
    jne dec_loop
    dec rsi
    mov byte ptr [rsi], '0'
    mov rdx, 1
    call write_stdout
    ret
dec_loop:
    xor rdx, rdx
    div rbx
    add dl, '0'
    dec rsi
    mov byte ptr [rsi], dl
    inc rcx
    test rax, rax
    jne dec_loop
    mov rdx, rcx
    call write_stdout
    ret

# Thin wrapper around write(1, rsi, rdx). Calls with zero length are ignored.
write_stdout:
    test rdx, rdx
    je write_done
    push rbx
    push r12
    mov rbx, rsi
    mov r12, rdx
write_stdout_loop:
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, rbx
    mov rdx, r12
    syscall
    cmp rax, -ERRNO_EINTR
    je write_stdout_loop
    test rax, rax
    jle write_stdout_done
    add rbx, rax
    sub r12, rax
    jnz write_stdout_loop
write_stdout_done:
    test rax, rax
    jge write_stdout_ok
    mov qword ptr [io_error], 1
write_stdout_ok:
    pop r12
    pop rbx
write_done:
    ret
