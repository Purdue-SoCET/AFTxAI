#!/bin/bash

# Ensure script is run from the verification directory, not from within scripts/
if [[ $(basename $(pwd)) == "scripts" ]]; then
    echo "Please run this script from the bus/ahb/verification directory:"
    echo "cd .. && ./scripts/run_regression.sh"
    exit 1
fi

module load cadence/xcelium/23.03 2>/dev/null || true
module load cadence/vmanager/23.03 2>/dev/null || true

# Run inside sim directory to keep root clean
mkdir -p sim
cd sim

# Clean up previous coverage and logs
rm -rf cov_work cov_report
rm -f xrun.log
rm -f sim_*.log
mkdir -p regression_logs

# List of tests to run in regression
TESTS=("ahb_base_test" "ahb_matrix_test" "ahb_error_test")

echo "Starting AHB UVM Regression..."

for TEST in "${TESTS[@]}"; do
    echo "Running ${TEST}..."
    xrun -uvm -timescale 1ns/1ps \
      -coverage all -covoverwrite \
      -covtest ${TEST} \
      -incdir ../../include \
      -incdir .. \
      ../../../generic/bus_protocol_if.sv \
      ../../include/ahb_pkg.sv \
      ../../include/ahb_if.sv \
      ../../ahb_manager/ahb_manager.sv \
      ../../ahb_subordinate/ahb_subordinate.sv \
      ../../ahb_interconnect/ahb_interconnect.sv \
      ../ahb_uvm_pkg.sv \
      ../tb/tb_uvm_top.sv \
      +UVM_TESTNAME=${TEST} \
      > regression_logs/${TEST}.log 2>&1
      
    if grep -q "UVM_ERROR :    0" regression_logs/${TEST}.log && grep -q "UVM_FATAL :    0" regression_logs/${TEST}.log; then
        echo "  [PASS] ${TEST}"
    else
        echo "  [FAIL] ${TEST} (check regression_logs/${TEST}.log for details)"
    fi
done

echo "Merging Coverage..."
imc -exec ../scripts/imc_merge.tcl > regression_logs/imc_merge.log 2>&1

echo "Regression complete. Coverage report generated in sim/cov_report/"
