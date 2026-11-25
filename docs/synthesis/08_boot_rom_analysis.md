# 08 - Boot ROM Hardware Initialization Analysis

This document addresses Section 7 of the ASIC implementation milestone: investigating a reproducible, synthesizable approach for the on-chip **4 KiB Boot ROM** (`BOOT_ROM_BASE = 0x0000_0000`, 1024 words × 32 bits).

---

## 1. Problem Statement

In the baseline simulation and FPGA environment:
- The Boot ROM was instantiated using `ff_ram #(.NBYTES(4096), .ROM(1'b1)) u_boot_rom`.
- In `ff_ram.sv`, the `$readmemb` statement was commented out (`// Handled by top_tb explicitly using readmemh`), meaning memory contents were dynamically poked into the array by the Verilog testbench at $t=0$.
- In ASIC standard-cell synthesis:
  - Without an initial block or physical ROM macro, Yosys optimizes unwritten read-only flip-flops into constant `$undef` or zero logic (32 bits of zeroes).
  - During real silicon fabrication, there is no testbench to backdoor-load registers. The CPU requires non-volatile boot instructions immediately upon reset deassertion at address `0x0000_0000` to jump to firmware.

---

## 2. Technical Evaluation of Architectural Options

We evaluated three potential implementation paths for the 4 KiB Boot ROM:

| Option | Architecture | Silicon Area | Flexibility | Physical Feasibility (SKY130) |
|---|---|---|---|---|
| **Option A: Synthesized Combinational Lookup Decoder (Case/ROM array in RTL)** | Synthesizable `always_comb` case statement mapping addresses `0x0` to `0xFFC` to constants. | $\approx 0.15\text{--}0.25\ \text{mm}^2$ (standard cells) | Low (requires resynthesis to update firmware) | **High (100% standard-cell compatible, no custom macros required).** |
| **Option B: Dedicated Hard Metal-Programmed ROM Macro** | Hardened ROM macro generator (e.g., OpenLane / SkyWater Via-programmed ROM). | $\approx 0.04\ \text{mm}^2$ | Low (firmware fixed in metal via mask) | **Medium (requires qualified SKY130 metal ROM compiler view).** |
| **Option C: Hardware SPI Bootloader to SRAM (First-Stage Bootloader)** | Minimal 128-byte hardware state machine or tiny 256-byte ROM that loads program code from off-chip SPI Flash into on-chip 16 KiB SRAM on reset. | $< 0.02\ \text{mm}^2$ | **Very High** (Flash can be reprogrammed at any time) | **High (standard practice for commercial SoCs like ESP32 / RP2040).** |

---

## 3. Engineering Recommendation

### Primary Recommendation: Option C (First-Stage SPI Flash Bootloader into SRAM)
- Rather than burning a large 4 KiB fixed boot program into mask silicon, commercial RISC-V microcontrollers implement a small autonomous hardware loader or minimal microcode ROM (< 256 bytes) that copies firmware from external QSPI Flash into the newly verified 16 KiB OpenRAM macro.
- The CPU reset vector is pointed to SRAM (`0x0000_8000`), giving users infinite firmware reconfigurability without metal mask respins.

### Secondary Recommendation for Closed/Fixed Silicon: Option A (Case Table Netlist)
- If an immutable on-chip ROM is strictly required, author a synthesizable `rom_4k.sv` module where:
  ```systemverilog
  always_comb begin
      case (bus.addr[11:2])
          10'h000: bus.rdata = 32'h00000297; // auipc t0, 0
          10'h001: bus.rdata = 32'h02028067; // jr 32(t0) -> jump to SRAM
          ...
          default: bus.rdata = 32'h00000013; // nop
      endcase
  end
  ```
- Yosys maps this cleanly into combinational NAND/NOR/AOI standard cells without flip-flops or clocks, eliminating uninitialized registers.
