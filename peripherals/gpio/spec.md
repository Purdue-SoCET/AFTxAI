# AiFTx GPIO Peripheral: Functional, Interface, and Verification Specification

**Document:** `peripherals/gpio/spec.md` (proposed repository location)
**Revision:** 0.1, design-review candidate
**Status:** COMPLETE FOR STANDALONE GPIO DESIGN; NOT APPROVED FOR SOC INTEGRATION
**Owner:** AiFTx GPIO workstream
**Audience:** ChipNexus Nex, reviewers, verification engineers
**Language:** IEEE 1800 SystemVerilog

> **Read before implementing:** This document intentionally contains a complete standalone GPIO behavior contract **and** explicit integration approval gates. Nex may implement and verify the standalone peripheral using the selected local interface once it has inspected the repository. It must not silently alter the shared APB interface, global address map, PLIC allocation, clock architecture, or reset architecture. Stop and report any conflict with `NEX.md` or `docs/AiFT_spec.md`. Do not report full-SoC integration readiness until Section 2's integration gates are closed.
>

## 1. Purpose, hierarchy of authority, and provenance

### 1.1 Scope

Implement a reusable, synthesizable, memory-mapped **APB4 GPIO slave**. The same RTL must support GPIO0–GPIO3 instances, each independently parameterizable from 1 to 32 pins. The default configuration is 32 pins. The GPIO controls output data and output enables; reads synchronized digital inputs; provides software-controlled pull-up/pull-down *requests*, open-drain operation, atomic output updates, and per-pin rising-edge, falling-edge, high-level and low-level interrupt detection. One aggregate interrupt output is provided per GPIO bank.

This GPIO block is an **APB slave only**. It must not contain an AHB-to-APB bridge, APB address decoder for multiple slaves, physical I/O pads, actual internal tristate nets, a PLIC, a pin-mux register bank, or firmware.

### 1.2 Source priority

1. The repository's `NEX.md` controls engineering workflow, toolchain, and repository conventions.
2. `docs/AiFT_spec.md` controls approved *system* behavior. If it conflicts with a proposal in this document, **report the discrepancy before changing RTL**. Obtain approval and update the system specification rather than assuming this file supersedes it.
3. This document controls GPIO-local behavior and its defined register contract once adopted.
4. Arm's **AMBA APB Protocol Specification** controls actual APB protocol semantics. A design choice here cannot override the standard.

### 1.3 External references (documentation only)
- Teamworkflow: `NEX.md`.
- Arm, **AMBA APB Protocol Specification**, ARM IHI 0024E: https://documentation-service.arm.com/static/63fe2c1356ea36189d4e79f3 . Implement the APB4 subset, not the APB5 extensions.

### 1.4 Normative wording

**MUST** and **MUST NOT** are mandatory acceptance requirements. **SHOULD** indicates a strong design recommendation. **MAY** indicates implementation freedom that cannot alter externally visible behavior. All requirements are uniquely identified as `GPIO-...` for review and test traceability.

## 2. Integration review gates and non-assumptions

These unresolved issues **do not prevent a standalone simulation of the GPIO**, but **do prevent an unqualified claim of full-chip pin compatibility**.

| Gate | System-level question | Present standalone contract | Required team approval before integration |
|---|---|---|---|
| IG-01 | Does the shared APB fabric and AHB-to-APB bridge implement APB4? | Use `PSTRB[3:0]` and `PPROT[2:0]`; 32-bit data | Confirm the common APB interface exposes them; revise fabric/bridge only in an approved separate task. |
| IG-02 | Who synchronizes APB reset deassertion? | `presetn` is asynchronous-assert, **synchronously deasserted before reaching the GPIO**. The GPIO itself is not a reset-domain controller. | Confirm reset controller guarantees release on `pclk` with synchronizer appropriate for physical implementation. |
| IG-03 | Are HCLK and PCLK phase-related? | GPIO operates **only** in PCLK and contains no HCLK logic. | Bridge/clock owners resolve HCLK-to-PCLK crossing; do not add CDC to GPIO bus slave. |
| IG-04 | GPIO3 has an abnormally large region in the draft map. | Each bank occupies exactly 256 bytes. | Confirm GPIO3 `0x80000300–0x800003FF` and reserve or allocate `0x80000400–0x80000FFF`. Do not alter top-level address decoder without approval. |
| IG-05 | I/O Mux and GPIOBOOT ranges overlap in the draft map. | The GPIO slave uses **no GPIOBOOT address**. | Resolve ownership/decoding at the system level before APB integration. |
| IG-06 | Which PLIC source numbers correspond to GPIO banks? | One level-sensitive aggregate `irq_o` per bank. | Assign four PLIC source IDs, or explicitly approve an alternate aggregation, and document priorities/polarity. |
| IG-07 | What physical pin counts are packaged or bonded? | `GPIO_WIDTH=32` default, legal 1–32 per instance. | Confirm per-bank parameter values and mux connections. |
| IG-08 | Does the repository already have an APB interface with modports? | Reuse the **existing approved shared interface** if APB4-compatible; no new private GPIO bus protocol. | If absent or incompatible, stop and propose the minimum bus-wide interface contract to the team. |

**GPIO-INT-001:** Do not resolve IG-01 through IG-08 by silent implementation choices. Document observations and ask for a decision. Standalone development may proceed with the logical signal contract in Section 4; integration remains blocked until affected gates are approved.

**GPIO-INT-002:** Nex must inspect actual repository paths before creating files. `peripherals/gpio/` is a proposed location, not evidence that the current tree contains it. Use the agreed major-module layout (`include/`, `src/`, `tb/`, `wav/`, `Makefile`).

## 3. Top-level architecture and parameters

### 3.1 Functional organization

Conceptually, the GPIO peripheral contains: APB4 register access, output/direction/pull/open-drain state, two-flop input synchronizers, interrupt edge/level logic, and a reduction-OR interrupt output. Nex may choose its internal decomposition and RTL structure, provided all observed behavior and timing remain identical to this specification.

### 3.2 Parameter contract

| Parameter | Type | Default | Legal values | Meaning |
|---|---|---:|---|---|
| `GPIO_WIDTH` | positive integer | 32 | 1 through 32 | Number of actual GPIO pins connected to one bank. |

**GPIO-PAR-001:** For GPIO_WIDTH less than 32, all per-pin 32-bit registers must return zeros in inactive bits `[31:GPIO_WIDTH]`; writes to inactive bits must have no effect. `gpio_*` pin-side ports use exactly `GPIO_WIDTH` bits. Use width-safe masking/sizing; the parameter values 1, 7, 16, 31, and 32 must elaborate cleanly.

**GPIO-PAR-002:** Values outside 1–32 are illegal configurations and must fail clearly during elaboration/simulation or static configuration checking. Do not quietly truncate.

**GPIO-PAR-003:** Do not create one RTL copy per bank, nor hardcode bank number/base address into GPIO logic.

### 3.3 Clock target and reset

- Peripheral clock: `pclk`, target frequency 12.5 MHz (80 ns nominal period). Frequency is a timing target, not a divided-clock generator requirement.
- Reset input: `presetn`, active low; asynchronous assertion is supported in all state elements. System-level synchronously controlled deassertion is a **precondition**, supplied externally (IG-02).
- No local clock gating or derived clocks. No `initial` state assignments for synthesized logic.

**GPIO-RST-001:** Assertion of `presetn==0` must immediately force all configuration registers, event latches, synchronizer state, and interrupt outputs into their specified reset state, independently of a PCLK edge.

**GPIO-RST-002:** On reset, all pins are safe inputs (output enable low); output data latch zero; pull requests low; open drain disabled; interrupt enables and pending bits zero; aggregate interrupt low.

**GPIO-RST-003:** On reset release, no false rising/falling interrupt may be generated merely because the input synchronizer was reset to zero while a real pin was already high. Establish an initial synchronized baseline before enabling edge event detection. Once baseline is established, high/low-level interrupts reflect the qualified input when enabled. Baseline acquisition may suppress edges during the initial synchronization interval; document and test that startup window.

**GPIO-RST-004:** Deassertion of `presetn` is only permitted when its required external reset synchronizer has produced a clean deassertion synchronized to PCLK. Do not imply that two-flop GPIO input synchronizers substitute for reset release synchronization.

## 4. Port and APB4 contract

### 4.1 Logical port list

Port packing may use a shared SystemVerilog `interface` and modports per `NEX.md`; the following names/directions/widths are normative at the interface boundary. If a repository-approved shared interface uses different member names, preserve its names and document a mapping; no loss of functionality is allowed.

| Logical signal | Direction, GPIO perspective | Width | Function |
|---|---|---:|---|
| `pclk` | input | 1 | APB peripheral clock. |
| `presetn` | input | 1 | Active-low reset. |
| `paddr` | input | 8 | **Bank-local byte address**, not absolute SoC address. |
| `psel` | input | 1 | GPIO instance select. |
| `penable` | input | 1 | APB ACCESS phase. |
| `pwrite` | input | 1 | 1 = write, 0 = read. |
| `pwdata` | input | 32 | Write data. |
| `pstrb` | input | 4 | Write-byte validity mask, `pstrb[i]` covers `pwdata[8*i +: 8]`. |
| `pprot` | input | 3 | APB protection attributes, accepted but not used for privilege enforcement by this GPIO. |
| `prdata` | output | 32 | Read data. |
| `pready` | output | 1 | GPIO can complete immediately in ACCESS. |
| `pslverr` | output | 1 | Error only on a completed invalid access. |
| `gpio_in_i` | input | `GPIO_WIDTH` | Asynchronous physical pad input sense, **after** external pin mux/pad routing. |
| `gpio_out_o` | output | `GPIO_WIDTH` | Digital value for GPIO output selection at mux/pad interface. |
| `gpio_oe_o` | output | `GPIO_WIDTH` | Active-high GPIO output-enable request. |
| `gpio_pull_up_o` | output | `GPIO_WIDTH` | Pull-up enable request for external pad/pull circuitry. |
| `gpio_pull_down_o` | output | `GPIO_WIDTH` | Pull-down enable request for external pad/pull circuitry. |
| `irq_o` | output | 1 | Active-high, level-sensitive aggregate interrupt request for **this bank**. |

**GPIO-IF-001:** `gpio_out_o`, `gpio_oe_o`, and pull outputs must be ordinary synthesizable logic vectors. Do **not** drive `1'bz` inside the module; top-level pad cells perform actual high impedance and programmable pulls.

**GPIO-IF-002:** GPIO does not select SPI/PWM/I2C alternate functions. The separate Digital I/O Mux chooses GPIO or peripheral pin functions and handles the final pad drive/pull controls. GPIO must not claim control of an external pad when another function is selected.

**GPIO-IF-003:** The GPIO contains no assumed pin feedback loop. `gpio_in_i` is the pad sense as routed by the I/O Mux, regardless of whether GPIO is configured for input or output. Do not substitute `gpio_out_o` for sampled input.

### 4.2 APB transfer semantics

Define `complete = psel && penable && pready` at a rising edge of `pclk`. A *valid write commit* occurs only when `complete && pwrite && !pslverr`. An accepted read is sampled at the completion edge.

**GPIO-APB-001:** Follow APB4 IDLE → SETUP (`psel=1, penable=0`) → ACCESS (`psel=1, penable=1`) sequencing, supporting consecutive transfers that transition directly from an ACCESS completion to a new SETUP. The requester must hold `paddr`, `pwrite`, `pwdata` (on write), `pstrb`, and `pprot` stable from SETUP through completion. Nex must supply protocol checks in verification.

**GPIO-APB-002:** The slave must be a **zero-wait-state** APB4 completer. `pready` may be tied HIGH. No register modifications or software-requested operations happen solely in SETUP, IDLE, or a nonexistent wait-state cycle.

**GPIO-APB-003:** Reading a mapped readable register returns a 32-bit value in `prdata` valid for the ACCESS completion edge. Drive deterministic zero when not performing a selected valid read; for invalid read return `prdata=0` with an error. `prdata` need not be frozen between SETUP and ACCESS if live input or interrupt state changes.

**GPIO-APB-004:** On a completed illegal read/write, assert `pslverr=1`; on a completed legal operation assert `pslverr=0`. Outside valid selected ACCESS, drive `pslverr=0`. Illegal operations must have no **software-requested** side effects; independent input sampling and asynchronous external events can still affect hardware state.

**GPIO-APB-005:** A non-word-aligned address (`paddr[1:0] != 0`) is illegal and must return `pslverr`. GPIO registers are 32-bit word-addressable. The address presented to the GPIO decoding logic is its local offset in 0x00–0xFF. The top-level decoder/adapter is responsible for producing that offset (potentially from a wider shared `PADDR` bus); GPIO must not decode full system address.

**GPIO-APB-006:** Reserved/unmapped addresses within 0x00–0xFF must error on both reads and writes. Access to a read-only register as a write, or to a write-only register as a read, must error and have no side effects. The APB4 *requester* must drive `pstrb=0` on reads; assertions must check this requester-side protocol rule.

**GPIO-APB-007:** For legal write operations, mask written bit lanes using `pstrb` in little-endian lane order. Unstrobed bytes retain their old value. A write with `pstrb=4'b0000` is a **legal no-op** on a writable register. Writing 1 to out-of-range GPIO bits is also a no-op.

**GPIO-APB-008:** On writes to output aliases and W1C pending registers, only byte-strobed 1 bits have an effect. A 0 bit is never interpreted as an implicit clear/set. No read-modify-write race must be introduced by software alias operations.

**GPIO-APB-009:** `pprot` must be passed through/accepted but not used to implement any permission restrictions in this GPIO revision. Document it as unused and verify both ordinary and alternate `pprot` values do not affect valid transactions. If the SoC later requires privileged-only GPIO access, that needs an explicitly revised security contract.

**GPIO-APB-010:** Every 32-bit APB register access is a single-beat transfer. No bursts, AHB-only control signals, or asynchronous APB handshakes are part of this module.

### 4.3 Output register and open-drain semantics

The `DATA_OUT` latch stores *requested logic values*, independent of pad input. `DIR=1` means GPIO requests output mode; `DIR=0` means input (no output drive). `OPEN_DRAIN=1` changes pin drive behavior as follows:

| `DIR` | `OPEN_DRAIN` | `DATA_OUT` | `gpio_oe_o` | `gpio_out_o` | Effective request |
|---:|---:|---:|---:|---:|---|
| 0 | 0 or 1 | 0 or 1 | 0 | 0 if OD, otherwise data | Release pin; input. |
| 1 | 0 | 0 | 1 | 0 | Push-pull low. |
| 1 | 0 | 1 | 1 | 1 | Push-pull high. |
| 1 | 1 | 0 | 1 | 0 | Open-drain sink low. |
| 1 | 1 | 1 | 0 | 0 | Open-drain release (high comes from external pull if present). |

Per pin `i`, exact output equations are:

```text
gpio_out_o[i] = DATA_OUT[i] & ~OPEN_DRAIN[i]
gpio_oe_o[i]  = DIR[i] & (~OPEN_DRAIN[i] | ~DATA_OUT[i])
gpio_pull_up_o[i]   = PULL_UP[i]
gpio_pull_down_o[i] = PULL_DOWN[i]
```

**GPIO-OUT-001:** OUT_SET, OUT_CLEAR, and OUT_TOGGLE must modify the same underlying DATA_OUT latch with respectively OR, AND-NOT, and XOR semantics at completed writes. A read of DATA_OUT must reflect the resulting latch value (not the actual pin voltage).

**GPIO-OUT-002:** PULL_UP and PULL_DOWN requests must be mutually exclusive per pin. If a write to either register would produce any pin with both bits = 1, the **entire APB write** must error (`pslverr=1`) and leave **all software-writable configuration state** unchanged; unrelated input sampling and hardware interrupt events may still advance. The testbench must cover multi-byte and zero-strobe cases and must verify atomic rejection.

**GPIO-OUT-003:** Pull requests are purely digital control outputs. Do not infer analog resistors or assume these controls have physical effect without IO-cell support. External mux/pad integration must define whether pulls are honored in alternate-function mode.

**GPIO-OUT-004:** Do not infer latches, internal tri-state cells, or vendor-specific IO primitives in this module.

## 5. Register map (one GPIO bank)

All offsets are byte offsets relative to this GPIO bank. Registers are 32 bits wide. `RW` = read/write, `RO` = read-only, `WO` = write-only (reads error), `RW1C` = readable with write-one-to-clear semantics (writes of zero do nothing). Except `GPIO_INFO`, all register reset values are `0x00000000`.

| Offset | Symbol | Access | Reset | Function |
|---:|---|---|---:|---|
| `0x00` | `DATA_IN` | RO | 0 | Synchronized external GPIO pin values. |
| `0x04` | `DATA_OUT` | RW | 0 | Output data latch. |
| `0x08` | `DIR` | RW | 0 | 1=GPIO output request; 0=input. |
| `0x0C` | `OUT_SET` | WO | 0* | Set DATA_OUT bits selected by written ones. |
| `0x10` | `OUT_CLEAR` | WO | 0* | Clear DATA_OUT bits selected by written ones. |
| `0x14` | `OUT_TOGGLE` | WO | 0* | Toggle DATA_OUT bits selected by written ones. |
| `0x18` | `PULL_UP` | RW | 0 | Per-pin request for pad pull-up. |
| `0x1C` | `PULL_DOWN` | RW | 0 | Per-pin request for pad pull-down. |
| `0x20` | `OPEN_DRAIN` | RW | 0 | 1=open-drain; 0=push-pull. |
| `0x24` | `IRQ_RISE_EN` | RW | 0 | Enables reporting latched rising events. |
| `0x28` | `IRQ_FALL_EN` | RW | 0 | Enables reporting latched falling events. |
| `0x2C` | `IRQ_HIGH_EN` | RW | 0 | Enables reporting sampled high levels. |
| `0x30` | `IRQ_LOW_EN` | RW | 0 | Enables reporting sampled low levels. |
| `0x34` | `IRQ_RISE_PENDING` | RW1C | 0 | Latched rising events, **captured even while masked**. |
| `0x38` | `IRQ_FALL_PENDING` | RW1C | 0 | Latched falling events, **captured even while masked**. |
| `0x3C` | `IRQ_LEVEL_STATUS` | RO | 0 | Bitwise active enabled level conditions. |
| `0x40` | `IRQ_STATUS` | RO | 0 | Bitwise aggregate pending/enabled sources. |
| `0x44` | `GPIO_INFO` | RO | see below | Capabilities and implemented width. |
| `0x48–0xFC` | reserved | none | N/A | Any access returns error. |

*Write-only action aliases have **no independent state**; the reset entry means they have no state to reset. Reading them is illegal, not a readback of 0.*

`GPIO_INFO` is a read-only constant with this encoding:

| Field | Bits | Value |
|---|---|---|
| `WIDTH` | `[7:0]` | `GPIO_WIDTH`, unsigned (1–32). |
| `HAS_IRQ` | `[8]` | 1. |
| `HAS_PULL_REQ` | `[9]` | 1. |
| `HAS_OPEN_DRAIN` | `[10]` | 1. |
| `RESERVED` | `[31:11]` | 0. |

**GPIO-REG-001:** The table above is the complete 0x100-byte register map. There are no hidden, undocumented, mirrored, or aliased writable addresses. **Do not invent extra registers.**

**GPIO-REG-002:** Every bit in `[31:GPIO_WIDTH]` in per-pin registers reads zero, ignores writes, and must never set an interrupt. The width reported by `GPIO_INFO` is the elaborated width, not the default width.

**GPIO-REG-003:** Reads of W1C pending registers must not clear them. Only completed byte-strobed writes of 1 can request a clear. The effective clear mask is `expand_byte_strobes(pstrb) & pwdata & active_pin_mask`.

**GPIO-REG-004:** For ordinary RW registers, a legal APB write modifies only byte-strobed, implemented pin bits. No side effect may occur if the register is not selected, the bus is in SETUP, or the completed transfer is an error.

**GPIO-REG-005:** The only exception to reset-zero register content is the constant `GPIO_INFO`; it is defined by feature bits and `GPIO_WIDTH` without flip-flops.

## 6. Input synchronizing and interrupt behavior

### 6.1 Digital input path

**GPIO-IN-001:** Every external `gpio_in_i` pin passes through **two sequential flip-flops clocked by PCLK** before it is consumed by DATA_IN, edge detection, or level detection. These synchronizer flip-flops must be identifiable for subsequent CDC/physical-design treatment (for example, stable instance/signal naming and an integration note). Do not use `gpio_in_i` combinationally in output control, register reads, or IRQ logic.

**GPIO-IN-002:** All implemented pins are sampled regardless of GPIO direction or open-drain configuration. Input reads and IRQs represent the synchronized sensed pad value, **not** the output latch. The testbench supplies known 0/1 pin values and must not depend on resolving physical Z/X as a valid digital input.

**GPIO-IN-003:** A change to a physical pin should propagate to DATA_IN after the two-flop synchronization pipeline, with no additional deliberate debounce or input filtering. Exact observation relative to asynchronous arrival may vary by a PCLK cycle; test with transitions away from sampling edges and permit the expected synchronizer latency. Do not claim metastability can be reproduced or proven eliminated by RTL simulation.

**GPIO-IN-004:** No input debounce filter, pin drive-strength configuration, or slew-rate configuration is included in revision 0.1. Atomic output aliases and open-drain control are the specified advanced digital features. Adding analog-dependent or debounce features requires a revised specification and area/timing assessment.

### 6.2 Event detection and pending storage

Let `sample[i]` be the current synchronized pin sense and `prev[i]` the preceding valid synchronized sample. Once initialization baseline is valid:

```text
rise_event[i] =  sample[i] & ~prev[i]
fall_event[i] = ~sample[i] &  prev[i]
```

**GPIO-IRQ-001:** Rising and falling event capture is independent of the respective IRQ enable registers. Events are latched even when software masks the interrupt. Enabling a previously masked source with a pending event may therefore immediately assert `irq_o`.

**GPIO-IRQ-002:** On every PCLK edge, update event pending bits according to the following priority equation (SET/event wins over simultaneous W1C clear):

```text
rise_pending_next = (rise_pending & ~effective_rise_w1c_mask) | rise_event
fall_pending_next = (fall_pending & ~effective_fall_w1c_mask) | fall_event
```

A rising or falling event must not be lost when software clears a different or the same pending bit on that clock edge.

**GPIO-IRQ-003:** Following reset, the first valid synchronized input value initializes the edge-history baseline, without generating a synthetic edge. Rising and falling events are detected only when an established baseline and a new sample exist. Verify a pin held high through reset produces no rising pending flag merely on reset release.

**GPIO-IRQ-004:** Edge pending bits stay asserted until individually cleared through their RW1C register or reset. They are not auto-cleared by reading status or by deassertion of an input.

### 6.3 Level interrupts and aggregation

For valid synchronized samples, let bitwise vectors be:

```text
rise_active  = IRQ_RISE_PENDING & IRQ_RISE_EN
fall_active  = IRQ_FALL_PENDING & IRQ_FALL_EN
high_active  = DATA_IN & IRQ_HIGH_EN
low_active   = (~DATA_IN) & IRQ_LOW_EN & active_pin_mask
level_status = high_active | low_active
irq_status   = rise_active | fall_active | level_status
irq_o        = |irq_status
```

While the input synchronization baseline is not yet valid after reset, **high_active and low_active must be suppressed**; `irq_o` remains low unless there is another genuine event (there cannot be one before valid baseline). After baseline initialization they follow the above equations. `IRQ_LEVEL_STATUS` and `IRQ_STATUS` read back these bitwise values, masked to implemented pins.

**GPIO-IRQ-005:** High/low level interrupts do not latch pending flags. A high-level interrupt remains asserted for as long as an enabled qualified input is high; low level likewise while low. Level sources are cleared by the level becoming inactive or by disabling that level enable, not by writing RW1C edge flags.

**GPIO-IRQ-006:** The four interrupt classes may be independently enabled on the same pin. Both high and low enables set means exactly one level condition is active for a valid 0/1 input. Aggregate IRQ is a level, not a one-cycle pulse.

**GPIO-IRQ-007:** At a PCLK edge where APB modifies an IRQ enable or clears a pending flag while new input events occur, the next registered state must reflect both operations according to the above equations. Combinational IRQ/status outputs reflect the resulting current registers and synchronized input; the checker must sample after the appropriate clock-edge update to avoid false races.

**GPIO-IRQ-008:** `irq_o` is one active-high signal per bank for the PLIC. No claim is made about final PLIC source IDs until IG-06 is resolved. IRQ must not depend on AHB/HCLK or on firmware running.

## 7. Address decoding and chip integration

The **proposed bank windows** from the AiFT system specification are:

| Bank | Base | Local usable range | Note |
|---|---|---|---|
| GPIO0 | `0x8000_0000` | `0x8000_0000–0x8000_00FF` | Draft map agrees. |
| GPIO1 | `0x8000_0100` | `0x8000_0100–0x8000_01FF` | Draft map agrees. |
| GPIO2 | `0x8000_0200` | `0x8000_0200–0x8000_02FF` | Draft map agrees. |
| GPIO3 | `0x8000_0300` | **proposed** `0x8000_0300–0x8000_03FF` | Draft currently says ending `0x8000_0FFF`; see IG-04. |

**GPIO-MAP-001:** The GPIO module consumes local offsets only. External APB routing must assert the appropriate bank's `psel`, forward low address bits as `paddr`, and ensure only one bank responds per transfer.

**GPIO-MAP-002:** The GPIO block must not mirror registers through multiple absolute addresses. External decode coverage of `0x8000_0400–0x8000_0FFF`, if any, is a team-wide decision not supplied by this module.

**GPIO-MAP-003:** Nothing in this block implements GPIOBOOT; the current overlapping GPIOBOOT/I/O Mux ranges are a system-level issue, not justification to combine those modules.

## 8. Detailed mandatory verification plan

The baseline must include **both** a quick directed self-checking SV testbench and a real Questa-compatible UVM environment. These serve different purposes. Both must test the spec independently of the DUT's internal implementation, and both must terminate with unambiguous pass/fail status.

### 8.1 Independent verification model

**GPIO-VER-001:** The checker/scoreboard must be based on **Section 5 and Section 6** rather than copying the RTL's internal assignments, state machine, or helper functions. Define expected register side effects, PSTRB masks, pending events, read data, output drive, and interrupt behavior explicitly from this specification. If the RTL and checker share a source file or direct internal-state mirroring, verification independence is insufficient.

**GPIO-VER-002:** A test must **fail nonzero** on mismatch, timeout, missing expected transfer, or missing required check. Do not replace failing assertions with informational `$display` messages. Do not alter checks to match incorrect DUT behavior.

**GPIO-VER-003:** Directed smoke tests must exercise **all** documented registers (including errors for WO reads/RO writes and reserved offsets), multiple values of `pstrb`, reset, IRQ pending/clearing, bank-pin outputs, and an actual pin input stimulus. Printing `PASS` after only compilation is not acceptable.

### 8.2 Required directed tests

The following test IDs must appear in a test plan and results table. Tests may be combined into fewer simulation binaries, but each requirement must have concrete independently checked observations.

| ID | Stimulus and mandatory observation |
|---|---|
| T01 | Reset while clocking and without a clock edge; all registers/output enables/pulls/IRQ meet reset values. |
| T02 | Reset deasserted on a legal synchronized boundary; high pin held through reset creates no artificial rise event. |
| T03 | APB SETUP-only transaction never changes a writable register. |
| T04 | Completed APB write followed by readback; correct direction and output values. |
| T05 | Back-to-back APB transfers to distinct registers, no dropped/duplicated operations. |
| T06 | All 16 combinations of PSTRB on representative RW register and output alias, including 0000. |
| T07 | OUT_SET/OUT_CLEAR/OUT_TOGGLE affect only asserted, strobed bits; DATA_OUT readback correct. |
| T08 | Non-word-aligned, unmapped, WO-read, RO-write accesses error with no state change. |
| T09 | PULL_UP and PULL_DOWN valid requests; attempted simultaneous pull conflict errors and atomically preserves state. |
| T10 | DIR and DATA_OUT output truth table; push-pull and open-drain release/sink behavior; no internal Z required. |
| T11 | Two-flop synchronized DATA_IN senses pad independent of DIR and DATA_OUT. |
| T12 | Rising edge generates exactly the specified pending bit; pending survives mask and input return to 0. |
| T13 | Falling edge generates pending bit; W1C clears only selected bits/bytes and reads do not clear. |
| T14 | Simultaneous new edge and W1C clear on same PCLK edge: event wins. |
| T15 | High-level and low-level interrupts correctly track current synchronized pin state and enables. |
| T16 | All four sources can be enabled independently; IRQ_STATUS, IRQ_LEVEL_STATUS, and irq_o agree. |
| T17 | Masked edge captured and later unmasked, causing IRQ immediately until W1C. |
| T18 | Changing GPIO inputs while APB is idle still updates input status/interrupt state. |
| T19 | Changing PPROT values does not break valid transfers (no implemented access-control policy). |
| T20 | Widths 1, 7, 16, 31, and 32 elaborate, simulate, and mask inactive bits correctly. |
| T21 | GPIO_INFO returns actual width and capability bits; writes to it error. |
| T22 | Random valid/invalid transactions and changing inputs checked against an independent reference model. |
| T23 | No X/Z on GPIO control outputs, read response at legal read completion, or IRQ after reset with known input values. |
| T24 | Second reset in the middle of activity clears prior state and recovers cleanly. |
| T25 | Edge trigger both while IRQ enabled and while disabled; status/pending lifecycle exactly specified. |

**GPIO-VER-004:** For tests of simultaneous W1C and edge arrival, time the physical-input transition sufficiently before the clock to pass the synchronizer stages. Align the APB completion edge with the *synchronized detected edge*, not the raw pad edge.

**GPIO-VER-005:** The smoke test must include a timeout and a check-count guard (nonzero tests run; expected minimum transactions observed). A test that never reaches its assertions fails.

### 8.3 UVM environment

**GPIO-UVM-001:** Supply a Questa-compatible UVM APB4 agent (sequencer, driver, monitor, sequence items), input-pin stimulus monitor/driver, GPIO scoreboard, reset-aware reference state model, and functional coverage. Reuse approved verification IP if present instead of inventing a second APB implementation.

**GPIO-UVM-002:** Include directed sequences plus reproducible seeded constrained-random sequences covering: register classes, legal/illegal accesses, all PSTRB combinations, GPIO widths through separately elaborated configurations, pin toggles, zero/one/high-activity cases, simultaneous software/hardware activity, and reset mid-traffic.

**GPIO-UVM-003:** APB monitors/checkers must detect illicit requester signal changes between SETUP and ACCESS, invalid read strobes, invalid PENABLE sequencing, and side effects outside a completed transfer. The slave must not be blamed for deliberately malformed requester stimulus without clearly labeling such negative tests.

**GPIO-UVM-004:** Coverage must measure real functional scenarios (not merely simulation cycles): all registers, access outcomes, each output action, each IRQ source, W1C collision case, pull conflicts, open-drain truth table, width boundary configurations, and reset recovery. Report **hit/total** counts for mandatory feature bins and distinguish exclusions from missing coverage. Do not invent a percentage without a tool report.

**GPIO-UVM-005:** A regression passes only when all required assertions/scoreboard checks pass, no UVM_ERROR or UVM_FATAL remains, and every mandatory directed test was executed. A compilation or `UVM_INFO ... PASS` message alone is not sufficient.

### 8.4 Testbench defensibility and independent review

Nex can generate a testbench, but its authorship is not independent evidence. A human reviewer must compare the checker to this specification. As a sanity check, use **at least three temporary mutation experiments** (restore RTL afterward): (1) disable a DATA_OUT write; (2) incorrectly clear an edge-pending bit on read; (3) reverse an open-drain output-enable case. The appropriate verification tests should each fail for the injected bug. Record the outcomes. Do not keep mutations or change the reference model to accommodate them.

## 9. Static, build, and implementation requirements

**GPIO-RTL-001:** Use synthesizable IEEE 1800 SystemVerilog (`always_ff`, `always_comb` where appropriate, nonblocking sequential assignments), complete assignments, and width-safe arithmetic. No inferred latches, multiple procedural drivers, unsized magic masks, or combinational loops.

**GPIO-RTL-002:** Do not synthesize `#delay`, `$display`, `$readmemh`, `force`, simulator-only drivers, internal X/Z assignments, or dynamic/unbounded constructs in the DUT. Verification-only code belongs under `tb/`.

**GPIO-RTL-003:** Minimize area and switching without compromising correctness: synchronizer per input bit, compact registers, and ordinary bitwise output logic. No fabricated analog pull devices or huge generic frameworks inside the synthesizable module. Leave area/timing characterization for the chosen synthesis/STA flow.

**GPIO-RTL-004:** Preserve public interfaces and existing shared bus definitions. If `bus/include/` (or its actual equivalent) contains a shared APB interface, inspect before use. If it lacks APB4 features, **stop and request approval** before changing it. Never generate an incompatible GPIO-only interface to conceal this conflict.

**GPIO-BLD-001:** Supply module Makefile targets `lint`, `sim TEST=<name> SEED=<n>`, `regress`, `cov`, `wave TEST=<name>`, `clean` consistent with `NEX.md`. For standalone smoke, use repository-approved tools; use Siemens Questa for UVM peripheral tests and Verilator for lint. Do not substitute an unapproved simulator.

**GPIO-BLD-002:** Inspect environment module setup, existing repository Makefiles, and UVM installation rather than assuming executables or hardcoding machine-specific paths. If licenses or tools are unavailable, record **NOT RUN** and the concrete blocking output; never claim pass.

**GPIO-BLD-003:** Output waveforms to a build directory, not repository root. Track `src/`, `include/`, `tb/`, `Makefile`, and waveform configuration files as source; ignore simulator binaries, coverage databases, VCD/FST, logs, and test outputs.

**GPIO-BLD-004:** No synthesis or STA claim unless tools are explicitly approved in `NEX.md` and those checks really ran. Lint and simulation do not prove timing closure, power, DRC/LVS, or tapeout readiness.

## 10. Nex execution procedure (one-file prompt)

Treat this file as an executable engineering task description, **not** authorization to change unrelated architecture. Proceed in phases and report evidence after each. Do not claim the whole task complete until all mandatory verification criteria have evidence.

### Phase A — repository inspection (before editing)

1. Read `NEX.md`, `docs/AiFT_spec.md` (if present), this file, and existing module conventions.
2. Locate the existing APB interface definition, bridge, decoder, peripheral directory layout, Makefiles, digital_lib CDC/synchronizer helpers, and verification patterns.
3. Print a short compatibility matrix comparing Section 4 with actual shared APB interface members; list any missing features. Identify exact clocks/resets already in the repository.
4. Confirm no architecture- or protocol-affecting conflict. If one exists, **STOP with the specific conflict and required decision**. Do not invent a workaround.
5. Create a descriptive Git branch before any edits. Never commit directly to `main`.

### Phase B — GPIO implementation

1. Use one configurable module, not four hardcoded instances.
2. Implement the exact register map and all documented conditions.
3. Reuse repository interfaces and digital_lib helpers if suitable; create no unnecessary frameworks.
4. Keep pin-mux, pad, bridge, clock-generation and PLIC integration outside this block.
5. Add concise documentation/comments only where they clarify the contract or tricky priority/timing behavior.
6. Compile/lint immediately and correct synthesis-oriented warnings; document intentional exceptions with technical justification. Do not suppress errors merely to get a green run.

### Phase C — verification implementation

1. Create the quick self-checking directed testbench **after RTL has been written**, in accordance with `NEX.md`.
2. Create Questa UVM verification and an independent scoreboard implementing this document's observable behavior, **not** reading internal DUT state.
3. Execute tests T01–T25, constrained random regression, and UVM functional coverage with reproducible seeds.
4. Run Verilator lint and Questa simulation via supplied Makefile targets; keep command lines and raw logs in generated build output.
5. Human reviewer will separately assess verification independence and run mutation checks. Do not certify your own tests as independent proof.

### Phase D — deliverable report

Output a compact report containing:

- **Git branch**, repository state, and implementation file inventory.
- **Requirements traceability table:** `GPIO-*` and T01–T25, with test names and PASS / FAIL / NOT RUN (not merely a narrative statement).
- **Verification evidence:** precise commands, simulator versions, seeds, exit codes, and log locations; the highest-severity UVM messages and assertion failures.
- **Interface compatibility:** pin/interface mapping and status of IG-01 through IG-08.
- **Area/synthesis/timing:** explicitly `NOT RUN` unless approved tools actually executed.
- **Open defects, assumptions, and limitations:** with severity and proposed disposition.
- **Git output:** `git status`, `git diff --stat`, and a suggested commit message. Do not commit unless asked.

**GPIO-AGT-001:** Do not alter expected values, remove assertions, reduce test coverage, ignore error codes, fabricate coverage, or add an output that trivially makes tests pass. If spec and code disagree, fix RTL; if the spec is genuinely ambiguous, stop and report the ambiguity before altering expected behavior.

**GPIO-AGT-002:** If phase A identifies a shared bus/reset/system conflict, stop **before RTL changes**, cite the exact file and issue, and request a team decision. A standalone shim is not permission to misrepresent pin compatibility.

**GPIO-AGT-003:** If an integration gate remains open, the maximum allowed status is **standalone GPIO implemented and verified**. Do not call this block SoC-integrated, tapeout-ready, or physically signed off.

## 11. Acceptance criteria

A block is accepted for **standalone GPIO verification** only when all of the following are true:

1. All legal GPIO widths (1–32) are supported by source code, with explicit elaboration/testing of required boundary configurations.
2. RTL has the specified APB4 logical interface and register behavior, passes lint without unresolved errors, and demonstrates no unintended latch inference.
3. All mandatory functional tests T01–T25 have passing evidence from simulation, including positive and negative register transactions.
4. The Questa UVM environment runs, produces an auditable scoreboard result, and reports meaningful coverage against the required feature bins.
5. A reviewer has checked the reference model against this document and assessed the mutation experiments.
6. No tests were weakened to accommodate the DUT; no pass was inferred from compile/lint alone.
7. Git diff is limited to the requested GPIO block, its tests/build setup, and narrowly justified documentation/build adjustments.
8. Known outstanding integration gates are clearly labeled, and the result is **not** overstated as fully integrated hardware.

## 12. Explicitly deferred features

Input debounce/glitch filtering; programmable drive strength/slew; pad-analog configuration; Schmitt-trigger selection; timestamp capture; wake-from-deep-sleep/always-on domain; alternate-function selection; GPIOBOOT behavior; separate IRQ per pin; DMA trigger generation; bus-level privilege enforcement; >32 GPIO pins per bank; GPIO hardware pin loopback. These are not required by the current approved standalone contract, and Nex **must not** silently add them under the label of 'advanced functionality'.

## 13. Human review checklist before integration

- [ ] Confirm IG-01 through IG-08 with relevant team members.
- [ ] Align `docs/AiFT_spec.md` address map and protocol version with approved GPIO choices.
- [ ] Review 0x00–0x44 register definitions and approve firmware-visible ABI before drivers are written.
- [ ] Assign GPIO0–GPIO3 PLIC source numbers and pin-mux ownership/pull behavior.
- [ ] Confirm asynchronous-reset assertion / synchronous-deassertion implementation is consistent chip-wide.
- [ ] Verify approved Questa/Verilator builds, test logs, randomized seeds, and coverage.
- [ ] Confirm verification reference model and mutation results independently.
- [ ] Evaluate synthesized area/timing and physical IO-cell mappings when a synthesis/signoff flow is approved.

---
