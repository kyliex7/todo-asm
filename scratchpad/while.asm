format ELF64 executable

entry _start
_start:
	mov		r15, 0
.while:
	mov		rax, 1
	mov		rdi, 1
	mov		rsi, hello
	mov		rdx, hello_len
	syscall
	inc		r15
	cmp		r15, 10
	jl		.while
	jmp		.endwhile
.endwhile:
	mov		rax, 60
	mov		rdi, 0
	syscall

hello: db "i can literary put what the fuck i want here", 0x0d, 0x0a
hello_len = $ - hello
