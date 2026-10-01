# ---------------------------------------------------------
# RISC-V CPU Makefile
# Supports Siemens Questa (vsim), Cadence Xcelium (xrun),
# and Verilator (linting).
# ---------------------------------------------------------

# Project structure
SRC_DIR := src
INC_DIR := include
TB_DIR  := tb

# Files (Order is critical: Packages, Interfaces, then Sources)
PKG     := $(INC_DIR)/riscv_pkg.sv
IF      := $(INC_DIR)/cpu_bus_if.sv
SRCS    := $(wildcard $(SRC_DIR)/*.sv)
TB_SRC  := $(TB_DIR)/tb_top.sv

# The hex program to load into SRAM
PROG_HEX ?= program.hex

.PHONY: all help vsim vsim-gui xrun xrun-gui lint clean

all: help

help:
	@echo "Makefile Targets:"
	@echo "  make vsim      - Compile and run simulation using Siemens Questa/ModelSim (CLI)"
	@echo "  make vsim-gui  - Compile and run simulation using Siemens Questa/ModelSim (GUI)"
	@echo "  make xrun      - Compile and run simulation using Cadence Xcelium (CLI)"
	@echo "  make xrun-gui  - Compile and run simulation using Cadence Xcelium (GUI)"
	@echo "  make lint      - Lint the SV source code using Verilator"
	@echo "  make clean     - Remove all build and simulation artifacts"

# ---------------------------------------------------------
# Siemens Questa / ModelSim Flow
# ---------------------------------------------------------
vsim: $(TB_SRC)
	vlib work
	vlog -sv +incdir+$(INC_DIR) $(PKG) $(IF) $(SRCS) $(TB_SRC)
	vsim -c -voptargs="+acc" tb_top -do "run -all; exit"

vsim-gui: $(TB_SRC)
	vlib work
	vlog -sv +incdir+$(INC_DIR) $(PKG) $(IF) $(SRCS) $(TB_SRC)
	vsim -gui -voptargs="+acc" tb_top -gINIT_FILE=$(PROG_HEX) -do "add wave -r /*; run -all"

# ---------------------------------------------------------
# Cadence Xcelium Flow
# ---------------------------------------------------------
xrun: $(TB_SRC)
	xrun -sv -64bit -access +rw +incdir+$(INC_DIR) \
		$(PKG) $(IF) $(SRCS) $(TB_SRC) \
		-defparam tb_top.dut.INIT_FILE=\"$(PROG_HEX)\" \
		-run

xrun-gui: $(TB_SRC)
	xrun -sv -64bit -access +rw +incdir+$(INC_DIR) \
		$(PKG) $(IF) $(SRCS) $(TB_SRC) \
		-defparam tb_top.dut.INIT_FILE=\"$(PROG_HEX)\" \
		-gui -linedebug

# ---------------------------------------------------------
# Open-Source Flow (Verilator Linting)
# ---------------------------------------------------------
lint:
	verilator --lint-only -sv -I$(INC_DIR) $(PKG) $(IF) $(SRCS) --top-module riscv_top

# ---------------------------------------------------------
# Cleanup
# ---------------------------------------------------------
clean:
	rm -rf work transcript vsim.wlf *.log *.key
	rm -rf xcelium.d xrun.history xrun.log waves.vcd
	rm -rf obj_dir