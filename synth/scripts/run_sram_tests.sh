#!/usr/bin/env bash
# synth/scripts/run_sram_tests.sh
# Runs the SRAM macro equivalence regression test suite using Verilator in Docker.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$REPO_ROOT/synth/out"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/sram_regression.log"

CONTAINER_NAME="verilator_runner"
IMAGE_NAME="${AFTXAI_IMAGE:-aftxai_eda:latest}"

echo "============================================================"
echo " AFTxAI: SRAM Macro Equivalence & Read Handshake Regression"
echo "============================================================"
echo "Repository Root: $REPO_ROOT"
echo "Log File:        $LOG_FILE"

# Ensure container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "==> Starting existing container $CONTAINER_NAME..."
        docker start "$CONTAINER_NAME" > /dev/null
    else
        echo "==> Creating and starting container $CONTAINER_NAME..."
        docker run -d --name "$CONTAINER_NAME" \
            -v "$REPO_ROOT:/work:rw" \
            -w /work \
            "$IMAGE_NAME" sleep infinity > /dev/null
    fi
fi

echo "==> Compiling and running SRAM equivalence testbench inside container..."
set +e
docker exec "$CONTAINER_NAME" bash -lc "
    cd /work && \
    verilator --binary --timing -Wno-fatal -Wno-lint \
      -I/work/bus/generic \
      -I/work/peripherals/ff_ram/rtl \
      -I/work/peripherals/ff_ram/include \
      -I/OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_64x256_8 \
      /work/bus/generic/bus_protocol_if.sv \
      /work/peripherals/ff_ram/rtl/ff_ram.sv \
      /OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_64x256_8/sky130_sram_1rw1r_64x256_8.v \
      /work/peripherals/ff_ram/rtl/sky130_sram_banked_16k.sv \
      /work/peripherals/ff_ram/verification/tb_sram_vs_ffram.sv \
      --top-module tb_sram_vs_ffram -o /tmp/sim_sram_tests 2>&1 && \
    /tmp/sim_sram_tests
" 2>&1 | tee "$LOG_FILE"
SIM_STATUS=${PIPESTATUS[0]}
set -e

if [ $SIM_STATUS -eq 0 ]; then
    echo "==> [SUCCESS] SRAM regression passed with exit status 0."
    echo "==> Full log saved at $LOG_FILE"
    exit 0
else
    echo "==> [ERROR] SRAM regression failed with exit status $SIM_STATUS."
    echo "==> See full log at $LOG_FILE"
    exit $SIM_STATUS
fi
