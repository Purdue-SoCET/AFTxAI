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

REL_NETLIST="${NETLIST_INPUT#$REPO_ROOT/}"
REL_SDC="${SDC_INPUT#$REPO_ROOT/}"
STA_TCL="/tmp/run_sta_sram_${RANDOM}.tcl"

echo "==> Running OpenROAD in Docker..."
docker exec "$CONTAINER_NAME" bash -lc "
cat << EOF > $STA_TCL
set lib_file \"/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib\"
set tech_lef \"/OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd.tlef\"
set cell_lef \"/OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd_merged.lef\"
set sram_lib \"/OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_64x256_8/sky130_sram_1rw1r_64x256_8_TT_1p8V_25C.lib\"
set sram_lef \"/OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_64x256_8/sky130_sram_1rw1r_64x256_8.lef\"
set netlist_file \"/work/$REL_NETLIST\"
set sdc_file \"/work/$REL_SDC\"

read_liberty \\\$lib_file
read_liberty \\\$sram_lib
read_lef \\\$tech_lef
read_lef \\\$cell_lef
read_lef \\\$sram_lef
read_verilog \\\$netlist_file
link_design aft_synth_top
read_sdc \\\$sdc_file

check_setup -unconstrained_endpoints
report_checks -through [get_pins -hierarchical *u_sram*/*] -endpoint_count 5
report_checks -fields {capacitance slew input_pins nets} -format full_clock_expanded -path_delay max -digits 4
report_checks -path_delay max -endpoint_count 10 -digits 4
report_worst_slack -max
report_worst_slack -min
report_clock_skew
report_checks -unconstrained -endpoint_count 20
exit
EOF
    source /OpenROAD-flow-scripts/env.sh
    openroad -exit $STA_TCL
" 2>&1 | tee "$LOG_FILE"

echo "==> [SUCCESS] SRAM STA complete. Log written to $LOG_FILE"
