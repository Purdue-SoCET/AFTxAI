# Makefile for DMA Verification

# Tools
VCS = vcs
XRUN = xrun
VLOG = vlog
VSIM = vsim

# Source paths
RTL_DIR = ../rtl
INC_DIR = ../include
BUS_DIR = ../../../bus
TB_DIR = tb

# Files
# APB and AHB interfaces
IF_FILES = $(BUS_DIR)/apb/include/apb_if.sv $(BUS_DIR)/ahb/include/ahb_if.sv $(INC_DIR)/memArb_if.sv
# RTL files
RTL_FILES = $(RTL_DIR)/memArbiter.sv $(RTL_DIR)/fifo.sv $(RTL_DIR)/counter.sv \
            $(RTL_DIR)/read_control.sv $(RTL_DIR)/write_control.sv \
            $(RTL_DIR)/registers.sv $(RTL_DIR)/dma_controller.sv
# TB file
TB_FILES = $(TB_DIR)/tb_dma.sv

ALL_FILES = $(IF_FILES) $(RTL_FILES) $(TB_FILES)

# Include directories
INCDIRS = +incdir+$(INC_DIR) +incdir+$(BUS_DIR)/ahb/include +incdir+$(BUS_DIR)/apb/include

.PHONY: all lint sim regress cov clean

all: sim

lint:
	verilator --lint-only -Wall --timing -Wno-fatal -Wno-DECLFILENAME -Wno-WIDTHTRUNC -Wno-COVERIGN $(INCDIRS) $(ALL_FILES)

sim:
	# Running with Xcelium (xrun) as requested by NEX environment
	xrun -sv -64bit -access +rwc -timescale 1ns/1ps $(INCDIRS) $(ALL_FILES)

regress:
	@echo "Running full regression (Smoke test for now)..."
	make sim

cov:
	xrun -sv -64bit -access +rwc -timescale 1ns/1ps -coverage all -covoverwrite $(INCDIRS) $(ALL_FILES)

clean:
	rm -rf xcelium.d xrun.history xrun.log INCA_libs waves.shm cov_work *.key *.err
