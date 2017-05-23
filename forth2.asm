;system interupt dfns
sys_exit 	equ 	1
sys_read 	equ 	3
sys_write 	equ	4
stdin 		equ 	0
stdout 		equ 	1
stderr 		equ 	3

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
%macro NEXT 0
	mov 	eax, [esi]	;save fPC in eax
	add 	esi, 0x4 	;increment fPC
	jmp 	eax 		;go to fPC
%endmacro


_start:				;tell linker the entry point
	mov 	[SP0],esp 	;store stack pointer in SP0
	mov	esi, PROGRAM	;set the fPC
	mov 	ebp, RSTACK
	NEXT    	;go!

;"code fragments"
QUIT:	mov 	ebp, RSTACK	;clear return stack
	mov 	DWORD[in_str_os], 0 	;reset in_str offset
	mov 	esi, QLOOP 	;set fPC to QLOOP

	mov 	ecx, promptMsg 	;terminal prompt!
	mov 	edx, promptLen
	call 	DisplayText

	mov 	ecx, in_str 	;terminal input.
	mov 	edx, in_str_len
	call 	ReadText
	NEXT			;run QLOOP

DisplayText:
	mov 	eax, sys_write
	mov 	ebx, stdout
	int 	0x80
	ret
ReadText:
	mov 	ebx, stdin
	mov 	eax, sys_read
	int 	0x80
	ret

PROGRAM dd 	QUIT

QLOOP	dd 	STATE, DEREF
	dd 		QBRANCH, 0x10, COMPILE_WORD
	dd 		BRANCH, 0x08, INTERPRET_WORD
	dd 	BRANCH, -0x24

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

HEADR 	DOT, "."
	push 	message
	call 	printf
	add 	esp, 8
	NEXT

HEADR 	DUP, "DUP"
 	push	DWORD [esp]
	NEXT

HEADR 	STATE, "STATE" 		;push @compile_flag on stack
	push 	COMPILE_FLAG
	NEXT

HEADR 	DEREF, "@"
	pop 	eax
	push 	DWORD[eax]
	NEXT

HEADR 	STAR, "*"
	pop 	ebx
	pop 	eax
	imul 	ebx	;imul uses eax & stores in eax
	push 	eax
	NEXT

HEADR 	EXIT, "EXIT"
	sub	ebp, 0x4
	mov 	esi, [ebp]
	NEXT

HEADR 	QBRANCH, "?BRANCH"
	pop 	eax
	cmp	eax,0 		;is TOS = 0?
	jne	Q_NOTZ		;GOTO !0 branch
	;skip
	add 	esi, [esi]	;move fPC forward by contents of fPC (QB's arg)
	NEXT
	;IF = TRUE
Q_NOTZ:	add 	esi, 0x4 	;skip QB's arg
	NEXT

HEADR 	BRANCH, "BRANCH"
	add 	esi, [esi]	;move fPC forward by contents of fPC (B's arg)
	NEXT

HEADR 	BLANK, "BL"
 	push	0x20 		;push SPACE
	NEXT

HEADR 	WERD, "WORD"
	push	DWORD[in_str_os];string offset (already read)
	push 	in_str 		;address of input string
	push 	word_str	;address of output return str
	call 	c_WORD 		;ret length of WORD
	add 	esp, 0x8 	;drop 2 vals
	pop 	DWORD[in_str_os];update offset
		; leaves *token(as string) on stack
	NEXT

HEADR 	FIND, "FIND"
	push 	LATEST	;push &h_of_last_word_in_dict
	add 	ebp, 0x4;add 1 extra space on rtn_stk
	push 	ebp	;push &returnstack
	call 	c_FIND
	add 	esp, 0xC 	;c_FIND pushed a val
	push 	DWORD[ebp]
	sub 	ebp, 0x4
	push 	DWORD[ebp]
	NEXT


HEADR 	EXECUTE, "EXECUTE" 	;note eax req'd for DOCOLON to work
	pop 	eax		;pop XT into eax
	jmp	eax		;NON-IMMEDIATE

HEADR 	TONUM, "TONUM"
	pop	ecx		;pop *string off stack
	mov 	eax, 0 		;clear eax (store output val)

NIN:	mov 	ebx, [ecx]	;dereference char into ebx
	and 	ebx, 0xFF 	;mask for lowest BYTE only
	cmp 	ebx, 0x0 	;terminator
	je 	NEND		;if num processed jump out!
	cmp 	ebx, 0x30 ;is it >= '0'
	jl	ABORT 		;not a number
	cmp 	ebx, 0x39 ;is it <= 9
	jg 	ABORT 		;not a number

	sub 	ebx, 0x30 ;rebase to 0
	mov 	edx, 0xA 	;imul needs arg in register?
	imul	edx 		;mul eax*10: move decimal place
	add 	eax, ebx 	;add new digit to count
	add 	ecx, 0x1 	;next byte
	jmp 	NIN 		;repeat
NEND:	push 	eax 		;push result
	NEXT

HEADR 	ABORT, "ABORT"
	;print error message
	mov 	ecx, abortMsg
	mov 	edx, abortLen
	call 	DisplayText

	jmp 	QUIT 		;return to top-level

HEADR 	QDUP, "?DUP" 		;DUP stack if non-zero
	cmp 	DWORD [esp], 0 	;is zero?
	je 	QDNO		;skip DUP if zero
 	push	DWORD [esp] 	;duplicate TOS!
QDNO:	NEXT

HEADR 	BYE, "BYE"
	mov	eax,1
	pop 	ebx
	int 	0x80

HEADR 	ZEROLESS, "0<" 	;true if n < 0
	cmp 	DWORD[esp], 0 	;compare TOS to 0
	jl 	ZLL
	mov 	DWORD[esp], 0
	NEXT
ZLL: 	mov  	DWORD[esp], 1
	NEXT

HEADR 	ZEROMORE, "0>" 	;true if n > 0
	cmp 	DWORD[esp], 0 	;compare TOS to 0
	jg 	ZMM
	mov 	DWORD[esp], 0
	NEXT
ZMM: 	mov  	DWORD[esp], 1
	NEXT

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
	NEXT

HEADR 	COMPILE, "COMPILE"
	;
	NEXT

HEADR 	COLON, ":"
	mov 	DWORD[COMPILE_FLAG], 1 ;compile mode!
	;skip leading space
	;add new DICT entry (use %HEADR)
	;set the 'COMPILE' flag so next iteration of
	;QUIT loop sends following WORD into compile_word
	;rather than INTERPRET
	NEXT
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
	add 	esi, 0x20	;move DOCOLON + NEXT words forward
	NEXT
	align	16, db 0 	;force DWORD alignment
%endmacro

%macro 	HEADR 2
	align 	16, db 0
	h%1 	dd 	prev_h 		;previous invocation's header
		%define prev_h 	h%1 	;redefine prev_h!
		db 	%2		;max 12chars
		align	16, db 0
		%1: 	DOCOLON
%endmacro


HEADR 	INTERPRET_WORD, "INTERPRET_W"
	dd 	BLANK, WERD, FIND
	dd 	QBRANCH, 0x10, EXECUTE, BRANCH, 0x8
	dd 	TONUM, EXIT

HEADR 	COMPILE_WORD, "COMPILE_W"
	dd 	BLANK, WERD, FIND
	dd 	QDUP, QBRANCH, 0x20
	dd 		ZEROMORE, QBRANCH, 0x10
	dd 		EXECUTE, BRANCH, 0x08
	dd 		COMPILE
	dd 	EXIT

HEADR	SQUARED, "SQUARED"
	dd	DUP, STAR, EXIT


section	.data

SP0 dd 0 		;pointer to bottom of stack
RSTACK TIMES 0x10 dd 0x0;return stack init

LATEST dd hSQUARED 	;pointer to header of last word added to dict
COMPILE_FLAG dd 0 	;not compiling

in_str_os dd 0 		;save how many chars have been used
word_str TIMES 0x10 db 0

message	db  'numbness: 0x%x', 0xA, 0x0
debugP 	db 'asm_p: %p',0xA,0x0
debugDD db 'asm_dd: 0x%x',0xA,0x0

ds_sz 	db  '<0x%x> ',0x0 		;no new line!
ds_num 	db  '0x%x ',0x0 		;print a hex num
ds_end 	db  'nice stack ;)',0xA,0x0 	;close printf statement

promptMsg db 'fawth: '
promptLen equ $-promptMsg

abortMsg db 'no can do.',0xA,0
abortLen equ $-abortMsg

section .bss

in_str 	resb 	0x50	;80char limit
in_str_len equ $-in_str


