#!/bin/bash
set -e

xrun -64 -sv -timescale 1ns/1ps \
    -incdir ../../bus/apb/include \
    ../../bus/ahb/include/ahb_if.sv \
    ../../bus/apb/include/apb_if.sv \
    ../../bus/bridge/rtl/ahb2apb.sv \
    ../../bus/apb/rtl/apb_interconnect.sv \
    src/pwm_core.sv \
    src/pwm_apb_wrapper.sv \
    tb/pwm_tb_ahb_integration.sv \
    +access+rwc
