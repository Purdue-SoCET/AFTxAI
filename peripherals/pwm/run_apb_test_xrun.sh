#!/bin/bash
set -e

xrun -64 -sv -timescale 1ns/1ps \
    -incdir ../../bus/apb/include \
    ../../bus/apb/include/apb_if.sv \
    ../../bus/apb/rtl/apb_interconnect.sv \
    src/pwm_core.sv \
    src/pwm_apb_wrapper.sv \
    tb/pwm_tb_apb_integration.sv \
    +access+rwc
