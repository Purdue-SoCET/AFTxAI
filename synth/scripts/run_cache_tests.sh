#!/usr/bin/env bash
# synth/scripts/run_cache_tests.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/synth/out}"
mkdir -p "$OUT_DIR"
LOG_FILE="$OUT_DIR/l1_cache_regression.log"

CONTAINER_NAME="verilator_runner"
IMAGE_NAME="${AFTXAI_IMAGE:-aftxai_eda:latest}"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker start "$CONTAINER_NAME" > /dev/null
    else
        docker run -d --name "$CONTAINER_NAME" -v "$REPO_ROOT:/work" -w /work \
            "$IMAGE_NAME" sleep infinity > /dev/null
    fi
fi

echo "============================================================"
echo " AFTxAI: Focused L1 Cache Direct Functional Regression"
echo "============================================================"
echo "Log File: $LOG_FILE"

set +e
docker exec "$CONTAINER_NAME" bash -lc "
    cd /work
    verilator --binary -Wno-fatal -sv --timing \
      -I/work/riscv/include \
      /work/riscv/include/cpu_cache_if.sv \
      /work/riscv/include/cache_bus_if.sv \
      /work/riscv/include/l1_cache_if.sv \
      /work/riscv/rtl/caches/l1_cache.sv \
      /work/riscv/verification/tb/tb_l1_cache_direct.sv \
      --top-module tb_l1_cache_direct -o /tmp/sim_l1_cache_direct 2>&1 && \
    /tmp/sim_l1_cache_direct
" 2>&1 | tee "$LOG_FILE"
SIM_STATUS=${PIPESTATUS[0]}
set -e

if [ $SIM_STATUS -eq 0 ]; then
    echo "==> [SUCCESS] L1 Cache unit testbench passed with exit status 0."
    exit 0
else
    echo "==> [FAIL] L1 Cache unit testbench failed with exit status $SIM_STATUS."
    exit $SIM_STATUS
fi
