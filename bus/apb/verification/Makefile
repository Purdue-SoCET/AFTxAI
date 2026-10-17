SIM_OPTS = -access +rwc -uvm -timescale 1ns/1ps
COV_OPTS = -covoverwrite -coverage all

SRC = ../../include/apb_if.sv \
      ../../rtl/apb_interconnect.sv \
      apb_sva.sv \
      apb_pkg.sv \
      tb_top.sv

TEST ?= sanity_test

.PHONY: all sim regress cov clean

all: sim

sim:
	xrun $(SIM_OPTS) $(COV_OPTS) -covtest $(TEST) $(SRC) +UVM_TESTNAME=$(TEST)

regress:
	-make sim TEST=sanity_test
	-make sim TEST=unmapped_test
	-make sim TEST=boundary_test
	-make sim TEST=wait_state_test
	-make sim TEST=slverr_test
	-make sim TEST=b2b_test
	-make sim TEST=full_random_test
	-make sim TEST=reset_test

cov:
	imc -execcmd "merge cov_work/scope/* -out cov_work/merged; report -summary -out coverage_summary.txt; exit"

clean:
	rm -rf xcelium.d xrun.history xrun.log cov_work coverage_summary.txt
