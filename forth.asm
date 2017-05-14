section     .text

extern 	printf			;include C printf function
; extern	c_WORD
; extern 	c_FIND
extern 	atoi

global	_start		;must be declared for linker (ld)
global 	LATEST

;constant register allocations

; esp:	TOS pointer
; esi: 	forth program counter
; ebp: 	return stack pointer

_start:				;tell linker the entry point
	; mov 	[SP0],esp 	;store stack pointer in SP0
	mov	esi, PROGRAM	;set the fPC
	mov 	ebp, RSTACK
	jmp	NEXT    	;go!

;"code fragments"
NEXT:
	mov 	eax, esi	;save fPC in eax
	add 	esi, 0x4 	;increment fPC
	jmp 	[eax] 		;go to *fPC

QUIT:
	mov 	ebp, RSTACK	;clear return stack
	mov 	DWORD[in_str_os], 0 	;reset in_str offset
	mov 	esi, INTERP 	;set fPC to INTERP
	jmp 	NEXT		;run INTERP

DOCOLON:
	mov 	[ebp], esi	;push fPC onto rtn stack
	add 	ebp, 0x4	;"
				;eax=prev fPC
	mov 	esi, eax	;resolve last fPC into fPC
	add 	esi, 0x4	;move 1 word forward
	jmp	NEXT


;DICTIONARY
align 	16, db 0
hFIVE	dd 	0
	db	"5"
	align 	16, db 0
	FIVE 	dd 	cFIVE
	cFIVE: 	push 	0x5
		jmp	NEXT

align	16, db 0
hDOT	dd 	hFIVE
	db 	"."
	align 	16, db 0
	DOT 	dd 	cDOT
	cDOT:	push 	message
		call 	printf
		add 	esp, 8
		jmp 	NEXT

align 	16, db 0
hDUP 	dd 	hDOT
	db 	"DUP"
	align	16, db 0
	DUP 	dd 	cDUP
	cDUP: 	push	DWORD [esp]
		jmp	NEXT

align 	16, db 0
hSTAR	dd 	hDUP
	db 	"*"
	align 	16, db 0
	STAR 	dd 	cSTAR
	cSTAR:	pop 	ebx
		pop 	eax
		imul 	ebx	;imul uses eax & stores in eax
		push 	eax
		jmp 	NEXT

align 	16, db 0
hEXIT 	dd 	hSTAR
	db 	"EXIT"
	align	16, db 0	
	EXIT	dd 	cEXIT
	cEXIT:	sub	ebp, 0x4
		mov 	esi, [ebp]
		jmp 	NEXT

align 	16, db 0
hZERO	dd 	hEXIT
	db	"BL"
	align 	16, db 0
	ZERO 	dd 	cZERO
	cZERO: 	push	DWORD 0x20	;push SPACE
		jmp	NEXT

align 	16, db 0
hQBRANCH dd 	hZERO
	db 	"QBRANCH"
	align	16, db 0
	QBRANCH dd 	hBRANCH
	cQBRANCH:
		cmp	DWORD[esp],0 	;is TOS = 0?
		jne	Q_NOTZ		;GOTO !0 branch
		;skip
		add 	esi, [esi]	;move fPC forward by contents of fPC (QB's arg)
		jmp 	NEXT
		;IF = TRUE
	Q_NOTZ:	add 	esi, 0x4 	;skip QB's arg
		jmp 	NEXT

align 	16, db 0
hBRANCH dd 	hQBRANCH
	db 	"BRANCH"
	align	16, db 0
	BRANCH dd 	cBRANCH
	cBRANCH:
		pop 	eax		;rm FLAG from stack
		cmp	eax,0 		;is TOS = 0?
		je	B_ISZ		;GOTO !0 branch
		add 	esi, [esi]	;move fPC forward by contents of fPC (B's arg)
		jmp 	NEXT
	B_ISZ:	add 	esi, 0x4 	;skip B's arg
		jmp 	NEXT

align 	16, db 0
hWERD	dd 	hBRANCH
	db	"WORD"
	align 	16, db 0
	WERD 	dd 	cWERD
	cWERD: 	
		; push	DWORD[in_str_os];string offset (already read)
		push 	in_str 		;address of input string
		push 	word_str	;address of output return str
		; call 	c_WORD 		;ret length of WORD
		add 	esp, 0x8 	;drop 2 vals
		pop 	DWORD[in_str_os];update offset
			; leaves *token(as string) on stack
		jmp	NEXT
		; passes test (for first word)
		; drops top 2 vals on stack
		; pushes count-of-used chars into in_str_os var
		; leaves *word_str on stack

align 	16, db 0
hINTERP dd 	hWERD
	db 	"INTERP"
	align	16, db 0
	INTERP 	dd 	DOCOLON
		dd 	ZERO, WERD, FIND
		dd 	QBRANCH, 0x8, EXECUTE
		dd 	BRANCH, 0x8, TONUM
		dd 	EXIT


; align 	16, db 0
hFIND	dd 	hINTERP
	db	"FIND"
	align 	16, db 0
	FIND 	dd 	cFIND
	cFIND: 			;str is on stack
				;match str to dict word
				;push a -1/0/+1 depending on if found
		push 	esp
		; call 	c_FIND
		sub 	esp, 0x4;c_FIND pushes 1 val
		jmp	NEXT

align 	16, db 0
hEXECUTE dd 	hFIND
	db	"EXECUTE"
	align 	16, db 0
	EXECUTE dd 	cEXECUTE
	cEXECUTE:
		pop 	eax		;pop FLAG into eax
		pop 	ebx		;pop XT into eax
		cmp	eax, 1
		je	X_IMM 		;if flag=1 DO IT NOW		
		jmp	[ebx]		;NON-IMMEDIATE
	X_IMM:	jmp	[ebx]		;IMMEDIATE

align 	16, db 0
hTONUM	dd 	hEXECUTE
	db	"TONUM"
	align 	16, db 0
	TONUM 	dd 	cTONUM
	cTONUM: call 	atoi		;c lib func char->int
		jmp	NEXT

align 	16, db 0
hBYE 	dd 	hTONUM
	db 	"BYE"
	align	16, db 0
	BYE	dd 	cBYE
	cBYE:	mov	eax,1
		pop 	ebx
		int 	0x80

align 	16, db 0
hSQUARED dd 	hBYE
	db 	"SQUARED"
	align	16, db 0
	SQUARED dd 	DOCOLON
		dd	DUP, STAR, EXIT

; align 16, db 0

; : SQUARED ( a -- a^2 ) DUP * ;

section	.data

PROGRAM dd 	QUIT



SP0 	dd 0 		;pointer to bottom of stack
RSTACK  TIMES 0x10 dd 0x0;return stack init

LATEST  dd hSQUARED 	;pointer to header of last word added to dict

in_str  db "5 DUP * . BYE ;",0 ;fake shell input string
in_str_os dd 0 		;save how many chars have been used
word_str TIMES 0x10 db 0

message	db  'the number: 0x%x', 0xA, 0x0
debugP 	db  'asm_p: %p',0xA,0x0
debugDD db  'asm_dd: 0x%x',0xA,0x0

; ds_sz 	db  '<0x%x> ',0x0 		;no new line!
; ds_num 	db  '0x%x ',0x0 		;print a hex num
; ds_end 	db  'nice stack ;)',0xA,0x0 	;close printf statement
