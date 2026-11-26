# 07 - Status and Roadmap
**Date: November 26, 2026**

## 1. Current Milestone Status

- [x] **Milestone 1:** Establish synthesizable Boot ROM and standalone SRAM macro functional wrappers.
- [x] **Milestone 2:** Verify AHB-Lite subordinate to SRAM macro integration with cycle-accurate read handshake (6/6 passing).
- [x] **Milestone 3:** Full SoC instruction-driven CPU execution verification with SRAM load/store verification (6/6 passing).
- [x] **Milestone 4:** Full ASIC synthesis with macro blackbox preservation and SKY130HD standard cell mapping (73,451 cells).
- [x] **Milestone 5:** Establish physical placement floorplan with 8 SRAM macros and legal standard-cell placement.
- [x] **Milestone 6:** Physical macro GDS audit isolating OpenRAM metallic supply short defect (`met3`, 260 shorting polygons, 70.07 µm²).
- [x] **Milestone 7:** Research, inspect, and physically verify SRAM22 (`sram22_256x64m4w8`) macro geometry (0 planar/via shorts).
- [x] **Milestone 8:** Author parameter-selectable backend (`SRAM_BACKEND=0/1`) in RTL, synthesis, STA, and PnR flows.
- [x] **Milestone 9:** Synthesize full SRAM22-backed SoC, validate 8-macro structural netlist, and run macro-aware OpenROAD STA.
- [x] **Milestone 10:** Create SRAM22 physical placement floorplan with halo blockages, achieving 100% full legality validation (`check_placement -verbose` passes with 0 errors).
- [x] **Milestone 11:** Measure and document comparative PPA metrics (SRAM22 delivers 52% macro area reduction and 18% lower TNS).

---

## 2. Active Roadmap

1. **Timing Closure on Combinational Bus Path:**
   - Critical path: PLIC register `dut.u_plic.enable_q[31]` through APB/AHB multiplexing to CPU I-Cache refill register (`_102400_`), slack −19.66 ns.
   - Pipelining / registering read responses will break this long cross-subsystem combinational path into two single-cycle transfers.
2. **Clock Tree Synthesis (CTS) & Routing:**
   - With complete placement legality validated and 1.51 mm wide central routing channels available, advance design through TritonCTS and detailed routing.
3. **DRC / LVS Tapeout Signoff:**
   - Execute full chip DRC and LVS checks using Pegasus/Magic/KLayout signoff decks.
