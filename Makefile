ifeq ($(DEBUG),1)
        STABS = -F stabs
endif

PROG = sort

build:
	nasm -f elf64 $(STABS) ./src/$(PROG).asm -o ./target/$(PROG).o
	ld ./target/$(PROG).o -o ./target/$(PROG)
ifeq ($(DEBUG),1)
	cp ./src/$(PROG).asm ./target
endif

clean:
	rm ./target/$(PROG){,.o}

.PHONY: build, clean
