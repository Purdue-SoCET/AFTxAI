# AFTxAI Synthesis & ASIC Implementation Documentation

Welcome to the **AFTxAI Synthesis and Implementation Engineering Guide**. This documentation collection provides a complete, self-contained, reproducible workflow for elaborating, synthesizing, optimizing, and timing the AFTxAI System-on-Chip (SoC) using open-source Electronic Design Automation (EDA) tools targeting the **SkyWater SKY130 (130nm) High-Density (HD)** standard-cell technology.

---

## Measured Milestone Comparison (Synthesis Baseline vs. SRAM vs. Physical Placement)

> **Important Engineering Note on Timing & Physical Metrics:**  
> Checkpoints 1 through 3 represent unplaced or pre-repair estimates. Checkpoint 4 presents the **first fully legalized physical placement checkpoint** with placed OpenRAM macros, legalized standard cells, and post-repair high-fanout buffer trees. Physical metrics now use exact LEF macro dimensions ($1040.76\ \mu\text{m} \times 403.035\ \mu\text{m} = 0.4195\text{ mm}^2$ per macro; $3.3557\text{ mm}^2$ total macro area). While high-fanout buffering successfully resolved the severe cache slew bottleneck (reducing WNS from −80.91 ns down to −19.54 ns), full 100 MHz closure has not yet been achieved.

The table below contrasts the baseline register-based SoC against the SRAM experiment and physical placement milestones:

| Metric | FF-RAM Baseline (`feat/full-soc-synthesis`) | SRAM Baseline (`6e83625`) | L1 Cache Optimized (`feat/sram-macro-experiment`) | Placed & Repaired (`c4cbdce0`) | Delta / Engineering Impact |
|---|---|---|---|---|---|
| **Standard-Cell Count** | 233,481 cells | 82,518 cells | 73,501 cells | **76,318 cells** | +2,817 buffer/inverter cells inserted |
| **Sequential Flip-Flops** | 159,878 DFFs | 28,816 DFFs | 28,816 DFFs | **28,816 DFFs** | Identical synchronous state storage |
| **Standard-Cell Area** | 5.799 mm² | 1.177 mm² | 1.123 mm² | **1.157 mm²** | +33,408 µm² buffer insertion area |
| **SRAM Hard Macro Footprint** | 0 mm² | 3.36 mm² (est.) | 3.36 mm² (est.) | **3.356 mm²** ($8 \times 1040.76 \times 403.04\ \mu\text{m}$) | 8 placed & legalized macro instances |
| **Total Core Area / Utilization**| N/A | N/A | N/A | **9.602 mm² / 47.0%** (3.15 × 3.15 mm core) | Feasible density; 759 µm central channel |
| **Worst Setup Slack (WNS)** | **-1532.34 ns** | **-84.49 ns** | **-80.91 ns** | **-19.54 ns** | **+61.37 ns timing closure (4.1× reduction!)** |
| **Total Negative Slack (TNS)** | -4.12E+07 ns | -2.18E+06 ns | -2.11E+06 ns | **-2.72E+05 ns** | **87.1% TNS reduction post-repair** |
| **Worst Hold Slack** | +0.20 ns | +0.11 ns | +0.11 ns | **+0.12 ns** | Met across all checkpoints |
| **Critical Timing Path** | 16,393-load RAM Decoder | L1 D-Cache Writeback MUX | L1 D-Cache Read Multiplexer | **PLIC Enable (`enable_q[31]`) -> I-Cache Fill** | Cache fanout bottleneck resolved! |
| **Max Slew Violation** | ~84 ns | ~83 ns | 83.89 ns | **8.09 ns** | **-75.80 ns slew reduction** |
| **SRAM Macro Timing Arcs** | N/A | +3.67 ns slack (MET) | +3.68 ns slack (MET) | **+3.68 ns slack (MET)** | Macro read output arcs comfortably meet timing |

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
   - 30-check regression verification suite.
6. **[06 - Troubleshooting & Verified Fixes](06_troubleshooting.md)**
   - Real encountered errors and their step-by-step remedies (`STA-0171`, `ORD-2010`, `ORD-2013`, `$_TBUF_` linking, undriven nets, simulation race conditions).
7. **[07 - Project Status & Implementation Roadmap](07_status_and_roadmap.md)**
   - Current status of RTL, synthesis, timing, and SRAM experiment.
   - The Boot ROM initialization challenge and physical macro placement checklist.
8. **[08 - Boot ROM Hardware Initialization Analysis](08_boot_rom_analysis.md)**
   - Synthesizable case-ROM vs. hard metal ROM vs. QSPI Flash first-stage bootloader.

---

## One-Command Automation Workflows

The repository provides automated, reviewable bash entry points under `synth/scripts/`:

```bash
# 1. Environment and toolchain verification
bash synth/scripts/check_environment.sh

# 2. Standalone SRAM 30-check regression suite
bash synth/scripts/run_sram_tests.sh

# 3. AHB-Lite subordinate to SRAM integration suite
bash synth/scripts/run_ahb_sram_tests.sh

# 4. Full-SoC simulation smoke test with SRAM macros
bash synth/scripts/run_soc_sram_smoke.sh

# 5. Full-SoC SystemVerilog elaboration (Default FF-RAM vs. SRAM)
bash synth/scripts/run_elaboration.sh         # Elaboration with FF-RAM
bash synth/scripts/run_elaboration.sh --sram  # Elaboration with SRAM macros

# 6. Full-SoC SRAM-backed synthesis & SKY130HD mapping
bash synth/scripts/run_sram_synthesis.sh

# 7. OpenROAD macro-aware Static Timing Analysis
bash synth/scripts/run_sram_sta.sh
```
