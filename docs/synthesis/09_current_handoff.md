# 09 - Current Engineering Handoff
**Date: November 26, 2026**

## 1. Branch and Repository State
- **Repository:** `Purdue-SoCET/AFTxAI`
- **Active Branch:** `feat/sram-macro-experiment`
- **Base Commit:** `8b2b147` (*feat(sram22): integrate verified SRAM22 macro backend, validate GDS supply integrity, and verify full-SoC CPU execution*)
- **Target PDK:** SkyWater SKY130 (sky130hd standard cells, sram22 macros, sky130ram baseline)
- **Target Clock:** 100 MHz (10.0 ns period)

---

## 2. Configuration Control & Separation of Workflows

The build flow enforces clean separation between the historical OpenRAM baseline and the fabrication-ready SRAM22 candidate:
- **`SRAM_BACKEND=0` (OpenRAM):**
  - Synthesizes `sky130_sram_banked_16k.sv` with `synth/sky130_sram_1rw1r_64x256_8_bb.v`.
  - Outputs gate netlist to `synth/out_sram/netlist_sta_linked.v`.
  - Places macros into `synth/out_physical/`.
- **`SRAM_BACKEND=1` (SRAM22):**
  - Synthesizes `sram22_sram_banked_16k.sv` with `synth/sram22/sram22_256x64m4w8_bb.v`.
  - Outputs gate netlist to `synth/out_sram22/netlist_sta_linked.v`.
  - Places macros into `synth/out_physical_sram22/`.

Every synthesis, STA, and physical placement script honors `SRAM_BACKEND`, validates Docker repository mounts, and verifies netlist macro counts before proceeding.

---

## 3. Verified SRAM22 Synthesis & Physical PPA Results

### A. Synthesis & Netlist Structural Audit
- Command: `SRAM_BACKEND=1 bash synth/scripts/run_sram_synthesis.sh`
- Structural Audit:
  - Exact `sram22_256x64m4w8` instance count: **8**
  - OpenRAM macro instances: **0**
  - Unintended memory flip-flops: **0** (synthesizable Boot ROM and SRAM blackboxes cleanly preserved)
  - Standard cell gate count: **73,451 cells** (1.122 mm² mapped area)

### B. Pre-Placement OpenROAD Macro-Aware STA
- Command: `SRAM_BACKEND=1 bash synth/scripts/run_sram_sta.sh`
- Timing arcs through SRAM22 macros:
  - Macro Setup time: **0.47 ns** (Slack: **+4.33 ns MET**)
  - Macro Clock-to-Q read access time: **3.40 ns** (Slack: **+5.70 ns MET**)
  - Demonstrates that SRAM22 comfortably supports 100 MHz synchronous read/write timing.

### C. Physical Placement & Complete Legality Validation
- Command: `SRAM_BACKEND=1 bash synth/scripts/run_physical_placement.sh`
- Macro Floorplan:
  - 2 columns of 4 macros: Column 0 at $X = 150.42\ \mu\text{m}$, Column 1 at $X = 2350.14\ \mu\text{m}$.
  - Central routing channel width: **1509.60 µm** (nearly double OpenRAM's 759.22 µm corridor).
  - Placement blockages: Applied $5.0\ \mu\text{m}$ halo blockages over macro bounding boxes.
- Placement Convergence:
  - Detailed placement negotiation legalizer converged in 18 iterations (0 illegal cells, 0 illegal sites).
  - Unconstrained full placement check (`check_placement -verbose`) passed with **0 errors**.
- Placement Timing & Area:
  - Total macro area: **1.610 mm²** (vs OpenRAM's 3.356 mm², **52.0% macro area reduction**).
  - Core utilization: **28.9%** (vs OpenRAM's 47.1%).
  - Detailed placement setup WNS: **−19.66 ns** (TNS: **−91,756 ns**, down from −111,938 ns in baseline).
  - Detailed placement hold WNS: **+0.43 ns (MET)**.
  - Critical path: `dut.u_plic.enable_q[31]` through APB/AHB bus multiplexers to `dut.u_core.icache_inst.data_array[6][3]` (`_102400_`).

---

## 4. Multi-Layer Supply Integrity Audit
- Command: `bash synth/scripts/run_verify_sram22.sh`
- Layer-aware geometric audit across `met1` (68/20), `met2` (69/20), and `via1` (68/44) cuts.
- 728 VDD labels, 697 VSS labels.
- Zero planar supply shorts, zero via bridging cuts.
- Result: **Clean PASS (Status 0)**.

---

## 5. Next Engineering Steps
1. **Pipelining Critical Path:** Register the PLIC/APB read response to break the −19.66 ns combinational path into two single-cycle transfers.
2. **Clock Tree Synthesis (CTS):** Run TritonCTS on `synth/out_physical_sram22/aft_synth_top_placed.odb`.
3. **Routing & GDS Export:** Stream out routed GDS for DRC/LVS tapeout signoff.
