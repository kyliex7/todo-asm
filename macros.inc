macro funcall2 func, a, b
{
    mov rdi, a
    mov rsi, b
    call func
}

macro funcall3 func, a, b, c
{
    mov rdi, a
    mov rsi, b
    mov rdx, c
    call func
}

macro funcall4 func, a, b, c, d
{
    mov rdi, a
    mov rsi, b
    mov rdx, c
    mov r10, d
    call func
}

macro syscall1 number, a
{
	mov		rax, number
	mov		rdi, a
	syscall
}

macro syscall2 number, a, b
{
	mov		rax, number
	mov		rdi, a
	mov		rsi, b
	syscall
}

macro syscall3 number, a, b, c
{
	mov		rax, number
	mov		rdi, a
	mov		rsi, b
	mov		rdx, c
	syscall
}

macro syscall5 number, a, b, c, d, e
{
	mov		rax, number
	mov		rdi, a
	mov		rsi, b
	mov		rdx, c
	mov		r10, d
	mov		r11, e
	syscall
}

macro write fd, buf, count
{
	syscall3 1, fd, buf, count
}

macro read fd, buf, count
{
	syscall3 0, fd, buf, count
}

macro close fd
{
	syscall1 3, fd
}

macro open fname, flags, mode 
{
	syscall3 2, fname, flags, mode
}
