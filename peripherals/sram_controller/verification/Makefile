.PHONY: lint sim regress cov clean

RTL_DIR = ../rtl
INC_DIR = ../include
TB_DIR = tb
BUS_DIR = ../../../bus/generic
LIB_DIR = ../../../digital_lib

SRC_FILES = $(BUS_DIR)/bus_protocol_if.sv $(INC_DIR)/sram_if.sv $(LIB_DIR)/counter.sv $(RTL_DIR)/sram_controller.sv $(TB_DIR)/tb_sram_controller.sv

lint:
	verilator --lint-only -Wall -Wno-UNDRIVEN -Wno-UNUSEDSIGNAL -Wno-TIMESCALEMOD -I$(BUS_DIR) -I$(LIB_DIR) -I$(INC_DIR) $(BUS_DIR)/bus_protocol_if.sv $(INC_DIR)/sram_if.sv $(LIB_DIR)/counter.sv $(RTL_DIR)/sram_controller.sv

sim:
	xrun -64bit -sv -timescale 1ns/1ps -I$(BUS_DIR) -I$(LIB_DIR) -I$(INC_DIR) $(SRC_FILES)

regress: sim

cov:
	xrun -64bit -sv -timescale 1ns/1ps -I$(BUS_DIR) -I$(LIB_DIR) -I$(INC_DIR) $(SRC_FILES) -coverage all -covoverwrite

clean:
	rm -rf build xcelium.d xrun.history xrun.log cov_work