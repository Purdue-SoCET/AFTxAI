#!/bin/bash
set -e

xrun -64 -sv -timescale 1ns/1ps \
    -incdir ../../bus/apb/include \
    ../../bus/apb/include/apb_if.sv \
    ../../bus/generic/bus_protocol_if.sv \
    ../../peripherals/interrupt_controller/plic/include/plic_if.sv \
    ../../peripherals/interrupt_controller/plic/rtl/plic.sv \
    src/pwm_core.sv \
    tb/pwm_tb_plic.sv \
    +access+rwc
