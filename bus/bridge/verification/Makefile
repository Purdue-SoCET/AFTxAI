VCS = xrun

# Default parameters
SIM_ARGS = -sv -access +rwc -timescale 1ns/1ps -warn_multiple_driver -exit
COV_ARGS = -coverage all -covoverwrite

INCDIRS = -incdir ../../ahb/include -incdir ../../apb/include
IF_FILES = ../../ahb/include/ahb_if.sv ../../apb/include/apb_if.sv
RTL_FILES = ../rtl/ahb2apb.sv
TB_FILES = tb_ahb2apb.sv

lint:
	verilator --lint-only -Wall -Wno-fatal -sv $(INCDIRS) $(IF_FILES) $(RTL_FILES) $(TB_FILES) --top-module tb_ahb2apb || true

sim:
	$(VCS) $(SIM_ARGS) $(INCDIRS) $(IF_FILES) $(RTL_FILES) $(TB_FILES) -top tb_ahb2apb

cov:
	$(VCS) $(SIM_ARGS) $(COV_ARGS) $(INCDIRS) $(IF_FILES) $(RTL_FILES) $(TB_FILES) -top tb_ahb2apb

clean:
	rm -rf xcelium.d xrun.history xrun.log cov_work *.key
