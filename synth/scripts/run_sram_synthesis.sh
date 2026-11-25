#!/usr/bin/env bash
# synth/scripts/run_sram_synthesis.sh
# Performs full-SoC Yosys synthesis and SKY130HD standard-cell technology mapping
# with the 16 KiB SRAM macro backend enabled (USE_SRAM_MACRO=1).
#
# Macro instances sky130_sram_1rw1r_64x256_8 are preserved as blackboxes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/synth/out_sram}"
mkdir -p "$OUT_DIR"

CONTAINER_NAME="verilator_runner"
IMAGE_NAME="${AFTXAI_IMAGE:-aftxai_eda:latest}"

echo "============================================================"
echo " AFTxAI: Full-SoC SRAM-Backed Synthesis & SKY130HD Mapping"
echo "============================================================"
echo "Repository Root: $REPO_ROOT"
echo "Output Dir:      $OUT_DIR"

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

REL_OUT_DIR="${OUT_DIR#$REPO_ROOT/}"

SYNTH_SCRIPT="/tmp/run_sram_synth.ys"

docker exec "$CONTAINER_NAME" bash -lc "
cat << 'EOF' > $SYNTH_SCRIPT
# Read design with read_slang with SRAM backend enabled
read_slang --single-unit --top aft_synth_top -DUSE_SRAM_MACRO=1 \
  -I bus/ahb/include \
  -I bus/apb/include \
  -I bus/generic \
  -I peripherals/sram_controller/include \
  -I top_level/map \
  -I riscv/include \
  -I peripherals/interrupt_controller/clint/include \
  -I peripherals/interrupt_controller/plic/include \
  -I peripherals/spi/include \
  -I peripherals/digital_io_mux/include \
  top_level/map/aft_map_pkg.sv \
  bus/ahb/include/ahb_pkg.sv \
  bus/generic/bus_protocol_if.sv \
  bus/ahb/include/ahb_if.sv \
  bus/apb/include/apb_if.sv \
  peripherals/sram_controller/include/sram_if.sv \
  riscv/include/bus_ahbm_if.sv \
  riscv/include/riscv_if.sv \
  peripherals/interrupt_controller/clint/include/clint_if.sv \
  peripherals/interrupt_controller/plic/include/plic_if.sv \
  peripherals/dma/include/memArb_if.sv \
  peripherals/spi/include/spi_types_pkg.sv \
  peripherals/uart/include/uart_if.sv \
  peripherals/spi/include/spi_if.sv \
  peripherals/i2c/include/i2c_if.sv \
  digital_lib/sync_2ff.sv \
  digital_lib/counter.sv \
  riscv/include/*.sv \
  riscv/rtl/datapath/*.sv \
  riscv/rtl/caches/*.sv \
  riscv/rtl/memory/*.sv \
  riscv/rtl/*.sv \
  peripherals/dma/rtl/*.sv \
  bus/bridge/rtl/*.sv \
  bus/ahb/ahb_interconnect/*.sv \
  bus/ahb/ahb_manager/*.sv \
  bus/ahb/ahb_subordinate/*.sv \
  bus/apb/rtl/*.sv \
  peripherals/ff_ram/rtl/*.sv \
  peripherals/sram_controller/rtl/*.sv \
  peripherals/digital_io_mux/rtl/digital_io_mux_apb.sv \
  peripherals/digital_io_mux/rtl/digital_io_mux_cell.sv \
  peripherals/digital_io_mux/rtl/digital_io_mux.sv \
  peripherals/gpio/src/*.sv \
  peripherals/pwm/src/*.sv \
  peripherals/timer/src/*.sv \
  peripherals/spi/rtl/*.sv \
  peripherals/i2c/rtl/i2c_engine.sv \
  peripherals/i2c/rtl/i2c_regs.sv \
  peripherals/i2c/rtl/i2c.sv \
  peripherals/uart/rtl/*.sv \
  peripherals/interrupt_controller/clint/rtl/*.sv \
  peripherals/interrupt_controller/plic/rtl/plic.sv \
  synth/sky130_sram_1rw1r_64x256_8_bb.v \
  top_level/rtl/*.sv \
  synth/aft_synth_top.sv

hierarchy -check -top aft_synth_top

# Generic synthesis (flatten design while preserving macro blackboxes)
synth -top aft_synth_top -flatten
stat -top aft_synth_top

# Technology mapping to SKY130HD standard cells
dfflibmap -liberty /OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
abc -liberty /OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
clean
stat -liberty /OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Write gate-level netlists into output directory
write_verilog -noattr /work/$REL_OUT_DIR/netlist_synth.v
EOF
"

echo "==> Running Yosys synthesis inside Docker..."
docker exec "$CONTAINER_NAME" bash -lc "
    source /OpenROAD-flow-scripts/env.sh
    cd /work
    yosys -l /work/$REL_OUT_DIR/soc_synth.log $SYNTH_SCRIPT
" 2>&1 | tee "$OUT_DIR/soc_synth_terminal.log"

echo "==> Re-exporting clean structural netlist via Yosys (removing simulation artifacts)..."
bash "$REPO_ROOT/synth/scripts/export_clean_netlist.sh" "$OUT_DIR/netlist_synth.v" "$OUT_DIR/netlist_sta_linked.v"

echo "==> [SUCCESS] SRAM-backed synthesis complete! Netlist: $OUT_DIR/netlist_sta_linked.v"
