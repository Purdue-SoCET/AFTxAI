#!/usr/bin/env bash
# synth/scripts/export_clean_netlist.sh
# Performs Yosys-native syntax-aware structural re-export of the mapped netlist,
# removing simulation/formal artifacts ($print, $check) without text-based regex.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

INPUT_NETLIST="${1:-$REPO_ROOT/synth/out_sram/netlist_synth.v}"
OUTPUT_NETLIST="${2:-$REPO_ROOT/synth/out_sram/netlist_sta_linked.v}"
OUT_DIR="$(dirname "$OUTPUT_NETLIST")"
mkdir -p "$OUT_DIR"

CONTAINER_NAME="verilator_runner"
IMAGE_NAME="${AFTXAI_IMAGE:-aftxai_eda:latest}"

echo "============================================================"
echo " AFTxAI: Yosys-Native Structural Netlist Re-Export"
echo "============================================================"
echo "Input Netlist:  $INPUT_NETLIST"
echo "Output Netlist: $OUTPUT_NETLIST"

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

YOSYS_CLEAN_SCRIPT="/tmp/export_clean_netlist.ys"

docker exec "$CONTAINER_NAME" bash -lc "
cat << 'EOF' > $YOSYS_CLEAN_SCRIPT
read_verilog /work/${INPUT_NETLIST#$REPO_ROOT/}
# Select and remove only the formal/simulation assertion and print cells
delete t:\$print t:\$check
proc
clean -purge
write_verilog -noattr /work/${OUT_DIR#$REPO_ROOT/}/netlist_yosys_clean.v
EOF
source /OpenROAD-flow-scripts/env.sh
cd /work
yosys -l /work/${OUT_DIR#$REPO_ROOT/}/yosys_clean_export.log $YOSYS_CLEAN_SCRIPT
"

# Append SKY130 structural tri-state cell implementation for OpenROAD linking
cat "$OUT_DIR/netlist_yosys_clean.v" "$REPO_ROOT/synth/tbuf_sky130.v" > "$OUTPUT_NETLIST"

echo "==> [SUCCESS] Netlist structurally re-exported via Yosys to: $OUTPUT_NETLIST"
