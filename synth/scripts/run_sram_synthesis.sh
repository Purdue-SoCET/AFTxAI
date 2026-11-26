#!/usr/bin/env bash
# synth/scripts/run_sram_synthesis.sh
# Performs full-SoC Yosys synthesis and SKY130HD standard-cell technology mapping
# with the 16 KiB SRAM macro backend enabled (USE_SRAM_MACRO=1).
#
# Supports selectable SRAM backends:
#   SRAM_BACKEND=0 : OpenRAM (sky130_sram_1rw1r_64x256_8) -> output dir synth/out_sram
#   SRAM_BACKEND=1 : SRAM22  (sram22_256x64m4w8)          -> output dir synth/out_sram22
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SRAM_BACKEND="${SRAM_BACKEND:-1}"

if [ "$SRAM_BACKEND" -eq 1 ]; then
    BACKEND_NAME="SRAM22 (sram22_256x64m4w8)"
    DEFAULT_OUT_DIR="$REPO_ROOT/synth/out_sram22"
    BLACKBOX_FILE="synth/sram22/sram22_256x64m4w8_bb.v"
    EXPECTED_MACRO="sram22_256x64m4w8"
else
    BACKEND_NAME="OpenRAM (sky130_sram_1rw1r_64x256_8)"
    DEFAULT_OUT_DIR="$REPO_ROOT/synth/out_sram"
    BLACKBOX_FILE="synth/sky130_sram_1rw1r_64x256_8_bb.v"
    EXPECTED_MACRO="sky130_sram_1rw1r_64x256_8"
fi

OUT_DIR="${OUT_DIR:-$DEFAULT_OUT_DIR}"
mkdir -p "$OUT_DIR"

CONTAINER_NAME="verilator_runner"
IMAGE_NAME="${AFTXAI_IMAGE:-aftxai_eda:latest}"

echo "============================================================"
echo " AFTxAI: Full-SoC SRAM-Backed Synthesis & SKY130HD Mapping"
echo "============================================================"
echo "Repository Root: $REPO_ROOT"
echo "Backend:         $BACKEND_NAME (SRAM_BACKEND=$SRAM_BACKEND)"
echo "Blackbox Stub:   $BLACKBOX_FILE"
echo "Output Dir:      $OUT_DIR"

# Ensure container is running and bind mount is valid
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

# Verify container bind mount
docker exec "$CONTAINER_NAME" test -f "/work/$BLACKBOX_FILE" || {
    echo "[ERROR] Container bind mount check failed for /work/$BLACKBOX_FILE!"
    exit 1
}

REL_OUT_DIR="${OUT_DIR#$REPO_ROOT/}"
SYNTH_SCRIPT="/tmp/run_sram_synth_${SRAM_BACKEND}.ys"

docker exec "$CONTAINER_NAME" bash -lc "
cat << 'EOF' > $SYNTH_SCRIPT
# Read design with read_slang with SRAM backend and synthesizable Boot ROM enabled
read_slang --single-unit --top aft_synth_top -DUSE_SRAM_MACRO=1 -DSRAM_BACKEND=$SRAM_BACKEND -DUSE_SYNTH_ROM=1 \
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
  $BLACKBOX_FILE \
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

echo "==> Verifying structural netlist requirements..."
NUM_MACROS=$(grep -c "sram22_256x64m4w8 " "$OUT_DIR/netlist_sta_linked.v" || true)
NUM_OPENRAM=$(grep -c "sky130_sram_1rw1r_64x256_8 " "$OUT_DIR/netlist_sta_linked.v" || true)

if [ "$SRAM_BACKEND" -eq 1 ]; then
    echo "SRAM22 instance count: $NUM_MACROS (expected 8)"
    echo "OpenRAM instance count: $NUM_OPENRAM (expected 0)"
    if [ "$NUM_MACROS" -ne 8 ] || [ "$NUM_OPENRAM" -ne 0 ]; then
        echo "[ERROR] Netlist verification failed! Expected exactly 8 SRAM22 macros and 0 OpenRAM macros."
        exit 1
    fi
else
    echo "OpenRAM instance count: $NUM_OPENRAM (expected 8)"
    echo "SRAM22 instance count: $NUM_MACROS (expected 0)"
    if [ "$NUM_OPENRAM" -ne 8 ] || [ "$NUM_MACROS" -ne 0 ]; then
        echo "[ERROR] Netlist verification failed! Expected exactly 8 OpenRAM macros and 0 SRAM22 macros."
        exit 1
    fi
fi

echo "==> [SUCCESS] SRAM-backed synthesis complete! Netlist: $OUT_DIR/netlist_sta_linked.v"
