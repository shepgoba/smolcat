%define sys_read 0
%define sys_write 1
%define sys_open 2
%define sys_close 3
%define sys_stat 4
%define sys_fstat 5
%define sys_exit 60
%define print_buf_size 16384

global _start
section .text
_start:
	cmp dword [rsp], 2 ; argc
	jl .badargs_shim ; using shim so the jump relative imm8 can be used, saves 2 bytes (2+2 vs 6)

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

	cmp eax, -4095
	jb .file_valid

	push 33
	pop rdx
	mov esi, file_not_found
	call .write_stdout_wrapper

	jmp .exit
.badargs_shim:
	jmp .badargs ; using shim so the jump relative imm8 can be used, saves 2 bytes (2+2 vs 6)
.file_valid: ; eax holds fd
	sub rsp, 96
	mov ebx, eax

	mov edi, ebx
	push sys_fstat
	pop rax ; mov eax, sys_fstat
	lea rsi, [rsp - 48]
	syscall

	test byte [rsp - 23], 0x40 ; test if directory, on newer linux this would be 8 bytes higher (rsp - 15)
	jnz .direrror
	
	mov r12, [rsp] ; r12 = st_size (struct offset 48)
	mov ebp, print_buf_size

	sub rsp, rbp
.writeloop:
	mov r13, rbp 
	cmp r12, rbp
	cmovl r13, r12

	mov rdx, r13 ; edx = amount to read (print_buf_size or less)
	xor eax, eax ; eax = sys_read (syscall no.)
	mov edi, ebx ; edi = fd
	mov rsi, rsp ; rsi = top of stack
	syscall

	mov rsi, rsp ; rsi = top of stack
	mov rdx, r13  ; edx = print_buf_size
	call .write_stdout_wrapper

	sub r12, r13 ; sets 0 flag
	jnz .writeloop
.exit_close: ; make sure fd is still in ebx
	push sys_close ; mov eax, sys_close
	pop rax
	mov edi, ebx
	syscall
.exit: ; exit cleanly
	push sys_exit ; mov eax, sys_exit
	pop rax
	xor edi, edi
	syscall

.direrror:
	push 28 ; mov edx, 28
	pop rdx
	mov esi, isdirstr
	call .write_stdout_wrapper
	jmp .exit_close
.badargs:
	push 22 ; mov edx, 22
	pop rdx
	mov esi, arg_str
	push .exit ; jank return address
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
