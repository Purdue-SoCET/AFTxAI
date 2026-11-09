#!/bin/bash
set -e

# Load modules
#source /etc/profile.d/modules.sh || true
module load riscv-gcc/13.2.0
module load cadence/xcelium/23.03

cd "$(dirname "$0")"

TESTS=("main" "bitwise_alu" "matrix_mult" "comprehensive" "csr_test")

for TEST in "${TESTS[@]}"; do
    echo "========================================"
    echo "Running test: $TEST"
    echo "========================================"
    
    # Compile C to ELF
    riscv64-unknown-elf-gcc -march=rv32i_zicsr -mabi=ilp32 -T cFiles/link.ld -nostdlib cFiles/crt0.s cFiles/${TEST}.c -o cFiles/${TEST}.elf
    
    # Convert ELF to Verilog hex (32-bit words)
    riscv64-unknown-elf-objcopy -O verilog --verilog-data-width=4 cFiles/${TEST}.elf mem.hex
    
    # Run simulation
    ./run_xrun.sh | grep -E "SUCCESS|FAILURE|TIMEOUT|Error"
    
    echo ""
done
