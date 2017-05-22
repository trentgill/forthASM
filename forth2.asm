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
	jmp 	eax 		;go to fPC
%endmacro


_start:				;tell linker the entry point
	mov 	[SP0],esp 	;store stack pointer in SP0
	mov	esi, PROGRAM	;set the fPC
	mov 	ebp, RSTACK
	NXT    	;go!

;"code fragments"
QUIT:	mov 	ebp, RSTACK	;clear return stack
	mov 	DWORD[in_str_os], 0 	;reset in_str offset
	mov 	esi, ILOOP 	;set fPC to INTERPRET
	NXT			;run INTERPRET


PROGRAM dd 	QUIT
ILOOP	dd 	INTERPRET, BRANCH, -0x8, BYE, EXIT


;DICTIONARY- NATIVE WORDS

;arg1: internal name; arg2: string name for interpretter
;NB: the tags can be removed now as the calls can be direct
%define prev_h	0
%macro 	HEADR 2
	align 	16, db 0
	h%1 	dd 	prev_h 		;previous invocation's header
		%define prev_h 	h%1 	;redefine prev_h!
		db 	%2		;max 12chars, unless change to align 32(wasteful)
		align	16, db 0
		%1:
%endmacro


HEADR 	FIVE, "5"
	push 	0x5
	NXT 		;threaded tail

HEADR 	DOT, "."
	push 	message
	call 	printf
	add 	esp, 8
	NXT

HEADR 	DUP, "DUP"
 	push	DWORD [esp]
	NXT

HEADR 	STAR, "*"
	pop 	ebx
	pop 	eax
	imul 	ebx	;imul uses eax & stores in eax
	push 	eax
	NXT

HEADR 	EXIT, "EXIT"
	sub	ebp, 0x4
	mov 	esi, [ebp]
	NXT

HEADR 	QBRANCH, "?BRANCH"
	pop 	eax
	cmp	eax,0 	;is TOS = 0?
	jne	Q_NOTZ		;GOTO !0 branch
	;skip
	add 	esi, [esi]	;move fPC forward by contents of fPC (QB's arg)
	NXT
	;IF = TRUE
Q_NOTZ:	add 	esi, 0x4 	;skip QB's arg
	NXT

HEADR 	BRANCH, "BRANCH"
	add 	esi, [esi]	;move fPC forward by contents of fPC (B's arg)
	NXT

HEADR 	ZERO, "BL"
 	push	0x20 		;push SPACE
	NXT

HEADR 	WERD, "WORD"
	push	DWORD[in_str_os];string offset (already read)
	push 	in_str 		;address of input string
	push 	word_str	;address of output return str
	call 	c_WORD 		;ret length of WORD
	add 	esp, 0x8 	;drop 2 vals
	pop 	DWORD[in_str_os];update offset
		; leaves *token(as string) on stack
	NXT

HEADR 	FIND, "FIND"
	push 	LATEST	;push &h_of_last_word_in_dict
	add 	ebp, 0x4;add 1 extra space on rtn_stk
	push 	ebp	;push &returnstack
	call 	c_FIND
	add 	esp, 0xC 	;c_FIND pushed a val
	push 	DWORD[ebp]
	sub 	ebp, 0x4
	push 	DWORD[ebp]
	NXT


HEADR 	EXECUTE, "EXECUTE" 	;note eax req'd for DOCOLON to work
	pop 	eax		;pop XT into eax
	jmp	eax		;NON-IMMEDIATE

HEADR 	TONUM, "TONUM"
	;unimplemented!
	NXT

HEADR 	BYE, "BYE"
	mov	eax,1
	pop 	ebx
	int 	0x80

HEADR 	DOTESS, ".S"
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

HEADR 	COLON, ":"
	;first allocate a new dictionary header
	;set the 'COMPILE' flag so next iteration of
	;QUIT loop sends following WORD into compile_word
	;rather than INTERPRET
	NXT
	;should this be in a register so it's quick access
	;as the flag is checked when parsing any word
	;?is this a high-volume use case?


;DICTIONARY- COMPILED WORDS

;redefine HEADR to include DOCOLON
%macro DOCOLON 0
	mov 	[ebp], esi	;push fPC onto rtn stack
	add 	ebp, 0x4	;"
				;eax=prev fPC
	mov 	esi, eax	;last fPC into fPC
	add 	esi, 0x20	;move DOCOLON + NXT words forward
	NXT
	align	16, db 0 	;force DWORD alignment
%endmacro

%macro 	HEADR 2
	align 	16, db 0
	h%1 	dd 	prev_h 		;previous invocation's header
		%define prev_h 	h%1 	;redefine prev_h!
		db 	%2		;max 12chars, unless change to align 32(wasteful)
		align	16, db 0
		%1: 	DOCOLON
%endmacro


HEADR 	INTERPRET, "INTERPRET"
	dd 	ZERO, WERD, FIND
	dd 	QBRANCH, 0x14, EXECUTE, BRANCH, 0x8
	dd 	TONUM, EXIT

HEADR	SQUARED, "SQUARED"
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
