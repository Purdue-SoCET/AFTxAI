#!/usr/bin/env bash
# synth/scripts/run_sram_sta.sh
# Runs OpenROAD Static Timing Analysis (STA) on the SRAM-backed mapped netlist.
# Supports selectable SRAM backends:
#   SRAM_BACKEND=0 : OpenRAM (sky130_sram_1rw1r_64x256_8) -> Netlist in synth/out_sram
#   SRAM_BACKEND=1 : SRAM22  (sram22_256x64m4w8)          -> Netlist in synth/out_sram22
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SRAM_BACKEND="${SRAM_BACKEND:-1}"

if [ "$SRAM_BACKEND" -eq 1 ]; then
    BACKEND_NAME="SRAM22 (sram22_256x64m4w8)"
    DEFAULT_OUT_DIR="$REPO_ROOT/synth/out_sram22"
    SRAM_LIB="/work/synth/sram22/sram22_256x64m4w8/sram22_256x64m4w8_tt_025C_1v80.lib"
    SRAM_LEF="/work/synth/sram22/sram22_256x64m4w8/sram22_256x64m4w8.lef"
else
    BACKEND_NAME="OpenRAM (sky130_sram_1rw1r_64x256_8)"
    DEFAULT_OUT_DIR="$REPO_ROOT/synth/out_sram"
    SRAM_LIB="/OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_64x256_8/sky130_sram_1rw1r_64x256_8_TT_1p8V_25C.lib"
    SRAM_LEF="/OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_64x256_8/sky130_sram_1rw1r_64x256_8.lef"
fi

OUT_DIR="${OUT_DIR:-$DEFAULT_OUT_DIR}"
mkdir -p "$OUT_DIR"

NETLIST_INPUT="$OUT_DIR/netlist_sta_linked.v"
SDC_INPUT="$REPO_ROOT/synth/aft_top.sdc"
LOG_FILE="$OUT_DIR/openroad_sta.log"

CONTAINER_NAME="verilator_runner"
IMAGE_NAME="${AFTXAI_IMAGE:-aftxai_eda:latest}"

echo "============================================================"
echo " AFTxAI: OpenROAD Macro-Aware Static Timing Analysis (STA)"
echo "============================================================"
echo "Backend:  $BACKEND_NAME (SRAM_BACKEND=$SRAM_BACKEND)"
echo "Netlist:  $NETLIST_INPUT"
echo "SRAM Lib: $SRAM_LIB"
echo "SRAM Lef: $SRAM_LEF"
echo "SDC:      $SDC_INPUT"
echo "Log File: $LOG_FILE"

if [ ! -f "$NETLIST_INPUT" ]; then
    echo "[FAIL] Input netlist not found: $NETLIST_INPUT"
    echo "       Run SRAM_BACKEND=$SRAM_BACKEND bash synth/scripts/run_sram_synthesis.sh first."
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
STA_TCL="/tmp/run_sta_sram_${SRAM_BACKEND}_${RANDOM}.tcl"

echo "==> Running OpenROAD in Docker..."
docker exec "$CONTAINER_NAME" bash -lc "
cat << EOF > $STA_TCL
set lib_file \"/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib\"
set tech_lef \"/OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd.tlef\"
set cell_lef \"/OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd_merged.lef\"
set sram_lib \"$SRAM_LIB\"
set sram_lef \"$SRAM_LEF\"
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

puts \"=== DESIGN METRICS ===\"
report_design_area

puts \"=== SETUP CHECK UNCONSTRAINED ENDPOINTS ===\"
check_setup -unconstrained_endpoints

puts \"=== TIMING CHECKS THROUGH SRAM MACROS ===\"
report_checks -through [get_pins -hierarchical *u_sram*/*] -endpoint_count 5 -digits 4

puts \"=== TIMING CHECKS FROM SRAM MACROS (READ LAUNCH) ===\"
report_checks -from [get_pins -hierarchical *u_sram*/dout*] -endpoint_count 5 -digits 4

puts \"=== WORST SETUP PATHS (TOP 10) ===\"
report_checks -path_delay max -endpoint_count 10 -digits 4

puts \"=== WORST SLACK SUMMARY ===\"
report_worst_slack -max
report_worst_slack -min
report_tns -digits 4

exit
EOF
    source /OpenROAD-flow-scripts/env.sh
    openroad -exit -no_splash $STA_TCL
" 2>&1 | tee "$LOG_FILE"

echo "==> [SUCCESS] SRAM STA complete. Log written to $LOG_FILE"
