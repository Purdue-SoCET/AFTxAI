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
| **Boot ROM Implementation** | **Pending Physical Solution** | Boot ROM currently uses synthesizeable flop array. Needs conversion to hard ROM macro or metal-programmed array. |
| **Physical Floorplan & Place-and-Route** | **Not Started** | Awaits macro placement, power distribution network (PDN), and I/O pad ring integration. |

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
- [ ] **Milestone 5:** AHB-Lite bus integration testing of SRAM wrapper under full master protocol.
- [ ] **Milestone 6:** Floorplanning: Macro placement of 8 SRAM instances with proper spacing, halo, and pin orientations.
- [ ] **Milestone 7:** Power Distribution Network (PDN): Core power grid (VDD/VSS) routing to SRAM macro rings and stripes.
- [ ] **Milestone 8:** Clock Tree Synthesis (CTS): Clock buffering to balance skew between processor core and SRAM clock pins.
- [ ] **Milestone 9:** I/O Pad Ring Integration: Connecting chip periphery to SkyWater pad macros (`sky130_fd_io`).
- [ ] **Milestone 10:** Post-Routing Signoff: Parasitic extraction (SPEF), post-route STA, Design Rule Checking (DRC), and Layout Versus Schematic (LVS) in Pegasus/Magic.
