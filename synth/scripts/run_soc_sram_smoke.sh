#!/usr/bin/env bash
# synth/scripts/run_soc_sram_smoke.sh
# Runs full-SoC simulation with USE_SRAM_MACRO=1 using Verilator in Docker.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$REPO_ROOT/synth/out"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/soc_sram_smoke.log"

CONTAINER_NAME="verilator_runner"
IMAGE_NAME="${AFTXAI_IMAGE:-aftxai_eda:latest}"

echo "============================================================"
echo " AFTxAI: Full-SoC SRAM Macro Connectivity & Smoke Test"
echo "============================================================"
echo "Repository Root: $REPO_ROOT"
echo "Log File:        $LOG_FILE"

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

echo "==> Compiling full-SoC testbench with Verilator..."
set +e
docker exec "$CONTAINER_NAME" bash -lc "
    cd /work && \
    verilator --binary --timing -Wno-fatal -Wno-lint \
      -I/work/bus/ahb/include -I/work/bus/apb/include -I/work/bus/generic \
      -I/work/peripherals/sram_controller/include -I/work/top_level/map -I/work/riscv/include \
      -I/work/peripherals/interrupt_controller/clint/include -I/work/peripherals/interrupt_controller/plic/include \
      -I/work/peripherals/spi/include -I/work/peripherals/digital_io_mux/include \
	      -I/work/peripherals/ff_ram/rtl -I/work/peripherals/ff_ram/include \
	      -I/OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_64x256_8 \
	      -I/work/synth/sram22/sram22_256x64m4w8 \
	      /work/top_level/map/aft_map_pkg.sv /work/bus/ahb/include/ahb_pkg.sv /work/bus/generic/bus_protocol_if.sv \
      /work/bus/ahb/include/ahb_if.sv /work/bus/apb/include/apb_if.sv /work/peripherals/sram_controller/include/sram_if.sv \
      /work/riscv/include/bus_ahbm_if.sv /work/riscv/include/riscv_if.sv \
      /work/peripherals/interrupt_controller/clint/include/clint_if.sv \
      /work/peripherals/interrupt_controller/plic/include/plic_if.sv /work/peripherals/dma/include/memArb_if.sv \
      /work/peripherals/spi/include/spi_types_pkg.sv /work/peripherals/uart/include/uart_if.sv \
      /work/peripherals/spi/include/spi_if.sv /work/peripherals/i2c/include/i2c_if.sv \
      /work/digital_lib/sync_2ff.sv /work/digital_lib/counter.sv \
      /work/riscv/include/*.sv /work/riscv/rtl/datapath/*.sv /work/riscv/rtl/caches/*.sv /work/riscv/rtl/memory/*.sv /work/riscv/rtl/*.sv \
      /work/peripherals/dma/rtl/*.sv /work/bus/bridge/rtl/*.sv /work/bus/ahb/ahb_interconnect/*.sv /work/bus/ahb/ahb_manager/*.sv \
      /work/bus/ahb/ahb_subordinate/*.sv /work/bus/apb/rtl/*.sv \
      /work/peripherals/ff_ram/rtl/*.sv /work/peripherals/sram_controller/rtl/*.sv \
      /work/peripherals/digital_io_mux/rtl/digital_io_mux_apb.sv /work/peripherals/digital_io_mux/rtl/digital_io_mux_cell.sv \
      /work/peripherals/digital_io_mux/rtl/digital_io_mux.sv /work/peripherals/gpio/src/*.sv /work/peripherals/pwm/src/*.sv \
      /work/peripherals/timer/src/*.sv /work/peripherals/spi/rtl/*.sv /work/peripherals/i2c/rtl/i2c_engine.sv \
      /work/peripherals/i2c/rtl/i2c_regs.sv /work/peripherals/i2c/rtl/i2c.sv /work/peripherals/uart/rtl/*.sv \
	      /work/peripherals/interrupt_controller/clint/rtl/*.sv /work/peripherals/interrupt_controller/plic/rtl/plic.sv \
	      /OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_64x256_8/sky130_sram_1rw1r_64x256_8.v \
	      /work/synth/sram22/sram22_256x64m4w8/sram22_256x64m4w8.v \
	      /work/top_level/rtl/*.sv /work/synth/aft_synth_top.sv \
      /work/top_level/verification/tb/tb_aft_top_sram_integration.sv \
      --top-module tb_aft_top_sram_integration -o /tmp/sim_soc_sram_smoke 2>&1 && \
    /tmp/sim_soc_sram_smoke
" 2>&1 | tee "$LOG_FILE"
SIM_STATUS=${PIPESTATUS[0]}
set -e

if [ $SIM_STATUS -eq 0 ]; then
    echo "==> [SUCCESS] Full-SoC SRAM smoke test passed with exit status 0."
    echo "==> Log file: $LOG_FILE"
    exit 0
else
    echo "==> [FAIL] Full-SoC SRAM smoke test failed with exit status $SIM_STATUS."
    echo "==> See log file: $LOG_FILE"
    exit $SIM_STATUS
fi
