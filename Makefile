all: forth

forth.o: forth2.asm
	nasm -f elf $< -o $@

# LIBS=/usr/lib/gcc/x86_64-linux-gnu/5


LDFLAGS+= --dynamic-linker /lib/ld-linux.so.2
LDFLAGS+= -lc
LDFLAGS+= -m elf_i386
# LDFLAGS+= --verbose

%.o: %.c
	gcc -c -m32 -o $@ $<

forth: forth.o interpret.o
	ld $(LDFLAGS) -o $@ $^

clean:
	rm -f *.o forth