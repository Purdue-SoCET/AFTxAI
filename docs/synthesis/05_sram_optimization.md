# 05 - SRAM Integration and Comparative PPA Analysis
**Date: November 26, 2026**

## 1. Executive Summary & Comparative PPA Metrics

We completed full ASIC synthesis, Static Timing Analysis (STA), and macro-aware detailed physical placement for the RISC-V SoC with two memory backends:
1. **OpenRAM Baseline (`sky130_sram_1rw1r_64x256_8`):** Preserved for historical comparison; physically unqualified for tapeout due to a 260-polygon metallic VDD-to-GND supply short on `met3`.
2. **SRAM22 Fabrication Candidate (`sram22_256x64m4w8`):** Silicon-proven macro from UC Berkeley Substrate, physically verified clean of supply shorts, mapped through Yosys and placed cleanly through OpenROAD.

### Measured PPA & Physical Comparison Table

| Metric | OpenRAM Baseline (`SRAM_BACKEND=0`) | SRAM22 Candidate (`SRAM_BACKEND=1`) | Delta / Advantage |
|---|---|---|---|
| **Macro Type** | `sky130_sram_1rw1r_64x256_8` | `sram22_256x64m4w8` | Silicon-proven candidate |
| **Macro Instance Count** | 8 macros (16 KiB total) | 8 macros (16 KiB total) | Identical organization |
| **Single Macro Footprint** | $1040.76 \times 403.04\ \mu\text{m} = 0.4195\text{ mm}^2$ | $690.12 \times 291.64\ \mu\text{m} = 0.2013\text{ mm}^2$ | **−52.0% area per macro** |
| **Combined 8-Macro Area** | **3.356 mm²** | **1.610 mm²** | **−1.746 mm² (−52.0%)** |
| **Standard Cell Area** | 1.164 mm² (76,789 cells) | 1.161 mm² (76,401 cells) | Comparable logic complexity |
| **Total Placed Instances Area** | 4.520 mm² | **2.771 mm²** | **−1.749 mm² (−38.7%)** |
| **Core Area & Utilization** | 9.602 mm² / 47.1% utilization | 9.602 mm² / **28.9% utilization** | **18.2% more free space** |
| **Central Routing Channel Width**| 759.22 µm | **1509.60 µm** | **+750.38 µm routing corridor** |
| **Unplaced Setup WNS** | −81.17 ns (TNS: −2.11M ns) | −85.52 ns (TNS: −2.11M ns) | Comparable pre-placement |
| **Post-Repair Setup WNS** | −17.77 ns (TNS: −110.3k ns) | −19.48 ns (TNS: −90.4k ns) | Better post-repair TNS |
| **Post-Detailed Placement WNS**| −18.03 ns (TNS: −111.9k ns) | **−19.66 ns (TNS: −91.8k ns)** | TNS reduced by **18.0%** |
| **Hold Slack WNS** | +0.12 ns (MET) | **+0.43 ns (MET)** | Positive hold margin across design |
| **SRAM Read Access Slack** | +4.10 ns (MET) | **+5.70 ns (MET)** | **1.60 ns faster memory read slack** |
| **Full Placement Legality** | 0 illegal movable cells; boundary abutment warning | **100% Legalized with 0 violations** | Complete blockage isolation |
| **Physical Defect Status** | **FATAL (260 shorts, 70.07 µm²)** | **CLEAN (0 supply shorts)** | Validated fabrication candidate |

---

## 2. Configuration Control Architecture

The build system enforces strict backend separation across directories and scripts:
- **`SRAM_BACKEND=0`**:
  - RTL Target: `sky130_sram_banked_16k.sv`
  - Blackbox: `synth/sky130_sram_1rw1r_64x256_8_bb.v`
  - Netlist Output: `synth/out_sram/netlist_sta_linked.v`
  - Physical Output: `synth/out_physical/`
- **`SRAM_BACKEND=1`**:
  - RTL Target: `sram22_sram_banked_16k.sv`
  - Blackbox: `synth/sram22/sram22_256x64m4w8_bb.v`
  - Netlist Output: `synth/out_sram22/netlist_sta_linked.v`
  - Physical Output: `synth/out_physical_sram22/`

---

## 3. Floorplan & Placement Legality

In `synth/scripts/physical_design.tcl`, the SRAM22 arrangement leverages the compact macro dimensions:
- Column 0: $X = 150.42\ \mu\text{m}$, Rows at $Y = 149.60, 701.76, 1300.16, 1901.28\ \mu\text{m}$.
- Column 1: $X = 2350.14\ \mu\text{m}$, Rows at $Y = 149.60, 701.76, 1300.16, 1901.28\ \mu\text{m}$.
- Placement blockages with a $5.0\ \mu\text{m}$ halo are applied directly over each macro bounding box (`create_blockage -region`).
- **Result:** Detailed placement converged in 18 iterations with 0 illegal cells, and the full unconstrained `check_placement -verbose` passed with **zero errors**.
