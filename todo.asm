;; DO WHAT THE FUCK YOU WANT WITH THIS
;; I BET YOU WON'T

format ELF64 executable 3
include "macros.inc"
entry _start

virtual at 0
    task_t.status   db 0
    task_t.id       db 0
    task_t.len      db 0
    task_t.desc     db 61 dup(0)
    sizeof.task_t   = $
end virtual

;; .data
segment readable writeable
MAX_task_tS equ 10
RECORD_SIZE equ sizeof.task_t

tasks_list: db 64*10 dup(0)
next_id: dq 0

dashboard: file "dashboard.txt"
dashboard_len = $ - dashboard

optmsg: db "Chose something: "
optmsg_len = $ - optmsg

print_done: db " [x] "
print_done_len = $ - print_done

print_not_done: db " [ ] "
print_not_done_len = $ - print_not_done

choice_buf: rb 1
jump_table: dq add_task, mark_task, view_task, del_task, exit

task_id: rb 2

invalid_choice_msg: db "Invalid choice", 0x0a
invalid_choice_msg_len = $ - invalid_choice_msg

enter_task_id: db "Enter task id: "
enter_task_id_len = $ - enter_task_id

enter_task_name: db "Enter task name: "
enter_task_name_len = $ - enter_task_name

;; add task
task_add_suc: db "Task added successfully", 0x0a
task_add_suc_len = $ - task_add_suc

;; mark task
task_mark_suc: db "Task marked successfully", 0x0a
task_mark_suc_len = $ - task_mark_suc

;; view task
task_view_tmp: db "You chose to view tasklist", 0x0a
task_view_tmp_len = $ - task_view_tmp

;; delete task
task_del_suc: db "Task deleted successfully", 0x0a
task_del_suc_len = $ - task_del_suc

;; dbg
; succ: db "[debug] this is expected", 0x0a
; succl = $ - succ
; tadd: db "[debug] you're about to add a task", 0x0a
; taddl = $ - tadd
; tdel: db "[debug] you're about to del a task", 0x0a
; tdell = $ - tdel
; tmod: db "[debug] you're about to modify a task", 0x0a
; tmodl = $ - tmod
; tview: db "[debug] you're about to view tasklist", 0x0a
; tviewl = $ - tview
;; .text
segment readable executable
_start:
mainloop:
	write 1, dashboard, dashboard_len
	write 1, optmsg, optmsg_len

	read 0, choice_buf, 1

	;; flush the newline from stdin
	.flush:
		sub rsp, 8
		read 0, rsp, 1
		cmp byte [rsp], 0x0a
		add rsp, 8
		je .flush

	movzx rax, byte [choice_buf]
	sub rax, '0'
	cmp rax, 4
	jbe valid_choice
	jmp invalid_choice

valid_choice:
	push rax
	pop rax
	jmp qword [jump_table + rax*8]

invalid_choice:
	write 1, invalid_choice_msg, invalid_choice_msg_len
	jmp mainloop

exit:
	jmp endroute

print_err:
	write 1, rdi, rsi
	jmp mainloop

add_task:
	movzx rax, byte [next_id]
	shl rax, 6	; rax = id * 64
	lea rbx, [tasks_list + rax] ; rbx = base + offset
	mov byte [rbx + task_t.status], 1
	mov al, [next_id]
	mov byte [rbx + task_t.id], al

	write 1, enter_task_name, enter_task_name_len
	lea rsi, [rbx + task_t.desc]
	read 0, rsi, 61
	mov [rbx + task_t.len], al

	write 1, task_add_suc, task_add_suc_len
	inc qword [next_id]
	jmp mainloop

mark_task:
	write 1, enter_task_id, enter_task_id_len
	read 0, task_id, 2
	movzx rax, byte [task_id]
	sub rax, '0'

	cmp rax, [next_id]
	jae .invalid_id

	shl rax, 6
	lea rbx, [tasks_list + rax]
	
	cmp [rbx + task_t.status], 0
	je .invalid_id ;; already deleted

	mov byte [rbx + task_t.status], 2
	write 1, task_mark_suc, task_mark_suc_len
	jmp mainloop

.invalid_id:
	write 1, invalid_choice_msg, invalid_choice_msg_len
	jmp mainloop

view_task:
	mov r8, [next_id]
	test r8, r8
	jz .done
	xor r9, r9
	lea rbx, [tasks_list]

.loop:
	mov al, byte [rbx + task_t.status]
	cmp al, 0
	je .next_iteration

	push r8
	push r9
	push rbx

	cmp al, 1
	je .print_desc
	jmp .print_done
.print_done:
	movzx rax, [rbx + task_t.id]
	
	add al, '0'
	sub rsp, 8
	mov [rsp], al
	write 1, rsp, 2
	add rsp, 8

	write 1, print_done, print_done_len; [x]
	lea rsi, [rbx + task_t.desc]
	movzx rdx, byte [rbx + task_t.len]
	write 1, rsi, rdx

	pop rbx
	pop r9
	pop r8

	jmp .next_iteration

.print_desc:
	movzx rax, [rbx + task_t.id]
	
	add al, '0'
	sub rsp, 8
	mov [rsp], al
	write 1, rsp, 2
	add rsp, 8

	write 1, print_not_done, print_not_done_len; [ ]
	lea rsi, [rbx + task_t.desc]
	movzx rdx, [rbx + task_t.len]
	write 1, rsi, rdx

	pop rbx
	pop r9
	pop r8

	jmp .next_iteration

.next_iteration:
	add rbx, sizeof.task_t
	inc r9
	cmp r9, r8
	jl .loop
.done:
	jmp mainloop

del_task:
	write 1, enter_task_id, enter_task_id_len
	read 0, task_id, 2
	movzx rax, byte [task_id]
	sub rax, '0'

	cmp rax, [next_id]
	jae .invalid_id

	shl rax, 6
	lea rbx, [tasks_list + rax]
	
	cmp [rbx + task_t.status], 0
	je .invalid_id ;; already deleted

	mov byte [rbx + task_t.status], 0
	write 1, task_del_suc, task_del_suc_len
	jmp mainloop

.invalid_id:
	write 1, invalid_choice_msg, invalid_choice_msg_len
	jmp mainloop


endroute:
	syscall1 60, 0
