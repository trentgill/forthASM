section     .text

extern 	printf			;include C printf function

global      _start		;must be declared for linker (ld)

_start:				;tell linker the entry point
	mov 	[SP0],esp 	;store stack pointer in SP0
	mov	esi,PROGRAM	;set the fPC
	mov 	DWORD [STACK_P], RSTACK 
	jmp	NEXT    	;go!

NEXT:
	mov	eax,[esi]	;*esi into eax
	add	esi,0x4		;inc address by 4 due to 32bit
	jmp	eax

DOTESS:
	;ebx is base-stack-pointer
	;ecx is size, and then decrements to zero
	mov 	ebx, [SP0]
	sub	ebx, esp	;find stack size (in 32b)
	mov 	ecx, ebx	;copy size
	sar 	ecx, 2 		;bytes in 32b
	; print size
	push	ecx		;push size to stack
	push	ds_sz 		;format "<size>"
	call 	printf
	add 	esp, 8		;remove msg from stack
	; print contents
DS_ITER:jbe	DS_ENDR		;close print if size == 0
	mov 	ecx, esp	;save stack pointer
	add 	ecx, ebx	;move toward base from top
	sub 	ecx, 4
	mov 	edx, [ecx]	;derefence val and store in edx
	
	push	edx
	push	ds_num		;end printf message (\n\r)
	call 	printf
	add 	esp, 8		;remove msg from stack pointer
	
	sub 	ebx, 4		;decrement counter (set flags!)
	jmp 	DS_ITER		;iterate through stack
	;print end of msg
DS_ENDR:push	ds_end		;end printf message (\n\r)
	call 	printf
	add 	esp, 4		;remove msg from stack pointer
	jmp	NEXT

DOT:
	push	message
	call 	printf
	add 	esp, 8		;restore stack?! shouldn't be -ve?
	jmp	NEXT

DUP:				;could just mov & push
	pop	eax		;pop stack[-1] and save in eax
	push	eax		;push it back on top
	push	eax		;add another copy
	jmp	NEXT

STAR:
	pop	ebx
	pop	eax
	imul	eax, ebx
	push	eax
	jmp	NEXT

SEVEN:
	push	0x7
	jmp	NEXT

FIVE:
	push	0x5
	jmp	NEXT

BYE:	
	mov	eax,1                               ;system call number (sys_exit)
	int	0x80                                ;call kernel

ENTER:
	;push
	mov 	eax, [STACK_P] 	;deref TOS into eax
	mov 	[eax], esi	;save prog counter's address
	add 	DWORD [STACK_P],0x4		;inc stack pointer
	;
	sub 	esi, 0x4	;go to previous PC location
	mov 	ecx, [esi] 	;deref PC into sub-fn
	add 	ecx, 0x4 	;this is 1st inst, go to 2nd
	mov 	esi, ecx 	;set PC to 2nd command in metafn
	jmp 	NEXT

EXIT:
	sub 	DWORD [STACK_P], 0x4
	mov 	eax, [STACK_P]	; ??? double*?
	mov 	esi, [eax]
	jmp 	NEXT
	
; program map
PROGRAM:
	dd 	FIVE
	dd 	SQUARE
	dd 	DOTESS
	dd 	BYE

SQUARE:
	dd 	ENTER
	dd 	DUP, STAR, EXIT


;vars called above have to be in .data!! otherwise no access!
section     .data

SP0	dd 	0x0 			;var to hold stack base pointer

RSTACK TIMES 0xF dd 0x0
STACK_P dd 	0x0

ds_sz 	db  '<0x%x> ',0x0 		;no new line!
ds_num 	db  '0x%x ',0x0 		;print a hex num
ds_end 	db  'nice stack ;)',0xA,0x0 	;close printf statement

message	db  'the number: 0x%x', 0xA, 0x0
;len     equ $ - msg 			;length of our dear string