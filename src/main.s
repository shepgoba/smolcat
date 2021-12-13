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
	xor eax, eax
.strloop:
	mov al, [rdi]
	inc rdi
	test al, al
	jnz .strloop

	mov eax, sys_open
	xor esi, esi ; mov esi, O_READ
	xor edx, edx
	syscall

	cmp eax, -1
	jg .file_valid
	cmp eax, -4095
	jl .file_valid

	xor eax, eax
	inc eax
	mov edi, eax
	lea rsi, [rel file_not_found]
	mov edx, 33
	syscall

	jmp .done_no_close

.file_valid:
	mov ebx, eax
	mov edi, ebx
	mov eax, sys_fstat
	lea rsi, [rsp - 144]
	syscall

	; test if directory
	xor edi, edi
	mov esi, [rsp - 120]
	test esi, 0x4000
	jnz .direrror
	
	mov r12, [rsp - 96] ; st_size @ offset 48

	sub rsp, print_buf_size
	jmp .writeloopstart

.writeloop:
	xor eax, eax ; mov eax, sys_read
	mov edi, ebx
	mov rdx, print_buf_size
	mov rsi, rsp
	syscall

	mov rsi, rsp
	mov rdx, print_buf_size

	xor eax, eax
	inc eax ; mov eax, sys_write
	
	mov edi, eax
	syscall

	sub r12, print_buf_size

.writeloopstart:
	cmp r12, print_buf_size
	jg .writeloop

	test r12, r12
	jz .done

	xor eax, eax ; mov eax, sys_read

	mov edi, ebx
	mov rdx, r12
	mov rsi, rsp
	syscall

	mov rsi, rsp
	mov rdx, r12

	xor eax, eax
	inc eax ; mov eax, sys_write

	mov edi, eax
	syscall

	add rsp, print_buf_size

.done: ; make sure fd is still in ebx
	mov eax, sys_close
	mov edi, ebx
	syscall

.done_no_close:
	mov eax, sys_exit
	xor edi, edi
	syscall

.direrror:
	xor eax, eax
	inc eax
	mov edi, eax
	mov edx, 32
	lea rsi, [rel isdirstr]
	syscall
	jmp .done

.badargs:
	xor eax, eax
	inc eax
	mov edi, eax
	lea rsi, [rel arg_str]
	mov edx, 19
	syscall

	jmp .done_no_close

isdirstr: db "Error: This file is a directory", 0xa ; 32
file_not_found: db "Error: No such file or directory", 0xa ; 33
arg_str: db "Usage: zcat <file>", 0xa
