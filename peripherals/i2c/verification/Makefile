TB_DIR ?= $(PWD)
PROJ_ROOT ?= $(TB_DIR)/../../..
BUILD_DIR ?= $(TB_DIR)/../build

# Interfaces
INC_DIRS = -incdir $(PROJ_ROOT)/bus/apb/include -incdir $(PROJ_ROOT)/bus/generic -incdir $(TB_DIR)/../include

# Source files
IF_SRCS = $(PROJ_ROOT)/bus/apb/include/apb_if.sv $(PROJ_ROOT)/bus/generic/bus_protocol_if.sv $(TB_DIR)/../include/i2c_if.sv
COMPLETER_SRC = $(PROJ_ROOT)/bus/apb/rtl/apb_completer.sv
TB_SRCS = $(TB_DIR)/i2c_target_model.sv $(TB_DIR)/tb_i2c.sv
RTL_SRCS = $(wildcard $(TB_DIR)/../rtl/*.sv)

# Targets
.PHONY: lint sim regress cov clean

lint:
	@mkdir -p $(BUILD_DIR)
	bash -l -c "module load cadence/xcelium/23.03 && xrun -timescale 1ns/1ps -compile -sv $(INC_DIRS) $(IF_SRCS) $(COMPLETER_SRC) $(TB_SRCS) $(RTL_SRCS)" | tee $(BUILD_DIR)/lint.log

sim:
	@mkdir -p $(BUILD_DIR)
	bash -l -c "module load cadence/xcelium/23.03 && xrun -timescale 1ns/1ps -sv $(INC_DIRS) $(IF_SRCS) $(COMPLETER_SRC) $(TB_SRCS) $(RTL_SRCS) +define+SIMULATION" | tee $(BUILD_DIR)/sim.log

regress:
	@echo "regress - Runs all CFG permutations."

cov:
	@mkdir -p $(BUILD_DIR)
	bash -l -c "module load cadence/xcelium/23.03 && xrun -timescale 1ns/1ps -sv -coverage all $(INC_DIRS) $(IF_SRCS) $(COMPLETER_SRC) $(TB_SRCS) $(RTL_SRCS)" | tee $(BUILD_DIR)/cov.log

clean:
	rm -rf $(BUILD_DIR)
