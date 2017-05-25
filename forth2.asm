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
	; mov 	eax, [esi]	;save fPC in eax
	; add 	esi, 0x4 	;increment fPC
	lodsd 	;functionally equiv to above 2lins
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

	mov 	DWORD[in_done], 0 ;set flag to read term
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

QLOOP	dd 	LINEFEED, QBRANCH, 0x8, DONE
	dd 	STATE, DEREF
	dd 		QBRANCH, 0x10, COMPILE_WORD
	dd 		BRANCH, 0x08, INTERPRET_WORD
	dd 	BRANCH, -0x34

;DICTIONARY- NATIVE WORDS

;arg1: internal name; arg2: string name for interpretter
;NB: the tags can be removed now as the calls can be direct
%define prev_h	0
%macro 	HEADR 3
	align 	16, db 0
	h%1 	dd 	prev_h 		;previous invocation's header
		%define prev_h 	h%1 	;redefine prev_h!
		db 	%3		;immediate flag
		db 	%2		;max 11chars
		align	16, db 0
		%1:
%endmacro

HEADR 	LINEFEED, "LINEFEED", -1
	push 	DWORD[in_done]
	NEXT

HEADR 	DOT, ".", -1
	push 	message
	call 	printf
	add 	esp, 8
	NEXT

HEADR 	DUP, "DUP", -1
 	push	DWORD [esp]
	NEXT

HEADR 	STATE, "STATE", -1 	;push @compile_flag on stack
	push 	COMPILE_FLAG
	NEXT

HEADR 	DEREF, "@", -1
	pop 	eax
	push 	DWORD[eax]
	NEXT

HEADR 	STAR, "*", -1
	pop 	ebx
	pop 	eax
	imul 	ebx	;imul uses eax & stores in eax
	push 	eax
	NEXT

HEADR 	PLUS, "+", -1
	pop 	ebx
	pop 	eax
	add 	eax, ebx
	push 	eax
	NEXT

HEADR 	DONE, "DONE", -1
	jmp 	QUIT

HEADR 	EXIT, "EXIT", -1
	sub	ebp, 0x4
	mov 	esi, [ebp]
	NEXT

HEADR 	QBRANCH, "?BRANCH", -1
	pop 	eax
	cmp	eax,0 		;is TOS = 0?
	jne	Q_NOTZ		;GOTO !0 branch
	;skip
	add 	esi, [esi]	;move fPC forward by contents of fPC (QB's arg)
	NEXT
	;IF = TRUE
Q_NOTZ:	add 	esi, 0x4 	;skip QB's arg
	NEXT

HEADR 	BRANCH, "BRANCH", -1
	add 	esi, [esi]	;move fPC forward by contents of fPC (B's arg)
	NEXT

HEADR 	BLANK, "BL", -1
 	push	0x20 		;push SPACE
	NEXT

HEADR 	WERD, "WORD", -1
	push	DWORD[in_str_os];string offset (already read)
	push 	in_str 		;address of input string
	push 	word_str	;address of output return str
	call 	c_WORD 		;ret length of WORD
	add 	esp, 0x4 	;drop 1 val
	pop 	DWORD[in_done]	;save 'done' flag
	pop 	DWORD[in_str_os];update offset
		; leaves *token(as string) on stack
	NEXT

HEADR 	FIND, "FIND", -1
	push 	LATEST	;push &h_of_last_word_in_dict
	add 	ebp, 0x4;add 1 extra space on rtn_stk
	push 	ebp	;push &returnstack
	call 	c_FIND
	add 	esp, 0xC 	;c_FIND pushed a val
	push 	DWORD[ebp]
	sub 	ebp, 0x4
	push 	DWORD[ebp]
	NEXT


HEADR 	EXECUTE, "EXECUTE", -1 	;note eax req'd for DOCOLON to work
	pop 	eax		;pop XT into eax
	jmp	eax		;NON-IMMEDIATE

HEADR 	TONUM, "TONUM", -1
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

HEADR 	ABORT, "ABORT", 1 	;immediacy doesn't matter?
	;print error message
	mov 	ecx, abortMsg
	mov 	edx, abortLen
	call 	DisplayText
	jmp 	QUIT 		;return to top-level


HEADR 	QDUP, "?DUP", -1 	;DUP stack if non-zero
	pop 	eax
	cmp 	eax, 0
	je 	QDUPPY
	push 	eax
QDUPPY: push 	eax
	NEXT

	; cmp 	DWORD [esp], 0 	;is zero?
	; je 	QDNO		;skip DUP if zero
 	; push	DWORD [esp] 	;duplicate TOS!
; QDNO:	NEXT

HEADR 	BYE, "BYE", -1
	mov	eax,1
	pop 	ebx 	;TOS = exit code for term
	int 	0x80

; use esp hack
HEADR 	ZEROLESS, "0<", -1 	;true if n < 0
	cmp 	DWORD[esp], 0 	;compare TOS to 0
	jl 	ZLL
	mov 	DWORD[esp], 0
	NEXT
ZLL: 	mov  	DWORD[esp], 1
	NEXT

; push & pop
HEADR 	ZEROMORE, "0>", -1 	;true if n > 0
	pop 	eax
	cmp 	eax, 0
	jg 	ZMO
	push 	0
	NEXT
ZMO: 	push 	1
	NEXT

HEADR 	DOTESS, ".S", -1
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

HEADR 	COMMA, ",", -1 	;i think
		; infers "," can be compiled to dict ->
		; hence words can themselves extend the dict!
	; append TOS to dictionary word
	mov 	eax, [dictP] 	;*dict into eax
	pop 	DWORD[eax] 	;append TOS to &dict
	add 	eax, 4 		;shift dict ref forward
	mov 	DWORD[dictP], eax ;save new address
	NEXT

HEADR 	COLON, ":", -1
;dd BLANK
	push	0x20
;dd WERD
	push	DWORD[in_str_os];string offset (already read)
	push 	in_str 		;address of input string
	push 	word_str	;address of output return str
	call 	c_WORD 		;ret length of WORD
	add 	esp, 0x4 	;drop 1 val
	pop 	DWORD[in_done]	;save 'done' flag
	pop 	DWORD[in_str_os];update offset
;end WORD, push *LL to dict

	mov 	edx, [dictP] 	;*dict memory
	mov 	ebx, [LATEST]	;*last_word to ebx
	mov 	DWORD[dcLocn],ebx ;reset *header
	mov 	DWORD[edx], ebx ;*last_word into dict
	mov 	[LATEST], edx 	;save *this_word for next
	add 	edx, 4 		;point to text destination
	mov 	DWORD[edx], -1 	;NON-IMMEDIATE
	add 	edx, 1
;cp 12 bytes to dict (as 3 DWORDs)
; eax=&name, ebx=counter, ecx=*name, edx=&dict
	pop 	eax		;*name from WORD
	mov 	ebx, 0x3 	;set counter to 3
CHACHA:	mov 	ecx, DWORD[eax]	;deref *name into ecx
	mov 	DWORD[edx], ecx ;copy 4*char
	add 	edx, 4 		;next 4*char (dest)
	add 	eax, 4 		;next 4*char (src)
	sub 	ebx, 1 		;decrease counter
	cmp 	ebx, 0 		;sub probably auto-cmps?
	jne 	CHACHA 		;do 12 bytes
	sub 	edx, 1 	;compensate for only 11byte name
;nb: CHACHA copies 12 chars regardless of string length
	; this leaves junk chars in the dict, but bc the word
	; is zero-terminated, anything after \0 is ignored!
;dd LEFTBRAK
	mov 	DWORD[COMPILE_FLAG], 1 ;compile mode!
;cp DOCOLON
	mov 	eax, [dcLocn] 	;save *header to eax
	add 	eax, 16 	;&DOCOLON
	mov 	ebx, 0x4 	;set counter to 4
TANGO:	mov 	ecx, DWORD[eax]	;*DOCOLON in ecx
	mov 	DWORD[edx], ecx ;copy DWORD
	add 	edx, 4 		;next 4*char (dest)
	add 	eax, 4 		;next 4*char (src)
	sub 	ebx, 1 		;decrease counter
	cmp 	ebx, 0
	jne 	TANGO 		;do 16 bytes
;update dictionary pointer
	mov 	DWORD[dictP],edx ;save end of word
	NEXT

HEADR 	DOLIT, "DOLIT", -1
	push 	DWORD[esi] 	;push next instruction to stack
	add 	esi, 0x4 	;skip DOLIT's arg
	NEXT

HEADR 	LEFTBRAK, "[", 1
	mov 	DWORD[COMPILE_FLAG], 1
	NEXT

HEADR 	RITEBRAK, "]", 1
	mov 	DWORD[COMPILE_FLAG], 0
	NEXT

HEADR 	DROP, "DROP", -1
	add 	esp, 4		;drop a value on stack
	NEXT

HEADR 	POSTPONE, "POSTPONE", -1
	mov 	edx, DWORD[dictP];*current dict into edx
	push 	edx 		;*current-dict onto data stack
	add 	edx, 4 		;move *dict forward
	mov 	DWORD[dictP], edx;save *dict 
	NEXT

HEADR 	FTHEN, "THEN", 1
	pop 	ebx		;*if/else arg
	mov 	eax, DWORD[dictP];*dict-current
	sub 	eax, ebx	;distance to jump to here
	mov 	DWORD[ebx], eax ;save distance into if/else arg
	NEXT

HEADR 	SWAP, "SWAP", -1
	pop 	ebx
	pop 	eax
	push 	ebx
	push 	eax
	NEXT


; ": DBL ( n -- n+n ) DUP + ;"

;DICTIONARY- COMPILED WORDS

;redefine HEADR to include DOCOLON
%macro DOCOLON 0
	mov 	[ebp], esi	;push fPC onto rtn stack
	add 	ebp, 0x4	;"
				;eax=prev fPC
	mov 	esi, eax	;last fPC into fPC
	add 	esi, 0x10	;move DOCOLON + NEXT words forward
	NEXT
	db 0,0 			;padding to DWORD boundary
%endmacro

%macro 	HEADR 3
	align 	16, db 0
	h%1 	dd 	prev_h 		;previous invocation's header
		%define prev_h 	h%1 	;redefine prev_h!
		db 	%3 		;immediacy
		db 	%2		;max 11chars
		align	16, db 0
		%1: 	DOCOLON
%endmacro


HEADR 	SEMIC, ";", 1
	dd 	RITEBRAK, DOLIT, EXIT, COMMA
	dd 	EXIT

HEADR 	PAREN, "(", 1 ;parse until close paren (shld be TONUM not DOLIT?)
	dd 	DOLIT, ')', WERD, EXIT

HEADR 	INTERPRET_WORD, "INTERPRET", -1
	dd 	BLANK, WERD, FIND
	dd 	QBRANCH, 0x10, EXECUTE, BRANCH, 0x8
	dd 	TONUM, EXIT

HEADR 	COMPILE_WORD, "COMPILE", -1
	dd 	BLANK, WERD, FIND
	dd 	QDUP, QBRANCH, 0x20
	dd 		ZEROMORE, QBRANCH, 0x10
	dd 			EXECUTE, BRANCH, 0x08
	dd 			COMMA
	dd 	EXIT

HEADR 	TICK, "'", -1 	; takes string from term-input not stack?!
	dd 	BLANK, WERD, FIND, DROP, EXIT

HEADR 	FIF, "IF", 1
	dd 	DOLIT, QBRANCH, COMMA
	dd 	POSTPONE, EXIT

HEADR 	FELSE, "ELSE", 1
	dd 	DOLIT, BRANCH, COMMA
	dd 	POSTPONE
	dd 	SWAP, FTHEN, EXIT

HEADR	SQUARED, "SQUARED", -1
	dd	DUP, STAR, EXIT


section	.data

SP0 dd 0 		;pointer to bottom of stack
RSTACK TIMES 0x10 dd 0x0;return stack init

LATEST 	dd hSQUARED 	;pointer to header of last word added to dict
dcLocn 	dd hSQUARED	;another *header for DOCOLON cpy
COMPILE_FLAG dd 0 	;not compiling

in_str_os dd 0 		;save how many chars have been used
word_str TIMES 0x10 db 0
in_done dd 1

message	db  'pancake: %d', 0xA, 0x0
debugP 	db 'asm_p: %p',0xA,0x0
debugDD db 'asm_dd: 0x%x',0xA,0x0

ds_sz 	db  '<0x%x> ',0x0 		;no new line!
ds_num 	db  '%d ',0x0 		;print a hex num
ds_end 	db  'nice stack :/',0xA,0x0 	;close printf statement

promptMsg db 'fawth: '
promptLen equ $-promptMsg

abortMsg db 'no can do.',0xA,0
abortLen equ $-abortMsg

dictP	dd dictNew 	;location of dictionary

section .bss

in_str 	resb 	0x50	;80char limit
in_str_len equ $-in_str

dictNew resd	0xFFFF	;64k reserved for dict additions
