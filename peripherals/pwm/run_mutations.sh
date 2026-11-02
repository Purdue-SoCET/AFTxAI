#!/bin/bash
# Script assumes it's run from the pwm directory or it changes to it
cd "$(dirname "$0")"

export TMPDIR=$(pwd)/tmp_dir

echo "--- Running T34 Mutations ---"

# Save original RTL
cp src/pwm_core.sv src/pwm_core.sv.orig

# Mutation A: phase <= duty (instead of phase < duty)
echo "Mutation A: phase <= active_duty"
sed -i 's/if (ch_phase\[i\] < ch_active_duty\[i\])/if (ch_phase[i] <= ch_active_duty[i])/' src/pwm_core.sv
if make sim_tb > mut_a.log 2>&1; then
    echo "ERROR: Mutation A passed unexpectedly!"
    mv src/pwm_core.sv.orig src/pwm_core.sv
    exit 1
else
    echo "Mutation A successfully caught (nonzero exit status)."
    grep "FAIL" mut_a.log | head -n 2
fi

# Restore
cp src/pwm_core.sv.orig src/pwm_core.sv

# Mutation B: early apply
echo "Mutation B: Apply shadow registers early (at phase == period - 2 instead of period - 1)"
sed -i 's/if (ch_phase\[i\] == ch_active_period\[i\] - 1)/if (ch_phase[i] == ch_active_period[i] - 2)/' src/pwm_core.sv
if make sim_tb > mut_b.log 2>&1; then
    echo "ERROR: Mutation B passed unexpectedly!"
    mv src/pwm_core.sv.orig src/pwm_core.sv
    exit 1
else
    echo "Mutation B successfully caught (nonzero exit status)."
    grep "FAIL" mut_b.log | head -n 2
fi

# Restore
cp src/pwm_core.sv.orig src/pwm_core.sv

# Mutation C: W1C over HW_SET
echo "Mutation C: W1C priority over HW_SET"
# The original code is:
# if (boundary_events[i]) begin irq_pending[i] <= 1'b1; end else if (w1c) begin irq_pending[i] <= 1'b0; end
# We swap the order so w1c wins:
sed -i 's/if (boundary_events\[i\])/if (w1c) irq_pending[i] <= 1'\''b0; else if (boundary_events[i])/' src/pwm_core.sv
sed -i 's/else if (w1c) begin//' src/pwm_core.sv
sed -i 's/irq_pending\[i\] <= 1'\''b0;//' src/pwm_core.sv

if make sim_tb > mut_c.log 2>&1; then
    echo "ERROR: Mutation C passed unexpectedly!"
    mv src/pwm_core.sv.orig src/pwm_core.sv
    exit 1
else
    echo "Mutation C successfully caught (nonzero exit status)."
    grep "FAIL" mut_c.log | head -n 2
fi

# Restore original
mv src/pwm_core.sv.orig src/pwm_core.sv
echo "--- All mutations caught successfully ---"
