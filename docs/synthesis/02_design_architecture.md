# 02 - Design Architecture & Elaboration

This document describes the internal structure of the AFTxAI System-on-Chip (SoC) and the technical methodology used to elaborate its modern SystemVerilog codebase into an elaboration database.

---

## 1. What is AFTxAI?

**AFTxAI** is an open-source RISC-V SoC designed for embedded acceleration, control, and edge sensing. It integrates:
- **Processor Core:** 32-bit RISC-V (RV32IM / IMC) with Harvard L1 instruction and data caches (`riscv/`).
- **Bus Fabric:**
  - **AHB-Lite Interconnect (`bus/ahb/`):** High-bandwidth system interconnect connecting the CPU master, DMA controller, on-chip SRAM/ROM, and AHB-to-APB bridge.
  - **APB Interconnect (`bus/apb/`):** Low-power peripheral bus for memory-mapped I/O.
- **On-Chip Memories:**
  - **Boot ROM (4 KiB):** Holding initial bootloader firmware.
  - **Main RAM (16 KiB):** Data and program RAM.
- **Peripherals (`peripherals/`):**
  - **DMA Controller:** Multi-channel memory-to-memory and memory-to-peripheral block transfer engine.
  - **Interrupt Infrastructure:** Core-Local Interruptor (CLINT) for timer/software interrupts and Platform-Level Interrupt Controller (PLIC) for prioritized external interrupts.
  - **Serial Communication:** UART, SPI Controller with FIFO, and I2C Master Engine.
  - **General-Purpose I/O:** 4 GPIO banks with configurable pull-up/pull-down and tri-state control, pin-multiplexed via `digital_io_mux`.
  - **Timers and PWM:** Multi-channel pulse-width modulators and capture timers.
  - **External SRAM Controller:** Off-chip parallel memory interface (`sram_controller/`).

---

## 2. Top-Level Hierarchy & Synthesis Wrapper (`aft_synth_top.sv`)

### Why Does `aft_synth_top` Exist?
In modern SystemVerilog testbenches, top-level ports often connect to virtual interfaces or structured bundles (e.g., `sram_if sram`). However, commercial and open-source ASIC synthesis tools expect the top-level module of a chip to have physical wire/logic pins suitable for wirebonding or pad mapping (e.g., discrete addresses, chip-enables, byte enables).

`synth/aft_synth_top.sv` serves as an adapter:
1. It instantiates the production `aft_top dut (...)`.
2. It breaks out the `sram_if` bundle into discrete physical output pins (`sram_addr[18:0]`, `sram_wdata[15:0]`, `sram_ce0_n`, etc.).
3. It keeps the production `aft_top.sv` 100% untouched and identical for both simulation and synthesis.

---

## 3. SystemVerilog Elaboration with `read_slang`

Standard open-source tools (like classic Yosys Verilog-2005 parsers) fail on complex SystemVerilog constructs such as:
- Packages (`aft_map_pkg.sv`, `ahb_pkg.sv`).
- Interfaces with modports (`bus_protocol_if.sv`, `ahb_if.sv`, `apb_if.sv`).
- Nested typedef structs and enums.
- Multidimensional arrays and generate loops.

To solve this, AFTxAI uses the **`read_slang`** plugin in Yosys. Slang is a high-performance C++ compiler for SystemVerilog that fully parses IEEE 1800-2017 language constructs.

### Executing Elaboration:
```bash
bash synth/scripts/run_elaboration.sh
```

### File Ordering & Include Paths:
Files must be fed with packages and interface definitions first:
1. Include flags (`-I bus/ahb/include`, `-I top_level/map`, etc.).
2. Package sources (`aft_map_pkg.sv`, `ahb_pkg.sv`, `spi_types_pkg.sv`).
3. Interface files (`bus_protocol_if.sv`, `ahb_if.sv`, `apb_if.sv`, etc.).
4. RTL source files across `riscv/`, `bus/`, `peripherals/`, `digital_lib/`, and `top_level/`.
5. Top wrapper: `synth/aft_synth_top.sv`.

### Elaboration Statistics (Baseline):
When elaboration finishes, Yosys reports:
- **Hierarchical Cells:** 12,578 cells.
- **Internal Wires:** 17,931 wires (695,550 wire bits).
- **Inferred Memories:** 7 memory arrays totaling 167,632 memory bits.
- **Top Module:** `\aft_synth_top` with 47 ports (361 port bits).
