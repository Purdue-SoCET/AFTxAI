#!/usr/bin/env bash
# run_openroad_sta.sh
set -euo pipefail

RESULTS_DIR="/home/fireb/eda/aiftx_synth_results/20261123T222254Z/aft_top"
SYNTH_DIR="/home/fireb/src/AFTxAI/synth"

echo "==> Preparing netlist with resolved \$_TBUF_ cells..."
# We create netlist_sta_linked.v by appending the structural implementation of \$_TBUF_
# using sky130_fd_sc_hd__inv_1 and sky130_fd_sc_hd__ebufn_1 (valid SKY130HD standard cells).
cat "$RESULTS_DIR/netlist_sta.v" "$SYNTH_DIR/tbuf_sky130.v" > "$RESULTS_DIR/netlist_sta_linked.v"
echo "==> Created $RESULTS_DIR/netlist_sta_linked.v"

echo "==> Running OpenROAD STA in Docker..."
docker run --rm \
    --memory=12g \
    --cpus=4 \
    --user "$(id -u):$(id -g)" \
    -v "$RESULTS_DIR:/work:rw" \
    -v "$SYNTH_DIR:/synth:ro" \
    openroad/orfs:latest \
    bash -lc "source /OpenROAD-flow-scripts/env.sh && openroad -exit /synth/run_sta_linked.tcl" 2>&1 | tee "$RESULTS_DIR/openroad_sta.log"

echo "==> STA completed. Log written to $RESULTS_DIR/openroad_sta.log"
