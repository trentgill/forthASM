section     .text

extern 	printf			;include C printf function

global      _start		;must be declared for linker (ld)

;constant register allocations
;;;;;

_start:				;tell linker the entry point
	mov 	[SP0],esp 	;store stack pointer in SP0
	mov	esi,PROGRAM	;set the fPC
	mov 	ebp, RSTACK

;insert INIT_D in here 	
	jmp	NEXT    	;go!

;"code fragments"
NEXT:
	mov 	eax, [esi]
	add 	esi, 0x4
	jmp 	[eax]

DOCOLON:
	mov 	[ebp], esi
	add 	ebp, 0x4
	mov 	esi, eax
	add 	esi, 0x4
	jmp	NEXT


PROGRAM dd 	FIVE, SQUARED, BYE

;DICTIONARY
FIVE 	dd 	cFIVE
cFIVE: 	push 	0x5
	jmp	NEXT

DUP 	dd 	cDUP
cDUP: 	push	DWORD [esp]
	jmp	NEXT

STAR 	dd 	cSTAR
cSTAR:	pop 	ebx
	pop 	eax
	imul 	ebx	;imul uses eax & stores in eax
	push 	eax
	jmp 	NEXT

EXIT	dd 	cEXIT
cEXIT:	sub	ebp, 0x4
	mov 	esi, [ebp]
	jmp 	NEXT

BYE	dd 	cBYE
cBYE:	mov	eax,1
	pop 	ebx
	int 	0x80
	
SQUARED dd 	DOCOLON, DUP, STAR, EXIT

section	.data

SP0 dd 0

RSTACK TIMES 0x10 dd 0x0
