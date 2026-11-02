# AiFTx Timer0: Functional, APB4, RTL and Verification Specification

**Proposed repository path:** `peripherals/timer/spec.md`  
**Revision:** 1.0, standalone implementation contract (16 October 2026)  
**Status:** Approved for *standalone implementation under this contract*; NOT approved for SoC integration or tapeout signoff  
**Audience:** ChipNexus Nex, design reviewers, firmware authors, verification engineers  
**Normative implementation language:** IEEE 1800 SystemVerilog

> **Agent mandate:** Read this entire specification and the repository's `NEX.md` before editing files. Implement a *fully functional* Timer0 and meaningful verification, not placeholders. The bus fabric and CPU are not ready: reuse the existing **provisional** `bus/include/apb4_if.sv` in testbenches; do not implement or modify an APB/AHB interconnect, bridge, CPU, CLINT, or PLIC. Keep the timer's logical APB ports cleanly replaceable by a future adapter. Follow Sections 11-14 before declaring completion. A compile, a printed PASS, a generated UCDB, and a Nex completion report are not by themselves evidence of functional correctness.

## 1. Authority, provenance, and scope

### 1.1 Source of requirements

1. The team's system-on-chip specification defines Timer0 as an APB slave at absolute address `0x8000_2000` through `0x8000_3FFF`, nominal PCLK 12.5 MHz. It describes general-purpose timekeeping, periodic interrupts, and/or input capture separately from CLINT. It does **not** define a Timer0 register ABI, counter mode, or capture timing.
2. `NEX.md` governs repository layout, SystemVerilog conventions, EDA tools, Git, and engineering process. If `docs/AiFT_spec.md` is absent from the checkout, use the provided system architecture as reference; report its absence, do not invent it or silently substitute CPU RTL.
3. Arm AMBA APB Protocol Specification governs APB4 signaling and transfers. See https://documentation-service.arm.com/static/60d5b505677cf7536a55c245 (Issue D, APB4 subset) or the latest official Arm revision. This specification selects **APB4** (`PSTRB`, `PPROT`) and does not require APB5 extensions.
 

**TMR-SCP-001:** Implement one reusable, standalone 32-bit programmable Timer0 instance operating entirely in PCLK. Its features are a 32-bit up-counter, 16-bit prescaler, periodic / one-shot / free-running modes, compare-match interrupt, free-run overflow interrupt, one asynchronous capture input with edge selection and value latch, capture-overrun interrupt, and one aggregate level-sensitive interrupt output.

**TMR-SCP-002:** Do not implement CLINT `mtime/mtimecmp`, a watchdog, RTC, PWM generator, DMA, pin mux, pad driver, APB address crossbar, APB bridge, or RISC-V CSR access. Timer0 is **not** the RISC-V architectural machine timer. PWM output generation belongs to the independent PWM peripheral. Legacy output-action functions are **explicitly deferred** pending system requirements.

**TMR-SCP-003:** The microarchitecture is Nex's choice; all externally observable behavior, timing, register fields, error conditions, and verification evidence below are mandatory. No undocumented extensions or dummy implementation are allowed.

## 2. System boundary and integration gates

| Gate | Standalone contract now | Integration owner / later action |
|---|---|---|
| IG-T01: APB fabric | APB4, 32-bit data, **13-bit local byte offset** (`0x0000`-`0x1FFF`), one select. | Bus team maps `0x8000_2000`-`0x8000_3FFF` exactly; agree on adapter/local-address slicing. |
| IG-T02: Shared interface | Reuse existing provisional `bus/include/apb4_if.sv` with `ADDR_WIDTH=13`, `DATA_WIDTH=32` when available. Scalar APB ports on DUT are allowed as in GPIO, with a thin testbench mapping. | Bus team later approves/modifies shared interface; minimize changes to `timer_apb.sv`. |
| IG-T03: Reset | `presetn`, active-low asynchronous assertion; system must synchronize deassertion to PCLK. | SoC reset owner specifies distribution and actual CDC/RDC strategy. |
| IG-T04: Clocks | All timer logic uses PCLK nominal 12.5 MHz; no HCLK inside timer. | AHB/APB bridge owner handles relationship and CDC. |
| IG-T05: IRQ | One active-high level-sensitive `irq_o`, with sticky underlying cause bits. | PLIC owner assigns interrupt source number and firmware servicing rules. |
| IG-T06: Capture pin | `capture_i` is asynchronous digital input presented by external I/O mux; two-flop synchronize internally. | I/O mux/pad owner allocates function and physical pin. |
| IG-T07: ABI | Local offsets in Section 5 are frozen for standalone tests. | Software/system reviewers approve before integrating firmware; changes require ABI review. |
| IG-T08: Physical flow | Synthesizable, lintable RTL without inferred latches, generated clocks or internal tristates. | Synthesis/STA, pad timing constraints and ASIC signoff tool selection belong to physical flow owners. |

**TMR-INT-001:** Missing CPU, bus fabric, or final pin mux are **not blockers to standalone design**. Use the provisional APB4 contract; never implement a fake functional bus or change GPIO's APB4 interface merely to make Timer0 tests pass. Do not hard-code absolute SoC addresses in Timer0 RTL.

**TMR-INT-002:** Preserve the existing GPIO branch's shared `apb4_if.sv` if present; do not create a second `timer_apb_if` with incompatible protocol fields. If it is absent, prefer one minimal clearly provisional compatible definition at `bus/include/apb4_if.sv`, documenting ownership. Compile it explicitly as a source in Questa; `+incdir` alone does not compile interface definitions.

**TMR-INT-003:** Integration gates can remain OPEN at **standalone RTL freeze**; they MUST remain visible and are blockers to unqualified system/tapeout readiness. Never claim full-chip pin compatibility until resolved.

## 3. Logical module ports and structure

The primary module shall be named `timer_apb`, in `peripherals/timer/src/timer_apb.sv`.

| Logical port | Direction | Width | Purpose |
|---|---|---:|---|
| `pclk` | input | 1 | PCLK domain clock. |
| `presetn` | input | 1 | Asynchronous active-low reset input; release synchronized outside DUT. |
| `paddr` | input | 13 | **Full local byte offset** 0x0000-0x1FFF, no truncation or alias. |
| `psel` | input | 1 | Timer0 APB select. |
| `penable` | input | 1 | ACCESS-phase indicator. |
| `pwrite` | input | 1 | 1 write, 0 read. |
| `pwdata` | input | 32 | Write data. |
| `pstrb` | input | 4 | Byte strobes, lane 0 = bits 7:0. |
| `pprot` | input | 3 | Protection hints; no privilege filtering in this peripheral. |
| `prdata` | output | 32 | Read data. |
| `pready` | output | 1 | Zero-wait completer. |
| `pslverr` | output | 1 | Error on invalid completed transfer. |
| `capture_i` | input | 1 | Asynchronous capture event input from future pin mux. |
| `irq_o` | output | 1 | Aggregate active-high level IRQ for Timer0. |

**TMR-IF-001:** Keep the timer internally single-clock synchronous logic (apart from asynchronous reset assertion and the capture input synchronizer). No new clock generator, gated clock, internal Z/X assignments, analog simulation-only behavior or external bridge logic.

**TMR-IF-002:** The implementation may use discrete APB ports like `gpio_apb.sv` and connect the provisional `apb4_if #(.ADDR_WIDTH(13), .DATA_WIDTH(32))` in UVM top. Do not embed a globally absolute address into the interface. All 13 address bits must participate in validity checking: `0x0000` is a different address than `0x0100`, `0x1000`, and `0x1FFC`.

**TMR-IF-003:** The module must instantiate/reuse `digital_lib/src/sync_2ff.sv` for `capture_i` (WIDTH=1) when available. Do not edit the shared synchronizer unless proving a real bug affecting its users and explicitly identifying downstream impact.

## 4. Clock, reset and timer timebase

**TMR-CLK-001:** Timer clock is `pclk`, targeted at 12.5 MHz (nominal 80 ns per rising edge). This is an integration target, **not** a parameter-dependent clock divider. All timer functionality advances in integer PCLK cycles.

**TMR-RST-001:** Every state-holding register, prescaler counter, IRQ pending bit, synchronizer state, capture register and baseline-valid state resets upon `negedge presetn`, without waiting for PCLK. The SoC is responsible for a PCLK-synchronous reset release. Keep reset logic synthesis-friendly.

**TMR-RST-002:** Reset values: `CONTROL=0`, `COUNT=0`, `PERIOD=0xFFFF_FFFF`, `PRESCALE=0`, `IRQ_ENABLE=0`, `IRQ_PENDING=0`, `CAPTURE_VALUE=0`, prescale phase=0, `irq_o=0`. All reserved bits read zero. Capture starts invalid until baseline acquisition.

**TMR-RST-003:** After deassertion, ignore capture transitions for the first **three** rising PCLK edges, allowing two synchronizer stages and a previous-value baseline. The first edge eligible to record a capture is the **fourth** rising edge after deassertion. Continue sampling `capture_i` even while the timer is disabled, so enabling the timer cannot manufacture an edge from a held-high input.

**TMR-CLK-002:** A software-visible tick occurs **once every `PRESCALE+1` rising PCLK edges** while `CONTROL.EN=1`. `PRESCALE=0` yields one tick per active PCLK edge. The internal prescale phase counts 0..PRESCALE inclusive; phase zero is the initial state.

**TMR-CLK-003:** Starting the timer (`EN` transition 0->1) resets prescale phase to zero, **does not update COUNT on that APB completion edge**, and first timer tick occurs exactly `PRESCALE+1` subsequent rising PCLK edges later. Disabling the timer (`EN` transition 1->0) prevents a timer tick on the disable APB completion edge, leaves COUNT unchanged and resets prescale phase to zero. Other APB reads/writes do not stall timekeeping.

**TMR-CLK-004:** When disabled, COUNT is held and prescale phase is zero. Upon re-enabling, COUNT resumes from its stored value (no implicit clearing/rearming). This holds for all modes, including after one-shot completion. Software must write COUNT=0 while disabled to restart a full one-shot interval.

**TMR-CLK-005:** Writing COUNT, PERIOD or PRESCALE is permitted only when disabled. An ACCESS write to any of these while running with nonzero PSTRB returns PSLVERR and changes **none** of the timer's configuration, counter, IRQ, or phase state because of that access. A zero-strobe write is a legal no-op even while running. See Section 6 for simultaneous tick handling.

## 5. Register ABI (new AiFTx design, not AFTx07 compatibility)

All registers are 32-bit words on aligned offsets. All valid local offsets are listed below; **every other offset from 0x0020 through 0x1FFF is unmapped**. All 32-bit reads are zero-extended for narrower registers. All resets are as specified; write-only operations use none in this map.

| Local byte offset | Register | Access | Reset | Field summary |
|---:|---|---|---|---|
| `0x0000` | `CONTROL` | RW | `0x0000_0000` | EN, MODE, CAP_EN, CAP_EDGE |
| `0x0004` | `COUNT` | RW when stopped, RO while running | `0x0000_0000` | 32-bit counter |
| `0x0008` | `PERIOD` | RW when stopped, RO while running | `0xFFFF_FFFF` | Terminal/compare value |
| `0x000C` | `PRESCALE` | RW when stopped, RO while running | `0x0000_0000` | Bits [15:0] tick divider minus one |
| `0x0010` | `IRQ_ENABLE` | RW | `0x0000_0000` | Mask for four event causes |
| `0x0014` | `IRQ_PENDING` | RO + W1C | `0x0000_0000` | Four sticky cause bits |
| `0x0018` | `CAPTURE_VALUE` | RO | `0x0000_0000` | Captured COUNT sample |
| `0x001C` | `TIMER_INFO` | RO | `0x544D_0101` | ID 'TM', ABI v1, one capture channel |

### 5.1 CONTROL

| Bits | Field | Values |
|---:|---|---|
| [0] | EN | 0 stopped; 1 running. One-shot completion auto-clears EN. |
| [2:1] | MODE | `00` periodic; `01` one-shot; `10` free-running; `11` illegal. |
| [3] | CAP_EN | 0 disable capture recording; 1 enable while timer running. |
| [5:4] | CAP_EDGE | `00` rising; `01` falling; `10` either; `11` illegal. |
| [31:6] | reserved | Read 0; write ignored. |

**TMR-REG-001:** CONTROL reset is zero; readback reflects actual EN (including hardware auto-clear), configured MODE/CAP_EN/CAP_EDGE, with all reserved bits zero. Writing an illegal MODE or CAP_EDGE value returns PSLVERR and **must not change any register**.

**TMR-REG-002:** CONTROL writes use merged old/new bytes under PSTRB, then validate the effective value atomically. While current EN=1, changes to MODE, CAP_EN or CAP_EDGE are forbidden; a write may leave config unchanged and change EN to zero. A write that attempts to change config while running fails entirely, even if it also attempts to disable in the same transfer. Firmware must first disable, then reconfigure. Writes to only reserved CONTROL bytes are legal no-ops.

**TMR-REG-003:** When CONTROL write transitions EN=0 to EN=1 in periodic or one-shot mode, it is valid only if current `COUNT <= PERIOD`. Invalid enable returns PSLVERR and leaves EN/COUNT/phase/interrupt state unchanged. Free-run has no COUNT-versus-PERIOD restriction. When EN is held unchanged by a write, there is no hidden timer restart.

### 5.2 COUNT, PERIOD, PRESCALE

**TMR-REG-004:** COUNT stores a full 32-bit unsigned count. PERIOD stores a full 32-bit unsigned limit/compare. PRESCALE uses only bits [15:0], with readback bits [31:16] zero and writes to these upper bits ignored. Writes use PSTRB byte merging; legal partial writes are atomic.

**TMR-REG-005:** Timer register writes are not dependent on external interrupt enables. COUNT/PERIOD/PRESCALE may be written in any order while stopped. Intermediate COUNT>PERIOD values are legal **while stopped**, but starting in periodic/one-shot mode with this relation is illegal as specified above.

**TMR-REG-006:** A read of COUNT during an active tick returns the COUNT value existing **before the completion rising edge** (APB read data is sampled at that edge). Count may update immediately after that edge; a testbench must sample during the completion edge using race-free clocking, not compare a post-NBA read against a pre-NBA expectation.

### 5.3 IRQ_ENABLE and IRQ_PENDING

| Bit | Cause | Meaning |
|---:|---|---|
| 0 | MATCH | One tick occurred while pre-tick COUNT == PERIOD, in any mode. |
| 1 | WRAP | In free-running mode, a tick incremented pre-tick COUNT `0xFFFF_FFFF` to zero. Never asserted by periodic reload. |
| 2 | CAPTURE | At least one qualifying capture edge was recorded and not yet cleared. |
| 3 | CAP_OVERRUN | A further qualifying capture edge occurred while CAPTURE pending was already 1. |
| [31:4] | reserved | Always read 0; writes ignored. |

**TMR-IRQ-001:** IRQ_ENABLE is ordinary RW with PSTRB masking and reset 0. `irq_o = |(IRQ_PENDING[3:0] & IRQ_ENABLE[3:0])`. It is **active-high and level-sensitive**, not a one-clock pulse; disabling interrupt mask does not erase recorded events.

**TMR-IRQ-002:** IRQ_PENDING is sticky event state, read-visible even with all mask bits zero. Writes are W1C **only in selected PSTRB bytes**; writing zero has no effect. Writing bits [31:4] has no effect. Reading IRQ_PENDING must not clear it.

**TMR-IRQ-003:** For all four bits, hardware SET dominates a simultaneous W1C clear at a PCLK edge: `pending_next = (pending_old & ~valid_w1c_mask) | event_vector`. Multiple event bits may set on the same edge. No interrupt source is gated by IRQ_ENABLE before storage.

### 5.4 CAPTURE_VALUE and TIMER_INFO

**TMR-CAP-001:** `capture_i` passes through a reused two-flop PCLK synchronizer; qualifying edges are evaluated against the **previous synchronized sample**, subject to the startup-baseline qualification of TMR-RST-003. There must be no combinational asynchronous input feeding functional timer state or `irq_o`.

**TMR-CAP-002:** Capture is armed only when **pre-edge** CONTROL.EN and CAP_EN are both 1, baseline is valid, and the selected CAP_EDGE condition occurs on the synchronized input. CAP_EDGE `00` detects 0->1, `01` detects 1->0, `10` detects both. Changes during the first three post-reset clocks or while stopped do not record captures.

**TMR-CAP-003:** On the first qualifying edge while `IRQ_PENDING.CAPTURE` is 0 before the edge, write `CAPTURE_VALUE = COUNT_old` (the counter before any tick update on the same PCLK edge) and set CAPTURE pending. The data remains stable until a later accepted capture, or reset. Reading it never alters status.

**TMR-CAP-004:** On another qualifying edge while `IRQ_PENDING.CAPTURE` was already 1 before the edge, retain the **first** CAPTURE_VALUE and set CAP_OVERRUN. If a W1C clearing CAPTURE occurs on the same edge as such a new capture, the prior pending state still controls overrun: retain old capture value and set both CAPTURE and CAP_OVERRUN pending by hardware-set priority. If pending was 0, the edge records a new value even when a W1C bit is also asserted.

**TMR-CAP-005:** Clearing CAPTURE pending through W1C re-arms the next capture if no simultaneous event. Clearing CAP_OVERRUN alone does not clear CAPTURE. Disabling CAP_EN or EN neither clears CAPTURE_VALUE nor any pending bits. No FIFO, timestamp queue, debounce, input pulse stretching or metastability elimination guarantee beyond the 2FF synchronizer is required.

**TMR-REG-007:** `TIMER_INFO` always reads exactly `0x544D_0101` (`0x544D` = 'TM', major ABI `01`, one capture channel `01`). 

## 6. Counter state transitions and exact cycle semantics

Let `tick` be true on a rising PCLK edge if, immediately before the edge, EN=1 and the internal prescale phase equals PRESCALE, **except** a valid CONTROL write disabling the timer at that edge suppresses the tick. When EN=1 and no tick occurs, phase increments by one. On a tick, phase returns to zero. Starting and disabling rules in Section 4 take priority. An APB read, IRQ_ENABLE write or IRQ_PENDING W1C does not suppress a tick.

**TMR-TIME-001 (periodic, MODE=00):** On each tick, if COUNT_old == PERIOD, assert a one-cycle internal MATCH event and set COUNT_next=0; otherwise COUNT_next=COUNT_old+1. EN remains 1. The periodic terminal interval contains exactly **PERIOD+1 ticks**. `PERIOD=0` matches on every tick. The MATCH pending bit persists until W1C, irrespective of subsequent periods.

**TMR-TIME-002 (one-shot, MODE=01):** On each tick, if COUNT_old == PERIOD, emit MATCH, hold COUNT_next=PERIOD, and auto-clear EN after that edge. Otherwise increment COUNT. Thus one-shot from COUNT=0 expires after PERIOD+1 ticks. After expiration, a fresh write setting EN=1 resumes from COUNT=PERIOD and will match at the first new tick; software must set COUNT=0 first for an entirely new interval. No extra match is emitted while stopped.

**TMR-TIME-003 (free-running, MODE=10):** On every tick, COUNT_next=COUNT_old+1 modulo 2^32 regardless of PERIOD. Emit MATCH when COUNT_old == PERIOD, and WRAP when COUNT_old == 32'hFFFF_FFFF. If PERIOD is also FFFF_FFFF, **both** MATCH and WRAP occur on the same tick. EN does not auto-clear.

**TMR-TIME-004:** For example, with PRESCALE=2, COUNT=0 and PERIOD=2, after an EN 0->1 completion edge, ticks occur on the 3rd, 6th, 9th, ... subsequent PCLK rising edges. Periodic mode updates COUNT 0->1 at tick 1, 1->2 at tick 2, 2->0 and MATCH at tick 3. One-shot instead updates 2->2, sets MATCH, and clears EN at tick 3. This example is normative and must be an executable directed check.

**TMR-TIME-005:** A capture event and counter tick may occur at the same PCLK edge: capture records COUNT_old, while counter and relevant IRQ pending state update according to their own rules. No event must be lost solely because a software access or another event occurred concurrently.

**TMR-TIME-006:** Reading TIMER_INFO, CONTROL, COUNT, PERIOD, PRESCALE, IRQ_ENABLE, IRQ_PENDING, and CAPTURE_VALUE is side-effect-free. Only a completed and valid APB write can change programmable state; hardware timer/capture events and reset may change state independently of the bus.

## 7. APB4 access rules

Define `access = psel && penable` and `write_commit = access && pready && pwrite && !pslverr`, evaluated on each rising PCLK edge. An APB requester presents one SETUP cycle (`psel=1, penable=0`) followed by ACCESS (`psel=1, penable=1`). It may present back-to-back transfers via new SETUP phases. The zero-wait slave completes on first ACCESS edge.

**TMR-APB-001:** `pready=1` (zero wait), no internal bus-stall FSM. No software write side effect during IDLE or SETUP. A valid ACCESS write commits exactly once per completed transfer.

**TMR-APB-002:** All local accesses must be **word-aligned** (`paddr[1:0]==0`); any unaligned access produces PSLVERR=1 on the selected ACCESS and no software-induced register change. All addresses not in the eight-entry register map, including `0x0020`, `0x0100`, `0x1000`, and `0x1FFC`, must error rather than aliasing low address bits.

**TMR-APB-003:** An APB read must use PSTRB=0 according to APB4. The requester BFM and assertions MUST enforce this. For deterministic error handling, this Timer0 additionally responds PSLVERR=1 with PRDATA=0 to a malformed read with nonzero PSTRB; test it separately as **illegal requester stimulus**, not as a valid APB transaction.

**TMR-APB-004:** PSTRB values 0000..1111 are legal for otherwise valid **writes**; only strobed bytes may change. Zero-strobe writes are no-ops to valid writable words. For unmapped/unaligned/RO-address writes, PSLVERR is asserted **even if PSTRB is zero**. Reserved writable-field bits are ignored and read zero.

**TMR-APB-005:** Every write to RO `CAPTURE_VALUE` or `TIMER_INFO` errors. Illegal CONTROL encodings, illegal running-state writes, invalid start COUNT>PERIOD, and all invalid addresses error with **atomic no-write/no-side-effect** semantics. A hardware tick or capture coincident with an errored write must still operate normally; “no side effect” refers to the rejected software write.

**TMR-APB-006:** All eight PPROT values are legal and have identical Timer0 behavior. Timer0 must not silently invent privilege or security gates. APB bridge security policy is outside this block.

**TMR-APB-007:** `pslverr=0` when `!access`; PSLVERR may be asserted during ACCESS for documented invalid operations and is meaningful only with PSEL/PENABLE/PREADY. `prdata=0` outside valid selected reads and on errored reads; data from valid reads is combinationally available throughout ACCESS, sampled at the completion edge. The DUT must not rely on sampled data in a UVM monitor after NBA updates to prove a pre-edge read.

**TMR-APB-008:** The APB requester must keep controls stable through SETUP and ACCESS; assert/check this in verification. For an invalid requester that violates phase sequencing, detect the violation in the **testbench protocol checker**; do not invent a hardware protocol-history detector or require PSLVERR for an illegal SETUP->ACCESS waveform. Reset aborts an outstanding transaction; requester must return to IDLE during reset and restart a fresh SETUP afterward.

## 8. Reset and collision priority reference

The following precedence is mandatory and must be mirrored by an independently written reference model.

1. Asynchronous reset dominates all events and writes.
2. A completed valid CONTROL EN change starts or stops timing at that edge; no timer tick occurs on that start/stop edge.
3. If current EN stays 1, an ordinary timer tick may coincide with valid IRQ writes, reads, and capture.
4. For sticky IRQ_PENDING, a hardware SET beats an APB W1C on the same clock; otherwise clear follows byte-masked W1C.
5. CAPTURE_VALUE first-hit/overrun determination uses **pre-edge** capture-pending state, even if pending W1C commits concurrently.
6. A rejected APB access never alters programmable state, but autonomous counting/capture is unaffected.

**TMR-PRI-001:** No combinational latch, inferred multiple driver, blocking/nonblocking race, simulator initialization trick, undocumented timing priority, or unclocked operation is allowed to resolve conflicts. Use `always_ff` for state and `always_comb` or continuous assignments for combinational decode; review widths, signedness, overflow arithmetic and reset completeness.

## 9. Structure, tools and reproducibility

Expected files (create only if not already present):

```
peripherals/timer/
  spec.md                   # this file: DO NOT weaken to match RTL
  include/                  # optional timer-local definitions
  src/timer_apb.sv
  tb/timer_tb.sv            # self-checking directed SV, independent expected results
  tb/timer_uvm_pkg.sv       # real UVM agent, BFM, monitor, scoreboard, coverage, sequences
  tb/timer_uvm_tb.sv        # UVM top with virtual interface config
  Makefile
  SIGNOFF.md                # after verification; truthful evidence
```

Reuse rather than fork `bus/include/apb4_if.sv` and `digital_lib/src/sync_2ff.sv`. Do not edit GPIO source, its Makefile, UVM environment, or its specification.

**TMR-BLD-001:** Provide `make lint`, `make sim TEST=<uvm_test> SEED=<seed>`, `make sim_tb`, `make regress`, `make cov`, `make wave TEST=<test>`, `make clean` matching `NEX.md`; optional `make sim_verilator` for fast directed checks. `make sim` runs **UVM** and `make sim_tb` runs **directed** tests; never switch their top modules invisibly.

**TMR-BLD-002:** Use Verilator `--lint-only` for RTL and **Siemens Questa** for UVM and code/functional coverage, as required by `NEX.md`. The user's asicfab terminal successfully ran Questa 2021.4; if a Nex shell sees a license error, diagnose environment module initialization, PATH, relevant license configuration, and actual shell context rather than claiming universally that Questa is unavailable. Never fabricate license values or bypass licensing. Preserve relevant logs.

**TMR-BLD-003:** Questa must compile `bus/include/apb4_if.sv` explicitly, **before** `timer_uvm_tb.sv` or other consumers. `+incdir` only affects include lookup and is not a compile action. Import the site's available UVM package compatible with Questa; do not require a different UVM major version without need. Check `uvm_config_db` virtual-interface delivery in build phases before running randomized tests.

**TMR-BLD-004:** Do not let simulator's nominal zero exit code conceal UVM_ERROR/UVM_FATAL, failed SV assertions, $fatal, timeout, no tests executed, or incomplete regression. Correct exit handling must distinguish UVM report-summary counts from actual errors; prove deliberate test failure causes `make sim` to fail. All builds must have bounded timeouts.

**TMR-BLD-005:** Compile with Questa code-coverage instrumentation (`+cover=...` or supported equivalent) **before** running `vsim -coverage`, and report code coverage separately from UVM functional bins. A generated UCDB with a `code was not compiled with coverage options` warning is NOT valid code-coverage evidence. Use separate unit/UVM UCDBs and merge only compatible databases. Never inflate a percentage by adding unreachable bins, exclusions or artificial sampling.

**TMR-BLD-006:** Write `build/` (and only ignored tool outputs) for `work`, `obj_dir`, transcript, logs, wave dumps, UCDB, coverage HTML. Ensure a clean checkout can run all documented targets without depending on an interactive working-library state. Follow server module-system conventions; no arbitrary new EDA tool or ad hoc build pipeline.

**TMR-BLD-007:** Keep branch focused (`feat/timer-peripheral`), preserve GPIO commits, make incremental logically grouped Git commits (spec, RTL, directed tests, UVM, fixes), and never merge into main or push without permission for the active session. Avoid committing generated files.

## 10. Required independent verification approach

**TMR-VER-001:** Write a self-checking directed testbench with at least one explicit independent expected-value assertion per test below, meaningful `assert/$fatal` or equivalent, randomized-independent clock-edge sampling, a hard timeout, and nonzero exit on failure. Do not rely on a printed PASS or a zero-error compile alone.

**TMR-VER-002:** Implement a genuinely independent UVM APB driver, monitor, reference model/scoreboard, and coverage subscriber. The model computes tick, mode, prescaler, interrupt pending, capture qualification and APB semantics from this spec, not by reading internal DUT counters/events. APB transaction readbacks and pin/IRQ observables must be compared at defined sampling times. UVM input stimulus must vary `capture_i` independently of APB operations, including concurrency.

**TMR-VER-003:** Tests must check exact **PCLK edge counts**, not only eventual events. Use a clocking block or well-defined sampling region; avoid testbench races at posedge with synchronous DUT logic. Explicitly test PRESCALE 0, 1, 2, 255, and 65535 (high-value prescaler may use short edge-to-tick test instead of long periodic full-loop).

**TMR-VER-004:** Use both directed tests and constrained-random APB sequences. UVM shall collect meaningful register/address, PSTRB, PPROT, mode, prescaler class, event type, masking, capture-edge selection, IRQ collision and error-response bins. Coverage of illegal modes must come from attempted invalid writes without corrupting state. Show required bins hit/total and unhit cases, not only a global percentage.

**TMR-VER-005:** Verification must check that the UVM driver/monitor are not silently missing transactions, that scoreboard mismatches cause nonzero process status, and that a functional coverage sampling event corresponds to a real tested transaction/event. A line of testbench code or a test ID in a comment is not an executed test.

**TMR-VER-006:** Perform at least three temporary mutation tests: (a) change periodic match at COUNT==PERIOD to COUNT==PERIOD-1; (b) disable hardware-SET-over-W1C priority; (c) invert rising-edge capture condition. Each must cause a relevant self-checking regression FAIL. Restore original RTL between mutations and verify clean Git status for mutations.

**TMR-VER-007:** Run at least three reproducible fixed UVM seeds (e.g. 1, 7, 23), directed testbench, lint, and code/functional coverage. More seeds are useful only if they exercise a documented risk. No arbitrary 100% code/branch/toggle threshold is required; every *mandatory reachable functional behavior* must be tested or explicitly reviewed/waived. Known major functional bugs are never waived solely to meet the schedule.

### 10.1 Mandatory directed test catalog (IDs are immutable)

Each T-number below must map to a real named test/check and have individual PASS / FAIL / NOT RUN evidence; do not relabel or regroup them to make the report look complete.

| Test | Required stimulus and observation |
|---|---|
| T01 | Assert reset between PCLK edges; check every register, output and pending bit resets, including capture and prescale phase observable via subsequent ticks. |
| T02 | ACCESS-only/SETUP-only requester behavior: no register write in SETUP; valid SETUP+ACCESS writes once; BFM flags illegal phases. |
| T03 | Read/write all eight mapped registers as applicable; verify reset, permissions, reserved-bit zeroing, and stable TIMER_INFO. |
| T04 | Exercise all 16 PSTRB masks on CONTROL/COUNT/PERIOD/PRESCALE/IRQ_ENABLE, plus zero-strobe no-op while running. |
| T05 | Test every invalid address category including 0x0020, 0x0100, 0x1000, 0x1FFC; no alias, no side effects. |
| T06 | Misaligned read/write; RO write attempts; nonzero PSTRB on read (separate malformed-requester case); proper PSLVERR. |
| T07 | All 8 PPROT encodings on otherwise identical legal accesses, no spurious privilege restriction. |
| T08 | Stop-to-start, start-to-stop on APB ACCESS edges; exact start/stop tick suppression and prescale restart. |
| T09 | PRESCALE=0 and PERIOD=2 in periodic mode; exact COUNT sequence and MATCH event at third tick. |
| T10 | PRESCALE=2, PERIOD=2; first tick exactly 3 cycles after enable, match at 9 cycles. |
| T11 | PERIOD=0 periodic: match each prescaled tick; COUNT remains 0, pending stays sticky. |
| T12 | One-shot from 0 with PERIOD=2: final COUNT=2, EN auto-clear after third tick, no further ticks/events. |
| T13 | One-shot re-enable after expiry from COUNT=PERIOD: match at first new tick; COUNT=0 software reload produces full interval. |
| T14 | Free-run COUNT near FFFF_FFFF wraps modulo 2^32; WRAP only at wrap; compare MATCH independent of wrap. |
| T15 | Free-run PERIOD=FFFF_FFFF and COUNT=FFFF_FFFF: MATCH and WRAP set on same tick. |
| T16 | COUNT>PERIOD while disabled allowed; enabling periodic/one-shot errors atomically; free-run allows same COUNT/PERIOD. |
| T17 | Writes to COUNT/PERIOD/PRESCALE while running are errors, with zero-strobe write as no-op and continuing timer tick. |
| T18 | MODE/CAP_* changes while enabled error even with simultaneous stop request; stop first, then reconfigure succeeds. |
| T19 | Masked MATCH/WRAP pending retained; subsequent IRQ_ENABLE write asserts IRQ without new event; IRQ deasserts on mask disable but pending remains. |
| T20 | W1C clears only strobed written-one IRQ bits; reads never clear; multiple pending causes independently clearable. |
| T21 | MATCH and W1C collision on same completion edge: hardware SET wins, and timer continues correct count behavior. |
| T22 | Capture rising/falling/either selection, including no capture for rejected edge polarity and baseline after reset. |
| T23 | Capture timestamp on same edge as timer tick equals **COUNT_old**; first capture held while CAPTURE pending remains 1. |
| T24 | Second capture sets CAP_OVERRUN, does not overwrite CAPTURE_VALUE; W1C rearm and simultaneous clear/capture collision priority. |
| T25 | Capture transitions while disabled, capture disabled, or initial three clocks after reset do not cause events. |
| T26 | Assert async reset while timer runs / capture pending / APB activity; restart without false capture or IRQ. |
| T27 | Back-to-back legal APB SETUP+ACCESS transfers while time advances and capture input changes, no dropped/double commits. |
| T28 | Unmapped/invalid/RO writes even with PSTRB=0000 error atomically; illegal CONTROL encodings return error. |
| T29 | Randomized independent APB traffic, capture edges and masks with multiple fixed seeds; scoreboard reports zero unexpected mismatches and all assertions execute. |
| T30 | Demonstrate nonzero Makefile exit on one temporary test failure and verify all three mutation experiments are detected. |

### 10.2 Minimum functional coverage categories

**TMR-COV-001:** Register: each legal mapped register read, writable registers written; RO-write, invalid/unmapped/misaligned and running-state errors, plus PSTRB 0 and full-mask and lane-specific values. Include meaningful PPROT coverage but avoid cross-products with irrelevant combinations.

**TMR-COV-002:** Modes/periods: periodic, one-shot, free-run; period 0, small, FFFF_FFFF; prescale zero, small, boundary; start, pause, re-enable, one-shot expiration, free-run wrap; collision scenarios.

**TMR-COV-003:** IRQ: all 4 causes asserted, observed masked/unmasked, independently W1C cleared; MATCH-vs-W1C priority; concurrent causes; IRQ output high and low.

**TMR-COV-004:** Capture: rising/falling/either modes, event suppression during reset baseline and stopped state, capture old COUNT, first-hit retention, overrun, rearm, capture-vs-W1C collision.

**TMR-COV-005:** Report real bin totals and specific uncovered behaviors. Exclusions/waivers need human rationale; zero untested critical mandatory behavior is required for standalone freeze, **not** mathematically maximal code coverage.

## 11. Bounded execution plan for Nex

Run this work in order. Implementation freedom is allowed; external behavior and evidence are not negotiable.

**Phase A: inspect (quickly).** Confirm tree/branch, `NEX.md`, existing GPIO APB design patterns, `bus/include/apb4_if.sv`, `sync_2ff.sv`, current Makefile practices, and missing/incomplete team files. Do not study legacy AFT RTL or soon-to-be-discarded `riscv/`/`core/` source as a functional baseline. Record any deviation from this contract. Do not stop solely because CPU/bus are unfinished.

**Phase B: implement.** GPIO development is occurring concurrently. Use a **separate Git worktree**; never switch branches, clean files, or run builds in the checkout used by the GPIO agent. Prefer a stacked `feat/timer-peripheral` branch based on the **committed** `feat/gpio-peripheral` tip (which already contains provisional `apb4_if.sv` and `sync_2ff.sv`), not on uncommitted GPIO changes. If the branch is not available locally, check remote refs and fetch the known branch; do not recreate shared files from memory. Document that Timer is temporarily based on GPIO and may require a later reviewed rebase when GPIO merges. Add this spec, the `timer_apb` synthesizable RTL, correct bus/sync reuse, and an initial directed TB; commit coherent milestones. Keep the register ABI immutable during tests.

**Phase C: verify.** Establish Questa 2021.4 compilation and runtime early. In the *first* build, ensure `apb4_if.sv` is compiled as source before consumers; do not wait until after writing the whole UVM. Add actual UVM components with config-db connectivity. Run `make sim_tb` and `make sim` on the real intended top modules. Fix actual failures before generating coverage; never claim a license failure without environment evidence.

**Phase D: targeted closure.** Implement missing T01..T30 checks, run bounded fixed-seed regression, true compilation-time code coverage, functional coverage, lint, mutation experiments. Fix mandatory failures. Do not chase cosmetic 100% coverage or add unrequested features indefinitely.

**Phase E: standalone freeze candidate.** Create truthful `peripherals/timer/SIGNOFF.md` and report actual tests/coverage/unresolved issues, one requirement per trace row and one T-ID per test row. Finish with `READY FOR STANDALONE RTL FREEZE` or `NOT READY`, not `tapeout ready`. Do not claim synthesis/STA/layout signoff when those flows/tools aren't configured.

## 12. Acceptance / stopping rule

**TMR-ACC-001:** Standalone freeze may be recommended after: (a) all mapped register operations and errors have true checker evidence; (b) prescaler, every counter mode, capture and IRQ collision behavior have self-checking passing tests; (c) T01-T30 and required functional coverage are traceable and completed, or any minor exclusions are independently reviewed with rationale; (d) no known critical/major RTL/protocol bug; (e) lint and actual Questa directed+UVM regression pass; and (f) code is independently reviewed at least once. The agent must not grant itself independent review or tapeout signoff.

**TMR-ACC-002:** If blocked, report *specific* reproducible failure, command, tool/version, exact log and needed human action. Continue productive local tests when another tool is blocked. If Questa UVM is unavailable to Nex but works for user, report environment discrepancy, do not permanently replace Questa with Verilator or call it an inherent license unavailability.

**TMR-ACC-003:** Once standalone criteria are met, stop working on Timer and move to next critical-path peripheral. Integration and physical signoff are tracked separately; no requirement to reach 100% statement/branch/toggle coverage or invent additional modes/features merely to delay freeze.

## 13. Final reporting template (required)

In `SIGNOFF.md` include:

1. **Version:** Git commit hashes and files changed, branch, declared functional scope, exact register ABI.
2. **Evidence:** tool versions, full `make` commands and saved logs, pass/fail counts, seeds, assertion counts and simulator exit results. Show real APB/UVM failures if encountered and fixes.
3. **Traceability:** one row for each `TMR-*` mandatory requirement and each T01-T30 (`RTL file:line`, `TB file:line`, `executed test`, `PASS/FAIL/NOT RUN`, `observed evidence`). Do not group tests or write `PASS (Static)` for runtime behavioral requirements.
4. **Coverage:** code coverage statement/branch/expression/toggle separately, UVM functional coverage bins hit/total, important missing coverage with disposition. Do not report meaningless UCDBs as coverage.
5. **Defect history:** independent model catches, resolved functional bugs, mutation tests with observed fail logs; current known bugs and risk categorization.
6. **Integration gates:** IG-T01..IG-T08 OPEN/CLOSED and named owner; unfinished CPU/bus/PLIC/I/O mux and physical flow marked OPEN.
7. **Recommendation:** `READY FOR STANDALONE RTL FREEZE` or `NOT READY`, with evidence and human-review requirement; never assert blanket tapeout readiness.

## 14. Human decisions locked for standalone

The following are **new, explicit AiFTx design decisions** for this bounded task, made to allow Nex to proceed without repeated permission requests. They may be changed later only through a reviewed spec/ABI change:

- One 32-bit Timer0; nominal PCLK 12.5 MHz; APB4 with full 13-bit local offset; no internal bridge.
- Three modes: periodic, one-shot, free-run; 16-bit prescaler; four interrupt causes; one synchronized capture input; no compare output or PWM output.
- 8-word register ABI at 0x0000..0x001C; all other local offsets are unmapped; simple 0-wait APB4 completer.
- Hardware events SET dominate W1C; first capture remains latched until capture pending clear; capture-overrun is separately sticky.
- Writes to COUNT/PERIOD/PRESCALE and CONTROL configuration are restricted while enabled; mode/edge invalid encodings error; IRQ configuration remains writable while running.
- Asynchronous reset assertion and externally synchronized PCLK-domain reset release; no derived clocks or unsynchronized capture path into counter state.
- `apb4_if.sv` is **provisional shared integration infrastructure**, not authority for global bus decisions. Never duplicate it privately.

**End of timer specification.**
