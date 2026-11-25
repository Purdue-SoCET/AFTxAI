#!/usr/bin/env bash
# synth/scripts/run_sta.sh
# Runs OpenROAD Static Timing Analysis (STA) on a mapped gate-level netlist.
#
# Usage:
#   bash synth/scripts/run_sta.sh [netlist_file] [sdc_file]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/synth/out}"
mkdir -p "$OUT_DIR"

NETLIST_INPUT="${1:-$OUT_DIR/netlist_sta.v}"
SDC_INPUT="${2:-$REPO_ROOT/synth/aft_top.sdc}"
LOG_FILE="$OUT_DIR/openroad_sta.log"

CONTAINER_NAME="verilator_runner"
IMAGE_NAME="${AFTXAI_IMAGE:-aftxai_eda:latest}"

echo "============================================================"
echo " AFTxAI: OpenROAD Static Timing Analysis (STA)"
echo "============================================================"
echo "Netlist:  $NETLIST_INPUT"
echo "SDC:      $SDC_INPUT"
echo "Log File: $LOG_FILE"

if [ ! -f "$NETLIST_INPUT" ]; then
    echo "[FAIL] Input netlist not found: $NETLIST_INPUT"
    echo "       Please ensure synthesis has generated the netlist."
    exit 1
fi

if [ ! -f "$SDC_INPUT" ]; then
    echo "[FAIL] SDC constraints file not found: $SDC_INPUT"
    exit 1
fi

# Ensure $_TBUF_ cells are resolved by linking structural definition
LINKED_NETLIST="$OUT_DIR/netlist_sta_linked.v"
echo "==> Resolving \$_TBUF_ primitives using sky130 standard cells..."
cat "$NETLIST_INPUT" "$REPO_ROOT/synth/tbuf_sky130.v" > "$LINKED_NETLIST"

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
    openroad -exit /work/synth/run_sta_linked.tcl
" 2>&1 | tee "$LOG_FILE"

echo "==> [SUCCESS] STA complete. Log written to $LOG_FILE"
