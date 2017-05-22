section	.text

extern 	printf			;include C printf function
extern	c_WORD
extern 	c_FIND

global	_start		;must be declared for linker (ld)

;constant register allocations

; esp:	TOS pointer
; esi: 	forth program counter
; ebp: 	return stack pointer

; research combined copy&increment instruction
%macro NXT 0
	mov 	eax, [esi]	;save fPC in eax
	add 	esi, 0x4 	;increment fPC
	jmp 	[eax] 		;go to *fPC
%endmacro

_start:				;tell linker the entry point
	mov 	[SP0],esp 	;store stack pointer in SP0
	mov	esi, PROGRAM	;set the fPC
	mov 	ebp, RSTACK
	NXT    	;go!

;"code fragments"
QUIT	dd 	xQUIT
xQUIT:	mov 	ebp, RSTACK	;clear return stack
	mov 	DWORD[in_str_os], 0 	;reset in_str offset
	mov 	esi, ILOOP 	;set fPC to INTERPRET
	NXT			;run INTERPRET

DOCOLON:mov 	[ebp], esi	;push fPC onto rtn stack
	add 	ebp, 0x4	;"
				;eax=prev fPC
	mov 	esi, eax	;resolve last fPC into fPC
	add 	esi, 0x4	;move 1 word forward
	NXT


; esi needs to hold a reference re: the pointer name at left
	;eg: ILOOP + 0x8, rather than 'FIVE' or something
PROGRAM dd 	QUIT
ILOOP	dd 	INTERPRET, BRANCH, -0x8, BYE, EXIT

;arg1: internal name; arg2: string name for interpretter
;NB: the tags can be removed now as the calls can be direct
;also: the final 'dd' indirection line can be RM after DOCOLON inlined
LAST_H	dd 	0

%macro 	HEADR 2
	align 	16, db 0
	h%1 	dd 	0 		;<*prev_word>
		db 	%2		;max 12chars, unless change to align 32(wasteful)
		align	16, db 0
		%1 	dd 	x%1
		x%1:
%endmacro			

	;EXIT still needs to be a forth word

	;DOCOLON as part of the header of a composite word
	;to move DOCOLON into header requires DC to
	;dereference into xt then move forward #bytes
	;equal to size of DOCOLON instructions.

;DICTIONARY
HEADR 	FIVE, "5"
	push 	0x5
	NXT 		;threaded tail

; align 	16, db 0
; hFIVE	dd 	0
	; db	"5"
	; align 	16, db 0
	; FIVE 	dd 	xFIVE
	; xFIVE: 	
		; push 	0x5
		; NXT

align	16, db 0
hDOT	dd 	hFIVE
	db 	"."
	align 	16, db 0
	DOT 	dd 	xDOT
	xDOT:	push 	message
		call 	printf
		add 	esp, 8
		NXT

align 	16, db 0
hDUP 	dd 	hDOT
	db 	"DUP"
	align	16, db 0
	DUP 	dd 	xDUP
	xDUP: 	push	DWORD [esp]
		NXT

align 	16, db 0
hSTAR	dd 	hDUP
	db 	"*"
	align 	16, db 0
	STAR 	dd 	xSTAR
	xSTAR:	pop 	ebx
		pop 	eax
		imul 	ebx	;imul uses eax & stores in eax
		push 	eax
		NXT

align 	16, db 0
hEXIT 	dd 	hSTAR
	db 	"EXIT"
	align	16, db 0	
	EXIT	dd 	xEXIT
	xEXIT:	sub	ebp, 0x4
		mov 	esi, [ebp]
		NXT

align 	16, db 0
hINTERPRET dd 	hEXIT
	db 	"INTERPRET"
	align	16, db 0
	INTERPRET dd 	DOCOLON
		dd 	ZERO, WERD, FIND
		dd 	QBRANCH, 0x14, EXECUTE
		dd 	BRANCH, 0x8, TONUM
		dd 	EXIT

align 	16, db 0
hQBRANCH dd 	hINTERPRET
	db 	"QBRANCH"
	align	16, db 0
	QBRANCH dd 	xQBRANCH
	xQBRANCH:
		pop 	eax
		cmp	eax,0 	;is TOS = 0?
		jne	Q_NOTZ		;GOTO !0 branch
		;skip
		add 	esi, [esi]	;move fPC forward by contents of fPC (QB's arg)
		NXT
		;IF = TRUE
	Q_NOTZ:	add 	esi, 0x4 	;skip QB's arg
		NXT

align 	16, db 0
hBRANCH dd 	hQBRANCH
	db 	"BRANCH"
	align	16, db 0
	BRANCH dd 	xBRANCH
	xBRANCH:
		add 	esi, [esi]	;move fPC forward by contents of fPC (B's arg)
		NXT

align 	16, db 0
hZERO	dd 	hBRANCH
	db	"BL"
	align 	16, db 0
	ZERO 	dd 	xZERO
	xZERO: 	push	0x20 		;push SPACE
		NXT

align 	16, db 0
hWERD	dd 	hZERO
	db	"WORD"
	align 	16, db 0
	WERD 	dd 	xWERD
	xWERD: 	push	DWORD[in_str_os];string offset (already read)
		push 	in_str 		;address of input string
		push 	word_str	;address of output return str
		call 	c_WORD 		;ret length of WORD
		add 	esp, 0x8 	;drop 2 vals
		pop 	DWORD[in_str_os];update offset
			; leaves *token(as string) on stack
		NXT
		; passes test (for first word)
		; drops top 2 vals on stack
		; pushes count-of-used chars into in_str_os var
		; leaves *word_str on stack

align 	16, db 0
hFIND	dd 	hWERD
	db	"FIND"
	align 	16, db 0
	FIND 	dd 	xFIND
	xFIND: 			;str is on stack
				;match str to dict word
				;push a -1/0/+1 depending on if found
		; push 	esp	;push &TOS to c_FIND
		push 	LATEST	;push &h_of_last_word_in_dict
		add 	ebp, 0x4;add 1 extra space on rtn_stk
		push 	ebp	;push &returnstack
		call 	c_FIND
		add 	esp, 0xC 	;c_FIND pushed a val
		push 	DWORD[ebp]
		sub 	ebp, 0x4
		push 	DWORD[ebp]
		NXT

align 	16, db 0
hEXECUTE dd 	hFIND
	db	"EXECUTE"
	align 	16, db 0
	EXECUTE dd 	xEXECUTE
	xEXECUTE:			;note eax req'd for DOCOLON to work
		pop 	eax		;pop XT into eax
		jmp	[eax]		;NON-IMMEDIATE

align 	16, db 0
hTONUM	dd 	hEXECUTE
	db	"TONUM"
	align 	16, db 0
	TONUM 	dd 	xTONUM
	xTONUM: ;call 	atoi		;c lib func char->int
		NXT

align 	16, db 0
hBYE 	dd 	hTONUM
	db 	"BYE"
	align	16, db 0
	BYE	dd 	xBYE
	xBYE:	mov	eax,1
		pop 	ebx
		int 	0x80

align 	16, db 0
hDOTESS dd 	hBYE
	db 	".S"
	align 	16, db 0
	DOTESS 	dd 	xDOTESS
	xDOTESS:
		mov 	ebx, [SP0]
		sub 	ebx, esp
		mov 	ecx, ebx
		sar 	ecx, 2
		;print size
		push 	ecx
		push 	ds_sz
		call 	printf
		add 	esp, 8
		;print contents
	DS_ITER:jbe	DS_ENDR
		mov 	ecx, esp
		add 	ecx, ebx
		sub 	ecx, 4
		mov 	edx, [ecx]

		push 	edx
		push 	ds_num
		call 	printf
		add 	esp, 8
		
		sub 	ebx, 4
		jmp 	DS_ITER
		;print end of message
	DS_ENDR:push 	ds_end
		call 	printf
		add 	esp, 4
		NXT

align 	16, db 0
hCOLON dd 	hDOTESS
	db 	"COLON"
	align	16, db 0
	COLON 	dd 	xCOLON
	xCOLON: ;first allocate a new dictionary header
		;set the 'COMPILE' flag so next iteration of
		;QUIT loop sends following WORD into compile_word
		;rather than INTERPRET

		;should this be in a register so it's quick access
		;as the flag is checked when parsing any word
		;?is this a high-volume use case?
			

align 	16, db 0
hSQUARED dd 	hCOLON
	db 	"SQUARED"
	align	16, db 0
	SQUARED dd 	DOCOLON
		dd	DUP, STAR, EXIT




; : SQUARED ( a -- a^2 ) DUP * ;

section	.data


SP0 dd 0 		;pointer to bottom of stack
RSTACK TIMES 0x10 dd 0x0;return stack init

LATEST dd hSQUARED 	;pointer to header of last word added to dict

in_str db "5 SQUARED . BYE ;",0 ;fake shell input string
in_str_os dd 0 		;save how many chars have been used
word_str TIMES 0x10 db 0

message	db  'the number: 0x%x', 0xA, 0x0
debugP db 'asm_p: %p',0xA,0x0
debugDD db 'asm_dd: 0x%x',0xA,0x0

ds_sz 	db  '<0x%x> ',0x0 		;no new line!
ds_num 	db  '0x%x ',0x0 		;print a hex num
ds_end 	db  'nice stack ;)',0xA,0x0 	;close printf statement
