#!/bin/bash
set -e

# Compile the software tests
echo "Building software tests..."
cd sw
make clean
make
cd ..

# Check module for xrun
module load cadence/xcelium/23.03

# Directories for includes
INC_DIRS="-incdir ../../bus/ahb/include -incdir ../../bus/apb/include -incdir ../../bus/generic -incdir ../../peripherals/sram_controller/include -incdir ../map -incdir ../../riscv/include -incdir ../../peripherals/interrupt_controller/clint/include -incdir ../../peripherals/interrupt_controller/plic/include -incdir ../../peripherals/spi/include -incdir ../../peripherals/digital_io_mux/include"

# Files to compile
SRC_FILES="../../top_level/map/aft_map_pkg.sv \
../../bus/ahb/include/ahb_pkg.sv \
../../bus/generic/bus_protocol_if.sv \
../../bus/ahb/include/ahb_if.sv \
../../bus/apb/include/apb_if.sv \
../../peripherals/sram_controller/include/sram_if.sv \
../../riscv/include/bus_ahbm_if.sv \
../../riscv/include/riscv_if.sv \
../../peripherals/interrupt_controller/clint/include/clint_if.sv \
../../peripherals/interrupt_controller/plic/include/plic_if.sv \
../../peripherals/dma/include/memArb_if.sv \
../../peripherals/spi/include/spi_types_pkg.sv \
../../peripherals/uart/include/uart_if.sv \
../../peripherals/spi/include/spi_if.sv \
../../peripherals/i2c/include/i2c_if.sv \
../../digital_lib/src/*.sv \
../../digital_lib/*.sv \
../../riscv/include/*.sv \
../../riscv/rtl/datapath/*.sv \
../../riscv/rtl/caches/*.sv \
../../riscv/rtl/memory/*.sv \
../../riscv/rtl/*.sv \
../../peripherals/dma/rtl/*.sv \
../../bus/bridge/rtl/*.sv \
../../bus/ahb/ahb_interconnect/*.sv \
../../bus/ahb/ahb_manager/*.sv \
../../bus/ahb/ahb_subordinate/*.sv \
../../bus/apb/rtl/*.sv \
../../peripherals/ff_ram/rtl/*.sv \
../../peripherals/sram_controller/rtl/*.sv \
../../peripherals/digital_io_mux/rtl/digital_io_mux_apb.sv \
../../peripherals/digital_io_mux/rtl/digital_io_mux_cell.sv \
../../peripherals/digital_io_mux/rtl/digital_io_mux.sv \
../../peripherals/gpio/src/*.sv \
../../peripherals/pwm/src/*.sv \
../../peripherals/timer/src/*.sv \
../../peripherals/spi/rtl/*.sv \
../../peripherals/i2c/rtl/i2c_engine.sv \
../../peripherals/i2c/rtl/i2c_regs.sv \
../../peripherals/i2c/rtl/i2c.sv \
../../peripherals/uart/rtl/*.sv \
../../peripherals/interrupt_controller/clint/rtl/*.sv \
../../peripherals/interrupt_controller/plic/rtl/plic.sv \
../rtl/*.sv \
tb/top_tb.sv"

# Tests to run
if [ -n "$1" ]; then
    TESTS=("$1")
else
    # Find all compiled hex files if no argument is given
    TESTS=(sw/*/*.hex)
fi

FAILURES=0

for TEST_HEX in "${TESTS[@]}"; do
    echo "======================================================================"
    echo "Running simulation with $TEST_HEX..."
    echo "======================================================================"
    
    LOG_FILE="xrun_$(basename $(dirname $TEST_HEX)).log"
    
    # Run xrun and save output to log file
    xrun -top top_tb -timescale 1ns/1ps -sv $INC_DIRS $SRC_FILES -access +rwc +test_hex=$TEST_HEX -exit -gateloopwarn -loopunroll -l $LOG_FILE
    
    # Check log for failure signatures
    if grep -q "Test Failed\|ERROR: Test Timeout" "$LOG_FILE"; then
        echo "ERROR: Simulation failed for $TEST_HEX (see $LOG_FILE)"
        FAILURES=$((FAILURES + 1))
    fi
done

if [ "$FAILURES" -ne 0 ]; then
    echo "$FAILURES test(s) failed."
    exit 1
else
    echo "All tests completed successfully."
fi