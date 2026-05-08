AS := as
LD := ld

.PHONY: all clean

all: ved

ved: ved.o
	$(LD) -o $@ $<

ved.o: ved.s
	$(AS) --64 -o $@ $<

clean:
	rm -f ved ved.o
