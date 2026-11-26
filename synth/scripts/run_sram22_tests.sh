#!/usr/bin/env bash
# synth/scripts/run_sram22_tests.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$REPO_ROOT/synth/out"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/sram22_regression.log"
CONTAINER_NAME="verilator_runner"

echo "============================================================"
echo " AFTxAI: SRAM22 Macro Equivalence & Handshake Regression"
echo "============================================================"

set +e
docker exec "$CONTAINER_NAME" bash -lc "
    cd /work && \
    verilator --binary --timing -Wno-fatal -Wno-lint \
      -I/work/bus/generic \
      -I/work/peripherals/ff_ram/rtl \
      -I/work/peripherals/ff_ram/include \
      -I/work/synth/sram22/sram22_256x64m4w8 \
      /work/bus/generic/bus_protocol_if.sv \
      /work/peripherals/ff_ram/rtl/ff_ram.sv \
      /work/synth/sram22/sram22_256x64m4w8/sram22_256x64m4w8.v \
      /work/peripherals/ff_ram/rtl/sram22_sram_banked_16k.sv \
      /work/peripherals/ff_ram/verification/tb_sram22_vs_ffram.sv \
      --top-module tb_sram22_vs_ffram -o /tmp/sim_sram22_tests 2>&1 && \
    /tmp/sim_sram22_tests 2>&1
" | tee "$LOG_FILE"
SIM_STATUS=${PIPESTATUS[0]}
set -e

if [ $SIM_STATUS -eq 0 ]; then
    echo "==> [SUCCESS] SRAM22 equivalence regression PASSED!"
    exit 0
else
    echo "==> [FAIL] SRAM22 equivalence regression FAILED with status $SIM_STATUS."
    exit $SIM_STATUS
fi
