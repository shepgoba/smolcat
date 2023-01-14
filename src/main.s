%define sys_read 0
%define sys_write 1
%define sys_open 2
%define sys_close 3
%define sys_stat 4
%define sys_fstat 5
%define sys_exit 60
%define print_buf_size 4096


global _start
section .text
_start:
	cmp dword [rsp], 2 ; argc
	jl .badargs

	mov rdi, [rsp + 8] ; args
	xor edx, edx
.strloop:
	mov dl, [rdi]
	inc rdi
	test dl, dl
	jnz .strloop

	; edx is already guaranteed to be 0

	push sys_open
	pop rax ; eax = 2
	xor esi, esi ; esi = O_READ
	syscall

	cmp rax, -4095 ; could compare eax, maybe UB(?)
	jb .file_valid

	push 33
	pop rdx
	lea rsi, [rel file_not_found]
	call .write_stdout_wrapper

	jmp .done_no_close

.file_valid:
	; eax holds fd
	; now ebx
	mov ebx, eax

	mov edi, ebx
	push sys_fstat
	pop rax; mov eax, sys_fstat
	lea rsi, [rsp - 144]
	syscall

	; test if directory
	mov esi, [rsp - 120]
	test esi, 0x4000
	jnz .direrror
	
	mov r12, [rsp - 96] ; r12 = st_size (struct offset 48)
	mov ebp, print_buf_size

	sub rsp, rbp

.writeloop:
	mov r13, rbp ; edx = print_buf_size
	cmp r12, rbp
	cmovl r13, r12

	mov rdx, r13
	xor eax, eax ; eax = sys_read (syscall no.)
	mov edi, ebx ; edi = fd
	mov rsi, rsp ; rsi = top of stack
	syscall

	mov rsi, rsp ; rsi = top of stack
	mov rdx, r13  ; edx = print_buf_size
	call .write_stdout_wrapper

	sub r12, r13
	jnz .writeloop

.done: ; make sure fd is still in ebx
	push sys_close ; mov eax, sys_close
	pop rax
	mov edi, ebx
	syscall

.done_no_close: ; exit cleanly
	push sys_exit; mov eax, sys_exit
	pop rax
	xor edi, edi
	syscall

.direrror:
	; mov edx, 28
	push 28
	pop rdx
	lea rsi, [rel isdirstr]
	call .write_stdout_wrapper

	jmp .done

.badargs:
	;mov edx, 22
	push 22
	pop rdx
	lea rsi, [rel arg_str]
	call .write_stdout_wrapper

	jmp .done_no_close

; set edx and rsi before calling
.write_stdout_wrapper:
	push sys_write
	pop rax
	mov edi, eax
	syscall
	ret

isdirstr: db "Error: Input is a directory", 0xa ; 28
file_not_found: db "Error: No such file or directory", 0xa ; 33
arg_str: db "Usage: smolcat <file>", 0xa ; 22
