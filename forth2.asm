section     .text

extern 	printf			;include C printf function
extern	c_interpret

global	_start		;must be declared for linker (ld)
global 	LATEST
;constant register allocations
;;;;;

_start:				;tell linker the entry point
	mov 	[SP0],esp 	;store stack pointer in SP0
	mov	esi,PROGRAM	;set the fPC
	mov 	ebp, RSTACK
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

QUIT:
	mov 	ebp, RSTACK
L1:	call	c_interpret
	jmp 	L1		;infinite loop


PROGRAM dd 	QUIT

;DICTIONARY
hFIVE	dd 	0
	db	"5"
	align 	16, db 0
FIVE 	dd 	cFIVE
cFIVE: 	push 	0x5
	jmp	NEXT

hDUP 	dd 	hFIVE
	db 	"DUP"
	align	16, db 0
	DUP 	dd 	cDUP
	cDUP: 	push	DWORD [esp]
		jmp	NEXT

hSTAR	dd 	hDUP
	db 	"*"
	align 	16, db 0
	STAR 	dd 	cSTAR
	cSTAR:	pop 	ebx
		pop 	eax
		imul 	ebx	;imul uses eax & stores in eax
		push 	eax
		jmp 	NEXT

hEXIT 	dd 	hSTAR
	db 	"EXIT"
	align	16, db 0	
	EXIT	dd 	cEXIT
	cEXIT:	sub	ebp, 0x4
		mov 	esi, [ebp]
		jmp 	NEXT

hBYE 	dd 	hEXIT
	db 	"BYE"
	align	16, db 0
	BYE	dd 	cBYE
	cBYE:	mov	eax,1
		pop 	ebx
		int 	0x80

hSQUARED dd 	hBYE
	db 	"SQUARED"
	align	16, db 0
	SQUARED dd 	DOCOLON, DUP, STAR, EXIT

"5 DUP * BYE ;"
: SQUARED ( a -- a^2 ) DUP * ;

section	.data

SP0 dd 0
RSTACK TIMES 0x10 dd 0x0

LATEST dd hSQUARED ;*dd in header of last created
