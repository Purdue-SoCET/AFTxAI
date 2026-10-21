# AiFTx PWM Peripheral: Standalone Functional, APB4, RTL, and Verification Specification

**Proposed repository file:** `peripherals/pwm/spec.md`  
**Revision:** 1.0 (standalone implementation contract)  
**Status:** AUTHORITATIVE FOR THIS STANDALONE PWM TASK; integration approvals outstanding  
**Language:** IEEE 1800 SystemVerilog  
**Audience:** ChipNexus Nex, RTL and verification reviewers, SoC integration owners

> **Mandatory reading:** Read this document fully and the actual repository `NEX.md` before implementation. This is a new AiFTx peripheral contract, not a request to copy another peripheral's functionality. The shared APB4 definition is provisional; the interconnect, bridge, PLIC routing, pin mux and physical pads do not yet exist. Deliver an independently tested, synthesizable peripheral with a stable logical interface and explicit integration gates, NOT a mock bus, a stub, or a claim of chip-level signoff.
>
> **Architecture availability:** The branch inspected while authoring this document contains `NEX.md`, GPIO/Timer block specifications, and `bus/include/apb4_if.sv`, but **does not contain** the referenced `docs/AiFT_spec.md`. Therefore the PWM channel count, register ABI, local aperture, and event semantics below are explicit **new standalone design decisions**. They must be confirmed by the SoC and firmware owners before integration. Do not pretend a missing top-level document approved them. If the authoritative system document appears and conflicts, report the conflict and request an interface review; do not silently overwrite system decisions.

## 1. Authority, scope and engineering priority

1. `NEX.md` governs workflow, toolchain, repository convention and Git behavior.
2. The actual approved SoC architecture specification, **if present**, governs system address allocations, pin routing, PLIC sources, clocks and reset distribution. If absent, these remain OPEN gates.
3. This document defines the PWM-local functional and register contract for standalone design and testing.
4. Arm **AMBA APB Protocol Specification** governs APB protocol semantics. Use APB4's `PSTRB` and `PPROT`; no APB5-only features. Official reference: https://documentation-service.arm.com/static/63fe2c1356ea36189d4e79f3

**PWM-SCP-001:** Implement one synthesizable, parameterized APB4 PWM peripheral with `PWM_CHANNELS` independent outputs, default **4**, supported range **1 through 4**. Each channel has its own 32-bit PERIOD (number of timer ticks per waveform), 32-bit DUTY (high ticks), 16-bit PRESCALE, enable, and inverted-polarity configuration. A channel does **not** share a counter, prescaler, or PERIOD with another channel.

**PWM-SCP-002:** Provide glitch-resistant, **period-boundary buffered** updates of PERIOD/DUTY/PRESCALE while running, with an explicit software ARM operation. Each channel produces a period-boundary event; maskable sticky event flags feed one aggregate level IRQ. The peripheral produces digital output-data and output-enable **requests** for a separate SoC pin mux, not physical pads.

**PWM-SCP-003:** Do not implement CPU, AHB or APB interconnect, AHB-to-APB bridge, GPIO, Timer0, PLIC, IO mux, pad macros, dead-time insertion, complementary half-bridge outputs, motor-control fault/shutdown pins, center-aligned PWM, DMA, capture, analog DAC, clock generator, or a timer cross-trigger. Do not borrow Timer0 counters. None of those features is silently implied by the word “PWM.”

**PWM-SCP-004:** Preserve the external ABI and the exact cycle-level semantics given here. Internal RTL hierarchy is unrestricted if it is synthesizable and externally equivalent. New features require explicit approval and a spec change; do not expand scope to raise coverage or impress a reviewer.

## 2. Integration gates: OPEN does not block standalone development

| Gate | Standalone choice / observable contract | Integration owner and required closure |
|---|---|---|
| IG-P01 Bus | APB4 32-bit data, 12-bit **local byte offset** `0x000`–`0xFFF`; one `psel` per PWM instance. | Bus/bridge owner confirms aperture size, base address, local address slicing, PSTRB/PPROT, and error propagation. **No absolute PWM address is asserted here.** |
| IG-P02 Shared bus interface | Reuse `bus/include/apb4_if.sv`, with `ADDR_WIDTH=12`, `DATA_WIDTH=32`, when present. Scalar RTL APB ports are acceptable as with GPIO/Timer0. | Fabric owner approves the final interface or provides a thin adapter. Do not modify the shared interface to suit PWM. |
| IG-P03 Clock | All PWM state is in `pclk`, nominal **12.5 MHz**; no HCLK inside PWM. | Clock owner confirms actual period and HCLK/PCLK relationship; bridge owns bus CDC. |
| IG-P04 Reset | `presetn` async assertion; synchronous, clean deassertion delivered by system. | Reset owner designs and verifies reset distribution / release. |
| IG-P05 Pads | Four logical digital PWM outputs maximum, plus one OE request per output. | Pin-mux/pad owner allocates mux functions, final pins and pad enables, and resolves routing/drive constraints. |
| IG-P06 IRQ | One active-high, level-sensitive aggregate `irq_o` across channel period events. | PLIC owner assigns/approves source number, priority, masking and service policy. |
| IG-P07 Firmware ABI | Independent channel stride `0x20`, global IRQ registers in `0x100` range, PWM_INFO signature. | Firmware/SoC owner approves before software integration; controlled ABI change required afterward. |
| IG-P08 Physical | Single-clock synthesizable RTL; registered PWM output data, no internal tri-states. | Physical-design team chooses synthesis/STA flow and validates clock, reset, IO and routing constraints before tapeout. |
| IG-P09 Channel/pin count | Default four independent outputs; parameter permits 1–4. | Integration owner approves actual instance count, pins and optional unbonded outputs. |

**PWM-INT-001:** All gates must be reported explicitly OPEN/CLOSED with owner in `SIGNOFF.md`. Do not close gates on your own by inventing missing system wiring, an address, a PLIC ID, a pin assignment, or a synthesis result.

**PWM-INT-002:** Work may proceed through *standalone RTL freeze* with these gates OPEN. Claiming **tapeout readiness** or complete SoC integration while the gates are OPEN is prohibited.

**PWM-INT-003:** Reuse the existing shared APB interface without edits. The bus team may later replace the provisional connection through an adapter while the PWM register semantics remain unchanged. No absolute SoC address may occur in the PWM RTL.

## 3. Module ports, parameters, clock and reset

**PWM-PAR-001:** `parameter int PWM_CHANNELS = 4` is legal only for 1, 2, 3, or 4; values outside this range must fail clearly at configuration/elaboration or in a fatal simulation configuration check. Do not instantiate unused physical outputs for channels above the parameter.

**PWM-PAR-002:** One common top module `pwm_apb`, with scalar APB ports compatible with the shared APB4 testbench adapter, and channel-side vectors exactly `PWM_CHANNELS` bits. Do not hardcode an instance number, bank base, or special 4-channel behavior into RTL.

| Signal | PWM direction | Width | Semantics |
|---|---|---:|---|
| `pclk` | input | 1 | APB peripheral clock, nominal 12.5 MHz |
| `presetn` | input | 1 | Active-low asynchronous reset assertion |
| `paddr` | input | 12 | Local byte address, **all 12 bits decoded** |
| `psel`, `penable`, `pwrite` | input | 1 each | APB4 selected SETUP/ACCESS/read-write |
| `pwdata` | input | 32 | APB write data |
| `pstrb` | input | 4 | Write-byte enables, byte 0 = bits `[7:0]` |
| `pprot` | input | 3 | Accepted for all 8 values; no PWM-local privilege gating |
| `prdata` | output | 32 | Valid read data during legal selected ACCESS |
| `pready` | output | 1 | Constant 1 (zero wait-state) |
| `pslverr` | output | 1 | High for invalid selected ACCESS; low otherwise |
| `pwm_out_o` | output | `PWM_CHANNELS` | Registered PWM digital output-data requests; 0 when disabled/reset |
| `pwm_oe_o` | output | `PWM_CHANNELS` | Active-high output-enable requests only while channel EN=1 |
| `irq_o` | output | 1 | Level-sensitive reduction of masked sticky boundary events |

**PWM-CLK-001:** All state changes use `posedge pclk`, except for asynchronous `negedge presetn` reset assertion. `pclk` is not divided into a new clock; prescale is a **clock enable**. No internal gated/derived clock, blocking delays, initial FF assignments for synthesis, internal `Z`, or physical pads.

**PWM-RST-001:** Reset asynchronously clears each channel's EN, POLARITY, phase, prescaler phase, pending update, output-data and output-enable requests, and clears global IRQ enables/pending and `irq_o`. Reset defaults per channel: `PERIOD_SHADOW=1`, `DUTY_SHADOW=0`, `PRESCALE_SHADOW=0`; active values reset to the same defaults. A disabled PWM output is low even when POLARITY=1.

**PWM-RST-002:** System reset deassertion must be synchronized to `pclk` upstream. PWM does not itself synchronize reset release and does not contain an asynchronous input that requires a `sync_2ff` instance.

**PWM-OUT-001:** `pwm_out_o` must be **registered**: after reset it changes only on rising `pclk` edges. Shadow register writes and invalid APB requests must not produce combinational or fractional-PCLK output glitches. With EN=0, both `pwm_out_o` and `pwm_oe_o` are zero independent of polarity or shadow values. The external mux/pad owner ultimately decides whether the requested function is selected.

**PWM-OUT-002:** Enabled output polarity: let `raw_high = (phase < active_duty)`. When EN=1, output-data value is `raw_high XOR POLARITY` (POLARITY=0 normal, 1 inverted). This includes 0%-duty and 100%-duty behavior. OE=1 while enabled; PWM does not generate an output pulse at reset release or during disabled configuration.

## 4. Register ABI and address decoding

Four channel register blocks use **stride `0x20`**. For legal channel `c` (`0 <= c < PWM_CHANNELS`), `BASE(c) = 0x20*c`. Uninstantiated channel blocks must error; do not alias to channel 0 or the last valid channel.

| Channel relative offset | Name | Access | Reset | Meaning |
|---|---|---|---:|---|
| `+0x00` | `CH_CTRL` | RW | `0x0000_0000` | Bit 0 EN, bit 1 POLARITY; bits 31:2 reserved RAZ/WI |
| `+0x04` | `CH_PERIOD_SHADOW` | RW | `0x0000_0001` | Number of PWM timer ticks per cycle (not PERIOD+1) |
| `+0x08` | `CH_DUTY_SHADOW` | RW | `0x0000_0000` | Number of asserted (non-inverted) ticks per cycle |
| `+0x0C` | `CH_PRESCALE_SHADOW` | RW | `0x0000_0000` | Bits 15:0; tick division = PRESCALE+1; upper bits RAZ/WI |
| `+0x10` | `CH_UPDATE` | WO | n/a | W1S bit 0: ARM/apply buffered configuration; other bits ignored |
| `+0x14` | `CH_STATUS` | RO | `0` | Bit 0 UPDATE_PENDING, bit 1 EN, bit 2 OE request, bit 3 output-data level; remaining bits zero |
| `+0x18` | `CH_PHASE` | RO | `0` | Current active PWM phase in ticks, `0 .. active_period-1` |
| `+0x1C` | reserved | invalid | n/a | PSLVERR on reads and writes |

Global PWM registers use the same local aperture (no channel selected):

| Local offset | Name | Access | Reset | Meaning |
|---|---|---|---:|---|
| `0x100` | `IRQ_ENABLE` | RW | `0` | Bits `[PWM_CHANNELS-1:0]`: enable individual period-boundary interrupt causes |
| `0x104` | `IRQ_PENDING` | RW1C | `0` | Sticky boundary event per channel; HW set dominates SW clear |
| `0x108` | `PWM_INFO` | RO | `0x5057_0100 \| PWM_CHANNELS` | `0x5057` ASCII "PW", ABI revision `01`, channel count in bits `[7:0]` |

**PWM-REG-001:** Register widths are 32 bits. For `PWM_CHANNELS<4`, all unused bits in global IRQ registers read zero; writes to unused bits are ignored. `PWM_INFO` is a compile-time constant with the selected channel count. Reserved implemented register bits are read-as-zero/write-ignored (RAZ/WI).

**PWM-REG-002:** All valid ordinary RW writes use APB4 little-endian `PSTRB`; each set strobe replaces one byte and each clear strobe preserves that byte. `pstrb==0` on an otherwise valid writable offset is a legal no-op; no validation/re-arm occurs solely from a zero-strobe transfer. For W1S/W1C, only **strobed 1 bits** act; zeros have no effect.

**PWM-REG-003:** The channel's `CH_PERIOD_SHADOW`, `CH_DUTY_SHADOW`, and `CH_PRESCALE_SHADOW` hold **staging** values, readable immediately after their APB writes. The active engine uses separate immutable active values until a valid enable or boundary update. Software may temporarily stage illegal combinations (e.g. duty > period) but cannot enable/ARM them. Partial writes must not accidentally commit or reset the running waveform.

**PWM-REG-004:** `CH_UPDATE` is WO. A read from it, a write to `CH_STATUS`/`CH_PHASE`/`PWM_INFO`, or any read/write to an absent channel or unmapped offset returns PSLVERR. `CH_UPDATE` write with bit0 0 is a legal no-op even when pending; other bits are ignored. `CH_UPDATE` write with bit0 1 is checked for validity as described in Section 6.

**PWM-REG-005:** An invalid operation must have no software-induced side effect on *any* channel or global state. Independent timer ticks and period events continue during an invalid APB transfer; a rejected access must not freeze timekeeping. Reads have no side effects.

**PWM-REG-006:** Reads of `CH_PHASE`, `CH_STATUS`, or `IRQ_PENDING` at a completion edge expose the **pre-edge** value; values may update immediately after the completion edge. Verification must sample in a region that distinguishes pre-NBA read sampling from post-NBA output checking.

## 5. Exact PWM timing and boundary behavior

Define `divider = active_prescale + 1`, mathematically a **17-bit** quantity (maximum 65536). The internal prescale phase advances only while EN=1. Define `tick` on a rising `pclk` when the channel was enabled before the edge and `prescale_phase == active_prescale`, unless that same edge completes a valid write disabling the channel. Tick then resets prescale phase to 0; otherwise phase increments by 1. Do not emit a tick on an enable-completion edge.

**PWM-TIME-001:** `CH_PERIOD_SHADOW` / `active_period` are **period length in timer ticks**, not terminal count. Active PERIOD must be in `[1, 0xFFFF_FFFF]`. Active DUTY must be in `[0, active_period]` inclusive. Duty 0 always generates raw low; DUTY == PERIOD generates raw high (100%); intermediate duty generates exactly DUTY raw-high ticks and `(PERIOD-DUTY)` raw-low ticks per period. This applies for period=1 and nontrivial prescalers.

**PWM-TIME-002:** At an accepted EN `0->1` CONTROL transfer, atomically validate staging PERIOD/DUTY, copy staged PERIOD/DUTY/PRESCALE to active state, set phase=0 and prescale_phase=0, clear UPDATE_PENDING, set OE=1, and register the phase-0 waveform level **after that completion edge**. The first tick occurs exactly `PRESCALE+1` **subsequent** rising `pclk` edges after enabling. The first complete waveform period consists of exactly `PERIOD*(PRESCALE+1)` subsequent PCLK cycles; no startup shortened/extra tick.

**PWM-TIME-003:** On an ordinary tick, compute `next_phase = phase+1` if `phase < active_period-1`. When `phase == active_period-1`, this tick is the **period boundary**: set `next_phase=0` and raise a one-edge boundary event for that channel. The registered output for the new phase follows `(next_phase < active_duty) XOR POLARITY`, using updated active DUTY if a pending update commits on the boundary. An APB read, an IRQ mask write, or a software W1C write does not stall this tick.

**PWM-TIME-004:** Example: normal polarity, active PERIOD=4, DUTY=1, PRESCALE=0, enable at edge E0. Post-E0 output is high, representing phase 0. Post-E1/E2/E3 output is low (phases 1/2/3). At E4 a boundary tick sets phase 0, output high and sticky boundary pending. This waveform repeats every **4 PCLK cycles**. With DUTY=2, phases 0 and 1 are high; with DUTY=0 all phases are low; with DUTY=4 all phases are high. This example is a mandatory self-checking waveform trace.

**PWM-TIME-005:** With PRESCALE=2, period/duty phase changes occur only on the 3rd, 6th, 9th ... rising edges after enable. Every raw phase lasts **3 PCLK cycles**. Over a complete period, the high and low times are multiplied by three without creating an internal divided clock. Exercise prescale 0, 1, 2, 255 and 65535 as bounded timing tests.

**PWM-TIME-006:** An accepted EN `1->0` CONTROL transfer suppresses a tick on that completion edge even if the divider would have ticked. Immediately after that edge the output-data and OE requests must be zero, prescale_phase=0, phase=0, UPDATE_PENDING=0; active values may remain internal but are ignored until the next start. Shadow registers are retained and visible. No boundary event is generated solely by stopping, and no event while disabled.

**PWM-TIME-007:** Writing CTRL with EN unchanged (1->1 or 0->0) and POLARITY unchanged is not a restart. Changing POLARITY while EN was 1 before the edge returns PSLVERR atomically, even if software simultaneously requests disable. Firmware must disable in one transfer, then change polarity while stopped. Changing polarity with EN=0 is allowed and must not drive the output until next enable. Attempts to enable with invalid shadow configuration are rejected without enabling or disturbing the old state.

**PWM-TIME-008:** Enabled output must not change between `pclk` rising edges, except assertion of reset which forces safe zero asynchronously. No shadow write, rejected register access, or IRQ operation may directly cause a pulse, shortened PWM interval, or OE glitch.

## 6. Buffered updates, validity and priority

**PWM-UPD-001:** Shadow writes while EN=1 are permitted **only if UPDATE_PENDING=0**. After UPDATE_PENDING becomes 1, any **nonzero-PSTRB** write to the three shadow registers of that channel must PSLVERR with no software side effect; zero-strobe writes are legal no-ops. This prevents modifying the armed configuration before the boundary without requiring a second shadow bank.

**PWM-UPD-002:** A valid `CH_UPDATE` write (`pstrb[0]=1`, `pwdata[0]=1`) when EN=1 and pending=0 sets UPDATE_PENDING=1 if `shadow_period>=1` and `shadow_duty<=shadow_period`. Other channels do not change. Invalid configuration or a second ARM while pending returns PSLVERR atomically. ARM **never** changes active parameters or output on its APB completion edge.

**PWM-UPD-003:** If UPDATE_PENDING was **already 1 before** a period-boundary rising edge, atomically copy current shadow PERIOD/DUTY/PRESCALE into active values, clear pending, reset phase and prescale_phase to 0, and compute the post-edge PWM output level from **new** active duty and polarity. There is no hybrid old/new period and no partial-period configuration switch. A new ARM issued on a boundary edge with pending previously 0 becomes pending for the **next** boundary, not the current one.

**PWM-UPD-004:** A valid ARM while stopped validates shadow state, copies it to active values immediately but keeps phase=0, prescale phase=0, output=0, OE=0 and pending=0. This is optional for software use because the next enable reloads from shadow anyway; it is **required** for the deterministic standalone register behavior. An invalid stopped ARM errors without changing active configuration.

**PWM-UPD-005:** Disabling a channel while pending=1 aborts the pending update and clears pending, without changing the shadow contents. Next enable uses the current shadow contents after validity check. Other channels' update states and waveforms must be unaffected.

**PWM-UPD-006:** Priority at the same rising edge: asynchronous reset dominates all. An accepted CTRL disable dominates tick/period boundary/update for that channel. Otherwise, a pre-existing pending update applies on a boundary and beats old active configuration for the **new** phase/output; the boundary IRQ event still corresponds to the ending period. A concurrent W1C of that channel's pending IRQ bit does not erase the newly generated boundary event. An error-producing APB access has no software side effects but does not block independent ticking.

**PWM-UPD-007:** Invalid configuration includes PERIOD=0, DUTY>PERIOD; the 16-bit PRESCALE can be any value including 65535. During staging, it is legal to temporarily hold invalid values; only accepted ENABLE or ARM must validate. Do not silently clamp the duty or turn an illegal request into a legal one. Invalid writes to CTRL/ARM return PSLVERR and preserve output/state.

## 7. Period IRQ and shared-register semantics

**PWM-IRQ-001:** Every period boundary when channel EN=1 sets that channel's `IRQ_PENDING` bit **whether or not IRQ_ENABLE is set**. Pending is sticky (not a one-clock pulse), readable independent of mask and clearable only by valid W1C or reset. A period event does not require output-data to toggle: 0% and 100% duty still generate period IRQs.

**PWM-IRQ-002:** `IRQ_ENABLE` is byte-strobed RW. `IRQ_PENDING` is strobed W1C. For each channel bit, `pending_next = (pending_old & ~valid_w1c_mask) | boundary_event`. Thus a boundary in the same cycle as a W1C wins. Boundary events on two or more independent channels at the same edge set all corresponding bits. Writes to upper or absent-channel bits have no effect.

**PWM-IRQ-003:** `irq_o = |(IRQ_PENDING[PWM_CHANNELS-1:0] & IRQ_ENABLE[PWM_CHANNELS-1:0])`, active-high and level-sensitive. Changing IRQ_ENABLE immediately changes the registered/masked pending request without clearing it. Period IRQs are the only interrupt sources in this PWM peripheral. PLIC connection is deferred to integration.

**PWM-IRQ-004:** A successful read of pending never clears it. An invalid/unmapped/RO write cannot clear pending. The APB W1C operation may clear a pending bit while a channel runs; subsequent boundary events can reassert it.

## 8. APB4 protocol contract

Define `access = psel && penable`, `complete = access && pready` at rising PCLK, and `valid_write = complete && pwrite && !pslverr`. One APB transfer consists of SETUP followed by ACCESS; requester holds address/control/strobes/data stable until completion. Zero wait states: `pready=1` continuously.

**PWM-APB-001:** Writes have effects **only on valid completion rising edges**; no effects in SETUP, IDLE, or aborted SETUP. Consecutive ACCESS completions may be followed immediately by new SETUP phases. A selected ACCESS that violates requester timing should be flagged by **testbench protocol assertions**, not repaired by a made-up history FSM in the slave.

**PWM-APB-002:** All legal addresses are **word-aligned**. `paddr[1:0] != 0`, reserved offsets, absent-channel registers and addresses such as `0x01C`, `0x080`, `0x10C`, `0x200`, `0xFFF` are illegal. The full 12-bit local address must be decoded; nothing at `0x100` may alias `0x000`, nor may out-of-range values alias an implemented register.

**PWM-APB-003:** On an invalid selected ACCESS, `pslverr=1`, `prdata=0` for reads, and no software side effect for writes. Otherwise `pslverr=0`. When no selected ACCESS is active, `pslverr=0`, `prdata=0`. Read data is combinational for selected valid reads and sampled **at completion**, before post-edge sequential updates.

**PWM-APB-004:** APB4 requesters must drive `PSTRB=0` on reads. The requester BFM/checker must enforce it. To make malformed reads deterministic, this slave returns PSLVERR=1/PRDATA=0 to a read with nonzero `pstrb`; label that an **invalid requester scenario**. All eight `PPROT` encodings are accepted for otherwise legal transfers; no unauthorized local permission policy.

**PWM-APB-005:** Writable-register zero-strobe access is a valid no-op, **even while pending**. But access to a RO, WO-read, reserved, absent-channel, or unaligned offset is illegal even for zero-strobe writes. Writes must not spuriously affect another channel or a global register. Use atomic byte-mask, side-effect and validity evaluation before FF updates.

**PWM-APB-006:** Register reads at the completion edge see pre-edge state. Read data and PSLVERR checks in both UVM and directed testbenches must avoid SystemVerilog Active/NBA race confusion. On the clock edge, monitors capture APB transaction signals before the edge updates; post-edge registered output checks sample after NBA settling.

## 9. Implementation, code organization, and build rules

Expected layout (create the directory if absent):

```text
peripherals/pwm/
  spec.md
  SIGNOFF.md                # only after evidence is available
  include/                  # only local definitions when useful
  src/pwm_apb.sv            # synthesizable PWM RTL
  tb/pwm_tb.sv              # self-checking directed tests
  tb/pwm_uvm_pkg.sv         # UVM driver/monitor/scoreboard/coverage
  tb/pwm_uvm_tb.sv          # UVM top / virtual interface config
  Makefile
  .gitignore                # ignored build outputs
```

**PWM-BLD-001:** Standard targets: `make lint`, `make sim_tb`, `make sim TEST=<test> SEED=<seed>`, `make regress`, `make cov`, `make wave TEST=<test>`, `make clean`. `sim_tb` runs directed SV tests, `sim` runs UVM, `regress` actually runs both and fails if any mandatory check fails. No decorative no-op target. With a standalone compiler environment, follow the site's `module`/`ml` setup per NEX.md.

**PWM-BLD-002:** Use Verilator for lint and Siemens Questa (available in the user's environment) for peripheral UVM. Do not report blanket Questa unavailability based on one agent shell. Diagnose PATH, environment modules and licensing honestly. Explicitly compile `../../bus/include/apb4_if.sv` **before** any testbench using the interface. `+incdir` does not compile it. Use the exact `virtual apb4_if #(.ADDR_WIDTH(12), .DATA_WIDTH(32))` parameterization everywhere in UVM config DB.

**PWM-BLD-003:** Use unique build dirs/libraries/logs and record source/seed/run command. Compile with actual coverage instrumentation before `vsim -coverage`. Collect directed and UVM coverage separately or with compatible UCDB merging; never call an empty UCDB code coverage. Ignore `build/`, wave dumps, transcripts, coverage binaries, work libraries and generated scripts. Keep source-level coverage definitions in Git.

**PWM-BLD-004:** Simulator `run -all; quit -code 0` may mask a test's failure if scripts ignore failure status. `make sim_tb`, `make sim`, `make regress` and `make cov` must fail on `$fatal`, timeout, any failed SV assertion, UVM_ERROR/UVM_FATAL, simulation crash, missing test, or zero expected checks executed. Verify this using an intentional temporary test failure. Preserve real failure logs, and never filter out unexpected errors by broad text matching.

**PWM-BLD-005:** All tests are time-bounded, have deterministic seed selection, and perform real signal or register assertions. Assert protocol phase stability, no APB side effects in SETUP, output stability between clock edges, correct registered output timing, safe reset outputs, proper pending IRQ and legal/illegal register responses.

**PWM-BLD-006:** Synthesis and STA tools are not selected in current `NEX.md`. Do not claim synthesis, timing closure, DRC/LVS, routed area or tapeout signoff. Keep RTL clean and technology-neutral so these checks can be performed later by the responsible team.

## 10. Independent verification model and required scenarios

**PWM-VER-001:** Directed expected waveforms, expected phase, tick timing, shadow/active commit and IRQ state **must derive from this spec and transactions/external channel outputs**, not `dut.phase`, `dut.tick`, internal waveform events or internal active registers. DUT internals may be logged for debugging only; never used to construct golden expectations.

**PWM-VER-002:** A meaningful UVM environment consists of a driver, monitor, independent clock-aware reference model/scoreboard, actual output/OE/IRQ observation and comparator, and a functional coverage subscriber. Model **all channels** independently with explicit tick, buffered-commit and IRQ logic; do not implement a scoreboard that compares only APB register readback. Avoid using observed RTL outputs to update prediction state.

**PWM-VER-003:** UVM stimulus must include **targeted valid cases** (PERIOD small, DUTY 0/middle/PERIOD, prescale 0/1/2, ENABLE, ARM, pending commit, boundary IRQ, invalid shadow) in addition to random register traffic. Pure random 32-bit periods cannot practically reach PWM boundaries in short tests. Seed reproducibly (at least 1, 7 and 23); use directed checks for rare collisions. Collect coverage from *verified* waveform/event outcomes, not configuration values alone.

**PWM-VER-004:** Compare output/data and OE at expected PCLK edges and check they remain stable between edges. Use clocking blocks or distinct pre-edge/post-NBA sampling regions to avoid races. Test reset assertion at off-clock instants, reset deassertion synchronized to PCLK, APB access during run, and simultaneous independent channel boundaries. No unknown X/Z at outputs after qualified reset; use four-state Questa checks.

### 10.1 Immutable mandatory test catalog

Each `Txx` is a required named executable check. Preserve the ID-to-requirement mapping exactly; comments or a blanket `All tests passed` print are insufficient evidence. Tests may share setup, but must contain explicit expected-value/assertion evidence.

| Test | Required stimulus / assertions |
|---|---|
| T01 | Assert reset asynchronously between PCLK edges; check **all** register defaults, outputs/OE, IRQ, active phase behavior after startup and no enabled output. |
| T02 | APB IDLE/SETUP/ACCESS; abort SETUP and verify no side effects; back-to-back legal transfers each commit once. |
| T03 | Read/write all legal per-channel and global offsets, permissions, PWM_INFO channel count, reserved bits and reset readbacks. |
| T04 | **All 16 PSTRB masks** on CTRL, PERIOD, DUTY, PRESCALE, IRQ_ENABLE; verify byte preservation, reserved bits, and legal zero-strobe no-op with running and pending channels. Design legal CTRL stimuli; rejected illegal configurations must preserve old state. |
| T05 | All invalid-address classes: misaligned, reserved channel `+0x1C`, global holes, high bits, `0x100` not aliasing `0x000`, invalid `0xFFF`. |
| T06 | Read WO UPDATE, write RO STATUS/PHASE/INFO (even with zero strobe); errors and atomic no-side-effect. |
| T07 | All eight PPROT values on otherwise identical valid reads/writes, and read-PSTRB malformed-requester handling. |
| T08 | EN 0->1 edge starts phase 0/high-or-low correctly and suppresses tick at completion; EN 1->0 suppresses tick and forces safe off, including polarity=1. |
| T09 | PERIOD=4, DUTY=1, PRESCALE=0 exact edge trace described in PWM-TIME-004, including boundary IRQ. |
| T10 | Duty 0%, 50%, 100% for PERIOD=4; registered rising/falling edges, no 1-cycle unintended pulses or phase shifts. |
| T11 | PERIOD=1 with DUTY=0 and DUTY=1; boundary occurs every tick; no underflow/overrun. |
| T12 | PRESCALE=1 and 2 exact tick and waveform transitions, including first tick delay after enable. |
| T13 | PRESCALE=255 and 65535: exact first-tick timing (bounded, no need to run many full cycles) and no 16-bit divider overflow/zero-extension bug. |
| T14 | Inverted polarity behavior at duty=0, intermediate and full duty; disabled output and OE remain low even for inverted channel. |
| T15 | 4 channels with different PERIOD/DUTY/PRESCALE/EN: independent phase, output and period boundaries, no coupling. |
| T16 | PWM_CHANNELS=1,2,3,4 elaborate and pass appropriate subsets; absent channel accesses PSLVERR; inactive IRQ bits read 0. |
| T17 | Invalid parameter PWM_CHANNELS 0 and 5 produce explicit configuration failure. |
| T18 | While running, shadow-only PERIOD/DUTY/PRESCALE writes leave active output cadence and phase unchanged until ARM and boundary. |
| T19 | ARM then assert UPDATE_PENDING; shadow writes rejected atomically while pending, zero-strobe no-op, repeated ARM rejected. |
| T20 | On next boundary, simultaneous PERIOD/DUTY/PRESCALE update applies together, UPDATE_PENDING clears and new phase/output uses **new** values, with no fractional-cycle glitch. |
| T21 | ARM completing **on the same edge as** a boundary with old pending=0 applies only at **next** boundary. Test valid transaction timing unambiguously. |
| T22 | ARM while disabled validates and loads active but does not drive output; enabling later reloads shadow with exact phase 0 semantics. |
| T23 | Disabling with pending update cancels pending, preserves staging and forces safe outputs; re-enable uses latest shadow. |
| T24 | PERIOD=0 or DUTY>PERIOD may be staged but enable and ARM reject them atomically; no silently clamped duty; repair then enable works. |
| T25 | POLARITY change while running rejected even on simultaneous stop request; disable first and change works; ordinary unchanged CTRL write does not restart divider/phase. |
| T26 | Boundary IRQ latches when IRQ masked; enabling mask later asserts `irq_o` without a new event; mask disable deasserts without clearing pending. |
| T27 | W1C clears only strobed selected IRQ bits; reading never clears; absent-channel bits ignored. |
| T28 | W1C **colliding with period boundary**: HW set wins; test with multiple simultaneously wrapping channels. |
| T29 | Period IRQ continues at 0% and 100% duty even with constant output-data level. |
| T30 | Aborted/invalid APB accesses during ticking and pending-arm state do not change staged/active state; PWM timekeeping continues. |
| T31 | Clock-edge stability: output-data and OE do not glitch between positive PCLK edges for duty updates/IRQ/APB traffic; async reset takes outputs low immediately. |
| T32 | Four-state Questa no-X/Z check for outputs, IRQ, valid APB reads following reset with defined input transactions. |
| T33 | UVM fixed seeds 1/7/23 execute checked APB *and* cycle-level waveform/OE/IRQ reference comparisons, with explicit observed check counts and no unexpected mismatches. |
| T34 | Mutation tests detect (a) `phase < duty` changed to `phase <= duty`, (b) drop/early apply a buffered update, (c) reverse HW-set-over-W1C priority. Restore RTL and record fail evidence. |
| T35 | Intentionally cause a temporary scoreboard mismatch / SV fatal and demonstrate `make sim`, `make sim_tb`, and `make regress` return nonzero (no fake green). |
| T36 | Clean checkout build: Verilator lint, Questa directed/UVM, and instrumented code/functional coverage run with reproducible commands; no stale work library, generated test script, or dependency on the GPIO/Timer worktrees. |

### 10.2 Minimum functional coverage bins

**PWM-COV-001:** Separate APB structural coverage from PWM functional coverage. The APB group includes implemented channel/global register classes, read/write/access permissions, error classes, all PSTRB values, and PPROT classes.

**PWM-COV-002:** **Behavioral coverage must be sampled on actual checked events**, not just config writes: each channel active/inactive, phase advance, period wrap, 0%/middle/100% duty, inverted output levels, 1/small/max prescaler timing, apply update at boundary, abort pending on disable, invalid ARM and enable, simultaneous channel wraps.

**PWM-COV-003:** Cover IRQ pending while masked, W1C, HW SET collision, simultaneous events and both IRQ output levels; test that update and IRQ conditions are actually observed. Report bin hit/total per group, exactly which reachable bins remain unhit, and whether directed evidence covers the gaps. A high APB coverage percentage does **not** imply timer-waveform coverage.

**PWM-COV-004:** Do not add unreachable cross-products or blindly inflate percentages; do not delete real coverage bins simply because missed. No universal 100% statement/branch/toggle threshold is mandated. **All mandatory reachable functional behaviors must be observed by independent assertions or have explicit human-approved waivers.**

### 10.3 Verification-defect prevention

**PWM-VER-005:** Every testbench model must use correct nonblocking edge semantics. Never use `dut.*` timing/phase to compute golden expectations, hardcode observed simulation outputs as expected constants without derivation, or compute expected PERIOD/phase by simply mirroring readback. Wrong reference models are a signoff defect.

**PWM-VER-006:** Make failures propagate through all Make targets; UVM driver must not silently skip transactions, report positive observed transfer/output check counts, and test failure must be demonstrated to be detected by the regression harness. A generated coverage report without nonzero meaningful checks is not acceptable.

**PWM-VER-007:** If coverage shows an important untested event, add a **targeted bounded scenario**, not thousands of random seeds. Honor the tapeout timeline: prioritize correct waveforms, reset safety, update atomicity, APB correctness and IRQ behavior. Do not endlessly expand verification infrastructure after these are validated.

## 11. Agent implementation and Git workflow

**PWM-DEV-001:** Work in an **independent sibling Git worktree**, suggested `~/AFTxAI-pwm`, on `feat/pwm-peripheral`. Base on the committed `origin/feat/gpio-peripheral` to reuse `bus/include/apb4_if.sv` without inheriting ongoing Timer verification changes. If an approved integration branch already contains equivalent shared definitions, inspect and document that before choosing a base. Never create a new worktree inside the GPIO/Timer checkout if a sibling worktree is available. Do not switch the user's other checkout's branch; do not modify their working files.

**PWM-DEV-002:** Inspect worktree and Git status before running `git worktree add`; if PWM branch/worktree already exists, resume it instead. The source path `peripherals/pwm/` is separate. Do not touch GPIO or Timer RTL, Makefiles, specifications, source dependencies, or internal state. Use isolated `peripherals/pwm/build/` for generated artifacts.

**PWM-DEV-003:** Before RTL: inspect the repository, read `NEX.md`, read this full document, inspect the shared APB4 interface and existing GPIO/Timer *interface conventions only*. Confirm the architecture file's existence or absence; do not derive PWM functionality from unrelated RTL. Report major spec conflicts, keep all system-level integration gate decisions OPEN.

**PWM-DEV-004:** Make cohesive small commits to feature branch for spec, RTL, directed tests, UVM, fixes, and signoff. Run `git diff --check`, lint and relevant regression before feature-completion commit. Push only the feature branch with the user's authorization in this session. Never merge to main, squash unrelated history or commit generated build files.

**PWM-DEV-005:** Implementation sequence: (A) standalone register/decode/parameter design and synth RTL; (B) immediate Verilator lint and directed Questa smoke with verified failure propagation; (C) all T01–T32 checker scenarios; (D) independent UVM+targeted sequences and functional coverage, T33–T36; (E) bounded bug fixes and signoff. If tools fail, give the real command/logs, do not say "PASS" based on compilation alone.

## 12. Acceptance, freeze boundary, evidence report

**PWM-ACC-001:** `READY FOR INDEPENDENT STANDALONE RTL FREEZE REVIEW` may be recommended only when: correct reset-safe 1..4-channel outputs; duty, period, phase and prescale waveforms at exact PCLK edges; atomic buffered updates; correct APB errors/strobes; accurate period IRQ/W1C priority; T01–T36 evidence; meaningful directed+UVM independent comparisons; Verilator lint and actual Questa regression passes; and zero known major functional/protocol blockers. Mandatory behaviors not directly covered require explicit reviewed disposition, not silently skipped tests.

**PWM-ACC-002:** At the end of a single **bounded** closure pass, produce `peripherals/pwm/SIGNOFF.md` reporting the exact commit hash, final source files, tool versions, commands and logs, seed values, true checks executed, one T-ID per table row with TB location and actual result, separate code coverage types and APB/behavioral bin hit/total, mutation experiment failures, known bugs/limitations, and IG-P01–IG-P09 gate status/owners. Do not certify your own independent review.

**PWM-ACC-003:** Stop at the requested standalone RTL freeze candidate and hand over for independent review. Open bus, pin mux, reset-distribution, PLIC allocation, firmware ABI approval, synthesis/STA and physical signoff are **later integration tasks** and do not justify inventing a bus or delaying independent PWM RTL development. Conversely, they remain blockers for any claim of complete SoC tapeout readiness.

**End of PWM standalone specification.**

