# 05 - OpenRAM Macro Optimization & Verification

This document provides a comprehensive technical breakdown of replacing register-based flip-flop RAM with physical OpenRAM hard macro instances in AFTxAI.

---

## 1. Motivation & Macro Candidate Selection

As established in Section 03 and Section 04:
- Register-based RAM consumed **82.01% of total chip standard-cell area** (4.76 mm² out of 5.80 mm²).
- Address multiplexers driving 131,072 flip-flops caused catastrophic fanout loads (16,393 loads per bitline), producing **-1532.34 ns setup slack**.

### Evaluation of OpenRAM Generators & Hard Macros:
SkyWater SKY130 includes pre-generated compiler macros under `/OpenROAD-flow-scripts/flow/platforms/sky130ram/`:
- `sky130_sram_1rw1r_32x256_8` (1 KiB: 256 words × 32 bits)
- `sky130_sram_1rw1r_64x256_8` (2 KiB: 256 words × 64 bits)
- `sky130_sram_1kbyte_1rw1r_32x256_8`
- `sky130_sram_2kbyte_1rw1r_32x512_8`

**Selection Decision:**
We selected **`sky130_sram_1rw1r_64x256_8`**:
- Verified and qualified with complete Liberty (`.lib`), Physical (`.lef`), Layout (`.gds`), and Behavioral Verilog models.
- Dual 32-bit word width (64 bits per row), allowing high memory density.
- Word count: 256 rows × 64 bits = 16,384 bits = 2048 bytes (2 KiB) per macro.
- 8 instances banked together deliver exactly **16 KiB (16,384 bytes = 4096 words × 32 bits)**.

### Physical Footprint Reality Check:
Each `sky130_sram_1rw1r_64x256_8` macro has physical dimensions of approximately $683\ \mu\text{m} \times 615\ \mu\text{m} \approx 0.42\ \text{mm}^2$.
- 8 macro instances total **3.36 mm² of core macro area**.
- Total chip area with SRAM macros is approximately:
  $$\text{Standard Cells (Non-RAM)} \approx 1.04\ \text{mm}^2 + \text{SRAM Macros} \approx 3.36\ \text{mm}^2 + \text{Routing/Pads} \approx 0.5\text{--}1.0\ \text{mm}^2 \approx 4.9\text{--}5.4\ \text{mm}^2$$
- While total die area decreases moderately from the unroutable 5.80 mm² flop baseline, the primary engineering wins are **eliminating 131,072 clock tree endpoints**, removing unbuffered 16,393-load decoding trees, and dramatically improving routeability.

---

## 2. Banked Architecture & Addressing

The wrapper is implemented in `peripherals/ff_ram/rtl/sky130_sram_banked_16k.sv`:

```text
Address Decoding (32-bit byte address):
[31:14] : Unused (Checked for range < 16384 bytes)
[13:11] : 3-bit Bank Select (Banks 0 through 7)
[10:3]  : 8-bit Macro Row Address (0 to 255 rows)
[2]     : 32-bit Word Select within 64-bit row (0 = Low [31:0], 1 = High [63:32])
[1:0]   : Byte within 32-bit word
```

### Byte Strobe Mapping:
- If `bus.addr[2] == 0`: `din0[31:0] = bus.wdata`, `wmask0[3:0] = bus.strobe`.
- If `bus.addr[2] == 1`: `din0[63:32] = bus.wdata`, `wmask0[7:4] = bus.strobe`.

---

## 3. Clock-Edge Timing & Read-Handshake Protocol

### The OpenRAM Read Timing Arc:
In the macro behavioral model and Liberty timing library:
- **`posedge clk0`:** Macro latches `csb0` (chip select, active-low), `web0` (write enable, active-low), and `addr0`.
- **`negedge clk0`:** Memory core senses bitlines and drives `dout0` with a propagation delay of $T_{fall} \approx 0.4\text{ ns}$ (`DELAY = 3` in behavioral model).
- **Subsequent `posedge clk0`:** Macro invalidates `dout0 <= 64'bx` internally to simulate dynamic precharge.

### The 3-State FSM Controller:
To ensure cycle-accurate, glitch-free synchronous handshakes, the wrapper uses a 3-state FSM:

| State | Clock Cycle | `request_stall` | Macro Pin Controls | Description |
|---|---|---|---|---|
| **`IDLE`** | Cycle 0 | 1 (if `ren`) | `csb0=0, web0=1, addr0=macro_addr` | Read requested by bus master; wrapper asserts stall and presents address to macro. |
| **`READ_WAIT`** | Cycle 1 | 1 | `csb0=0, web0=1, addr0=read_macro_addr_q` | Macro captures address on rising edge, senses array, drives `dout0` on falling edge. Stall held. |
| **`READ_DATA`** | Cycle 2 | 0 | `csb0=1` (Idle) | At rising edge, wrapper registers `dout0` into `rdata_captured_q`. Stall drops to 0. Bus master latches data on this cycle! |

```text
Clock:        _____/‾‾‾‾‾\_____/‾‾‾‾‾\_____/‾‾‾‾‾\_____/‾‾‾‾‾\_____
Cycles:            |  Cycle 0  |  Cycle 1  |  Cycle 2  | Next Trans
FSM State:         |   IDLE    | READ_WAIT | READ_DATA |   IDLE
bus.ren:      _____/‾‾‾‾‾‾‾‾‾‾‾\___________________________________
bus.stall:    _____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___________/___________
macro.addr0:  -----< addr >----< addr >----------------------------
macro.dout0:  -------------------------< valid data >--x-----------
rdata_cap_q:  -----------------------------< valid data held >-----
bus.rdata:    -----------------------------< valid data held >-----
AHB Latch:                                             ^ (Posedge)
```

---

## 4. Verification Suite & Execution

Run the standalone regression:
```bash
bash synth/scripts/run_sram_tests.sh
```

**Coverage of 30 Test Cases:**
- All 8 banks tested at base addresses (`0x0000`, `0x0800`, `0x1000`, ...).
- All 8 banks tested at top boundaries (`0x07FC`, `0x0FFC`, `0x17FC`, ...).
- Sub-word byte strobes (1-byte, 2-byte, and 4-byte writes).
- Low vs. High 32-bit word multiplexing within 64-bit macro words.
- Back-to-back writes across banks.
- Back-to-back reads across banks.
- Write-then-immediate-read on identical addresses.
- Mid-transaction reset assertion and idle state recovery.
