
AS = nasm
SOURCES := $(wildcard src/*.s)

ASFLAGS := -felf64
LDFLAGS := -z noseparate-code
OBJS := $(wildcard src/*.o)

main:
	$(AS) $(SOURCES) $(ASFLAGS)
	$(LD) $(OBJS) -o smolcat $(LDFLAGS)
	strip smolcat
