```
todo-fasm/
├── todo.asm          # Main source
├── macros.inc        # Reusable syscall macros
└── build.sh          # Single-step build: fasm todo.asm todo
```
## 🔑 FASM vs NASM — Syntax Diff (since you know Intel)

| Concept          | NASM                          | FASM                            | Why it differs                             |
|------------------|-------------------------------|---------------------------------|--------------------------------------------|
| Format header    | none (CLI flag `-f elf64`)    | `format ELF64 executable 3`     | FASM embeds format in source, not the CLI  |
| Entry point      | `global _start` + `_start:`   | `entry start` + `start:`        | `entry` is a FASM directive, not a label   |
| Sections         | `section .text`               | `segment readable executable`   | FASM declares page *permissions* directly  |
| Uninit memory    | `resb N`                      | `rb N`                          | FASM shorthand: `rb`, `rw`, `rd`, `rq`     |
| Compile constant | `equ`                         | `=`                             | `=` creates a numeric equate, not a label  |
| Macros           | `%macro name N` / `%endmacro` | `macro name args { }`           | FASM uses brace-delimited C-like syntax    |
| String length    | `$ - label`                   | `$ - label`                     | Identical — `$` = current address in both  |

## 🧱 Phase 1 — FASM Fundamentals

### 1.1 Minimal ELF64 Binary
- [ ] Write the required FASM header:
  ```fasm
  format ELF64 executable 3
  entry start

  segment readable executable
  start:
      ; code here
  ```
- [ ] Why `executable 3`? The `3` sets the OS/ABI byte in the ELF header to Linux. FASM lets you control this directly; NASM offloads it to `ld`.

### 1.2 Hello World via Raw Syscall
- [ ] Define data with FASM's segment syntax:
  ```fasm
  segment readable writeable
      msg    db "hello", 0xA
      msg_len = $ - msg
  ```
- [ ] Why `=` instead of a label? `=` is a **compile-time numeric constant** — it has no address, can't be referenced as memory, just gets substituted during assembly. Understand this or you'll get cryptic FASM errors.

### 1.3 Build a Syscall Macro
- [ ] In `macros.inc`:
  ```fasm
  macro sys_write fd, buf, len {
      mov rax, 1
      mov rdi, fd
      mov rsi, buf
      mov rdx, len
      syscall
  }

  macro sys_exit code {
      mov rax, 60
      mov rdi, code
      syscall
  }
  ```
- [ ] Why macros? They expand at **assemble time**, zero runtime cost. The call site reads like pseudocode but produces tight inline code. For red teaming: macro-generated shellcode stubs are a real technique.
- [ ] Include in main file: `include 'macros.inc'`

---

## 🗃️ Phase 2 — Memory Layout

> **Why does FASM's segment model matter?**
> Unlike NASM's `.text`/`.data`/`.bss` names, FASM's `segment readable executable` maps directly
> to ELF program header permissions (R, W, X). This is exactly what the OS uses to set page
> protections — the same model you reason about in ROP chains and shellcode injection.

### 2.1 Declare Segments Correctly
- [ ] `segment readable executable` — all code
- [ ] `segment readable writeable` — all data (init + uninit together)
- [ ] Use `rb N` for uninitialized: it **reserves bytes without emitting them** to the file — why: keeps binary size small, analogous to `.bss` but FASM just calls it reserved space

### 2.2 Todo Entry Layout
```fasm
ENTRY_SIZE  = 65       ; compile-time: status byte + 64 chars
MAX_ENTRIES = 16

segment readable writeable
    todo_list  rb ENTRY_SIZE * MAX_ENTRIES
    todo_count rb 1
```
- [ ] Why `ENTRY_SIZE` as a compile-time constant? You'll use it in `imul rax, ENTRY_SIZE` — FASM substitutes the literal at assembly time, same as `#define` in C but with no preprocessor needed.

---

## 📋 Phase 3 — Core Features

### 3.1 Print Menu
- [ ] Define menu string in data segment
- [ ] `sys_write 1, menu, menu_len` — notice how the macro call reads vs raw register setup

### 3.2 Read Input & Dispatch
- [ ] `sys_read` macro into a 2-byte buffer
- [ ] `cmp byte [input_buf], '1'` → `je add_task`
- [ ] Why `byte` specifier? FASM is strict about operand sizes — omitting it is an error, not a warning. Good discipline.

### 3.3 Add Task
- [ ] Bounds check: `cmp byte [todo_count], MAX_ENTRIES`
- [ ] Compute offset: `movzx rax, byte [todo_count]` / `imul rax, ENTRY_SIZE`
- [ ] Why `imul` not `mul`? `imul reg, reg/imm` form doesn't clobber `rdx` — `mul` always writes `rdx:rax`. Avoid surprise register corruption.
- [ ] Copy input to `todo_list + rax + 1`

### 3.4 List Tasks
- [ ] Loop with counter, use `jecxz` to skip if count is zero — why: single-instruction zero-check, tighter than `cmp ecx, 0` + `jz`
- [ ] Walk entries with pointer arithmetic: `add rsi, ENTRY_SIZE` each iteration

### 3.5 Mark Complete & Delete
- [ ] Optional: use FASM `struc` for named field access:
  ```fasm
  struc TodoEntry {
      .status db ?
      .text   rb 64
  }
  ```
- [ ] Why `struc`? It's a macro that computes field offsets by name — zero runtime overhead, just assembler arithmetic. Lets you write `[rsi + TodoEntry.status]` instead of magic numbers.

---

## 🔁 Phase 4 — Main Loop

- [ ] `main_loop:` → print menu → read input → dispatch → `jmp main_loop`
- [ ] Quit: `sys_exit 0`
- [ ] Why `xor rdi, rdi` instead of `mov rdi, 0`? 2-byte opcode vs 7-byte. Smaller code, builds shellcode-size awareness.

---

## 🐛 Phase 5 — Debugging

- [ ] Build: `fasm todo.asm todo` — errors show line numbers with clear messages
- [ ] `gdb ./todo` → `starti` — breaks at first instruction before any setup
- [ ] `info proc mappings` — verify your segment permissions match what you declared
- [ ] `x/65xb &todo_list` — dump entry memory after adding a task, confirm struct layout

---

## 🏗️ Build Script

```bash
#!/bin/bash
# build.sh — Why not Makefile? FASM is a one-step build, no separate link phase.
fasm todo.asm todo && chmod +x todo && echo "[+] OK" || echo "[-] Failed"
```

---

## 🔐 Bonus — FASM-Specific Explorations

- [ ] **`display` directive**: `display 'ENTRY_SIZE = ', `ENTRY_SIZE, 10` — FASM can print messages *during assembly*. Why: verify your compile-time constants are what you think before running anything.
- [ ] **Flat binary output**: change header to `format binary` — same code, no ELF wrapper. Why: this is how raw shellcode is produced. Assemble a working syscall, dump it, inspect the raw bytes.
- [ ] **Macro with variadic args**: FASM supports `macro name [args]` for variadic macros — explore building a generic `syscall_n` macro
- [ ] **Intentional overflow**: remove the `MAX_ENTRIES` bounds check, overflow `todo_list` into `todo_count`, watch gdb show the corruption. Why: understanding what unguarded writes actually do in memory is more valuable than reading about it.

---

## 📚 Syscall Reference

| Syscall   | `rax` | `rdi`  | `rsi`  | `rdx` |
|-----------|-------|--------|--------|-------|
| sys_read  | 0     | 0      | buf    | len   |
| sys_write | 1     | 1      | buf    | len   |
| sys_open  | 2     | path   | flags  | mode  |
| sys_exit  | 60    | code   | —      | —     |

---

## 🧠 FASM Concepts to Internalize

| Concept                    | Why it matters                                              |
|----------------------------|-------------------------------------------------------------|
| `format ELF64 executable`  | FASM owns the full output — not just object code            |
| `=` vs labels              | Compile-time substitution vs runtime memory address         |
| `rb/rw/rd/rq`              | Reserve without file emission — keeps binaries tight        |
| `macro { }`                | Zero-cost abstraction, assembler-time expansion only        |
| `struc`                    | Named offsets, still just arithmetic — no runtime overhead  |
| Segment permissions        | Maps directly to OS page protections (R/W/X)                |
| `display`                  | Assembler-time stdout — unique to FASM, great for debugging |
