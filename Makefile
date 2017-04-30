all: forth

forth.o: forth2.asm
	nasm -f elf $< -o $@

# LIBS=/usr/lib/gcc/x86_64-linux-gnu/5


LDFLAGS+= --dynamic-linker /lib/ld-linux.so.2
LDFLAGS+= -lc
LDFLAGS+= -m elf_i386
# LDFLAGS+= --verbose

forth: forth.o Makefile
	ld $(LDFLAGS) -o $@ $<