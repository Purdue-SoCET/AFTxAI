# Makefile for GPIO Peripheral

BUILD_DIR = build
WORK_DIR = $(BUILD_DIR)/work
VLOG = vlog
VSIM = vsim
VERILATOR = verilator

# Paths
SRC_DIR = src
TB_DIR = tb
INC_DIR = include
BUS_INC = ../../bus/include
LIB_INC = ../../digital_lib/src

# Source files
RTL_SRC = $(LIB_INC)/sync_2ff.sv $(SRC_DIR)/gpio_apb.sv
TB_SRC = $(TB_DIR)/gpio_tb.sv
UVM_TB_SRC = $(BUS_INC)/apb4_if.sv $(TB_DIR)/gpio_uvm_pkg.sv $(TB_DIR)/gpio_uvm_tb.sv

TEST ?= gpio_base_test
SEED ?= random

# Verilator lint
.PHONY: lint
lint:
	$(VERILATOR) --lint-only -Wall -Wno-DECLFILENAME --top-module gpio_apb \
		-I$(INC_DIR) -I$(BUS_INC) -I$(LIB_INC) \
		$(RTL_SRC)

# Coverage setup
.PHONY: build_cov
build_cov:
	mkdir -p $(BUILD_DIR)
	vlib $(WORK_DIR)
	$(VLOG) -work $(WORK_DIR) -sv -mfcu +incdir+$(INC_DIR) +incdir+$(BUS_INC) +incdir+$(LIB_INC) \
		+cover=bcesft $(RTL_SRC) $(TB_SRC) $(UVM_TB_SRC)

# Simulation setup
.PHONY: build_sim
build_sim:
	mkdir -p $(BUILD_DIR)
	vlib $(WORK_DIR)
	$(VLOG) -work $(WORK_DIR) -sv -mfcu +incdir+$(INC_DIR) +incdir+$(BUS_INC) +incdir+$(LIB_INC) \
		$(RTL_SRC) $(TB_SRC) $(UVM_TB_SRC)

# Run one test
.PHONY: sim
sim: build_sim
	cd $(BUILD_DIR) && $(VSIM) -c -do "onbreak {quit -f -code 1}; onerror {quit -f -code 1}; run -all; quit -code 0" \
		work.gpio_uvm_tb +UVM_TESTNAME=$(TEST) +UVM_MAX_QUIT_COUNT=1 -sv_seed $(SEED) -l sim.log
	@awk '/^# UVM_FATAL / && !/: +[0-9]+$$/ {f=1} /^# UVM_ERROR / && !/: +[0-9]+$$/ {e=1} /^# \*\* (Error|Fatal):/ {r=1} END {if(f||e||r) {print "Errors detected in log"; exit 1}}' $(BUILD_DIR)/sim.log

.PHONY: sim_tb
sim_tb: build_sim
	cd $(BUILD_DIR) && $(VSIM) -c -do "onbreak {quit -f -code 1}; onerror {quit -f -code 1}; run -all; quit -code 0" \
		work.gpio_tb -sv_seed $(SEED) -l sim_tb.log
	@awk '/^# \*\* (Error|Fatal):/ {r=1} END {if(r) {print "Errors detected in log"; exit 1}}' $(BUILD_DIR)/sim_tb.log

# Run one test with verilator
.PHONY: sim_verilator
sim_verilator:
	mkdir -p $(BUILD_DIR)/obj_dir
	$(VERILATOR) --Mdir $(BUILD_DIR)/obj_dir --cc --exe --build -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL --top-module gpio_tb \
		--binary -I$(INC_DIR) -I$(BUS_INC) -I$(LIB_INC) -GGPIO_WIDTH=$(WIDTH) \
		$(RTL_SRC) $(TB_SRC)
	./$(BUILD_DIR)/obj_dir/Vgpio_tb

# Default run (sim uses Questa, fallback to verilator if requested, or just use regress_verilator)
.PHONY: regress_verilator
regress_verilator:
	@echo "Running regression with Verilator..."
	$(MAKE) sim_verilator WIDTH=32
	$(MAKE) sim_verilator WIDTH=1
	$(MAKE) sim_verilator WIDTH=7
	$(MAKE) sim_verilator WIDTH=16
	$(MAKE) sim_verilator WIDTH=31

# Run with waves
.PHONY: wave
wave: build_sim
	cd $(BUILD_DIR) && $(VSIM) -voptargs="+acc" -do "log -r /*; run -all; quit" work.gpio_tb +UVM_TESTNAME=$(TEST) -sv_seed $(SEED)

# Coverage
.PHONY: cov
cov: build_cov
	cd $(BUILD_DIR) && $(VSIM) -c -coverage -do "onbreak {quit -f -code 1}; onerror {quit -f -code 1}; coverage save -onexit cov_tb.ucdb; run -all; quit -code 0" \
		work.gpio_tb -sv_seed $(SEED) -l cov_tb.log
	@awk '/^# \*\* (Error|Fatal):/ {r=1} END {if(r) {print "Errors detected in log"; exit 1}}' $(BUILD_DIR)/cov_tb.log
	cd $(BUILD_DIR) && $(VSIM) -c -coverage -do "onbreak {quit -f -code 1}; onerror {quit -f -code 1}; coverage save -onexit cov_uvm.ucdb; run -all; quit -code 0" \
		work.gpio_uvm_tb +UVM_TESTNAME=$(TEST) +UVM_MAX_QUIT_COUNT=1 -sv_seed $(SEED) -l cov_uvm.log
	@awk '/^# UVM_FATAL / && !/: +[0-9]+$$/ {f=1} /^# UVM_ERROR / && !/: +[0-9]+$$/ {e=1} /^# \*\* (Error|Fatal):/ {r=1} END {if(f||e||r) {print "Errors detected in log"; exit 1}}' $(BUILD_DIR)/cov_uvm.log
	cd $(BUILD_DIR) && vcover merge cov.ucdb cov_tb.ucdb cov_uvm.ucdb
	cd $(BUILD_DIR) && vcover report -html cov.ucdb -details

# Regression
.PHONY: regress
regress:
	@echo "Running regression..."
	$(MAKE) sim_tb
	$(MAKE) sim TEST=gpio_base_test

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR) obj_dir transcript vsim.wlf cov.ucdb covhtmlreport
