#!/bin/bash
cd peripherals/pwm

for CH in 1 2 3 4; do
    echo "Testing PWM_CHANNELS=$CH"
    vlog -sv -suppress 2244 +incdir+../../bus/include +incdir+tb ../../bus/include/apb4_if.sv src/pwm_core.sv tb/pwm_tb_directed.sv > /dev/null
    vsim -c -voptargs="+acc" -gPWM_CHANNELS=$CH -do "run -all; quit -f" work.pwm_tb_directed > vsim.log 2>&1
    if grep -q "PASSED" vsim.log; then
        echo "PWM_CHANNELS=$CH PASSED"
    else
        echo "ERROR: PWM_CHANNELS=$CH FAILED"
        cat vsim.log
        exit 1
    fi
done

echo "Testing PWM_CHANNELS=0 (Should Fail)"
vsim -c -voptargs="+acc" -gPWM_CHANNELS=0 -do "run -all; quit -f" work.pwm_tb_directed > vsim.log 2>&1
if grep -q "PWM_CHANNELS must be between 1 and 4. Got 0" vsim.log; then
    echo "PWM_CHANNELS=0 properly rejected."
else
    echo "ERROR: PWM_CHANNELS=0 not rejected!"
    cat vsim.log
    exit 1
fi

echo "Testing PWM_CHANNELS=5 (Should Fail)"
vsim -c -voptargs="+acc" -gPWM_CHANNELS=5 -do "run -all; quit -f" work.pwm_tb_directed > vsim.log 2>&1
if grep -q "PWM_CHANNELS must be between 1 and 4. Got 5" vsim.log; then
    echo "PWM_CHANNELS=5 properly rejected."
else
    echo "ERROR: PWM_CHANNELS=5 not rejected!"
    cat vsim.log
    exit 1
fi

echo "All channel configurations tested successfully."

