# Makefile for CLINT verification
RTL_DIR = ../rtl
INC_DIR = ../include
BUS_INC_DIR = ../../../../bus/generic

SRC = $(BUS_INC_DIR)/bus_protocol_if.sv $(INC_DIR)/clint_if.sv $(RTL_DIR)/clint.sv tb_clint.sv
LINT_SRC = $(BUS_INC_DIR)/bus_protocol_if.sv $(INC_DIR)/clint_if.sv tb_clint.sv

CFG ?= default

lint:
	verilator --lint-only -Wall -Wno-fatal -Wno-DECLFILENAME --top-module tb_clint $(LINT_SRC)

sim:
	mkdir -p build/$(CFG)
	cd build/$(CFG) && xrun -64bit -sv -timescale 1ns/1ns -coverage all -covoverwrite \
		+incdir+../../$(INC_DIR) +incdir+../../$(BUS_INC_DIR) \
		../../$(RTL_DIR)/clint.sv ../../tb_clint.sv

regress:
	make sim CFG=default

cov:
	# Add coverage report command here if needed
	echo "Coverage report target"

clean:
	rm -rf build xcelium.d xrun.history xrun.log
