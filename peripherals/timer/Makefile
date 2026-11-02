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

RTL_SRC = ../../bus/apb/include/apb_if.sv ../../digital_lib/src/sync_2ff.sv $(SRC_DIR)/timer_apb.sv $(SRC_DIR)/timer_apb_wrapper.sv
TB_SRC = $(TB_DIR)/timer_tb.sv
UVM_TB_SRC = $(TB_DIR)/timer_uvm_pkg.sv $(TB_DIR)/timer_uvm_tb.sv
INT_RTL_SRC = ../../bus/apb/rtl/apb_interconnect.sv ../../bus/ahb/include/ahb_if.sv ../../bus/bus/apb_ahb_bridge/ahb2apb.sv ../../bus/generic/bus_protocol_if.sv ../../peripherals/interrupt_controller/plic/include/plic_if.sv ../../peripherals/interrupt_controller/plic/rtl/plic.sv
INT_TB_SRC = $(TB_DIR)/timer_apb_integration_tb.sv $(TB_DIR)/timer_ahb_integration_tb.sv $(TB_DIR)/timer_plic_integration_tb.sv $(TB_DIR)/timer_capture_integration_tb.sv $(TB_DIR)/timer_fail_integration_tb.sv

SEED ?= 1
TEST ?= test_basic

.PHONY: all clean lint sim_tb sim regress cov wave

all: sim_tb

$(WORK_DIR):
	mkdir -p $(BUILD_DIR)
	$(VLIB) $(WORK_DIR)
	$(VMAP) work $(WORK_DIR)

lint:
	verilator --lint-only -Wall -Wno-DECLFILENAME -I../../bus/apb/include -I../../digital_lib/src $(RTL_SRC)

compile_tb: $(WORK_DIR)
	$(VLOG) -work work -sv +incdir+../../bus/apb/include $(RTL_SRC) $(TB_SRC)

sim_tb: compile_tb
	@echo "onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0" > $(WORK_DIR)/run_tb.do
	$(VSIM) -c -do $(WORK_DIR)/run_tb.do -l transcript work.timer_tb
	@if grep -q "\*\* Fatal:" transcript; then echo "Simulation failed (Fatal)!"; exit 1; fi
	@if grep -q "\*\* Error:" transcript; then echo "Simulation failed (Error)!"; exit 1; fi

compile_uvm: $(WORK_DIR)
	$(VLOG) -work work -sv +incdir+../../bus/apb/include $(RTL_SRC) $(UVM_TB_SRC)

sim: compile_uvm
	@echo "onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0" > $(WORK_DIR)/run_uvm.do
	$(VSIM) -c -do $(WORK_DIR)/run_uvm.do -l transcript work.timer_uvm_tb +UVM_TESTNAME=$(TEST) -sv_seed $(SEED)
	@if grep -q -E "UVM_ERROR :[ \t]+[1-9]" transcript; then echo "UVM_ERROR failed!"; exit 1; fi
	@if grep -q -E "UVM_FATAL :[ \t]+[1-9]" transcript; then echo "UVM_FATAL failed!"; exit 1; fi
	@if grep -q "\*\* Fatal:" transcript; then echo "Simulation failed (Fatal)!"; exit 1; fi
	@if grep -q "\*\* Error:" transcript; then echo "Simulation failed (Error)!"; exit 1; fi

compile_int: $(WORK_DIR)
	$(VLOG) -suppress 2892 -work work -sv +incdir+../../bus/apb/include +incdir+../../bus/ahb/include +incdir+../../peripherals/interrupt_controller/plic/include $(RTL_SRC) $(INT_RTL_SRC) $(INT_TB_SRC)

sim_int: compile_int
	@echo "onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0" > $(WORK_DIR)/run_int_apb.do
	$(VSIM) -c -do $(WORK_DIR)/run_int_apb.do -l transcript work.timer_apb_integration_tb
	@if grep -q "\*\* Fatal:" transcript; then echo "APB Simulation failed (Fatal)!"; exit 1; fi
	@if grep -q "\*\* Error:" transcript; then echo "APB Simulation failed (Error)!"; exit 1; fi
	@echo "onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0" > $(WORK_DIR)/run_int_ahb.do
	$(VSIM) -c -do $(WORK_DIR)/run_int_ahb.do -l transcript work.timer_ahb_integration_tb
	@if grep -q "\*\* Fatal:" transcript; then echo "AHB Simulation failed (Fatal)!"; exit 1; fi
	@if grep -q "\*\* Error:" transcript; then echo "AHB Simulation failed (Error)!"; exit 1; fi
	@echo "onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0" > $(WORK_DIR)/run_int_plic.do
	$(VSIM) -c -do $(WORK_DIR)/run_int_plic.do -l transcript work.timer_plic_integration_tb
	@if grep -q "\*\* Fatal:" transcript; then echo "PLIC Simulation failed (Fatal)!"; exit 1; fi
	@if grep -q "\*\* Error:" transcript; then echo "PLIC Simulation failed (Error)!"; exit 1; fi
	@echo "onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0" > $(WORK_DIR)/run_int_capture.do
	$(VSIM) -c -do $(WORK_DIR)/run_int_capture.do -l transcript work.timer_capture_integration_tb
	@if grep -q "\*\* Fatal:" transcript; then echo "Capture Simulation failed (Fatal)!"; exit 1; fi
	@if grep -q "\*\* Error:" transcript; then echo "Capture Simulation failed (Error)!"; exit 1; fi
	@echo "Running Negative Test..."
	@echo "onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0" > $(WORK_DIR)/run_int_fail.do
	@if $(VSIM) -c -do $(WORK_DIR)/run_int_fail.do -l transcript work.timer_fail_integration_tb; then \
		if grep -q "\*\* Error:" transcript; then echo "Negative test successfully caught error."; else echo "Negative test failed to fail!"; exit 1; fi \
	else \
		echo "Negative test exited non-zero as expected."; \
	fi

regress:
	@echo "Running Directed Tests..."
	$(MAKE) sim_tb
	@echo "Running UVM Basic Test..."
	$(MAKE) sim TEST=timer_base_test SEED=1
	$(MAKE) sim TEST=timer_base_test SEED=7
	$(MAKE) sim TEST=timer_base_test SEED=23
	@echo "Running APB Integration Test..."
	$(MAKE) sim_int
	@echo "Regression PASSED"

cov: $(WORK_DIR)
	$(VLOG) -work work -sv +incdir+../../bus/apb/include +cover=bcesft $(RTL_SRC) $(UVM_TB_SRC)
	$(VSIM) -c -do "coverage save -onexit timer_cov.ucdb; run -all; quit -code 0" work.timer_uvm_tb +UVM_TESTNAME=timer_base_test -sv_seed 1 -coverage
	vcover report -html timer_cov.ucdb -htmldir $(BUILD_DIR)/cov_html

wave: compile_tb
	$(VSIM) -voptargs=+acc work.timer_tb -do "add wave -r /*; run -all"

clean:
	rm -rf $(BUILD_DIR) transcript vsim.wlf modelsim.ini

