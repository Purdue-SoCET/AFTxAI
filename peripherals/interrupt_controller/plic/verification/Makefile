# Makefile for PLIC Verification

TB = tb_plic
RTL_DIR = ../rtl
INC_DIR = ../include
BUS_INC = ../../../../bus/generic

VFLAGS = --binary -j 0 --trace --assert -Wno-fatal -Wall -Wno-UNDRIVEN -Wno-UNUSEDSIGNAL
VFLAGS += -I$(INC_DIR) -I$(BUS_INC)

SOURCES = $(INC_DIR)/plic_if.sv $(BUS_INC)/bus_protocol_if.sv $(RTL_DIR)/plic.sv $(TB).sv

all: sim

build/V$(TB): $(SOURCES)
	verilator $(VFLAGS) --top-module $(TB) $(SOURCES) -Mdir build

sim: build/V$(TB)
	./build/V$(TB) +trace

lint:
	verilator --lint-only -Wall -Wno-UNDRIVEN -Wno-UNUSEDSIGNAL --top-module plic -I$(BUS_INC) -I$(INC_DIR) $(INC_DIR)/plic_if.sv $(BUS_INC)/bus_protocol_if.sv $(RTL_DIR)/plic.sv

clean:
	rm -rf build xcelium.d xrun.log xrun.history

# UVM execution using Xcelium
XRUN_ARGS = -64bit -sv -uvm -timescale 1ns/1ps
XRUN_ARGS += +incdir+$(INC_DIR) +incdir+$(BUS_INC) +incdir+uvm
XRUN_ARGS += $(BUS_INC)/bus_protocol_if.sv $(INC_DIR)/plic_if.sv
XRUN_ARGS += $(RTL_DIR)/plic.sv
XRUN_ARGS += uvm/plic_uvm_pkg.sv uvm/tb_uvm_top.sv
XRUN_ARGS += -access +rwc
XRUN_ARGS += +UVM_TESTNAME=plic_sanity_test

sim_uvm:
	xrun $(XRUN_ARGS)