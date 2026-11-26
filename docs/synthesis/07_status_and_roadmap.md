# 07 - Project Status & Implementation Roadmap

This document outlines the current state of the AFTxAI pre-silicon implementation and details the engineering checklist required for full physical signoff.

---

## 1. Current Status Summary

| Area | Status | Notes |
|---|---|---|
| **RTL Design & Elaboration** | **Production Ready** | Full-SoC cleanly elaborates in Yosys via `read_slang` with 0 errors. |
| **Standard-Cell Synthesis** | **Verified Baseline** | Flop-based SoC baseline mapped to SKY130HD standard cells (5.80 mm² area). |
| **Static Timing Analysis (STA)** | **Preliminary Pre-Placement** | 100 MHz target constrained; baseline critical path (-1532 ns) isolated to 16,393-fanout RAM decoding. |
| **SRAM Macro RTL & Handshake** | **Verified Experimental** | 16 KiB 8-bank OpenRAM macro wrapper with 3-state FSM passes 30/30 regression tests. |
| **SRAM Physical GDS Supply Quality** | **FABRICATION BLOCKER** | Hard VDD-GND short confirmed in local macro GDS on met3 (260 short polygons, 70.07 µm² overlap). Physically unqualified. |
| **Boot ROM Implementation** | **Synthesizable Demo** | Synthesizable Boot ROM verified running self-checking CPU execution smoke test. |
| **Physical Floorplan & Placement** | **Placed & Repaired** | 8 macros placed, core area 9.602 mm², detailed placement legalized, WNS reduced to -19.54 ns post-repair. |
| **Power Grid, CTS & Routing** | **Pending** | Clock tree synthesis, PDN, and detailed routing pending. |

---

## 2. The Boot ROM Initialization Challenge

In the current baseline design (`peripherals/ff_ram/rtl/ff_ram.sv`), both RAM and ROM use `$readmemh(".../meminit.bin", mem)`.
- During FPGA synthesis or simulation, `$readmemh` initializes memory contents at time zero.
- In ASIC standard-cell synthesis without hard macros, Yosys synthesizes initial ROM values into an unalterable combinational decoder or flip-flop initialization tree.
- When migrating the 16 KiB main RAM to SRAM macros, the **4 KiB Boot ROM** remains as flip-flop registers unless replaced with a dedicated metal-programmed Read-Only Memory (ROM) cell or an off-chip SPI flash bootloader.

---

## 3. Physical Implementation Checklist (Path to GDSII)

To advance AFTxAI to physical fabrication signoff, the following stages must be completed:

- [x] **Milestone 1:** Full-SoC SystemVerilog elaboration in open-source tooling.
- [x] **Milestone 2:** Gate-level synthesis and SKY130HD cell mapping.
- [x] **Milestone 3:** SDC constraint authoring and pre-placement OpenROAD STA linking.
- [x] **Milestone 4:** OpenRAM hard macro banking and cycle-accurate read handshake controller.
- [x] **Milestone 5:** AHB-Lite bus integration testing of SRAM wrapper under full master protocol.
- [x] **Milestone 6:** Floorplanning: Macro placement of 8 SRAM instances with proper spacing, halo, and pin orientations.
- [x] **Milestone 7:** Physical GDS Supply Verification: Formally identified and audited upstream OpenRAM VDD-GND defect.
- [ ] **Milestone 8:** Power Distribution Network (PDN): Core power grid (VDD/VSS) routing.
- [ ] **Milestone 9:** Clock Tree Synthesis (CTS): Clock buffering to balance skew between processor core and memories.
- [ ] **Milestone 10:** I/O Pad Ring Integration: Connecting chip periphery to SkyWater pad macros (`sky130_fd_io`).
- [ ] **Milestone 11:** Post-Routing Signoff: Parasitic extraction (SPEF), post-route STA, Design Rule Checking (DRC), and Layout Versus Schematic (LVS) in Pegasus/Magic.
