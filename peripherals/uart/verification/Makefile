# UART Testbench Makefile

# Variables
SIM ?= xrun
TOP = tb_uart
SRC_DIR = ../rtl
INC_DIR = ../include
BUS_DIR = ../../../bus/ahb/include

SRCS = \
	$(BUS_DIR)/ahb_if.sv \
	$(INC_DIR)/uart_if.sv \
	$(SRC_DIR)/uart_fifo.sv \
	$(SRC_DIR)/uart_tx.sv \
	$(SRC_DIR)/uart_rx.sv \
	$(SRC_DIR)/uart.sv \
	tb_uart.sv

XRUN_ARGS = -64bit -sv -access +rwc -timescale 1ns/1ps -exit -incdir $(INC_DIR) -incdir $(BUS_DIR) -coverage all -covoverwrite

.PHONY: all lint sim regress cov clean

all: sim

lint:
	# Using Verilator for fast linting
	verilator --lint-only --timing -sv -I$(INC_DIR) -I$(BUS_DIR) $(SRCS) -Wno-fatal -Wno-COVERIGN -Wno-WIDTHTRUNC

sim:
	$(SIM) $(XRUN_ARGS) $(SRCS)

regress: sim
	# In a full setup, this would loop over configurations

cov:
	# Coverage reporting (Xcelium typical flow or imc)
	imc -execcmd "load -run test ; report -summary -out coverage_summary.txt" || true

clean:
	rm -rf xcelium.d xrun.log xrun.history cov_work coverage_summary.txt
