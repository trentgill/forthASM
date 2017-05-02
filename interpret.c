// interpret.c
#include <stdio.h>
#include <string.h>

struct word_header{
	struct word_header* prev;
	char name[12];
	void* codefield;
};

extern struct word_header* LATEST;

// input_buffer[] = "5 DUP * DOT BYE ;"
void c_WORD( char* out, char* in, int in_offset, int delim )
{
/*	char* out_ptr = out; // save ptr to return token
	
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

	return;*/
}

void c_FIND( int* TOS, char* key )
{
/*	struct word_header* here = LATEST; // searching loc'n
	// int* token = (int *)&key; // void* ??
	// int* flag = (int *)&token - 0x4; // 1 address higher on stack

	// int* token = *TOS;
	// int* flag = *TOS - 4;
	// printf("&key  =%p\n\r", &key ); // pointer to TOS
	// printf("&here =%p\n\r", &here);
	// printf("token=%p\n\r", token); // dynamically allocated mem
	// printf("flag =%p\n\r", flag);
	// printf("C: in_offset=%x\n\r", in_offset);
	// printf("C: &in_offset=%p\n\r",&in_offset);	
	printf("\n\rFIND\n\r");

	do{
		if(strcmp( here->name, key ) == 0){
			// MATCH
			// *token = (int **)here->codefield; // ptr to token
			// *token = 0x13;
			// *flag = 1; // -1 if immediate word!!
			printf("FOUND!\n\r");
			// *key = 32;
			// key = 32;
			return;
		}
		here = here->prev; // go to prev word in DICT
	} while(here != NULL);

	printf("\n\rMUST BE A NUMBER\n\r");
	// *flag = 0; // no match

	return;*/
}