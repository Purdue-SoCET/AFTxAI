
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
	vlog -sv $(INC) tb/apb4_if.sv $(SRC) tb/pwm_tb_directed.sv
	vsim -c -voptargs="+acc" -do "run -all; quit -f" work.pwm_tb_directed
	@if grep -q -i "fail\|fatal:" transcript || grep -q "UVM_ERROR : \+[1-9]" transcript || grep -q "UVM_FATAL : \+[1-9]" transcript; then echo "Simulation Failed!"; exit 1; fi

sim:
	vlib work
	vlog -sv -cover bceft $(INC) tb/apb4_if.sv $(SRC) tb/pwm_if.sv tb/pwm_uvm_pkg.sv tb/pwm_tb.sv
	vsim -c -coverage -voptargs="+acc" -sv_seed $(SEED) -do "coverage save -onexit cov_$(TEST)_$(SEED).ucdb; run -all; quit -f" +UVM_TESTNAME=$(TEST) work.pwm_tb
	@if grep -q -i "fail\|fatal:" transcript || grep -q "UVM_ERROR : \+[1-9]" transcript || grep -q "UVM_FATAL : \+[1-9]" transcript; then echo "Simulation Failed!"; exit 1; fi

regress: sim_tb
	$(MAKE) sim TEST=pwm_base_test SEED=1
	$(MAKE) sim TEST=pwm_base_test SEED=7
	$(MAKE) sim TEST=pwm_base_test SEED=23

cov:
	vcover merge merged.ucdb cov_*.ucdb
	vcover report -details merged.ucdb
	vcover report -html -htmldir covhtmlreport merged.ucdb

clean:
	rm -rf build obj_dir work transcript *.wlf *.ucdb vsim.wlf covhtmlreport xcelium.d xrun.history xrun.log

integration-lint:
	$(VERILATOR) $(VFLAGS) -Wno-UNDRIVEN -Wno-UNUSEDSIGNAL -I../../bus/apb/include ../../bus/apb/include/apb_if.sv src/pwm_core.sv src/pwm_apb_wrapper.sv

integration-apb:
	./run_apb_test_xrun.sh

integration-ahb:
	./run_ahb_test_xrun.sh

integration-irq:
	./run_plic_test_xrun.sh

integration-waveform:
	./run_waveform_test_xrun.sh

integration-regress: integration-lint integration-apb integration-ahb integration-irq integration-waveform
