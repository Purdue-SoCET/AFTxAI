#!/usr/bin/env bash
# synth/scripts/run_ahb_sram22_tests.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$REPO_ROOT/synth/out"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/ahb_sram22_integration.log"
CONTAINER_NAME="verilator_runner"

echo "============================================================"
echo " AFTxAI: AHB-Lite to SRAM22 Integration Suite"
echo "============================================================"

set +e
docker exec "$CONTAINER_NAME" bash -lc "
    cd /work && \
    verilator --binary --timing -Wno-fatal -Wno-lint \
      -I/work/bus/ahb/include \
      -I/work/bus/generic \
      -I/work/peripherals/ff_ram/rtl \
      -I/work/peripherals/ff_ram/include \
      -I/work/synth/sram22/sram22_256x64m4w8 \
      /work/bus/ahb/include/ahb_pkg.sv \
      /work/bus/ahb/include/ahb_if.sv \
      /work/bus/generic/bus_protocol_if.sv \
      /work/bus/ahb/ahb_subordinate/ahb_subordinate.sv \
      /work/synth/sram22/sram22_256x64m4w8/sram22_256x64m4w8.v \
      /work/peripherals/ff_ram/rtl/sram22_sram_banked_16k.sv \
      /work/peripherals/ff_ram/verification/tb_ahb_sram22_integration.sv \
      --top-module tb_ahb_sram22_integration -o /tmp/sim_ahb_sram22_int 2>&1 && \
    /tmp/sim_ahb_sram22_int
" | tee "$LOG_FILE"
SIM_STATUS=${PIPESTATUS[0]}
set -e

if [ $SIM_STATUS -eq 0 ]; then
    echo "==> [SUCCESS] AHB-Lite to SRAM22 integration passed!"
    exit 0
else
    echo "==> [FAIL] AHB-Lite to SRAM22 integration failed with status $SIM_STATUS."
    exit $SIM_STATUS
fi
