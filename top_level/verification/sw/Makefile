# Basic Makefile for AFT SoC Top-Level Software Tests
TOOLCHAIN_PREFIX ?= riscv64-unknown-elf-
CC = $(TOOLCHAIN_PREFIX)gcc
OBJCOPY = $(TOOLCHAIN_PREFIX)objcopy
OBJDUMP = $(TOOLCHAIN_PREFIX)objdump

CFLAGS = -march=rv32i -mabi=ilp32 -mcmodel=medany -ffunction-sections -fdata-sections -O2 -Iinclude
LDFLAGS = -T common/link.ld -nostartfiles -Wl,--gc-sections

TESTS = uart gpio timer spi i2c dma pwm digital_io_mux sram_controller interrupt_controller ff_ram
COMMON_SRC = common/start.S

all: $(TESTS)

$(TESTS): %: %/main.elf %/main.hex %/main.dump

%/main.elf: %/main.c $(COMMON_SRC)
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@

%/main.hex: %/main.elf
	$(OBJCOPY) -O verilog $< $@

%/main.dump: %/main.elf
	$(OBJDUMP) -D $< > $@

clean:
	rm -f */*.elf */*.hex */*.dump

.PHONY: all clean $(TESTS)
