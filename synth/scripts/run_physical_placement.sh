#!/usr/bin/env bash
# synth/scripts/run_physical_placement.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${REPO_ROOT}/synth/out_physical"
LOG_FILE="${OUT_DIR}/openroad_physical.log"

mkdir -p "$OUT_DIR"

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
echo " AFTxAI: OpenROAD Physical Placement & High-Fanout Repair"
echo "============================================================"
echo "Netlist:    /work/synth/out_sram/netlist_sta_linked.v"
echo "SDC:        /work/synth/aft_top.sdc"
echo "Output Dir: $OUT_DIR"
echo "Log File:   $LOG_FILE"

set +e
docker exec "$CONTAINER_NAME" bash -lc "
    source /OpenROAD-flow-scripts/env.sh
    cd /work
    openroad -exit /work/synth/scripts/physical_design.tcl
" 2>&1 | tee "$LOG_FILE"
OR_STATUS=${PIPESTATUS[0]}
set -e

if [ $OR_STATUS -eq 0 ]; then
    echo "==> [SUCCESS] Physical placement flow completed successfully."
    exit 0
else
    echo "==> [FAIL] Physical placement flow failed with exit code $OR_STATUS."
    exit $OR_STATUS
fi
