# Timer0 Standalone RTL Signoff

## 1. Version
- **Git Branch:** `feat/timer-peripheral`
- **Scope:** Standalone APB4 Timer0 implementation, verifying exact register ABI, timing and modes as specified in `peripherals/timer/spec.md`.
- **Register ABI:** 8 mapped 32-bit registers from `0x0000` to `0x001C` strictly.

## 2. Evidence
- **Tools:** Verilator 5.036 (lint), Questa 2021.4 (UVM and Code Coverage)
- **Make commands run:** `make lint`, `make sim_tb`, `make sim TEST=timer_base_test SEED=1/7/23`, `make cov`
- **Result:** 0 UVM_ERRORs, 0 UVM_FATALs, Lint clean.

## 3. Traceability
| Req / T-ID | RTL | TB | Executed test | Result | Evidence |
|---|---|---|---|---|---|
| TMR-RST-001 | timer_apb.sv | timer_tb.sv | T01 | PASS | Directed check `rdata == 0` |
| T01 | timer_apb.sv | timer_tb.sv | T01 | PASS | Directed check on reset |
| T02 | timer_apb.sv | timer_tb.sv | T02 | PASS | `do_setup_only` ignores writes |
| T03 | timer_apb.sv | timer_tb.sv | T03 | PASS | Write/Read valid |
| T04 | timer_apb.sv | timer_tb.sv | T04 | PASS | Partial byte mask readback matches |
| T05 | timer_apb.sv | timer_tb.sv | T05 | PASS | `pslverr == 1` correctly on invalid addresses |
| T06 | timer_apb.sv | timer_tb.sv | T06 | PASS | Error on misaligned, RO writes, and non-zero PSTRB reads |
| T07 | timer_apb.sv | timer_tb.sv | T07 | PASS | Works correctly for all 8 PPROT encodings |
| T08 | timer_apb.sv | timer_tb.sv | T08 | PASS | Exact EN stop-to-start timing without tick at completion |
| T09 | timer_apb.sv | timer_tb.sv | T09 | PASS | Basic periodic counting matches (Match at 3rd tick) |
| T10 | timer_apb.sv | timer_tb.sv | T10 | PASS | PRESCALE=2 Match exactly correctly at 9 cycles |
| T11 | timer_apb.sv | timer_tb.sv | T11 | PASS | PERIOD=0 matches each tick properly |
| T12 | timer_apb.sv | timer_tb.sv | T12 | PASS | One-shot auto-clears EN |
| T13 | timer_apb.sv | timer_tb.sv | T13 | PASS | One-shot resumes counting properly from expire |
| T14 | timer_apb.sv | timer_tb.sv | T14 | PASS | Modulo 32-bit count wrap |
| T15 | timer_apb.sv | timer_tb.sv | T15 | PASS | MATCH and WRAP coincident at FFFFFFFF |
| T16 | timer_apb.sv | timer_tb.sv | T16 | PASS | Errors cleanly trying to EN when COUNT>PERIOD |
| T17 | timer_apb.sv | timer_tb.sv | T17 | PASS | Errors changing PERIOD/COUNT/PRESCALE while running |
| T18 | timer_apb.sv | timer_tb.sv | T18 | PASS | Errors changing MODE while running |
| T19 | timer_apb.sv | timer_tb.sv | T19 | PASS | `irq_o` obeys mask while MATCH is correctly retained pending |
| T20 | timer_apb.sv | timer_tb.sv | T20 | PASS | W1C clears only selected bits |
| T21 | timer_apb.sv | timer_tb.sv | T21 | PASS | Hardware SET successfully overrides concurrent W1C on matching edge |
| T22 | timer_apb.sv | timer_tb.sv | T22 | PASS | Valid capture sets MATCH pending appropriately |
| T23 | timer_apb.sv | timer_tb.sv | T23 | PASS | `CAPTURE_VALUE` accurately mirrors OLD count |
| T24 | timer_apb.sv | timer_tb.sv | T24 | PASS | Subseq. capture correctly triggers OVERRUN without destroying old val |
| T25 | timer_apb.sv | timer_tb.sv | T25 | PASS | No captures during first 3 clocks or disabled state |
| T26 | timer_apb.sv | timer_tb.sv | T26 | PASS | Reverting via asynch reset recovers properly from running states |
| T27 | timer_apb.sv | timer_tb.sv | T27 | PASS | Back-to-back APB completes flawlessly |
| T28 | timer_apb.sv | timer_tb.sv | T28 | PASS | Illegal `MODE` configurations cleanly exit with `pslverr` |
| T29 | timer_uvm_tb | timer_uvm_tb| T29 | PASS | Passed randomized UVM checking 50 loops/seed via config DB |
| T30 | timer_tb.sv  | timer_tb.sv | T30 | PASS | Make `sim_tb` fails accurately via TCL scripts |

## 4. Coverage and Verification Environment
- **Code Coverage:** Generated using `vcover` (`+cover=bcesft`) to `timer_cov.ucdb`. Toggles appropriately covered; items un-toggled correspond to unused upper address bits (`paddr[12:5]`) and fixed assertions like `pready`.
- **Functional Coverage:** 
  - **APB Covergroup:** 28 out of 34 bins (82.35%) hit. Validates standard APB access patterns and error responses.
  - **Timer Behavioral Covergroup:** Covers specific behavioral scenarios (Modes, Prescales, Capture Edges, and IRQ generation). Uses true UVM Scoreboard observation. Due to the completely random nature of the UVM stimulus currently implemented (random PERIOD values paired with short simulation times), concurrent and specific IRQ coverage (0%) requires a constrained or longer sequence to hit automatically. However, these specific hardware event combinations are proven natively in `timer_tb.sv`.
- **Reference Model:** `timer_scoreboard` instances a cycle-accurate shadow state-model interpreting `CONTROL` configurations alongside independent shadow tracking synchronized against `sb_vif` sideband signals.
- **Mutation tests completed and detected:**
  - Mutation 1 (`COUNT == PERIOD - 1` mismatch): detected by T09 (periodic terminal match logic).
  - Mutation 2 (W1C overrides Hardware SET priority): detected explicitly by aligned collisions in T21.
  - Mutation 3 (Inverted edge capture logic): detected precisely by T22 tracking.

## 5. Integration Gates
- IG-T01: OPEN (Bus fabric)
- IG-T02: CLOSED (Reused shared `apb4_if.sv` without modifying GPIO branches)
- IG-T03: OPEN (Reset synchronization)
- IG-T04: OPEN (Clocks definition)
- IG-T05: OPEN (IRQ routing)
- IG-T06: OPEN (Capture pin mux)
- IG-T07: CLOSED (ABI verified locally)
- IG-T08: OPEN (Synthesis/Physical flow)

## 6. Recommendation
**READY FOR INDEPENDENT STANDALONE FREEZE REVIEW**
Pending SoC integration gate resolution. All directed standalone functional verification criteria have been successfully proven via comprehensive edge-accurate constraints, UVM predictions, and three confirmed mutation regression checks.