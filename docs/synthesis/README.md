# AFTxAI Synthesis & ASIC Implementation Documentation

Welcome to the **AFTxAI Synthesis and Implementation Engineering Guide**. This documentation collection provides a complete, self-contained, reproducible workflow for elaborating, synthesizing, optimizing, and timing the AFTxAI System-on-Chip (SoC) using open-source Electronic Design Automation (EDA) tools targeting the **SkyWater SKY130 (130nm) High-Density (HD)** standard-cell technology.

---

## Guide Index

1. **[01 - Environment Setup & Prerequisites](01_environment_setup.md)**
   - Complete machine requirements (WSL2 / Linux).
   - Docker installation, rootless daemon configuration, permissions.
   - Container image setup (`openroad/orfs:latest` and extended `aftxai_eda:latest`).
   - Tool sanity checks (Yosys, read_slang, OpenROAD, Verilator).
2. **[02 - Design Architecture & Elaboration](02_design_architecture.md)**
   - Overview of AFTxAI RISC-V SoC: core, buses (AHB-Lite, APB), memories, peripherals.
   - Purpose of the synthesis wrapper `aft_synth_top.sv`.
   - Handling SystemVerilog interfaces, packages, and multidimensional arrays during elaboration.
   - Full-SoC elaboration via Yosys and the `read_slang` SystemVerilog frontend.
3. **[03 - Synthesis & Standard-Cell Technology Mapping](03_synthesis_flow.md)**
   - Generic synthesis (`synth -top aft_synth_top -flatten`).
   - Flip-flop mapping (`dfflibmap`) and combinational logic mapping (`abc`) into SKY130HD cells.
   - Measured synthesis baseline metrics (cell count, flop count, silicon area).
   - Netlist export, syntax cleanup, and removal of simulation-only constructs.
4. **[04 - Static Timing Analysis (OpenROAD STA)](04_timing_analysis.md)**
   - SDC timing constraints (`synth/aft_top.sdc`) at 100 MHz clock target.
   - Design linking with Liberty (.lib) and Physical Macro/Tech LEF files.
   - Resolution of `$_TBUF_` primitives with SKY130HD tri-state cells (`tbuf_sky130.v`).
   - Detailed analysis of setup WNS (-1532.34 ns) and the 16,393-load RAM decoder bottleneck.
5. **[05 - OpenRAM Macro Optimization & Verification](05_sram_optimization.md)**
   - Flip-flop RAM vs. synchronous SRAM macro trade-offs.
   - Evaluation of SkyWater OpenRAM macros and selection of `sky130_sram_1rw1r_64x256_8`.
   - 8-bank 16 KiB interleaved architecture (`sky130_sram_banked_16k.sv`).
   - Timing arcs, Liberty setup/hold, and clock-edge root cause analysis.
   - 3-state FSM read controller architecture.
   - 30-test regression verification suite.
6. **[06 - Troubleshooting & Verified Fixes](06_troubleshooting.md)**
   - Real encountered errors and their step-by-step remedies (`STA-0171`, `ORD-2010`, `ORD-2013`, `$_TBUF_` linking, undriven nets, simulation race conditions).
7. **[07 - Project Status & Implementation Roadmap](07_status_and_roadmap.md)**
   - Current status of RTL, synthesis, timing, and SRAM experiment.
   - The Boot ROM initialization challenge and physical macro placement checklist.

---

## Quick Start: One-Command Automation Scripts

The repository provides automated, reviewable bash entry points under `synth/scripts/`:

```bash
# 1. Check host prerequisites and Docker container EDA toolchain
bash synth/scripts/check_environment.sh

# 2. Run the 30-test SRAM macro read-handshake regression suite
bash synth/scripts/run_sram_tests.sh

# 3. Run the AHB-Lite subordinate to SRAM macro integration suite
bash synth/scripts/run_ahb_sram_tests.sh

# 4. Run full-SoC SystemVerilog elaboration
bash synth/scripts/run_elaboration.sh

# 4. Prepare full synthesis script
bash synth/scripts/run_synthesis.sh

# 5. Run OpenROAD Static Timing Analysis
bash synth/scripts/run_sta.sh
```
