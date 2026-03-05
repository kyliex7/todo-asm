format ELF64 executable

note: file "note.txt"
note_len = $ - note

macro exit code* {
	mov		rax, 60
	mov		rdi, code
	syscall
}

entry _start
_start:
	mov		rax, 1
	mov		rdi, 1
	mov		rsi, note
	mov		rdx, note_len
	syscall
	
	cmp		rax, 0
	je		exit_success
	jmp		exit_failure

exit_success: 
	exit	0
exit_failure:
	exit	1

