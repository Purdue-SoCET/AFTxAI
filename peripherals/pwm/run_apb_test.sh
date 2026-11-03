#!/bin/bash
set -e

# Compile APB interconnect, interface, core, wrapper and testbench
verilator --cc --exe --build -j 4 \
    --top-module pwm_tb_apb_integration \
    -I../../bus/apb/include \
    ../../bus/apb/include/apb_if.sv \
    ../../bus/apb/rtl/apb_interconnect.sv \
    src/pwm_core.sv \
    src/pwm_apb_wrapper.sv \
    tb/pwm_tb_apb_integration.sv \
    --timing -Wno-fatal -Wno-TIMESCALEMOD \
    --Mdir obj_dir_apb_int

./obj_dir_apb_int/Vpwm_tb_apb_integration
