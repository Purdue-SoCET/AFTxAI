#!/bin/bash
set -e

cd riscv/verification/tb

# Compile everything once
vlib work
vlog -sv -f filelist.f tb_alu.sv tb_regfile.sv tb_decoder.sv tb_hazard_unit.sv tb_forwarding_unit.sv tb_branch_predictor.sv tb_csr_regfile.sv tb_l1_cache.sv

TESTBENCHES=("tb_alu" "tb_regfile" "tb_decoder" "tb_hazard_unit" "tb_forwarding_unit" "tb_branch_predictor" "tb_csr_regfile" "tb_l1_cache")

for tb in "${TESTBENCHES[@]}"; do
    echo "========================================"
    echo "Running $tb"
    echo "========================================"
    vsim -c -voptargs=+acc -L work $tb -do "run -all; quit -f"
done
