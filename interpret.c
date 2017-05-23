// interpret.c
#include <stdio.h>
#include <stdint.h>
#include <string.h>

struct word_header{
	struct word_header* prev;
	uint8_t name[12];
	uint32_t* codefield; // should be void* really :s
};

void c_WORD( uint8_t* out, uint8_t* in, uint32_t in_offset, uint32_t delim )
{
	uint8_t* out_ptr = out; // save ptr to return token
	
	in += in_offset; // shift in_ptr to next word
	uint32_t count = in_offset;
	
	// check for null, delim (space), and linefeed
	while(*in != 0 && *in != delim && *in != 0xA){
		// push in char to out
		*out++ = *in++;
		count++; // used another char
	}
	*out = 0; // add null char to return str
	count++; // skip next space
		// need to protect against /0 end of string?

	uint32_t* out_offset = &in_offset;
	uint8_t** out_str = (uint8_t **)&delim; // pointer to str (which is *char)

	// overwrite stack vals
	*out_offset = count;
	*out_str = out_ptr;

	return;
}

void c_FIND( void* r_stk, struct word_header* here, uint8_t* key )
{
	uint32_t* token = (uint32_t *)&key; // void* ??
	uint32_t* flag = (uint32_t *)&token - 0x4; // 1 address higher on stack

	uint32_t* TOS = (uint32_t *)r_stk;
	uint32_t* TOS_next = (uint32_t *)r_stk - 0x1; // C KNOWS THAT IT'S A 32BIT ADDRESS!

	do{
		if(strcmp( here->name, key ) == 0){
			*TOS = (uint32_t)&(here->codefield);
			*TOS_next = 1; // SET FLAG TO 1 (EXECUTE)
			return;
		}
		here = here->prev; // go to prev word in DICT
	} while(here != NULL);

	*TOS = (uint32_t)key;
	*TOS_next = 0; // SET FLAG TO 0 (>NUM)
	return;
}