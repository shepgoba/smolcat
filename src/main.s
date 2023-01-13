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

	lea eax, [edx + 2] ; mov eax, sys_open ; rdi = path
	xor esi, esi ; esi = O_READ

	syscall

	cmp rax, -4095 ; could compare eax, maybe UB(?)
	jb .file_valid

	mov edx, 33
	lea rsi, [rel file_not_found]
	call .sys_write_wrapper

	jmp .done_no_close

.file_valid:
	; eax holds fd
	; now ebx
	mov ebx, eax

	mov edi, ebx
	mov eax, sys_fstat
	lea rsi, [rsp - 144]
	syscall

	; test if directory
	mov esi, [rsp - 120]
	test esi, 0x4000
	jnz .direrror
	
	mov r12, [rsp - 96] ; r12 = st_size (struct offset 48)
	mov ebp, print_buf_size

	sub rsp, rbp
	jmp .writeloopstart

.writeloop:
	xor eax, eax ; eax = sys_read (syscall no.)
	mov edi, ebx ; edi = fd
	mov edx, ebp ; edx = print_buf_size
	mov rsi, rsp ; rsi = top of stack
	syscall

	mov rsi, rsp ; rsi = top of stack
	mov edx, ebp ; edx = print_buf_size

	call .sys_write_wrapper

	sub r12, rbp

.writeloopstart:
	cmp r12, rbp
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

	call .sys_write_wrapper
	add rsp, rbp

.done: ; make sure fd is still in ebx
	mov eax, sys_close
	mov edi, ebx
	syscall

.done_no_close: ; exit cleanly
	mov eax, sys_exit
	xor edi, edi
	syscall

.direrror:
	mov edx, 28
	lea rsi, [rel isdirstr]
	call .sys_write_wrapper

	jmp .done

.badargs:
	mov edx, 22
	lea rsi, [rel arg_str]
	call .sys_write_wrapper

	jmp .done_no_close

; set edx and rsi before calling
.sys_write_wrapper:
	xor eax, eax
	inc eax
	mov edi, eax
	syscall
	ret

isdirstr: db "Error: Input is a directory", 0xa ; 28
file_not_found: db "Error: No such file or directory", 0xa ; 33
arg_str: db "Usage: smolcat <file>", 0xa
