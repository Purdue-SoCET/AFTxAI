# 09 - Current Engineering Handoff
**Date: November 26, 2026**

## 1. Branch and Repository State
- **Repository:** `Purdue-SoCET/AFTxAI`
- **Active Branch:** `feat/sram-macro-experiment`
- **Base Verification Commit:** `913161e` (*feat(pnr): implement macro-aware floorplan, physical placement, and high-fanout repair flow*)
- **Target PDK:** SkyWater SKY130 (sky130hd standard cells, sky130ram macros)
- **Target Clock:** 100 MHz (10.0 ns period)

---

## 2. Critical Blocker: SRAM Macro Physical GDS Supply Short (CONFIRMED)
Following up on upstream OpenROAD-flow-scripts Issue #4752, a rigorous, targeted physical layout investigation was executed directly against the local macro GDS file:
- **Macro File:** `/OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_64x256_8/sky130_sram_1rw1r_64x256_8.gds`
- **File SHA-256:** `d80b62abeddb681b143364b15131a5e0fad748544befbd2b7fd9fd5e67748e3d`
- **Verification Tool:** Python `pya` (KLayout layout engine) inside container `verilator_runner` (image `aftxai_eda:latest`)
- **Execution Script:** `synth/scripts/verify_sram_gds_short.sh` (backed by `synth/scripts/run_verify_report.py`)

### Findings & Evidence:
1. **Defect Classification:** Hard metallic supply short on metal layer 3 (`met3`, layer 70/20).
2. **Defect Quantification:**
   - Exact count of shorted polygons on `met3`: **260 distinct shorting geometries**.
   - Total shorted metal area: **70,070,000 dbu² (70.0700 µm²)**.
   - Polygons physically and directly overlap both `vdd` and `gnd` labels in the top cell (`sky130_sram_1rw1r_64x256_8`).
   - Sample short bounding box: `(876.350, 230.405)` to `(876.840, 230.955)` µm.
3. **Physical & Electrical Impact:**
   - Fabricating this layout as-is would produce an electrical dead short across the power rails, permanently disabling the entire chip upon power-up.
4. **Decision Gate Verdict:**
   - **The `sky130_sram_1rw1r_64x256_8` OpenRAM macro is physically UNQUALIFIED and an absolute FABRICATION BLOCKER.**
   - All functional RTL, synthesis wrappers, cycle-accurate 3-state handshake FSMs, and macro-placement floorplans remain highly valuable architectural and research achievements.
   - For tapeout signoff, this macro family cannot be fabricated until regenerated with a fixed OpenRAM compiler or replaced with alternative physical memory (e.g. SRAM22, standard-cell compiled memory, or verified non-shorted macro variants).

---

## 3. Verified Milestones & Test Status
All existing regressions and verification suites remain fully functional and passing:
- **Standalone SRAM Equivalence (30/30 checks):** PASS (`synth/scripts/run_sram_tests.sh`)
- **AHB-Lite Subordinate Integration (6/6 checks):** PASS (`synth/scripts/run_ahb_sram_tests.sh`)
- **L1 Cache Direct Regression (7/7 checks):** PASS (`synth/scripts/run_cache_tests.sh`)
- **Full SoC SRAM Smoke / CPU Execution (6/6 checks):** PASS (`synth/scripts/run_soc_sram_smoke.sh`)
- **Physical GDS Supply Short Verification:** FAIL (Exit code 1, defect formally proven and documented in `synth/out/sram_gds_defect_report.txt`)

---

## 4. Key Physical Results to Date (from `913161e` & Legal Placement Run)
- **Die Area:** 3200 × 3200 µm
- **Core Area:** 3100 × 3100 µm (9.602 mm², ~47.0% core utilization)
- **Macro Footprint:** 8 macros = 3.356 mm² ($8 \times 1040.76 \times 403.04\ \mu\text{m}$)
- **Standard Cells (Post-Repair):** 76,789 movable instances (1.164 mm²)
- **Timing Slack (Post-Detailed Placement):**
  - Unplaced setup WNS: −81.17 ns
  - Post-Buffer Repair WNS: −17.77 ns
  - Post-Detailed Placement WNS: −18.03 ns
  - TNS: −111,938 ns (down from −2.11M ns baseline)
- **Remaining Critical Path:** PLIC register `dut.u_plic.enable_q[31]` through bus response to I-cache refill register.
- **Physical Placement Status:** Cleanly passes `check_placement -placeable` with 0 overlaps, 0 site violations, and 0 illegal cells.

---

## 5. Next Engineering Priorities
1. **Physical Design TCL Flow Status:**
   - Completed: `set_wire_rc -layer met3` configured early before repair.
   - Completed: Updated pin placement syntax and legalizer validation (`check_placement -placeable`).
   - Open: Replace perimeter pin placement with structured I/O constraints or pad ring integration.
2. **Timing Analysis & Logic Optimization:**
   - Audit the −18.03 ns critical path from PLIC to I-cache refill.
   - Trace AHB-Lite subordinate and APB completer response latency into CPU instruction cache.
3. **Alternative Physical SRAM Investigation:**
   - Benchmark alternative memory generators (e.g., SRAM22 Sky130 macros or DFF-RAM array partitions) for clean physical DRC/LVS.
