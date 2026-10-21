VERILATOR = verilator
VFLAGS = --lint-only -Wall -Wno-DECLFILENAME -Wno-VARHIDDEN -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -I../../bus/include

SRC = src/pwm_core.sv
TB_SRC = tb/pwm_if.sv tb/pwm_uvm_pkg.sv tb/pwm_tb.sv
INC = +incdir+../../bus/include +incdir+tb

.PHONY: all lint clean sim_tb sim regress cov

all: lint

lint:
	$(VERILATOR) $(VFLAGS) $(SRC)

sim_tb:
	vlib work
	vlog -sv $(INC) ../../bus/include/apb4_if.sv $(SRC) $(TB_SRC)

sim: sim_tb
	vsim -c -voptargs="+acc" -sv_seed $(SEED) -do "coverage save -onexit cov_$(TEST)_$(SEED).ucdb; run -all; quit -f" +UVM_TESTNAME=$(TEST) work.pwm_tb

regress: sim_tb
	vsim -c -voptargs="+acc" -sv_seed 1 -do "coverage save -onexit cov_1.ucdb; run -all; quit -f" +UVM_TESTNAME=pwm_base_test work.pwm_tb
	vsim -c -voptargs="+acc" -sv_seed 7 -do "coverage save -onexit cov_7.ucdb; run -all; quit -f" +UVM_TESTNAME=pwm_base_test work.pwm_tb
	vsim -c -voptargs="+acc" -sv_seed 23 -do "coverage save -onexit cov_23.ucdb; run -all; quit -f" +UVM_TESTNAME=pwm_base_test work.pwm_tb

cov:
	vcover merge merged.ucdb cov_*.ucdb
	vcover report -details merged.ucdb

clean:
	rm -rf build obj_dir work transcript *.wlf *.ucdb vsim.wlf
