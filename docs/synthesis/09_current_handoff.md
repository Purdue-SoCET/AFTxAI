# 09 - Current Engineering Handoff
**Date: November 26, 2026**

## 1. Branch and Repository State
- **Repository:** `Purdue-SoCET/AFTxAI`
- **Active Branch:** `feat/sram-macro-experiment`
- **Base Verification Commit:** `4de22cf` (*feat(pnr): validate SRAM GDS defect, consolidate verification scripts, and fix physical placement checks*)
- **Target PDK:** SkyWater SKY130 (sky130hd standard cells, sky130ram macros, sram22 macros)
- **Target Clock:** 100 MHz (10.0 ns period)

---

## 2. SRAM Macro Physical Integrity & Replacement Assessment

### A. OpenRAM Macro (`sky130_sram_1rw1r_64x256_8`)
- **Status:** **Physically Unqualified — Absolute Fabrication Blocker**
- **Evidence:** Confirmed hard metallic supply short on `met3` (layer 70/20) with 260 shorting geometries and 70.07 µm² direct VDD-to-GND overlap.
- **Role:** Preserved solely as an experimental architectural baseline and historical comparison point.

### B. SRAM22 Replacement Macro (`sram22_256x64m4w8`)
- **Status:** **Physically Credible & Validated Replacement Candidate**
- **Source:** UC Berkeley Substrate project (`ucb-substrate/sram22_sky130_macros`, commit `292a4e2`, BSD-3-Clause).
- **Physical Layout Verification:**
  - Layout SHA-256: `b6d5e63d819133c617e96eaa12123b66a6b771ecbdaeb153b87f868d0e94abd5`
  - Dimensions: $690.120\ \mu\text{m} \times 291.640\ \mu\text{m} = 0.2013\text{ mm}^2$ per macro.
  - Total 8-macro footprint: **$1.610\text{ mm}^2$** (a **52.0% area reduction** compared to OpenRAM's $3.356\text{ mm}^2$!).
  - Signal pins located on `met1` along bottom boundary ($Y = 0.0$ to $0.32\ \mu\text{m}$).
  - Power rails on `met2` (VDD/VSS straps).
  - Supply Audit Result: **Clean PASS (Status 0)**. 732 VDD labels, 701 VSS labels, 0 shorted geometries across `met1` and `met2`.
- **Timing Characterization:**
  - Liberty corner: `sram22_256x64m4w8_tt_025C_1v80.lib`.
  - Clock-to-Q read access time: $\sim 3.40\text{ ns}$ (comfortably fits inside 10.0 ns / 100 MHz clock period).
  - Setup constraint on address/controls: $\sim 0.14\text{ ns}$ to $0.32\text{ ns}$.
  - Hold constraint: $\sim 0.07\text{ ns}$ to $0.12\text{ ns}$.
- **Silicon Silicon Provenance:** Tested on silicon via Cadence shuttle program at $V_{DD}=1.8\text{ V}$, 25 MHz functional operation.

---

## 3. Verified Regressions Across Backends

The architecture features a clean parameter-selectable memory backend in `aft_top` and `aft_synth_top`:
- `SRAM_BACKEND = 0`: OpenRAM (`sky130_sram_banked_16k`)
- `SRAM_BACKEND = 1`: SRAM22 (`sram22_sram_banked_16k`)

All test suites pass 100% cleanly:
- **SRAM22 Equivalence Regression (27/27 checks):** **PASS** (`synth/scripts/run_sram22_tests.sh`)
- **AHB-Lite to SRAM22 Subordinate Integration (6/6 checks):** **PASS** (`synth/scripts/run_ahb_sram22_tests.sh`)
- **Full-SoC CPU Boot & SRAM Readback Smoke Test:** **PASS** (`synth/scripts/run_soc_sram_smoke.sh`)
  - Real instruction stream execution from Boot ROM verified.
  - GPIO output configuration verified.
  - AHB memory write and readback verified matching expected data (`0x00005A5A`).
- **L1 Cache Direct Functional Regression (7/7 checks):** **PASS** (`synth/scripts/run_cache_tests.sh`)
- **SRAM22 Physical GDS Supply Audit:** **PASS** (`synth/scripts/run_verify_sram22.sh`, Exit 0, 0 shorts detected).

---

## 4. Key Physical Placement & Floorplan Metrics

- **Die Area:** 3200 × 3200 µm
- **Core Area:** 3100 × 3100 µm (9.602 mm², ~47.0% core utilization with OpenRAM macros; lower with SRAM22)
- **Standard Cells (Post-Repair):** 76,789 movable instances (1.164 mm²)
- **Timing Slack (Post-Detailed Placement):**
  - Unplaced setup WNS: −81.17 ns
  - Post-Buffer Repair WNS: −17.77 ns
  - Post-Detailed Placement WNS: −18.03 ns
  - TNS: −111,938 ns
- **Placement Legality Analysis:**
  - Movable cells: 100% legalized (`check_placement -placeable` exits 0 with 0 illegal cells and 0 overlaps).
  - Macro boundary abutment: OpenROAD's unconstrained checker flags standard cells placed directly on the unhaloed macro edge (DPL-0011). Adding explicit placement blockages or halos around macro columns completely decouples movable cell legalization from fixed macro boundaries.

---

## 5. Next Engineering Steps
1. **SRAM22 Physical Floorplan & PnR Run:**
   - Author macro floorplan script updated with SRAM22 dimensions ($690.12\ \mu\text{m} \times 291.64\ \mu\text{m}$).
   - Set up explicit placement halos (`set_halo -halo {5 5}`) and verify full unconstrained `check_placement`.
2. **Timing Optimization on Critical Path:**
   - Address the −18.03 ns combinational path from PLIC to I-cache refill line by pipelining or registering the bus response.
