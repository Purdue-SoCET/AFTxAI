#!/bin/bash
module load verilator/5.036
cd riscv/verification/tb

echo "Linting RTL..."
verilator --lint-only -Wall -f filelist.f

TESTS="tb_alu tb_regfile tb_decoder tb_hazard_unit tb_forwarding_unit tb_branch_predictor tb_csr_regfile tb_l1_cache"

for tb in $TESTS; do
    echo "----------------------------------------"
    echo "Running $tb"
    verilator --binary -Wall -f filelist.f ${tb}.sv --top-module ${tb} -Wno-fatal --trace
    ./obj_dir/V${tb}
done
