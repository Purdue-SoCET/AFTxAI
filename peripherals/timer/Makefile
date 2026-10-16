# Makefile for Timer APB peripheral

VLIB = vlib
VMAP = vmap
VLOG = vlog
VSIM = vsim
VOPT = vopt
VCOVER = vcover

WORK_DIR = build/work
BUILD_DIR = build
TB_DIR = tb
SRC_DIR = src

RTL_SRC = ../../bus/include/apb4_if.sv ../../digital_lib/src/sync_2ff.sv $(SRC_DIR)/timer_apb.sv
TB_SRC = $(TB_DIR)/timer_tb.sv
UVM_TB_SRC = $(TB_DIR)/timer_uvm_pkg.sv $(TB_DIR)/timer_uvm_tb.sv

SEED ?= 1
TEST ?= test_basic

.PHONY: all clean lint sim_tb sim regress cov wave

all: sim_tb

$(WORK_DIR):
	mkdir -p $(BUILD_DIR)
	$(VLIB) $(WORK_DIR)
	$(VMAP) work $(WORK_DIR)

lint:
	verilator --lint-only -Wall -Wno-DECLFILENAME -I../../bus/include -I../../digital_lib/src $(RTL_SRC)

compile_tb: $(WORK_DIR)
	$(VLOG) -work work -sv +incdir+../../bus/include $(RTL_SRC) $(TB_SRC)

sim_tb: compile_tb
	$(VSIM) -c -do "run -all; quit -f" -l transcript work.timer_tb
	@if grep -q -E "\*\* Fatal:|\*\* Error:" transcript; then echo "Simulation failed!"; exit 1; fi

compile_uvm: $(WORK_DIR)
	$(VLOG) -work work -sv +incdir+../../bus/include $(RTL_SRC) $(UVM_TB_SRC)

sim: compile_uvm
	@echo "onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0" > $(WORK_DIR)/run_uvm.do
	$(VSIM) -c -do $(WORK_DIR)/run_uvm.do -l transcript work.timer_uvm_tb +UVM_TESTNAME=$(TEST) -sv_seed $(SEED)
	@if grep -q -E "UVM_ERROR :[ ]+[1-9]" transcript; then echo "UVM_ERROR failed!"; exit 1; fi
	@if grep -q -E "UVM_FATAL :[ ]+[1-9]" transcript; then echo "UVM_FATAL failed!"; exit 1; fi
	@if grep -q "\*\* Fatal:" transcript; then echo "Simulation failed!"; exit 1; fi
	@if grep -q "\*\* Error:" transcript; then echo "Simulation failed!"; exit 1; fi

cov: $(WORK_DIR)
	$(VLOG) -work work -sv +incdir+../../bus/include +cover=bcesft $(RTL_SRC) $(UVM_TB_SRC)
	$(VSIM) -c -do "coverage save -onexit timer_cov.ucdb; run -all; quit -code 0" work.timer_uvm_tb +UVM_TESTNAME=timer_base_test -sv_seed 1 -coverage
	vcover report -html timer_cov.ucdb -htmldir $(BUILD_DIR)/cov_html

wave: compile_tb
	$(VSIM) -voptargs=+acc work.timer_tb -do "add wave -r /*; run -all"

clean:
	rm -rf $(BUILD_DIR) transcript vsim.wlf modelsim.ini

