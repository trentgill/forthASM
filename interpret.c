// interpret.c
#include <string.h>

struct word_header{
	struct word_header* prev;
	char name[16];
	void* codefield;
};

extern struct word_header* LATEST;

// input_buffer[] = "5 DUP * BYE ;"
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
	char** out_str = &delim; // pointer to str (which is *char)

	// overwrite stack vals
	*out_offset = count;
	*out_str = out_ptr;
	return;
}

void c_FIND( char* key )
{
	struct word_header* here = LATEST; // searching loc'n
	int* token = &key; // void* ??
	int* flag = &token - 0x4; // 1 address higher on stack

	do{
		if(strcmp( here->name, key ) == 0){
			// MATCH
			*token = here->codefield; // ptr to token
			*flag = 1; // -1 if immediate word!!
			return;
		}
		here = here->prev; // go to prev word in DICT
	} while(here != NULL);

	*flag = 0; // no match
	return;
}