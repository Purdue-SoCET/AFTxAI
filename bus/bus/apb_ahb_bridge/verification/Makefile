# Makefile for ahb2apb testbench

XRUN = xrun -sv -64bit -access +rwc -coverage all

RTL = ../ahb2apb.sv
INC = ~/AFTxAI/bus/ahb/include/ahb_if.sv ~/AFTxAI/bus/apb/include/apb_if.sv
TB = tb_ahb2apb.sv

sim:
	module load cadence/xcelium/23.03 && $(XRUN) $(INC) $(RTL) $(TB)

cov:
	module load cadence/xcelium/23.03 && imc &

clean:
	rm -rf xcelium.d xrun.history xrun.log cov_work
