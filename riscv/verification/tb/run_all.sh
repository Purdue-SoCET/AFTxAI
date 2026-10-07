#!/bin/bash
module load siemens/questa/2023.4
export MGLS_LICENSE_FILE=28000@marina.ecn.purdue.edu
export LM_LICENSE_FILE=1721@marina.ecn.purdue.edu

cd riscv/verification/tb
vlib work

echo "Compiling RTL..."
vlog -sv -f filelist.f

TESTS="tb_alu tb_regfile tb_decoder tb_hazard_unit tb_forwarding_unit tb_branch_predictor tb_csr_regfile tb_l1_cache"

for tb in $TESTS; do
    echo "----------------------------------------"
    echo "Running $tb"
    vlog -sv ${tb}.sv
    vsim -c $tb -do "run -all; quit" | grep -E "PASS|FAIL|Error|Warning|Fatal"
done
