#!/usr/bin/env bash
# synth/scripts/run_sram_sta.sh
# Runs OpenROAD Static Timing Analysis (STA) on the SRAM-backed mapped netlist.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/synth/out_sram}"
mkdir -p "$OUT_DIR"

NETLIST_INPUT="$OUT_DIR/netlist_sta_linked.v"
SDC_INPUT="$REPO_ROOT/synth/aft_top.sdc"
LOG_FILE="$OUT_DIR/openroad_sta.log"

CONTAINER_NAME="verilator_runner"
IMAGE_NAME="${AFTXAI_IMAGE:-aftxai_eda:latest}"

echo "============================================================"
echo " AFTxAI: OpenROAD Macro-Aware Static Timing Analysis (STA)"
echo "============================================================"
echo "Netlist:  $NETLIST_INPUT"
echo "SDC:      $SDC_INPUT"
echo "Log File: $LOG_FILE"

if [ ! -f "$NETLIST_INPUT" ]; then
    echo "[FAIL] Input netlist not found: $NETLIST_INPUT"
    echo "       Run bash synth/scripts/run_sram_synthesis.sh first."
    exit 1
fi

# Ensure container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker start "$CONTAINER_NAME" > /dev/null
    else
        docker run -d --name "$CONTAINER_NAME" \
            -v "$REPO_ROOT:/work:rw" \
            -w /work \
            "$IMAGE_NAME" sleep infinity > /dev/null
    fi
fi

echo "==> Running OpenROAD in Docker..."
docker exec "$CONTAINER_NAME" bash -lc "
    source /OpenROAD-flow-scripts/env.sh
    openroad -exit /work/synth/run_sta_sram_linked.tcl
" 2>&1 | tee "$LOG_FILE"

echo "==> [SUCCESS] SRAM STA complete. Log written to $LOG_FILE"
