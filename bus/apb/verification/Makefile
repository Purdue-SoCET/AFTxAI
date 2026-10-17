# APB Verification Makefile
CFG ?= default

# Tools are provided through environment modules.
# Ensure `module load cadence/xcelium/23.03` is run before make.
XRUN = xrun
XRUN_FLAGS = -sv -access +rwc -timescale 1ns/1ps -I../include -I../../generic

SRC_IF = ../include/apb_if.sv ../../generic/bus_protocol_if.sv
SRC_RTL = $(wildcard ../rtl/*.sv)
SRC_TB = tb_apb.sv

.PHONY: all lint sim regress cov clean

all: lint

lint:
	$(XRUN) -compile $(XRUN_FLAGS) $(SRC_IF) $(SRC_RTL) $(SRC_TB)

sim:
	$(XRUN) $(XRUN_FLAGS) $(SRC_IF) $(SRC_RTL) $(SRC_TB) -covoverwrite -coverage all -covtest $(CFG)

regress: sim

cov:
	@echo "Coverage configured. Run imc to view cov_work."

clean:
	rm -rf xcelium.d xrun.history xrun.log cov_work
