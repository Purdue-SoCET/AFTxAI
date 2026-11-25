#!/usr/bin/env bash
# synth/scripts/run_synthesis.sh
# Runs full-SoC Yosys synthesis and SKY130HD standard-cell technology mapping.
#
# Usage:
#   bash synth/scripts/run_synthesis.sh [--outdir <path>] [--clean-netlist]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/synth/out}"
mkdir -p "$OUT_DIR"

CONTAINER_NAME="verilator_runner"
IMAGE_NAME="${AFTXAI_IMAGE:-aftxai_eda:latest}"

echo "============================================================"
echo " AFTxAI: Full-SoC Synthesis & SKY130HD Technology Mapping"
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

SYNTH_SCRIPT="/tmp/run_synth_commands.ys"

docker exec "$CONTAINER_NAME" bash -lc "
cat << 'EOF' > $SYNTH_SCRIPT
# Read design with read_slang
read_slang --single-unit --top aft_synth_top \
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
  top_level/rtl/*.sv \
  synth/aft_synth_top.sv

hierarchy -check -top aft_synth_top

# Generic synthesis
synth -top aft_synth_top -flatten
stat -top aft_synth_top

# Technology mapping to SKY130HD standard cells
dfflibmap -liberty /OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
abc -liberty /OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
clean
stat -liberty /OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Write gate-level netlists
write_verilog -noattr /work/synth/out/netlist_synth.v
EOF
"

echo "==> Synthesis command prepared at $SYNTH_SCRIPT inside container."
echo "==> To run full synthesis (~15-30 min), invoke:"
echo "    docker exec $CONTAINER_NAME bash -lc 'source /OpenROAD-flow-scripts/env.sh && yosys -l /work/synth/out/soc_synth.log $SYNTH_SCRIPT'"
