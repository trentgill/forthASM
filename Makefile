OS:=$(shell uname -s | cut -f1 -d_ )

aflagsLinux= -f elf
aflagsDarwin= -f elf32

ldflagsLinux= --dynamic-linker /lib/ld-linux.so.2 -m elf_i386
ldflagsDarwin= -arch i386 -macosx_version_min 10.11

# LIBS=/usr/lib/gcc/x86_64-linux-gnu/5

export aflags = $(aflags$(OS))
export ldflugs = $(ldflags$(OS))

LDFLAGS+= $(ldflugs)
LDFLAGS+= -lc

all: forth

forth.o: forth.asm
	nasm $(aflags) $< -o $@

%.o: %.c
	gcc -c -m32 -o $@ $<

forth: forth.o interpret.o
	ld $(LDFLAGS) -o $@ $^

clean:
	rm -f *.o forth
