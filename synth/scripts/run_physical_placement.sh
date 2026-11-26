#!/usr/bin/env bash
# synth/scripts/run_physical_placement.sh
# Supports selectable SRAM backends:
#   SRAM_BACKEND=0 : OpenRAM -> synth/out_physical
#   SRAM_BACKEND=1 : SRAM22  -> synth/out_physical_sram22
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SRAM_BACKEND="${SRAM_BACKEND:-1}"

if [ "$SRAM_BACKEND" -eq 1 ]; then
    BACKEND_NAME="SRAM22 (sram22_256x64m4w8)"
    DEFAULT_OUT_DIR="${REPO_ROOT}/synth/out_physical_sram22"
    NETLIST="/work/synth/out_sram22/netlist_sta_linked.v"
else
    BACKEND_NAME="OpenRAM (sky130_sram_1rw1r_64x256_8)"
    DEFAULT_OUT_DIR="${REPO_ROOT}/synth/out_physical"
    NETLIST="/work/synth/out_sram/netlist_sta_linked.v"
fi

OUT_DIR="${OUT_DIR:-$DEFAULT_OUT_DIR}"
mkdir -p "$OUT_DIR"
LOG_FILE="${OUT_DIR}/openroad_physical.log"

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
echo "Backend:    $BACKEND_NAME (SRAM_BACKEND=$SRAM_BACKEND)"
echo "Netlist:    $NETLIST"
echo "SDC:        /work/synth/aft_top.sdc"
echo "Output Dir: $OUT_DIR"
echo "Log File:   $LOG_FILE"

set +e
docker exec -e SRAM_BACKEND="$SRAM_BACKEND" "$CONTAINER_NAME" bash -lc "
    source /OpenROAD-flow-scripts/env.sh
    cd /work
    openroad -exit -no_splash /work/synth/scripts/physical_design.tcl
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
