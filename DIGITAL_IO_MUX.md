# Digital I/O Mux: RTL and Verification Spec

**Location:** `peripherals/digital_io_mux/`
**Authority:** `NEX.md` → `docs/memory_map.md` / `docs/memory_structure.md` → this spec. Halt on conflicts.

---

## 1. Scope

Synthesizable, parameterized APB **completer**. Selects peripheral functions for each pad and routes input.

**In Scope:**
- Per-pin function selection
- Registered pad outputs
- 2-flop input synchronizers (per pad)
- APB completer & select registers

**Out of Scope:**
- Pad cells, tri-state (`1'bz`) nets, pull-up/down logic
- APB interconnect/address decode for other peripherals
- Peripheral-to-function wiring mapping
- Synthesis/CDC timing constraints (handled at top-level)

---

## 2. Architecture

| Module | Location | Role |
|---|---|---|
| `digital_io_mux_cell` | `peripherals/digital_io_mux/` | Single pin logic (mux, output flops, synchronizer). |
| `digital_io_mux_apb` | `peripherals/digital_io_mux/` | APB completer & registers. |
| `digital_io_mux` | `peripherals/digital_io_mux/` | Top-level. Instantiates 1 APB block + `NUM_PINS` cells. |
| `sync_2ff` | `digital_lib/` | Reusable 2-flop synchronizer. |

*   **Interfaces:** Every module has its own `<module>_if` file, **except** `sync_2ff` which uses standard ports.
*   **Independence:** `digital_io_mux_cell` and `digital_io_mux_apb` are fully decoupled.
*   **Top-level Signals:** Packed vectors matching cell signals, widened across all pins:
    *   `fsel`: Pin `i` = `[i*NUM_BITS +: NUM_BITS]`
    *   `from_module`, `output_enable`, `to_module`: Pin `i`, function `f` = bit `i*NUM_FUNCS + f`
    *   `from_module_ff`, `output_en_ff`, `to_module_iopad`: Bit `i` = pin `i`

---

## 3. Parameters

| Parameter | Description | Valid Range | Default |
|---|---|---|---|
| `NUM_PINS` | Pads controlled | 1–32 | 32 |
| `NUM_FUNCS` | Selectable functions per pad | 1–4 | 4 |
| `NUM_BITS` | Width of select field | 1–2 | 2 |
| `NUM_REGS` | 32-bit select registers | 1–2 | 2 |

*   **[IOMUX-PAR-001]** Elaboration must **fail** if: parameters out of range, `NUM_FUNCS > 2**NUM_BITS`, or `NUM_PINS*NUM_BITS > NUM_REGS*32`. No silent truncation.
*   **[IOMUX-PAR-002]** No hard-coded widths/addresses; derive all sizes from parameters.

---

## 4. Per-Pin Cell (`digital_io_mux_cell`)

### 4.1 Interface (`digital_io_mux_cell_if`)

| Signal | Dir | Width | Description |
|---|---|---|---|
| `fsel` | In | `NUM_BITS` | Function select |
| `from_module` | In | `NUM_FUNCS` | Output value per function |
| `output_enable` | In | `NUM_FUNCS` | Output enable per function |
| `to_module_iopad`| In | 1 | Async raw pad value |
| `from_module_ff` | Out | 1 | Registered output value |
| `output_en_ff` | Out | 1 | Registered output enable |
| `to_module` | Out | `NUM_FUNCS` | Synchronized pad input to functions |

*(Also uses `pclk` and `presetn`)*

### 4.2 Behavior

*   **[IOMUX-CELL-001]** If `fsel < NUM_FUNCS`: `from_module_ff` and `output_en_ff` capture the selected function's inputs. `to_module` routes the synchronized pad input to the selected function.
*   **[IOMUX-CELL-002]** `to_module` defaults to 0. Unselected functions see 0.
*   **[IOMUX-CELL-003]** If `fsel >= NUM_FUNCS` (unused code): `from_module_ff` and `output_en_ff` default to 0 (pad not driven). All `to_module` bits see 0.
*   **[IOMUX-CELL-004]** `to_module_iopad` routes through `sync_2ff` (clocked by `pclk`, reset to 0) before distribution.
*   **[IOMUX-CELL-005]** Timing latencies:
    *   `from_module` / `output_enable` / `fsel` → `from_module_ff` / `output_en_ff`: 1 cycle.
    *   `to_module_iopad` → `to_module`: 2 cycles.
    *   `fsel` → `to_module` routing: 0 cycles (combinational).
*   All flops reset to 0 (safe state).

---

## 5. Synchronizer (`sync_2ff`)

*   **[IOMUX-SYNC-001]** Reusable primitive in `digital_lib/`:
    *   Parameterized width (default 1).
    *   Async active-low reset to 0.
    *   Contains only 2 flop stages; uses standard IO ports (no interface).

---

## 6. APB Completer (`digital_io_mux_apb`)

### 6.1 Bus Contract

*   **Protocol:** APB4 (`paddr`, `psel`, `penable`, `pwrite`, `pwdata`, `pstrb`, `pprot`, `prdata`, `pready`, `pslverr`).
*   **Interface:** `bus/apb/include/apb_if` (`completer` modport).
*   **Address:** `paddr` contains the peripheral address.
*   **Control:** `pready` is always 1 (0 wait states). `pprot` is ignored.

### 6.2 Register Map

| Address | Name | Access | Reset | Description |
|---|---|---|---|---|
| `0x5000` | `SEL0` | RW | 0 | Select fields 0–31 |
| `0x5004` | `SEL1` | RW | 0 | Select fields 32–63 (only if `NUM_REGS == 2`) |

*   **[IOMUX-REG-001]** Reset state selects function 0 for all pins.
*   **[IOMUX-REG-002]** Bits beyond `NUM_PINS*NUM_BITS` read as 0 and ignore writes.
*   **[IOMUX-REG-003]** Writes are `pstrb`-masked. `pstrb = 0` is a legal no-op.
*   **[IOMUX-REG-004]** Writing an unused select code is legal (triggers [IOMUX-CELL-003]).

### 6.3 Errors

*   **[IOMUX-APB-001]** Assert `pslverr` strictly if `paddr` is not `0x5000` or `0x5004` (e.g., triggering if `0x5004` is accessed when `NUM_REGS=1`, or if any other address is mapped).
*   Error accesses drop writes and return `0` on reads. `pslverr` is `0` outside an access phase.
*   **[IOMUX-APB-002]** No aliasing. Each register responds only at its exact address.

---

## 7. Coding Rules

*   **Logic:** No logic in `always_ff`. Use `always_comb` for next-state.
*   **Interfaces:** One interface per module in `include/` (except `sync_2ff`), pass interfaces as ports.
*   **Structure:** `include/` for interfaces, `rtl/` for modules.
*   **Standard:** Synthesizable SV only. No latches, internal X/Z, multiple drivers, `#` delays, or simulation-only constructs.

---

## 8. Verification

Verify against this spec (expected values), not RTL structure.

### 8.1 Configurations (Must pass lint + tests)

| Config | PINS | FUNCS | BITS | REGS |
|---|---|---|---|---|
| max | 32 | 4 | 2 | 2 |
| one_reg | 16 | 4 | 2 | 1 |
| 1bit | 8 | 2 | 1 | 1 |
| min | 1 | 1 | 1 | 1 |
| partial | 10 | 3 | 2 | 1 |

*   Also verify illegal configurations fail elaboration.

### 8.2 Tests

*   **T01:** Reset (regs=0, cell outs=0, syncs=0).
*   **T02:** RW all registers with random data/unused bits.
*   **T03:** All 16 `pstrb` combinations.
*   **T04:** Errors (unmapped addresses strictly trigger `pslverr`).
*   **T05:** `pprot` independence.
*   **T06:** Output path latency (1 cycle).
*   **T07:** Input path latency (2 cycles).
*   **T08:** Dynamic `fsel` change timing (0 cycles).
*   **T09:** Unused select code isolation.
*   **T10:** Cross-talk prevention.
*   **T11:** Mid-traffic reset.
*   **T12:** Unit tests for submodules.
*   **T13:** APB protocol assertions.

*Self-checking testbench in `verification/`.*

### 8.3 Tools & Execution

*   **Lint/Sim:** `verilator/5.036` (`--lint-only -Wall` + fast sim).
*   **Coverage:** `lcov/2.1`.
*   **Sign-off:** `cadence/xcelium/23.03`.
*   **Flow:** `Makefile` with targets `lint`, `sim CFG=<name>`, `regress`, `cov`, `clean`. Artifacts in `build/`.

### 8.4 Acceptance

Standalone verification is achieved when:
*   All configs pass lint and T01–T13.
*   Elaboration correctly fails on invalid params.
*   Coverage reported.
*   No weakened tests.
*   Output table generated with PASS / FAIL / NOT RUN.
