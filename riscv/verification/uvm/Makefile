# Makefile for UVM simulation
# Uses Cadence Xcelium by default (xrun), fallback for Siemens Questa (make questa)

all: xrun

xrun:
	xrun -sv -uvm riscv_if.sv riscv_pkg.sv tb_top.sv +UVM_TESTNAME=riscv_test

questa:
	vlib work
	vlog -sv -mfcu riscv_if.sv riscv_pkg.sv tb_top.sv
	vsim -c -do "run -all; quit" tb_top +UVM_TESTNAME=riscv_test

clean:
	rm -rf work transcript vsim.wlf xcelium.d xrun.*
