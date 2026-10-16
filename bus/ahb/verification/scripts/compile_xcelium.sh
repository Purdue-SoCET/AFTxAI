#!/bin/bash

# Ensure script is run from the verification directory, not from within scripts/
if [[ $(basename $(pwd)) == "scripts" ]]; then
    echo "Please run this script from the bus/ahb/verification directory:"
    echo "cd .. && ./scripts/compile_xcelium.sh"
    exit 1
fi

module load cadence/xcelium/23.03 2>/dev/null || true

# Run inside sim directory to keep root clean
mkdir -p sim
cd sim

xrun -uvm -timescale 1ns/1ps \
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
  $@
