CROSS_COMPILE ?= riscv64-unknown-elf-
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump

# As per RISCV.md: RV32I build
CFLAGS = -march=rv32ia_zicsr_zifencei -mabi=ilp32 -nostdlib -nostartfiles -T link.ld -g
CFLAGS_RV32E = -march=rv32ea_zicsr_zifencei -mabi=ilp32e -nostdlib -nostartfiles -T link.ld -g

SRCS = $(wildcard *.S)
ELFS = $(SRCS:.S=.elf)
DUMPS = $(SRCS:.S=.dump)
HEXS = $(SRCS:.S=.hex)

all: $(ELFS) $(DUMPS) $(HEXS) test_rv32e.elf

%.elf: %.S
	$(CC) $(CFLAGS) $< -o $@

test_rv32e.elf: test_base.S
	$(CC) $(CFLAGS_RV32E) $< -o $@

%.dump: %.elf
	$(OBJDUMP) -D $< > $@

%.hex: %.elf
	$(OBJCOPY) -O verilog $< $@.tmp
	python3 hex2word.py $@.tmp $@
	rm $@.tmp

clean:
	rm -f *.elf *.dump *.hex

.PHONY: all clean
