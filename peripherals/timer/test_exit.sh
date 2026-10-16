#!/bin/bash
vsim -c -do "onbreak {quit -code 1}; onerror {quit -code 1}; onfinish exit; run -all" work.timer_tb
echo EXIT=$?
