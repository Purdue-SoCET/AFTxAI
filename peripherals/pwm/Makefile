
VERILATOR = verilator
VFLAGS = --lint-only -Wall -Wno-DECLFILENAME -Wno-VARHIDDEN -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -I../../bus/include

SRC = src/pwm_core.sv
INC = +incdir+../../bus/include +incdir+tb

.PHONY: all lint clean sim_tb sim regress cov

TEST ?= pwm_base_test
SEED ?= 1

all: lint

lint:
	$(VERILATOR) $(VFLAGS) $(SRC)

sim_tb:
	vlib work
	vlog -sv $(INC) ../../bus/include/apb4_if.sv $(SRC) tb/pwm_tb_directed.sv
	vsim -c -voptargs="+acc" -do "run -all; quit -f" work.pwm_tb_directed

sim:
	vlib work
	vlog -sv -cover bceft $(INC) ../../bus/include/apb4_if.sv $(SRC) tb/pwm_if.sv tb/pwm_uvm_pkg.sv tb/pwm_tb.sv
	vsim -c -coverage -voptargs="+acc" -sv_seed $(SEED) -do "coverage save -onexit cov_$(TEST)_$(SEED).ucdb; run -all; quit -f" +UVM_TESTNAME=$(TEST) work.pwm_tb

regress: sim_tb
	$(MAKE) sim TEST=pwm_base_test SEED=1
	$(MAKE) sim TEST=pwm_base_test SEED=7
	$(MAKE) sim TEST=pwm_base_test SEED=23

cov:
	vcover merge merged.ucdb cov_*.ucdb
	vcover report -details merged.ucdb
	vcover report -html -htmldir covhtmlreport merged.ucdb

clean:
	rm -rf build obj_dir work transcript *.wlf *.ucdb vsim.wlf covhtmlreport
