SIM_OPTS = -access +rwc -uvm -timescale 1ns/1ps +incdir+agent+env+sequences

COV_OPTS = -covoverwrite -coverage all

UVM_SRC = ../include/apb_if.sv \
      ../rtl/apb_interconnect.sv \
      tb/apb_sva.sv \
      apb_uvm_pkg.sv \
      tb/tb_uvm_top.sv

DIRECTED_SRC = ../../generic/bus_protocol_if.sv \
               ../include/apb_if.sv \
               ../rtl/apb_interconnect.sv \
               ../rtl/apb_requester.sv \
               ../rtl/apb_completer.sv \
               tb/tb_apb_top.sv

TEST ?= sanity_test

.PHONY: all sim sim_directed regress cov clean

all: sim

sim:
	xrun $(SIM_OPTS) $(COV_OPTS) -covtest $(TEST) $(UVM_SRC) +UVM_TESTNAME=$(TEST)

sim_directed:
	xrun -access +rwc -timescale 1ns/1ps $(COV_OPTS) -covtest directed $(DIRECTED_SRC)

regress:
	-make sim_directed
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
