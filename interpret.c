// interpret.c
#include <stdio.h>
#include <string.h>

struct word_header{
	struct word_header* prev;
	char name[12];
	int* codefield; // should be void* really :s
};

// input_buffer[] = "5 DUP * DOT BYE ;"
void c_WORD( char* out, char* in, int in_offset, int delim )
{
	char* out_ptr = out; // save ptr to return token
	
	in += in_offset; // shift in_ptr to next word
	int count = in_offset;
	
	while(*in != 0 && *in != delim){
		// push in char to out
		*out++ = *in++;
		count++; // used another char
	}
	*out = 0; // add null char to return str
	count++; // skip next space
		// need to protect against /0 end of string?

	int* out_offset = &in_offset;
	char** out_str = (char **)&delim; // pointer to str (which is *char)

	// overwrite stack vals
	*out_offset = count;
	*out_str = out_ptr;

	return;
}

void c_FIND( void* r_stk, struct word_header* here, char* key )
{
	int* token = (int *)&key; // void* ??
	int* flag = (int *)&token - 0x4; // 1 address higher on stack

	int* TOS = (int *)r_stk;
	int* TOS_next = (int *)r_stk - 0x1; // C KNOWS THAT IT'S A 32BIT ADDRESS!

	do{
		if(strcmp( here->name, key ) == 0){
			printf("FOUND!\n\r");
			*TOS = (int)&(here->codefield);
			*TOS_next = 1; // SET FLAG TO 1 (EXECUTE)
			return;
		}
		here = here->prev; // go to prev word in DICT
	} while(here != NULL);

	printf("\n\rMUST BE A NUMBER\n\r");
	*TOS = (int)key;
	*TOS_next = 0; // SET FLAG TO 0 (>NUM)
	return;
}