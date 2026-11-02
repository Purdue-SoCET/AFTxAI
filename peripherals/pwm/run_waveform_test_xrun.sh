#!/bin/bash
set -e

xrun -64 -sv -timescale 1ns/1ps \
    -incdir ../../bus/apb/include \
    ../../bus/apb/include/apb_if.sv \
    src/pwm_core.sv \
    tb/pwm_tb_waveform.sv \
    +access+rwc
